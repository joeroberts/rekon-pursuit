import CryptoKit
import Darwin
import Foundation
import Security

/// A non-restorable logical export. This intentionally has no relationship to
/// the portable archive format, catalogue, signing key, or restore pipeline.
nonisolated enum ProtectedExportService {
    static let formatVersion: UInt16 = 1
    static let magic = Data("RPEXPT01".utf8)
    private static let payloadMagic = Data("RPEPAY01".utf8)
    private static let manifestMagic = Data("RPEMAN01".utf8)
    private static let snapshotMagic = Data("RPEXSNP1".utf8)
    private static let headerLength: UInt32 = 182
    private static let category: UInt8 = 1 // Tracker workspace data
    private static let wrappingInfo = Data("RekonPursuit/export/wrapping-key/v1".utf8)
    private static let headerDomain = Data("RekonPursuit/export/header-commitment/v1\0".utf8)
    private static let payloadDomain = Data("RekonPursuit/export/payload/v1\0".utf8)

    static func writeAndVerify(snapshot: Data, sourceRevision: Int64, recoveryKey: RecoveryKey, exportID: UUID, createdAt: Date, to temporaryURL: URL) throws -> ProtectedExportReceipt {
        guard snapshot.count <= 480 * 1024 * 1024, sourceRevision >= 0 else { throw ProtectedExportError.invalidContainer }
        let createdMilliseconds = milliseconds(createdAt)
        let manifest = manifestBytes(exportID: exportID, createdAtMilliseconds: createdMilliseconds, sourceRevision: sourceRevision, snapshot: snapshot)
        let manifestHash = Data(SHA256.hash(data: manifest))
        let contentKey = try randomBytes(32)
        let salt = try randomBytes(32)
        let payload = try sealPayload(manifest: manifest, snapshot: snapshot, contentKey: contentKey, exportID: exportID, manifestHash: manifestHash)
        let checksum = Data(SHA256.hash(data: payload))
        let commitment = headerCommitment(exportID: exportID, createdAtMilliseconds: createdMilliseconds, salt: salt, manifestHash: manifestHash, payloadChecksum: checksum)
        let wrappingKey = HKDF<SHA256>.deriveKey(inputKeyMaterial: SymmetricKey(data: recoveryKey.operationBytes), salt: salt, info: wrappingInfo, outputByteCount: 32)
        guard let envelope = try AES.GCM.seal(contentKey, using: wrappingKey, authenticating: commitment).combined, envelope.count == 60 else { throw ProtectedExportError.invalidContainer }

        var file = magic
        file.appendExportUInt16(formatVersion)
        file.appendExportUInt32(headerLength)
        file.append(exportID.exportRawBytes)
        file.appendExportInt64(createdMilliseconds)
        file.append(1) // suite AES-GCM/HKDF-SHA256
        file.append(category)
        file.append(salt)
        file.append(manifestHash)
        file.append(checksum)
        file.append(envelope)
        guard file.count == magic.count + 2 + 4 + Int(headerLength) else { throw ProtectedExportError.invalidContainer }
        file.appendExportUInt64(UInt64(payload.count))
        file.append(payload)
        try file.write(to: temporaryURL, options: [.withoutOverwriting])
        let receipt = try verify(data: Data(contentsOf: temporaryURL), recoveryKey: recoveryKey)
        guard receipt.exportID == exportID, receipt.sourceRevision == sourceRevision, receipt.manifestHash == manifestHash else { throw ProtectedExportError.verificationFailed }
        return receipt
    }

    static func verify(data: Data, recoveryKey: RecoveryKey) throws -> ProtectedExportReceipt {
        var reader = ProtectedExportReader(data)
        guard try reader.take(8) == magic,
              try reader.uint16() == formatVersion,
              try reader.uint32() == headerLength else { throw ProtectedExportError.invalidContainer }
        let header = try reader.take(Int(headerLength))
        var h = ProtectedExportReader(header)
        let exportID = try h.uuid()
        let createdAt = try h.int64()
        guard try h.byte() == 1, try h.byte() == category else { throw ProtectedExportError.invalidContainer }
        let salt = try h.take(32)
        let manifestHash = try h.take(32)
        let checksum = try h.take(32)
        let envelope = try h.take(60)
        guard h.isAtEnd else { throw ProtectedExportError.invalidContainer }
        let payloadLength = try reader.uint64()
        guard payloadLength >= 28, payloadLength <= 512 * 1024 * 1024, payloadLength == UInt64(reader.remaining) else { throw ProtectedExportError.invalidContainer }
        let payload = try reader.take(Int(payloadLength))
        guard reader.isAtEnd, Data(SHA256.hash(data: payload)) == checksum else { throw ProtectedExportError.verificationFailed }
        let commitment = headerCommitment(exportID: exportID, createdAtMilliseconds: createdAt, salt: salt, manifestHash: manifestHash, payloadChecksum: checksum)
        let wrapping = HKDF<SHA256>.deriveKey(inputKeyMaterial: SymmetricKey(data: recoveryKey.operationBytes), salt: salt, info: wrappingInfo, outputByteCount: 32)
        let contentKey = try AES.GCM.open(AES.GCM.SealedBox(combined: envelope), using: wrapping, authenticating: commitment)
        let plaintext = try AES.GCM.open(AES.GCM.SealedBox(combined: payload), using: SymmetricKey(data: contentKey), authenticating: payloadDomain + exportID.exportRawBytes + exportUInt16Data(formatVersion) + manifestHash)
        var p = ProtectedExportReader(plaintext)
        guard try p.take(8) == payloadMagic else { throw ProtectedExportError.invalidContainer }
        let manifestLength = try p.uint32(); let snapshotLength = try p.uint64()
        guard manifestLength == 73, snapshotLength <= 480 * 1024 * 1024, Int(manifestLength) + Int(snapshotLength) == p.remaining else { throw ProtectedExportError.invalidContainer }
        let manifest = try p.take(Int(manifestLength)); let snapshot = try p.take(Int(snapshotLength))
        guard p.isAtEnd, Data(SHA256.hash(data: manifest)) == manifestHash else { throw ProtectedExportError.verificationFailed }
        let sourceRevision = try validateManifest(manifest, exportID: exportID, createdAtMilliseconds: createdAt, snapshot: snapshot)
        try ProtectedExportSnapshotCodec.validate(snapshot)
        return ProtectedExportReceipt(exportID: exportID, sourceRevision: sourceRevision, manifestHash: manifestHash)
    }

    static func manifestBytes(exportID: UUID, createdAtMilliseconds: Int64, sourceRevision: Int64, snapshot: Data) -> Data {
        var data = manifestMagic
        data.append(exportID.exportRawBytes)
        data.appendExportInt64(createdAtMilliseconds)
        data.append(category)
        data.appendExportUInt64(UInt64(bitPattern: sourceRevision))
        data.append(Data(SHA256.hash(data: snapshot)))
        return data
    }

    private static func sealPayload(manifest: Data, snapshot: Data, contentKey: Data, exportID: UUID, manifestHash: Data) throws -> Data {
        var plaintext = payloadMagic
        plaintext.appendExportUInt32(UInt32(manifest.count))
        plaintext.appendExportUInt64(UInt64(snapshot.count))
        plaintext.append(manifest)
        plaintext.append(snapshot)
        guard let combined = try AES.GCM.seal(plaintext, using: SymmetricKey(data: contentKey), authenticating: payloadDomain + exportID.exportRawBytes + exportUInt16Data(formatVersion) + manifestHash).combined else { throw ProtectedExportError.invalidContainer }
        return combined
    }

    private static func validateManifest(_ manifest: Data, exportID: UUID, createdAtMilliseconds: Int64, snapshot: Data) throws -> Int64 {
        var reader = ProtectedExportReader(manifest)
        guard try reader.take(8) == manifestMagic,
              try reader.uuid() == exportID,
              try reader.int64() == createdAtMilliseconds,
              try reader.byte() == category else { throw ProtectedExportError.invalidContainer }
        let revision = try reader.int64()
        let hash = try reader.take(32)
        guard reader.isAtEnd, revision >= 0, hash == Data(SHA256.hash(data: snapshot)) else { throw ProtectedExportError.verificationFailed }
        return revision
    }

    private static func headerCommitment(exportID: UUID, createdAtMilliseconds: Int64, salt: Data, manifestHash: Data, payloadChecksum: Data) -> Data {
        var data = headerDomain + magic
        data.appendExportUInt16(formatVersion)
        data.appendExportUInt32(headerLength)
        data.append(exportID.exportRawBytes)
        data.appendExportInt64(createdAtMilliseconds)
        data.append(1); data.append(category); data.append(salt); data.append(manifestHash); data.append(payloadChecksum)
        return data
    }

    private static func randomBytes(_ count: Int) throws -> Data {
        var data = Data(repeating: 0, count: count)
        guard data.withUnsafeMutableBytes({ SecRandomCopyBytes(kSecRandomDefault, count, $0.baseAddress!) }) == errSecSuccess else { throw ProtectedExportError.randomnessUnavailable }
        return data
    }
    private static func milliseconds(_ date: Date) -> Int64 { Int64((date.timeIntervalSince1970 * 1_000).rounded(.towardZero)) }
}

