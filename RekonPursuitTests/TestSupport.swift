import Foundation

struct FixtureManifest: Decodable {
    struct Fixture: Decodable {
        let id: String
        let schemaVersion: Int
        let provenance: String
        let fixedClock: String
        let fixedIDSeed: String
        let fixedRandomSeed: String
        let path: String
        let expectedResult: String
    }

    let schemaVersion: Int
    let fixtures: [Fixture]

    static let requiredM1FixtureIDs: Set<String> = [
        "WS-EMPTY-001", "WS-CORE-001", "WS-READONLY-001", "MIGRATE-NMINUS1-001",
        "MIGRATE-FAIL-001", "DB-CORRUPT-001", "BACKUP-VALID-001", "BACKUP-CORRUPT-001",
        "BACKUP-SWAP-001", "RESTORE-KEYCHAIN-001", "RESTORE-CLEANMAC-001", "RECOVERY-ENROLL-001",
        "RECOVERY-MISSING-001", "DELETE-LOGICAL-001", "DELETE-QUEUED-WORK-001", "BACKUP-RETENTION-001",
        "BACKUP-PURGE-001", "EXPORT-ENCRYPTED-001", "EXPORT-UNENCRYPTED-001", "EXPORT-CANCELLED-001",
        "LIFECYCLE-REDACTION-001", "RECON-OFFLINE-001"
    ]

    static func load(from bundle: Bundle) throws -> FixtureManifest {
        guard let url = bundle.url(forResource: "fixture-manifest", withExtension: "json") else {
            throw HarnessError.missingFixtureManifest
        }
        let manifest = try JSONDecoder().decode(FixtureManifest.self, from: Data(contentsOf: url))
        try validate(manifest)
        return manifest
    }

    static func validate(_ manifest: FixtureManifest) throws {
        guard manifest.schemaVersion == 1,
              manifest.fixtures.count == requiredM1FixtureIDs.count,
              Set(manifest.fixtures.map(\.id)) == requiredM1FixtureIDs else {
            throw HarnessError.invalidFixtureManifest
        }

        for fixture in manifest.fixtures {
            guard fixture.schemaVersion == 1,
                  fixture.provenance == "synthetic",
                  !fixture.fixedClock.isEmpty,
                  !fixture.fixedIDSeed.isEmpty,
                  !fixture.fixedRandomSeed.isEmpty,
                  fixture.path == "fixtures/\(fixture.id)",
                  !fixture.expectedResult.isEmpty else {
                throw HarnessError.invalidFixtureManifest
            }
        }
    }
}

enum HarnessError: Error {
    case missingFixtureManifest
    case invalidFixtureManifest
    case networkDenied
    case outsideTestRoot
    case injectedFault
    case keychainUnavailable
}

struct FixedClock {
    let now = Date(timeIntervalSince1970: 1_704_067_200) // 2024-01-01T00:00:00Z
}

final class DeterministicIDs {
    private let seed: String
    private var counter = 0

    init(seed: String) { self.seed = seed }

    func next() -> String {
        defer { counter += 1 }
        return "\(seed)-id-\(counter)"
    }
}

final class DeterministicRandom {
    private let seed: [UInt8]
    private var offset = 0

    init(seed: String) { self.seed = Array(seed.utf8) }

    func nextBytes(count: Int) -> [UInt8] {
        guard count > 0 else { return [] }
        defer { offset += count }
        return (0..<count).map { index in
            seed[(offset + index) % seed.count]
        }
    }
}

enum FileSystemFaultMode: Equatable {
    case none
    case diskFull
    case interrupted
    case permissionDenied
    case corrupt
}

struct TestFileStore {
    let root: URL
    var faultMode: FileSystemFaultMode = .none

    func isConfined(_ url: URL) -> Bool {
        let canonicalRoot = root.standardizedFileURL.path + "/"
        return url.standardizedFileURL.path.hasPrefix(canonicalRoot)
    }

    func checkedURL(relativePath: String) throws -> URL {
        let url = root.appendingPathComponent(relativePath).standardizedFileURL
        guard isConfined(url) else { throw HarnessError.outsideTestRoot }
        return url
    }

    func write(_ data: Data, relativePath: String) throws {
        let url = try checkedURL(relativePath: relativePath)
        guard faultMode == .none else { throw HarnessError.injectedFault }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}

enum FakeKeychainState {
    case available
    case locked
    case denied
    case missing
}

final class FakeKeychain {
    let namespace: String
    var state: FakeKeychainState = .available
    private var values: [String: Data] = [:]

    init(namespace: String) { self.namespace = namespace }

    func read(_ key: String) throws -> Data? {
        guard case .available = state else { throw HarnessError.keychainUnavailable }
        return values[key]
    }

    func write(_ value: Data, for key: String) throws {
        guard case .available = state else { throw HarnessError.keychainUnavailable }
        values[key] = value
    }

    func delete(_ key: String) throws {
        guard case .available = state else { throw HarnessError.keychainUnavailable }
        values.removeValue(forKey: key)
    }
}

struct FixedLocaleTimeZone {
    let locale = Locale(identifier: "en_US_POSIX")
    let timeZone = TimeZone(secondsFromGMT: 0)!
}

final class DefaultDenyHTTP {
    private(set) var attemptedRequests: [String] = []

    func send(_ request: String) throws {
        attemptedRequests.append(request)
        throw HarnessError.networkDenied
    }
}

final class FakeXPC {
    private(set) var launches = 0

    func recordLaunch() { launches += 1 }
}

final class FakeLifecycleCoordinator {
    private(set) var relaunches = 0

    func recordRelaunch() { relaunches += 1 }
}

final class TestHarness {
    let root: URL
    let clock = FixedClock()
    let localeTimeZone = FixedLocaleTimeZone()
    let ids: DeterministicIDs
    let random: DeterministicRandom
    let fileStore: TestFileStore
    let keychain: FakeKeychain
    let http = DefaultDenyHTTP()
    let xpc = FakeXPC()
    let lifecycle = FakeLifecycleCoordinator()

    private init(root: URL, seed: String) {
        self.root = root
        self.ids = DeterministicIDs(seed: seed)
        self.random = DeterministicRandom(seed: seed)
        self.fileStore = TestFileStore(root: root)
        self.keychain = FakeKeychain(namespace: "test.\(root.lastPathComponent)")
    }

    static func make(seed: String = "m0-fixture") throws -> TestHarness {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("rekon-pursuit-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        return TestHarness(root: root, seed: seed)
    }

    func tearDown() throws {
        guard http.attemptedRequests.isEmpty, xpc.launches == 0 else { throw HarnessError.networkDenied }
        try FileManager.default.removeItem(at: root)
    }
}
