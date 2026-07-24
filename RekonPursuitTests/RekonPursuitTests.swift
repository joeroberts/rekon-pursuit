import XCTest
@testable import RekonPursuit

final class RekonPursuitTests: XCTestCase {
    func testBootstrapCopyDescribesLocalOnlyFoundation() {
        XCTAssertEqual(BootstrapCopy.status, "Local-only foundation")
    }

    func testFixtureManifestContainsEveryM1RequiredFixture() throws {
        let manifest = try FixtureManifest.load(from: Bundle(for: Self.self))

        XCTAssertEqual(manifest.schemaVersion, 1)
        XCTAssertEqual(Set(manifest.fixtures.map(\.id)), FixtureManifest.requiredM1FixtureIDs)
        XCTAssertTrue(manifest.fixtures.allSatisfy { fixture in
            fixture.provenance == "synthetic" &&
                !fixture.fixedClock.isEmpty &&
                !fixture.fixedIDSeed.isEmpty &&
                !fixture.fixedRandomSeed.isEmpty &&
                !fixture.expectedResult.isEmpty &&
                fixture.path.hasPrefix("fixtures/")
        })
    }

    func testFixtureManifestRejectsDuplicateIDs() {
        let fixture = FixtureManifest.Fixture(
            id: "WS-EMPTY-001", schemaVersion: 1, provenance: "synthetic",
            fixedClock: "2024-01-01T00:00:00Z", fixedIDSeed: "seed",
            fixedRandomSeed: "seed", path: "fixtures/WS-EMPTY-001", expectedResult: "ok"
        )
        let manifest = FixtureManifest(schemaVersion: 1, fixtures: Array(repeating: fixture, count: 22))

        XCTAssertThrowsError(try FixtureManifest.validate(manifest))
    }

    func testFixtureManifestRejectsTraversalPath() {
        let fixtures = FixtureManifest.requiredM1FixtureIDs.sorted().map { id in
            FixtureManifest.Fixture(
                id: id, schemaVersion: 1, provenance: "synthetic",
                fixedClock: "2024-01-01T00:00:00Z", fixedIDSeed: id,
                fixedRandomSeed: id,
                path: id == "WS-EMPTY-001" ? "fixtures/../../outside" : "fixtures/\(id)",
                expectedResult: "ok"
            )
        }

        XCTAssertThrowsError(try FixtureManifest.validate(FixtureManifest(schemaVersion: 1, fixtures: fixtures)))
    }

    func testHarnessDefaultsToOfflineAndNoXPCLaunch() throws {
        let harness = try TestHarness.make()

        XCTAssertEqual(harness.http.attemptedRequests, [])
        XCTAssertEqual(harness.xpc.launches, 0)
        try harness.tearDown()
    }

    func testDefaultDenyHTTPRecordsRejectedRequest() {
        let http = DefaultDenyHTTP()
        let request = "https://jobs.fixture.rekon.test/open"

        XCTAssertThrowsError(try http.send(request))
        XCTAssertEqual(http.attemptedRequests, [request])
    }

    func testHarnessConfinementTeardownAndDeterministicValues() throws {
        let first = try TestHarness.make(seed: "fixture-seed")
        let second = try TestHarness.make(seed: "fixture-seed")
        defer {
            try? first.tearDown()
            try? second.tearDown()
        }

        XCTAssertEqual(first.clock.now, second.clock.now)
        XCTAssertEqual(first.ids.next(), second.ids.next())
        XCTAssertEqual(first.random.nextBytes(count: 4), second.random.nextBytes(count: 4))
        XCTAssertTrue(first.fileStore.isConfined(first.root.appendingPathComponent("state.json")))
        XCTAssertFalse(first.fileStore.isConfined(URL(fileURLWithPath: "/tmp/outside-state.json")))

        try first.tearDown()
        XCTAssertFalse(FileManager.default.fileExists(atPath: first.root.path))
    }

    func testHarnessInjectsFilesystemFaultsAndIsolatesKeychain() throws {
        let harness = try TestHarness.make()
        defer { try? harness.tearDown() }
        let faultingStore = TestFileStore(root: harness.root, faultMode: .diskFull)

        XCTAssertThrowsError(try faultingStore.write(Data("x".utf8), relativePath: "fixture.bin"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: harness.root.appendingPathComponent("fixture.bin").path))
        try harness.keychain.write(Data("value".utf8), for: "fixture")
        XCTAssertEqual(try harness.keychain.read("fixture"), Data("value".utf8))
        harness.keychain.state = .locked
        XCTAssertThrowsError(try harness.keychain.read("fixture"))
    }

    func testHarnessUsesFixedLocaleAndUTC() throws {
        let harness = try TestHarness.make()
        defer { try? harness.tearDown() }

        XCTAssertEqual(harness.localeTimeZone.locale.identifier, "en_US_POSIX")
        XCTAssertEqual(harness.localeTimeZone.timeZone.secondsFromGMT(), 0)
    }
}