nonisolated struct ProtectedExportReceipt: Equatable, Sendable {
    let exportID: UUID
    let sourceRevision: Int64
    let manifestHash: Data
}

nonisolated enum ProtectedExportError: Error, LocalizedError, Sendable {
    case enrollmentRequired, invalidRecoveryKey, invalidDestination, destinationExists, destinationUnavailable, sourceChanged, invalidContainer, verificationFailed, outputMayRemainAfterFailure, randomnessUnavailable
    var errorDescription: String? {
        switch self {
        case .enrollmentRequired: return "Set up a recovery key before exporting a protected copy."
        case .invalidRecoveryKey: return "The recovery key could not unlock this protected export."
        case .invalidDestination: return "Choose a new .rekonexport destination."
        case .destinationExists: return "Choose a new export file name; Rekon Pursuit will not overwrite an existing file."
        case .destinationUnavailable: return "Rekon Pursuit could not write to that destination. Choose another folder or file name."
        case .sourceChanged: return "Workspace data changed while you reviewed this export. Review it again before confirming."
        case .invalidContainer, .verificationFailed: return "The protected export could not be verified, so it was not saved."
        case .outputMayRemainAfterFailure: return "Final export writing or verification failed. The selected file may remain; treat it as unusable and remove it yourself."
        case .randomnessUnavailable: return "The protected export could not obtain secure random material."
        }
    }
}

