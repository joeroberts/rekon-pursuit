import CryptoKit
import Foundation
import Security

nonisolated struct PortableArchiveService {
    static let formatVersion: UInt16 = 1
    private static let magic = Data("RPARCH01".utf8)
    private static let payloadMagic = Data("RPPAYLD1".utf8)
    private static let headerLength: UInt32 = 317
    private static let wrappingInfo = Data("RekonPursuit/portable-archive/wrapping-key/v1".utf8)
    private static let headerDomain = Data("RekonPursuit/portable-archive/header-commitment/v1\0".utf8)
    private static let signatureDomain = Data("RekonPursuit/portable-archive/signature/v1\0".utf8)
    private static let payloadDomain = Data("RekonPursuit/portable-archive/payload/v1\0".utf8)

    static func writeAndVerify(snapshot: Data, recoveryKey: RecoveryKey, signingKey: Curve25519.Signing.PrivateKey, archiveID: UUID, createdAt: Date, to temporaryURL: URL) throws -> VerifiedPortableArchive {
        guard snapshot.count <= 480 * 1024 * 1024 else { throw PortableArchiveError.archiveInvalid }
        let createdAtMilliseconds = milliseconds(createdAt)
        let canonicalCreatedAt = Date(timeIntervalSince1970: Double(createdAtMilliseconds) / 1_000)
        let expiration = canonicalCreatedAt.addingTimeInterval(30 * 24 * 60 * 60)
        let manifest = manifestBytes(archiveID: archiveID, createdAt: canonicalCreatedAt, snapshot: snapshot)
        let manifestHash = Data(SHA256.hash(data: manifest))
        let contentKey = try randomBytes(32)
        let salt = try randomBytes(32)
        let payload = try sealPayload(manifest: manifest, snapshot: snapshot, key: contentKey, archiveID: archiveID, manifestHash: manifestHash)
        let checksum = Data(SHA256.hash(data: payload))
        let publicKey = signingKey.publicKey.rawRepresentation
        let fingerprint = Data(SHA256.hash(data: publicKey))
        let commitment = headerCommitment(archiveID: archiveID, createdAt: canonicalCreatedAt, expiresAt: expiration, salt: salt, manifestHash: manifestHash, payloadChecksum: checksum, publicKey: publicKey, fingerprint: fingerprint)
        let wrappingKey = HKDF<SHA256>.deriveKey(inputKeyMaterial: SymmetricKey(data: recoveryKey.operationBytes), salt: salt, info: wrappingInfo, outputByteCount: 32)
        guard let envelope = try AES.GCM.seal(contentKey, using: wrappingKey, authenticating: commitment).combined else { throw PortableArchiveError.archiveInvalid }
        guard envelope.count == 60 else { throw PortableArchiveError.archiveInvalid }
        let signature = try signingKey.signature(for: signatureDomain + commitment + envelope)
        guard signature.count == 64 else { throw PortableArchiveError.archiveInvalid }
        var file = magic
        file.appendUInt16(formatVersion); file.appendUInt32(headerLength)
        file.append(archiveID.rawBytes)
        file.appendInt64(createdAtMilliseconds)
        file.appendInt64(milliseconds(expiration))
        file.append(1)
        file.append(salt)
        file.append(manifestHash)
        file.append(checksum)
        file.append(publicKey)
        file.append(fingerprint)
        file.append(envelope)
        file.append(signature)
        let expectedHeaderFileLength = magic.count + 2 + 4 + Int(headerLength)
        guard file.count == expectedHeaderFileLength else { throw PortableArchiveError.archiveInvalid }
        file.appendUInt64(UInt64(payload.count)); file.append(payload)
        try file.write(to: temporaryURL, options: [.withoutOverwriting])
        let verified = try verify(data: Data(contentsOf: temporaryURL), recoveryKey: recoveryKey)
        guard verified.archiveID == archiveID,
              milliseconds(verified.createdAt) == createdAtMilliseconds,
              milliseconds(verified.expiresAt) == milliseconds(expiration),
              verified.ciphertextChecksum == checksum,
              verified.signingKeyFingerprint == fingerprint else {
            throw PortableArchiveError.verificationFailed
        }
        return verified
    }

    @discardableResult
    static func verify(data: Data, recoveryKey: RecoveryKey) throws -> VerifiedPortableArchive {
        try readVerifiedArchive(data: data, recoveryKey: recoveryKey).archive
    }

    static func readVerifiedArchive(data: Data, recoveryKey: RecoveryKey) throws -> PortableArchiveContents {
        var reader = ArchiveReader(data)
        guard try reader.take(8) == magic, try reader.uint16() == formatVersion, try reader.uint32() == headerLength else { throw PortableArchiveError.archiveInvalid }
        let header = try reader.take(Int(headerLength))
        var h = ArchiveReader(header)
        let archiveID = try h.uuid(); let createdAt = try h.int64(); let expiresAt = try h.int64(); guard try h.byte() == 1 else { throw PortableArchiveError.archiveInvalid }
        guard expiresAt == createdAt + 30 * 24 * 60 * 60 * 1000 else { throw PortableArchiveError.archiveInvalid }
        let salt = try h.take(32); let manifestHash = try h.take(32); let checksum = try h.take(32); let publicKey = try h.take(32); let fingerprint = try h.take(32); let envelope = try h.take(60); let signature = try h.take(64)
        guard h.isAtEnd, Data(SHA256.hash(data: publicKey)) == fingerprint else { throw PortableArchiveError.archiveInvalid }
        let commitment = headerCommitment(archiveID: archiveID, createdAt: Date(timeIntervalSince1970: Double(createdAt) / 1000), expiresAt: Date(timeIntervalSince1970: Double(expiresAt) / 1000), salt: salt, manifestHash: manifestHash, payloadChecksum: checksum, publicKey: publicKey, fingerprint: fingerprint)
        guard try Curve25519.Signing.PublicKey(rawRepresentation: publicKey).isValidSignature(signature, for: signatureDomain + commitment + envelope) else { throw PortableArchiveError.verificationFailed }
        let payloadLength = try reader.uint64(); guard payloadLength >= 28, payloadLength <= 512 * 1024 * 1024, payloadLength == UInt64(reader.remaining) else { throw PortableArchiveError.archiveInvalid }
        let payload = try reader.take(Int(payloadLength)); guard reader.isAtEnd, Data(SHA256.hash(data: payload)) == checksum else { throw PortableArchiveError.verificationFailed }
        let wrapping = HKDF<SHA256>.deriveKey(inputKeyMaterial: SymmetricKey(data: recoveryKey.operationBytes), salt: salt, info: wrappingInfo, outputByteCount: 32)
        let contentKey = try AES.GCM.open(AES.GCM.SealedBox(combined: envelope), using: wrapping, authenticating: commitment)
        var payloadReader = ArchiveReader(try AES.GCM.open(AES.GCM.SealedBox(combined: payload), using: SymmetricKey(data: contentKey), authenticating: payloadDomain + archiveID.rawBytes + uint16Data(formatVersion) + manifestHash))
        guard try payloadReader.take(8) == payloadMagic else { throw PortableArchiveError.archiveInvalid }
        let manifestLength = try payloadReader.uint32(); let snapshotLength = try payloadReader.uint64()
        guard manifestLength <= 8 * 1024 * 1024, snapshotLength <= 480 * 1024 * 1024, Int(manifestLength) + Int(snapshotLength) == payloadReader.remaining else { throw PortableArchiveError.archiveInvalid }
        let manifest = try payloadReader.take(Int(manifestLength)); let snapshot = try payloadReader.take(Int(snapshotLength))
        guard payloadReader.isAtEnd, Data(SHA256.hash(data: manifest)) == manifestHash else { throw PortableArchiveError.verificationFailed }
        let declaredSnapshotHash = try validateManifest(manifest, archiveID: archiveID, createdAtMilliseconds: createdAt)
        guard declaredSnapshotHash == Data(SHA256.hash(data: snapshot)) else { throw PortableArchiveError.verificationFailed }
        try validateSnapshot(snapshot)
        let archive = VerifiedPortableArchive(
            archiveID: archiveID,
            createdAt: Date(timeIntervalSince1970: Double(createdAt) / 1_000),
            expiresAt: Date(timeIntervalSince1970: Double(expiresAt) / 1_000),
            ciphertextChecksum: checksum,
            signingKeyFingerprint: fingerprint
        )
        return PortableArchiveContents(archive: archive, snapshot: snapshot)
    }

    private static func sealPayload(manifest: Data, snapshot: Data, key: Data, archiveID: UUID, manifestHash: Data) throws -> Data {
        var plaintext = payloadMagic; plaintext.appendUInt32(UInt32(manifest.count)); plaintext.appendUInt64(UInt64(snapshot.count)); plaintext.append(manifest); plaintext.append(snapshot)
        guard let combined = try AES.GCM.seal(plaintext, using: SymmetricKey(data: key), authenticating: payloadDomain + archiveID.rawBytes + uint16Data(formatVersion) + manifestHash).combined else { throw PortableArchiveError.archiveInvalid }
        return combined
    }

    static func manifestBytes(archiveID: UUID, createdAt: Date, snapshot: Data) -> Data {
        var data = Data("RPMAN01".utf8); data.append(archiveID.rawBytes); data.appendInt64(milliseconds(createdAt)); data.append(Data(SHA256.hash(data: snapshot))); return data
    }

    private static func validateManifest(_ manifest: Data, archiveID: UUID, createdAtMilliseconds: Int64) throws -> Data {
        var reader = ArchiveReader(manifest)
        guard try reader.take(7) == Data("RPMAN01".utf8), try reader.uuid() == archiveID, try reader.int64() == createdAtMilliseconds else { throw PortableArchiveError.archiveInvalid }
        let snapshotHash = try reader.take(32)
        guard reader.isAtEnd else { throw PortableArchiveError.archiveInvalid }
        return snapshotHash
    }

    private static func validateSnapshot(_ snapshot: Data) throws {
        let expectedTables = PortableArchiveSnapshotRegistry.tables
        var reader = ArchiveReader(snapshot)
        guard try reader.take(8) == Data("RPSNAP01".utf8), try reader.uint32() == UInt32(expectedTables.count) else { throw PortableArchiveError.archiveInvalid }
        for table in expectedTables {
            guard try reader.archiveText() == table.name else { throw PortableArchiveError.archiveInvalid }
            let rowCount = try reader.uint32()
            for _ in 0..<rowCount {
                let valueCount = try reader.uint32()
                guard valueCount == UInt32(table.columns.count) else { throw PortableArchiveError.archiveInvalid }
                for index in 0..<valueCount {
                    let value = try reader.archiveValue()
                    if table.timestampColumnIndexes.contains(Int(index)) {
                        guard value.isCanonicalTimestamp else {
                            throw PortableArchiveError.archiveInvalid
                        }
                    }
                }
            }
        }
        guard reader.isAtEnd else { throw PortableArchiveError.archiveInvalid }
    }

    private static func headerCommitment(archiveID: UUID, createdAt: Date, expiresAt: Date, salt: Data, manifestHash: Data, payloadChecksum: Data, publicKey: Data, fingerprint: Data) -> Data {
        var data = headerDomain + magic; data.appendUInt16(formatVersion); data.appendUInt32(headerLength); data.append(archiveID.rawBytes); data.appendInt64(milliseconds(createdAt)); data.appendInt64(milliseconds(expiresAt)); data.append(1); data.append(salt); data.append(manifestHash); data.append(payloadChecksum); data.append(publicKey); data.append(fingerprint); return data
    }

    private static func randomBytes(_ count: Int) throws -> Data { var data = Data(repeating: 0, count: count); guard data.withUnsafeMutableBytes({ SecRandomCopyBytes(kSecRandomDefault, count, $0.baseAddress!) }) == errSecSuccess else { throw PortableArchiveError.archiveInvalid }; return data }
    private static func milliseconds(_ date: Date) -> Int64 { Int64((date.timeIntervalSince1970 * 1000).rounded(.towardZero)) }
}

