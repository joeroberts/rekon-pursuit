import XCTest
@testable import RekonPursuit

final class RekonPursuitTests: XCTestCase {
    func testBootstrapCopyDescribesLocalOnlyFoundation() {
        XCTAssertEqual(BootstrapCopy.status, "Local-only foundation")
    }
}