/// Separate framing prevents this logical projection from being accepted by any
/// archive/restore decoder. Bookmark bytes and deletion tombstones are absent.
nonisolated enum ProtectedExportSnapshotCodec {
    static let tables = PortableArchiveSnapshotRegistry.tables.filter { $0.name != "deletion_tombstones" }

    static func encode(from database: EncryptedDatabase) throws -> Data {
        var result = Data("RPEXSNP1".utf8)
        result.appendExportUInt32(UInt32(tables.count))
        for table in tables {
            let rows = try database.rows(table.query)
            try append(.text(table.name), timestamp: false, to: &result)
            result.appendExportUInt32(UInt32(rows.count))
            for row in rows {
                guard row.count == table.columns.count else { throw ProtectedExportError.invalidContainer }
                result.appendExportUInt32(UInt32(row.count))
                for (index, value) in row.enumerated() { try append(value, timestamp: table.timestampColumnIndexes.contains(index), to: &result) }
            }
        }
        return result
    }

    static func validate(_ snapshot: Data) throws {
        var reader = ProtectedExportReader(snapshot)
        guard try reader.take(8) == Data("RPEXSNP1".utf8), try reader.uint32() == UInt32(tables.count) else { throw ProtectedExportError.invalidContainer }
        for table in tables {
            guard try reader.exportText() == table.name else { throw ProtectedExportError.invalidContainer }
            let rowCount = try reader.uint32()
            for _ in 0..<rowCount {
                guard try reader.uint32() == UInt32(table.columns.count) else { throw ProtectedExportError.invalidContainer }
                for index in 0..<table.columns.count {
                    let value = try reader.value()
                    if table.timestampColumnIndexes.contains(index), !value.isCanonicalTimestamp { throw ProtectedExportError.invalidContainer }
                }
            }
        }
        guard reader.isAtEnd else { throw ProtectedExportError.invalidContainer }
    }

    private static func append(_ value: DatabaseValue, timestamp: Bool, to data: inout Data) throws {
        if timestamp {
            switch value {
            case .null: data.append(0); data.appendExportUInt32(0)
            case let .real(seconds): data.append(1); data.appendExportUInt32(8); data.appendExportUInt64(UInt64(bitPattern: Int64((seconds * 1_000).rounded())))
            case let .integer(milliseconds): data.append(1); data.appendExportUInt32(8); data.appendExportUInt64(UInt64(bitPattern: milliseconds))
            default: throw ProtectedExportError.invalidContainer
            }
            return
        }
        switch value {
        case .null: data.append(0); data.appendExportUInt32(0)
        case let .integer(value): data.append(1); data.appendExportUInt32(8); data.appendExportUInt64(UInt64(bitPattern: value))
        case let .real(value): data.append(2); data.appendExportUInt32(8); data.appendExportUInt64(value.bitPattern)
        case let .text(value): let bytes = Data(value.utf8); data.append(3); data.appendExportUInt32(UInt32(bytes.count)); data.append(bytes)
        case let .blob(value): data.append(4); data.appendExportUInt32(UInt32(value.count)); data.append(value)
        }
    }
}

