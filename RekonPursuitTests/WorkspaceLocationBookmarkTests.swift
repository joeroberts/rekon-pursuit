import Foundation
import XCTest
@testable import RekonPursuit

@MainActor
final class WorkspaceLocationBookmarkTests: XCTestCase {
    func testValidateAndSavePersistsOpaqueBookmarkOnlyAfterDirectDatabaseValidation() throws {
        let fixture = BookmarkFixture()
        let priorBookmark = Data("prior-bookmark".utf8)
        fixture.bookmark = priorBookmark
        let folder = fixture.makeFolder(withDatabase: false)
        let store = fixture.makeStore()

        XCTAssertThrowsError(try store.validateAndSave(url: folder)) { error in
            XCTAssertEqual(error as? WorkspaceLocationBookmarkError, .missingWorkspaceDatabase)
        }

        XCTAssertEqual(fixture.bookmark, priorBookmark)
        XCTAssertEqual(fixture.startedURLs, [folder])
        XCTAssertEqual(fixture.stoppedURLs, [folder])
    }

    func testValidateAndSaveKeepsPriorBookmarkForAnEmptyFolder() throws {
        let fixture = BookmarkFixture()
        let priorBookmark = Data("prior-bookmark".utf8)
        fixture.bookmark = priorBookmark
        let folder = fixture.makeFolder(withDatabase: false)

        XCTAssertThrowsError(try fixture.makeStore().validateAndSave(url: folder))

        XCTAssertEqual(fixture.bookmark, priorBookmark)
    }

    func testValidateAndSaveReturnsLeaseThatBalancesTheSecurityScopeExactlyOnce() throws {
        let fixture = BookmarkFixture()
        let folder = fixture.makeFolder(withDatabase: true)
        let store = fixture.makeStore()

        let lease = try store.validateAndSave(url: folder)

        XCTAssertEqual(fixture.startedURLs, [folder])
        XCTAssertEqual(fixture.stoppedURLs, [])
        XCTAssertNotNil(fixture.bookmark)
        lease.close()
        lease.close()
        XCTAssertEqual(fixture.stoppedURLs, [folder])
    }

    func testResolveReturnsAvailableLeaseForPersistedBookmark() throws {
        let fixture = BookmarkFixture()
        let folder = fixture.makeFolder(withDatabase: true)
        let bookmark = Data("opaque-bookmark".utf8)
        fixture.bookmark = bookmark
        fixture.resolvedBookmarks[bookmark] = (folder, false)

        let resolution = fixture.makeStore().resolve()

        guard case let .available(lease) = resolution else {
            return XCTFail("Expected an available workspace lease")
        }
        XCTAssertEqual(lease.url, folder)
        lease.close()
        XCTAssertEqual(fixture.startedURLs, [folder])
        XCTAssertEqual(fixture.stoppedURLs, [folder])
    }

    func testResolveReturnsStaleForAStaleOrMissingBookmarkedFolder() throws {
        let fixture = BookmarkFixture()
        let bookmark = Data("opaque-bookmark".utf8)
        fixture.bookmark = bookmark
        fixture.resolvedBookmarks[bookmark] = (fixture.makeFolder(withDatabase: false), true)

        XCTAssertEqual(fixture.makeStore().resolve(), .stale)
        XCTAssertEqual(fixture.stoppedURLs.count, 0)
    }

    func testResolveReturnsMissingWhenNoBookmarkIsStored() {
        let fixture = BookmarkFixture()
        XCTAssertEqual(fixture.makeStore().resolve(), .missing)
    }
}

@MainActor
private final class BookmarkFixture {
    var bookmark: Data?
    var resolvedBookmarks: [Data: (URL, Bool)] = [:]
    private var validDatabaseURLs: Set<URL> = []
    private(set) var startedURLs: [URL] = []
    private(set) var stoppedURLs: [URL] = []

    func makeFolder(withDatabase: Bool) -> URL {
        let folder = URL(fileURLWithPath: "/fixture/\(UUID().uuidString)", isDirectory: true)
        if withDatabase { validDatabaseURLs.insert(folder.appendingPathComponent("workspace.sqlite")) }
        return folder
    }

    func makeStore() -> WorkspaceLocationBookmarkStore {
        WorkspaceLocationBookmarkStore(dependencies: .init(
            loadBookmark: { [weak self] in self?.bookmark },
            saveBookmark: { [weak self] bookmark in self?.bookmark = bookmark },
            createBookmark: { url in Data("bookmark:\(url.lastPathComponent)".utf8) },
            resolveBookmark: { [weak self] bookmark in
                guard let result = self?.resolvedBookmarks[bookmark] else { throw BookmarkFixtureError.unresolvable }
                return result
            },
            startAccessing: { [weak self] url in self?.startedURLs.append(url); return true },
            stopAccessing: { [weak self] url in self?.stoppedURLs.append(url) },
            containsWorkspaceDatabase: { [weak self] url in self?.validDatabaseURLs.contains(url) ?? false }
        ))
    }
}

private enum BookmarkFixtureError: Error {
    case unresolvable
}
