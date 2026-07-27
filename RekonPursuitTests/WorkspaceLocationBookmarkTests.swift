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

    func testDocumentReferenceValidationRequiresDOCXPackageEntries() throws {
        let genericZIP = zipArchive(entries: ["note.txt": Data("[Content_Types].xml word/document.xml".utf8)])
        XCTAssertThrowsError(try DocumentReferenceBookmarkStore.validateContents(genericZIP, pathExtension: "docx"))

        let docx = zipArchive(entries: [
            "[Content_Types].xml": Data("<Types/>".utf8),
            "word/document.xml": Data("<w:document/>".utf8)
        ])
        XCTAssertEqual(try DocumentReferenceBookmarkStore.validateContents(docx, pathExtension: "docx"), "application/vnd.openxmlformats-officedocument.wordprocessingml.document")
    }

    func testDocumentReferenceCreateBalancesSecurityScope() throws {
        let fixture = DocumentBookmarkFixture(data: Data("%PDF-1.7".utf8))
        let url = URL(fileURLWithPath: "/fixture/resume.pdf")

        let result = try fixture.makeStore().create(from: url)

        XCTAssertEqual(result.bookmark, fixture.bookmark)
        XCTAssertEqual(result.contentType, "application/pdf")
        XCTAssertEqual(result.byteCount, fixture.data.count)
        XCTAssertEqual(fixture.startedURLs, [url])
        XCTAssertEqual(fixture.stoppedURLs, [url])
    }

    func testDocumentReferenceMismatchStopsSecurityScope() throws {
        let fixture = DocumentBookmarkFixture(data: Data("%PDF-1.7".utf8))
        let url = URL(fileURLWithPath: "/fixture/resume.pdf")
        let reference = DocumentReference(
            id: "reference", opportunityID: "opportunity", kind: .resume,
            filename: "resume.pdf", contentType: "application/pdf",
            sourceHash: String(repeating: "0", count: 64), byteCount: fixture.data.count,
            bookmarkData: fixture.bookmark, availability: .available,
            attachedAt: .distantPast, finalSentAt: nil
        )

        XCTAssertThrowsError(try fixture.makeStore().resolveAndVerify(reference)) { error in
            XCTAssertEqual(error as? DocumentReferenceBookmarkError, .mismatch)
        }

        XCTAssertEqual(fixture.startedURLs, [url])
        XCTAssertEqual(fixture.stoppedURLs, [url])
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

private func zipArchive(entries: [String: Data]) -> Data {
    var archive = Data()
    var centralDirectory = Data()
    var offset = 0

    for (name, contents) in entries.sorted(by: { $0.key < $1.key }) {
        let nameBytes = Data(name.utf8)
        archive.appendLE(0x04034b50, width: 4)
        archive.appendLE(20, width: 2)
        archive.appendLE(0, width: 2)
        archive.appendLE(0, width: 2)
        archive.appendLE(0, width: 2)
        archive.appendLE(0, width: 2)
        archive.appendLE(0, width: 4)
        archive.appendLE(UInt32(contents.count), width: 4)
        archive.appendLE(UInt32(contents.count), width: 4)
        archive.appendLE(UInt16(nameBytes.count), width: 2)
        archive.appendLE(0, width: 2)
        archive.append(nameBytes)
        archive.append(contents)

        centralDirectory.appendLE(0x02014b50, width: 4)
        centralDirectory.appendLE(20, width: 2)
        centralDirectory.appendLE(20, width: 2)
        centralDirectory.appendLE(0, width: 2)
        centralDirectory.appendLE(0, width: 2)
        centralDirectory.appendLE(0, width: 2)
        centralDirectory.appendLE(0, width: 2)
        centralDirectory.appendLE(0, width: 4)
        centralDirectory.appendLE(UInt32(contents.count), width: 4)
        centralDirectory.appendLE(UInt32(contents.count), width: 4)
        centralDirectory.appendLE(UInt16(nameBytes.count), width: 2)
        centralDirectory.appendLE(0, width: 2)
        centralDirectory.appendLE(0, width: 2)
        centralDirectory.appendLE(0, width: 2)
        centralDirectory.appendLE(0, width: 2)
        centralDirectory.appendLE(0, width: 4)
        centralDirectory.appendLE(UInt32(offset), width: 4)
        centralDirectory.append(nameBytes)
        offset = archive.count
    }

    let centralOffset = archive.count
    archive.append(centralDirectory)
    archive.appendLE(0x06054b50, width: 4)
    archive.appendLE(0, width: 2)
    archive.appendLE(0, width: 2)
    archive.appendLE(UInt16(entries.count), width: 2)
    archive.appendLE(UInt16(entries.count), width: 2)
    archive.appendLE(UInt32(centralDirectory.count), width: 4)
    archive.appendLE(UInt32(centralOffset), width: 4)
    archive.appendLE(0, width: 2)
    return archive
}

private extension Data {
    mutating func appendLE<T: FixedWidthInteger>(_ value: T, width: Int) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0.prefix(width)) }
    }
}

@MainActor
private final class DocumentBookmarkFixture {
    let data: Data
    let bookmark = Data("document-bookmark".utf8)
    let url = URL(fileURLWithPath: "/fixture/resume.pdf")
    private(set) var startedURLs: [URL] = []
    private(set) var stoppedURLs: [URL] = []

    init(data: Data) {
        self.data = data
    }

    func makeStore() -> DocumentReferenceBookmarkStore {
        DocumentReferenceBookmarkStore(dependencies: .init(
            createBookmark: { [bookmark] _ in bookmark },
            resolveBookmark: { [url] _ in (url, false) },
            startAccessing: { [weak self] url in self?.startedURLs.append(url); return true },
            stopAccessing: { [weak self] url in self?.stoppedURLs.append(url) },
            inspectFile: { [weak self] _ in
                guard let self else { return nil }
                return DocumentReferenceFileInspection(isRegularFile: true, byteCount: self.data.count)
            },
            readData: { [weak self] _ in self?.data ?? Data() }
        ))
    }
}