nonisolated private struct ProtectedExportValue { let tag: UInt8; let length: UInt32; var isCanonicalTimestamp: Bool { (tag == 0 && length == 0) || (tag == 1 && length == 8) } }
nonisolated private struct ProtectedExportReader {
    var data: Data; var offset = 0
    init(_ data: Data) { self.data = data }
    var remaining: Int { data.count - offset }; var isAtEnd: Bool { offset == data.count }
    mutating func take(_ count: Int) throws -> Data { guard count >= 0, remaining >= count else { throw ProtectedExportError.invalidContainer }; defer { offset += count }; return data.subdata(in: offset..<(offset + count)) }
    mutating func byte() throws -> UInt8 { try take(1)[0] }
    mutating func uint16() throws -> UInt16 { let d = try take(2); return UInt16(d[0]) << 8 | UInt16(d[1]) }
    mutating func uint32() throws -> UInt32 { try take(4).reduce(0) { ($0 << 8) | UInt32($1) } }
    mutating func uint64() throws -> UInt64 { try take(8).reduce(0) { ($0 << 8) | UInt64($1) } }
    mutating func int64() throws -> Int64 { Int64(bitPattern: try uint64()) }
    mutating func uuid() throws -> UUID { let b = try take(16); return UUID(uuid: (b[0],b[1],b[2],b[3],b[4],b[5],b[6],b[7],b[8],b[9],b[10],b[11],b[12],b[13],b[14],b[15])) }
    mutating func exportText() throws -> String { guard try byte() == 3 else { throw ProtectedExportError.invalidContainer }; let len = try uint32(); guard let value = String(data: try take(Int(len)), encoding: .utf8) else { throw ProtectedExportError.invalidContainer }; return value }
    mutating func value() throws -> ProtectedExportValue { let tag = try byte(); let length = try uint32(); guard tag <= 4 else { throw ProtectedExportError.invalidContainer }; switch tag { case 0: guard length == 0 else { throw ProtectedExportError.invalidContainer }; case 1, 2: guard length == 8 else { throw ProtectedExportError.invalidContainer }; case 3: guard String(data: try take(Int(length)), encoding: .utf8) != nil else { throw ProtectedExportError.invalidContainer }; return .init(tag: tag, length: length); default: _ = try take(Int(length)) }; return .init(tag: tag, length: length) }
}
nonisolated private extension Data { mutating func appendExportUInt16(_ value: UInt16) { append(contentsOf: Swift.withUnsafeBytes(of: value.bigEndian, Array.init)) }; mutating func appendExportUInt32(_ value: UInt32) { append(contentsOf: Swift.withUnsafeBytes(of: value.bigEndian, Array.init)) }; mutating func appendExportUInt64(_ value: UInt64) { append(contentsOf: Swift.withUnsafeBytes(of: value.bigEndian, Array.init)) }; mutating func appendExportInt64(_ value: Int64) { appendExportUInt64(UInt64(bitPattern: value)) } }
nonisolated private extension UUID { var exportRawBytes: Data { Swift.withUnsafeBytes(of: uuid) { Data($0) } } }
nonisolated private func exportUInt16Data(_ value: UInt16) -> Data { var data = Data(); data.appendExportUInt16(value); return data }
