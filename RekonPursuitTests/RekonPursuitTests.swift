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
}