nonisolated struct PortableArchiveContents: Sendable {
    let archive: VerifiedPortableArchive
    let snapshot: Data
}

nonisolated private struct ArchiveSnapshotValue { let tag: UInt8; let length: UInt32; var isCanonicalTimestamp: Bool { (tag == 0 && length == 0) || (tag == 1 && length == 8) } }
nonisolated private struct ArchiveReader { var data: Data; var offset = 0; init(_ data: Data) { self.data = data }; var remaining: Int { data.count - offset }; var isAtEnd: Bool { offset == data.count }; mutating func take(_ count: Int) throws -> Data { guard count >= 0, remaining >= count else { throw PortableArchiveError.archiveInvalid }; defer { offset += count }; return data.subdata(in: offset..<(offset + count)) }; mutating func byte() throws -> UInt8 { try take(1)[0] }; mutating func uint16() throws -> UInt16 { let bytes = try take(2); return UInt16(bytes[0]) << 8 | UInt16(bytes[1]) }; mutating func uint32() throws -> UInt32 { let bytes = try take(4); return bytes.reduce(0) { ($0 << 8) | UInt32($1) } }; mutating func uint64() throws -> UInt64 { let bytes = try take(8); return bytes.reduce(0) { ($0 << 8) | UInt64($1) } }; mutating func int64() throws -> Int64 { Int64(bitPattern: try uint64()) }; mutating func uuid() throws -> UUID { let bytes = try take(16); return UUID(uuid: (bytes[0],bytes[1],bytes[2],bytes[3],bytes[4],bytes[5],bytes[6],bytes[7],bytes[8],bytes[9],bytes[10],bytes[11],bytes[12],bytes[13],bytes[14],bytes[15])) }; mutating func archiveText() throws -> String { guard try byte() == 3 else { throw PortableArchiveError.archiveInvalid }; let length = try uint32(); guard let value = String(data: try take(Int(length)), encoding: .utf8) else { throw PortableArchiveError.archiveInvalid }; return value }; mutating func archiveValue() throws -> ArchiveSnapshotValue { let tag = try byte(); let length = try uint32(); guard tag <= 4 else { throw PortableArchiveError.archiveInvalid }; switch tag { case 0: guard length == 0 else { throw PortableArchiveError.archiveInvalid }; case 1, 2: guard length == 8 else { throw PortableArchiveError.archiveInvalid }; case 3: guard String(data: try take(Int(length)), encoding: .utf8) != nil else { throw PortableArchiveError.archiveInvalid }; return ArchiveSnapshotValue(tag: tag, length: length); default: break }; _ = try take(Int(length)); return ArchiveSnapshotValue(tag: tag, length: length) } }
nonisolated private extension Data { mutating func appendUInt16(_ value: UInt16) { append(contentsOf: Swift.withUnsafeBytes(of: value.bigEndian, Array.init)) }; mutating func appendUInt32(_ value: UInt32) { append(contentsOf: Swift.withUnsafeBytes(of: value.bigEndian, Array.init)) }; mutating func appendUInt64(_ value: UInt64) { append(contentsOf: Swift.withUnsafeBytes(of: value.bigEndian, Array.init)) }; mutating func appendInt64(_ value: Int64) { appendUInt64(UInt64(bitPattern: value)) } }
nonisolated private extension UUID { var rawBytes: Data { Swift.withUnsafeBytes(of: uuid) { Data($0) } } }
nonisolated private func uint16Data(_ value: UInt16) -> Data { var data = Data(); data.appendUInt16(value); return data }
