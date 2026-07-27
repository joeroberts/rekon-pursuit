import Foundation
import XCTest
@testable import RekonPursuit

@MainActor
final class WorkspaceLocationBookmarkTests: XCTestCase {
    func testDocumentReferenceValidationRejectsRenamedNonPDFBytes() {
        XCTAssertThrowsError(try DocumentReferenceBookmarkStore.validateContents(Data("not a PDF".utf8), pathExtension: "pdf")) { error in
            XCTAssertEqual(error as? DocumentReferenceBookmarkError, .unsupportedType)
        }
    }

    func testDocumentReferenceValidationAcceptsPDFSignatureAndRejectsOversize() throws {
        XCTAssertEqual(try DocumentReferenceBookmarkStore.validateContents(Data("%PDF-1.7".utf8), pathExtension: "pdf"), "application/pdf")
        XCTAssertThrowsError(try DocumentReferenceBookmarkStore.validateContents(Data(repeating: 0, count: DocumentReferenceBookmarkStore.maximumByteCount + 1), pathExtension: "pdf")) { error in
            XCTAssertEqual(error as? DocumentReferenceBookmarkError, .tooLarge)
        }
    }

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

    func testValidateAndSaveRetainsPriorBookmarkWhenScopeCannotStart() throws {
        let fixture = BookmarkFixture()
        let priorBookmark = Data("prior-bookmark".utf8)
        fixture.bookmark = priorBookmark
        fixture.startAccessingResult = false
        let folder = fixture.makeFolder(withDatabase: true)

        XCTAssertThrowsError(try fixture.makeStore().validateAndSave(url: folder)) { error in
            XCTAssertEqual(error as? WorkspaceLocationBookmarkError, .securityScopeUnavailable)
        }

        XCTAssertEqual(fixture.bookmark, priorBookmark)
        XCTAssertEqual(fixture.startedURLs, [folder])
        XCTAssertEqual(fixture.stoppedURLs, [])
    }

    func testValidateAndSaveRetainsPriorBookmarkWhenWorkspaceIsNotSafeForSQLiteWrites() throws {
        let fixture = BookmarkFixture()
        let priorBookmark = Data("prior-bookmark".utf8)
        fixture.bookmark = priorBookmark
        fixture.workspaceValidationError = .workspaceNotWritable
        let folder = fixture.makeFolder(withDatabase: true)

        XCTAssertThrowsError(try fixture.makeStore().validateAndSave(url: folder)) { error in
            XCTAssertEqual(error as? WorkspaceLocationBookmarkError, .workspaceNotWritable)
        }

        XCTAssertEqual(fixture.bookmark, priorBookmark)
        XCTAssertEqual(fixture.stoppedURLs, [folder])
    }

    func testValidateAndSaveRejectsSpecialOrSymbolicDatabaseBeforeReplacingBookmark() throws {
        let fixture = BookmarkFixture()
        let priorBookmark = Data("prior-bookmark".utf8)
        fixture.bookmark = priorBookmark
        fixture.workspaceValidationError = .unsafeWorkspaceDatabase
        let folder = fixture.makeFolder(withDatabase: true)

        XCTAssertThrowsError(try fixture.makeStore().validateAndSave(url: folder)) { error in
            XCTAssertEqual(error as? WorkspaceLocationBookmarkError, .unsafeWorkspaceDatabase)
        }

        XCTAssertEqual(fixture.bookmark, priorBookmark)
        XCTAssertEqual(fixture.stoppedURLs, [folder])
    }

    func testValidateAndSaveRetainsPriorBookmarkWhenPersistenceFails() throws {
        let fixture = BookmarkFixture()
        let priorBookmark = Data("prior-bookmark".utf8)
        fixture.bookmark = priorBookmark
        fixture.saveError = BookmarkFixtureError.persistenceFailed
        let folder = fixture.makeFolder(withDatabase: true)

        XCTAssertThrowsError(try fixture.makeStore().validateAndSave(url: folder)) { error in
            XCTAssertEqual(error as? WorkspaceLocationBookmarkError, .bookmarkPersistenceFailed)
        }

        XCTAssertEqual(fixture.bookmark, priorBookmark)
        XCTAssertEqual(fixture.stoppedURLs, [folder])
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

    func testResolveStopsScopeAndReturnsStaleWhenResolvedFolderNoLongerHasDatabase() {
        let fixture = BookmarkFixture()
        let bookmark = Data("opaque-bookmark".utf8)
        let folder = fixture.makeFolder(withDatabase: false)
        fixture.bookmark = bookmark
        fixture.resolvedBookmarks[bookmark] = (folder, false)

        XCTAssertEqual(fixture.makeStore().resolve(), .stale)
        XCTAssertEqual(fixture.startedURLs, [folder])
        XCTAssertEqual(fixture.stoppedURLs, [folder])
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
    var startAccessingResult = true
    var workspaceValidationError: WorkspaceLocationBookmarkError?
    var saveError: Error?
    private var validFolderPaths: Set<String> = []
    private(set) var startedURLs: [URL] = []
    private(set) var stoppedURLs: [URL] = []

    func makeFolder(withDatabase: Bool) -> URL {
        let folder = URL(fileURLWithPath: "/fixture/\(UUID().uuidString)", isDirectory: true)
        if withDatabase { validFolderPaths.insert(folder.standardizedFileURL.path) }
        return folder
    }

    func makeStore() -> WorkspaceLocationBookmarkStore {
        WorkspaceLocationBookmarkStore(dependencies: .init(
            loadBookmark: { [weak self] in self?.bookmark },
            saveBookmark: { [weak self] bookmark in
                if let error = self?.saveError { throw error }
                self?.bookmark = bookmark
            },
            createBookmark: { url in Data("bookmark:\(url.lastPathComponent)".utf8) },
            resolveBookmark: { [weak self] bookmark in
                guard let result = self?.resolvedBookmarks[bookmark] else { throw BookmarkFixtureError.unresolvable }
                return result
            },
            startAccessing: { [weak self] url in self?.startedURLs.append(url); return self?.startAccessingResult ?? false },
            stopAccessing: { [weak self] url in self?.stoppedURLs.append(url) },
            validateWorkspace: { [weak self] url in
                if let error = self?.workspaceValidationError { return error }
                return self?.validFolderPaths.contains(url.standardizedFileURL.path) == true ? nil : .missingWorkspaceDatabase
            }
        ))
    }
}

private enum BookmarkFixtureError: Error {
    case unresolvable
    case persistenceFailed
}
