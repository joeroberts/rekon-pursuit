import CryptoKit
import Foundation
import XCTest
@testable import RekonPursuit

@MainActor
final class WorkspaceViewModelTests: XCTestCase {
    private func makeVerifiedPortableArchive() -> VerifiedPortableArchive {
        VerifiedPortableArchive(
            archiveID: UUID(),
            createdAt: Date(timeIntervalSince1970: 1_704_067_200),
            expiresAt: Date(timeIntervalSince1970: 1_706_659_200),
            ciphertextChecksum: Data(repeating: 1, count: 32),
            signingKeyFingerprint: Data(repeating: 2, count: 32)
        )
    }

    func testPortableArchiveRestoreKeepsSecurityScopeUntilExplicitConfirmationCompletes() async throws {
        let store = try makeStore()
        let archiveURL = URL(fileURLWithPath: "/private/tmp/portable.rekonarchive")
        let recoveryKey = try RecoveryKey.generate()
        let verified = VerifiedPortableArchive(
            archiveID: UUID(),
            createdAt: Date(timeIntervalSince1970: 1_704_067_200),
            expiresAt: Date(timeIntervalSince1970: 1_706_659_200),
            ciphertextChecksum: Data(repeating: 1, count: 32),
            signingKeyFingerprint: Data(repeating: 2, count: 32)
        )
        let tracker = PortableArchiveRestoreTestTracker()
        let dependencies = PortableArchiveRestoreDependencies(
            chooseArchive: { archiveURL },
            beginAccess: { url in
                tracker.startedURLs.append(url)
                return true
            },
            endAccess: { url in tracker.stoppedURLs.append(url) },
            verify: { url, key in
                XCTAssertEqual(url, archiveURL)
                XCTAssertEqual(key, recoveryKey)
                return verified
            },
            restore: { request in
                XCTAssertEqual(request.archiveURL, archiveURL)
                XCTAssertEqual(request.confirmation, .init(archiveID: verified.archiveID, createdAt: verified.createdAt, signingKeyFingerprint: verified.signingKeyFingerprint))
                return RestoredWorkspaceCandidate(candidateID: UUID(), archiveID: verified.archiveID)
            }
        )
        let model = WorkspaceViewModel(
            openWorkspace: { .ready(store) },
            createWorkspace: { store },
            portableArchiveRestore: dependencies,
            separateLocalWorkspace: .disabledForTesting
        )
        model.start()

        model.choosePortableArchiveForRestore()
        XCTAssertEqual(model.portableArchiveRestoreState, .awaitingRecoveryKey)
        XCTAssertTrue(model.isRestoringPortableArchive)
        model.verifyPortableArchiveForRestore(recoveryKey.displayValue)
        while model.portableArchiveRestoreState != .awaitingConfirmation(verified) { await Task.yield() }

        model.confirmPortableArchiveRestore()
        while model.isRestoringPortableArchive { await Task.yield() }

        XCTAssertEqual(model.portableArchiveRestoreState, .ready(verified.archiveID))
        XCTAssertEqual(tracker.startedURLs, [archiveURL])
        XCTAssertEqual(tracker.stoppedURLs, [archiveURL])
        XCTAssertEqual(model.statusMessage, "Restored workspace ready. It remains inactive; a future workspace-open action is required.")
    }

    func testPortableArchiveRestoreDoesNotInvokeWorkerWhenSecurityScopeCannotStart() throws {
        let store = try makeStore()
        let archiveURL = URL(fileURLWithPath: "/private/tmp/inaccessible.rekonarchive")
        let tracker = PortableArchiveRestoreTestTracker()
        let dependencies = PortableArchiveRestoreDependencies(
            chooseArchive: { archiveURL },
            beginAccess: { _ in false },
            endAccess: { url in tracker.stoppedURLs.append(url) },
            verify: { _, _ in
                XCTFail("The restore worker must not run without a security scope.")
                throw PortableArchiveRestoreError.restoreFailed
            },
            restore: { _ in
                XCTFail("The restore worker must not run without a security scope.")
                throw PortableArchiveRestoreError.restoreFailed
            }
        )
        let model = WorkspaceViewModel(
            openWorkspace: { .ready(store) },
            createWorkspace: { store },
            portableArchiveRestore: dependencies,
            separateLocalWorkspace: .disabledForTesting
        )
        model.start()

        model.choosePortableArchiveForRestore()

        XCTAssertEqual(model.portableArchiveRestoreState, .idle)
        XCTAssertFalse(model.isRestoringPortableArchive)
        XCTAssertEqual(tracker.stoppedURLs, [])
        XCTAssertEqual(model.statusMessage, "The selected archive could not be accessed. Choose it again.")
    }

    func testMalformedPortableArchiveRecoveryKeyRemainsVisibleUntilDismissed() throws {
        let store = try makeStore()
        let archiveURL = URL(fileURLWithPath: "/private/tmp/malformed-key.rekonarchive")
        let tracker = PortableArchiveRestoreTestTracker()
        let dependencies = PortableArchiveRestoreDependencies(
            chooseArchive: { archiveURL },
            beginAccess: { url in tracker.startedURLs.append(url); return true },
            endAccess: { url in tracker.stoppedURLs.append(url) },
            verify: { _, _ in
                XCTFail("Malformed recovery key must not reach the worker.")
                throw PortableArchiveRestoreError.restoreFailed
            },
            restore: { _ in throw PortableArchiveRestoreError.restoreFailed }
        )
        let model = WorkspaceViewModel(
            openWorkspace: { .ready(store) },
            createWorkspace: { store },
            portableArchiveRestore: dependencies,
            separateLocalWorkspace: .disabledForTesting
        )
        model.start()

        model.choosePortableArchiveForRestore()
        model.verifyPortableArchiveForRestore("not-a-recovery-key")

        XCTAssertEqual(model.portableArchiveRestoreState, .failed(.invalidRecoveryKey))
        XCTAssertEqual(model.statusMessage, "Enter the complete recovery key, including its checksum.")
        XCTAssertEqual(tracker.stoppedURLs, [archiveURL])

        model.dismissPortableArchiveRestoreFailure()
        XCTAssertEqual(model.portableArchiveRestoreState, .idle)
    }

    func testPortableArchiveVerificationFailureRemainsVisibleUntilDismissed() async throws {
        let store = try makeStore()
        let archiveURL = URL(fileURLWithPath: "/private/tmp/unverifiable.rekonarchive")
        let recoveryKey = try RecoveryKey.generate()
        let tracker = PortableArchiveRestoreTestTracker()
        let dependencies = PortableArchiveRestoreDependencies(
            chooseArchive: { archiveURL },
            beginAccess: { url in
                tracker.startedURLs.append(url)
                return true
            },
            endAccess: { url in tracker.stoppedURLs.append(url) },
            verify: { _, _ in throw RestoreSentinelError.untrustedInput },
            restore: { _ in
                XCTFail("Restore must not begin when archive verification fails.")
                throw PortableArchiveRestoreError.restoreFailed
            }
        )
        let model = WorkspaceViewModel(
            openWorkspace: { .ready(store) },
            createWorkspace: { store },
            portableArchiveRestore: dependencies,
            separateLocalWorkspace: .disabledForTesting
        )
        model.start()

        model.choosePortableArchiveForRestore()
        model.verifyPortableArchiveForRestore(recoveryKey.displayValue)
        while model.isRestoringPortableArchive { await Task.yield() }

        XCTAssertEqual(model.portableArchiveRestoreState, .failed(.verificationFailed))
        XCTAssertEqual(model.statusMessage, "The archive could not be verified. The current workspace was not changed.")
        XCTAssertFalse(model.statusMessage.localizedCaseInsensitiveContains("sentinel"))
        XCTAssertFalse(model.statusMessage.localizedCaseInsensitiveContains("untrusted"))
        XCTAssertEqual(tracker.stoppedURLs, [archiveURL])

        model.dismissPortableArchiveRestoreFailure()
        XCTAssertEqual(model.portableArchiveRestoreState, .idle)
    }

    func testPostConfirmationFailureUsesSafeStageThenDismissAndRetryReleasesEachScopeOnce() async throws {
        let store = try makeStore()
        let existing = try store.create(CreateOpportunity(title: "Current role", company: "Example"))
        let archiveURL = URL(fileURLWithPath: "/private/tmp/post-confirmation.rekonarchive")
        let recoveryKey = try RecoveryKey.generate()
        let verified = makeVerifiedPortableArchive()
        let tracker = PortableArchiveRestoreTestTracker()
        let restoreAttempts = PortableArchiveRestoreAttemptCounter()
        let dependencies = PortableArchiveRestoreDependencies(
            chooseArchive: { archiveURL },
            beginAccess: { url in tracker.startedURLs.append(url); return true },
            endAccess: { url in tracker.stoppedURLs.append(url) },
            verify: { _, _ in verified },
            restore: { _ in
                if await restoreAttempts.next() == 1 {
                    throw PortableArchiveRestoreError.postConfirmationFailure(.preparing)
                }
                return RestoredWorkspaceCandidate(candidateID: UUID(), archiveID: verified.archiveID)
            }
        )
        let model = WorkspaceViewModel(
            openWorkspace: { .ready(store) },
            createWorkspace: { store },
            portableArchiveRestore: dependencies,
            separateLocalWorkspace: .disabledForTesting
        )
        model.start()

        model.choosePortableArchiveForRestore()
        model.verifyPortableArchiveForRestore(recoveryKey.displayValue)
        while model.portableArchiveRestoreState != .awaitingConfirmation(verified) { await Task.yield() }
        model.confirmPortableArchiveRestore()
        while model.isRestoringPortableArchive { await Task.yield() }

        XCTAssertEqual(model.portableArchiveRestoreState, .failed(.postConfirmation(.preparing)))
        XCTAssertEqual(model.statusMessage, "The restored workspace could not be prepared. The current workspace was not changed.")
        XCTAssertEqual(try store.opportunities().map(\.id), [existing.id])
        XCTAssertEqual(tracker.startedURLs, [archiveURL])
        XCTAssertEqual(tracker.stoppedURLs, [archiveURL])

        model.dismissPortableArchiveRestoreFailure()
        model.choosePortableArchiveForRestore()
        model.verifyPortableArchiveForRestore(recoveryKey.displayValue)
        while model.portableArchiveRestoreState != .awaitingConfirmation(verified) { await Task.yield() }
        model.confirmPortableArchiveRestore()
        while model.isRestoringPortableArchive { await Task.yield() }

        XCTAssertEqual(model.portableArchiveRestoreState, .ready(verified.archiveID))
        XCTAssertEqual(tracker.startedURLs, [archiveURL, archiveURL])
        XCTAssertEqual(tracker.stoppedURLs, [archiveURL, archiveURL])
    }

    func testCleanupPendingRestoreFailureStaysSafeAndNeverBecomesReady() async throws {
        let store = try makeStore()
        let archiveURL = URL(fileURLWithPath: "/private/tmp/cleanup-pending.rekonarchive")
        let recoveryKey = try RecoveryKey.generate()
        let verified = makeVerifiedPortableArchive()
        let tracker = PortableArchiveRestoreTestTracker()
        let dependencies = PortableArchiveRestoreDependencies(
            chooseArchive: { archiveURL },
            beginAccess: { url in tracker.startedURLs.append(url); return true },
            endAccess: { url in tracker.stoppedURLs.append(url) },
            verify: { _, _ in verified },
            restore: { _ in throw PortableArchiveRestoreError.candidateCleanupPending }
        )
        let model = WorkspaceViewModel(
            openWorkspace: { .ready(store) },
            createWorkspace: { store },
            portableArchiveRestore: dependencies,
            separateLocalWorkspace: .disabledForTesting
        )
        model.start()

        model.choosePortableArchiveForRestore()
        model.verifyPortableArchiveForRestore(recoveryKey.displayValue)
        while model.portableArchiveRestoreState != .awaitingConfirmation(verified) { await Task.yield() }
        model.confirmPortableArchiveRestore()
        while model.isRestoringPortableArchive { await Task.yield() }

        XCTAssertEqual(model.portableArchiveRestoreState, .failed(.cleanupPending))
        XCTAssertEqual(model.statusMessage, "Restore cleanup is pending. The current workspace was not changed.")
        XCTAssertEqual(tracker.stoppedURLs, [archiveURL])
    }

    func testCancellingAwaitedPortableArchiveVerificationReleasesScopeExactlyOnceAfterWorkerFinishes() async throws {
        let store = try makeStore()
        let archiveURL = URL(fileURLWithPath: "/private/tmp/cancel-verify.rekonarchive")
        let recoveryKey = try RecoveryKey.generate()
        let verified = makeVerifiedPortableArchive()
        let tracker = PortableArchiveRestoreTestTracker()
        let gate = PortableArchiveRestoreTestGate()
        let dependencies = PortableArchiveRestoreDependencies(
            chooseArchive: { archiveURL },
            beginAccess: { url in tracker.startedURLs.append(url); return true },
            endAccess: { url in tracker.stoppedURLs.append(url) },
            verify: { _, _ in
                await gate.wait()
                return verified
            },
            restore: { _ in throw PortableArchiveRestoreError.restoreFailed }
        )
        let model = WorkspaceViewModel(
            openWorkspace: { .ready(store) },
            createWorkspace: { store },
            portableArchiveRestore: dependencies,
            separateLocalWorkspace: .disabledForTesting
        )
        model.start()

        model.choosePortableArchiveForRestore()
        model.verifyPortableArchiveForRestore(recoveryKey.displayValue)
        await gate.waitUntilBlocked(count: 1)
        XCTAssertTrue(model.isRestoringPortableArchive)

        model.cancelPortableArchiveRestore()
        XCTAssertEqual(tracker.stoppedURLs, [], "The scope must remain held until the awaited worker exits.")
        await gate.releaseOne()
        while tracker.stoppedURLs.isEmpty { await Task.yield() }

        XCTAssertEqual(model.portableArchiveRestoreState, .idle)
        XCTAssertEqual(tracker.startedURLs, [archiveURL])
        XCTAssertEqual(tracker.stoppedURLs, [archiveURL])
    }

    func testCancellingAwaitedPortableArchiveRestoreReleasesScopeExactlyOnceAfterWorkerFinishes() async throws {
        let store = try makeStore()
        let archiveURL = URL(fileURLWithPath: "/private/tmp/cancel-restore.rekonarchive")
        let recoveryKey = try RecoveryKey.generate()
        let verified = makeVerifiedPortableArchive()
        let tracker = PortableArchiveRestoreTestTracker()
        let gate = PortableArchiveRestoreTestGate()
        let dependencies = PortableArchiveRestoreDependencies(
            chooseArchive: { archiveURL },
            beginAccess: { url in tracker.startedURLs.append(url); return true },
            endAccess: { url in tracker.stoppedURLs.append(url) },
            verify: { _, _ in verified },
            restore: { _ in
                await gate.wait()
                return RestoredWorkspaceCandidate(candidateID: UUID(), archiveID: verified.archiveID)
            }
        )
        let model = WorkspaceViewModel(
            openWorkspace: { .ready(store) },
            createWorkspace: { store },
            portableArchiveRestore: dependencies,
            separateLocalWorkspace: .disabledForTesting
        )
        model.start()

        model.choosePortableArchiveForRestore()
        model.verifyPortableArchiveForRestore(recoveryKey.displayValue)
        while model.portableArchiveRestoreState != .awaitingConfirmation(verified) { await Task.yield() }
        model.confirmPortableArchiveRestore()
        await gate.waitUntilBlocked(count: 1)

        model.cancelPortableArchiveRestore()
        XCTAssertEqual(tracker.stoppedURLs, [], "The scope must remain held until the awaited restore worker exits.")
        await gate.releaseOne()
        while tracker.stoppedURLs.isEmpty { await Task.yield() }

        XCTAssertEqual(model.portableArchiveRestoreState, .idle)
        XCTAssertEqual(tracker.startedURLs, [archiveURL])
        XCTAssertEqual(tracker.stoppedURLs, [archiveURL])
    }

    func testPortableArchiveControlsStayDisabledThroughoutAwaitedVerificationAndRestore() async throws {
        let store = try makeStore()
        let archiveURL = URL(fileURLWithPath: "/private/tmp/disabled-controls.rekonarchive")
        let recoveryKey = try RecoveryKey.generate()
        let verified = makeVerifiedPortableArchive()
        let gate = PortableArchiveRestoreTestGate()
        let dependencies = PortableArchiveRestoreDependencies(
            chooseArchive: { archiveURL },
            beginAccess: { _ in true },
            endAccess: { _ in },
            verify: { _, _ in
                await gate.wait()
                return verified
            },
            restore: { _ in
                await gate.wait()
                return RestoredWorkspaceCandidate(candidateID: UUID(), archiveID: verified.archiveID)
            }
        )
        let model = WorkspaceViewModel(
            openWorkspace: { .ready(store) },
            createWorkspace: { store },
            portableArchiveRestore: dependencies,
            separateLocalWorkspace: .disabledForTesting
        )
        model.start()

        model.choosePortableArchiveForRestore()
        model.verifyPortableArchiveForRestore(recoveryKey.displayValue)
        await gate.waitUntilBlocked(count: 1)
        XCTAssertTrue(model.isRestoringPortableArchive, "Archive creation and restore controls must remain disabled while verification awaits.")
        await gate.releaseOne()
        while model.portableArchiveRestoreState != .awaitingConfirmation(verified) { await Task.yield() }

        model.confirmPortableArchiveRestore()
        await gate.waitUntilBlocked(count: 2)
        XCTAssertTrue(model.isRestoringPortableArchive, "Archive creation and restore controls must remain disabled while restore awaits.")
        await gate.releaseOne()
        while model.isRestoringPortableArchive { await Task.yield() }
        XCTAssertEqual(model.portableArchiveRestoreState, .ready(verified.archiveID))
    }

    func testPortableArchiveBusyStateRejectsDuplicateAndWorkspaceSwitch() async throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("rekon-view-model-archive-\(UUID().uuidString).sqlite")
        defer {
            try? FileManager.default.removeItem(at: databaseURL)
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: databaseURL.path + "-wal"))
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: databaseURL.path + "-shm"))
        }
        let database = try EncryptedDatabase.open(url: databaseURL, key: Data(repeating: 4, count: 32))
        let worker = GatedPortableArchiveWorker()
        let store = try WorkspaceStore(
            database: database,
            actorID: "test",
            correlationID: "test",
            portableArchiveWorker: worker
        )
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("archive-\(UUID().uuidString).rekonarchive")
        let model = WorkspaceViewModel(
            openWorkspace: { .ready(store) },
            createWorkspace: { store },
            portableArchiveDestination: { destination },
            separateLocalWorkspace: .disabledForTesting
        )
        model.start()
        let recoveryKey = try RecoveryKey.generate()

        model.createPortableArchive(reentry: recoveryKey.displayValue)
        while !(await worker.hasStarted) {
            await Task.yield()
        }

        XCTAssertTrue(model.isCreatingPortableArchive)
        model.createPortableArchive(reentry: recoveryKey.displayValue)
        XCTAssertEqual(model.statusMessage, "A portable recovery archive is already being created.")
        model.closeWorkspace()
        XCTAssertTrue(model.workspaceReady)
        XCTAssertEqual(model.statusMessage, "Wait for portable archive creation to finish before switching workspaces.")

        await worker.release()
        while model.isCreatingPortableArchive {
            await Task.yield()
        }
        XCTAssertEqual(model.statusMessage, "Portable recovery archive verified and saved.")
    }

    func testExternalFolderLeaseIsRetainedForTheOpenedStoreThenReleasedOnClose() throws {
        let store = try makeStore()
        let bookmarkFixture = ViewModelBookmarkFixture()
        let folder = bookmarkFixture.makeFolder(withDatabase: true)
        var openedURL: URL?
        let model = WorkspaceViewModel(
            openWorkspace: { .createAvailable },
            createWorkspace: { store },
            workspaceLocationBookmarks: bookmarkFixture.makeStore(),
            openExternalWorkspace: { url in
                openedURL = url
                return .ready(store)
            },
            separateLocalWorkspace: .disabledForTesting
        )

        model.chooseExistingWorkspaceFolder(folder)

        XCTAssertEqual(openedURL, folder)
        XCTAssertTrue(model.workspaceReady)
        XCTAssertEqual(bookmarkFixture.startedURLs, [folder])
        XCTAssertEqual(bookmarkFixture.stoppedURLs, [])

        model.closeWorkspace()

        XCTAssertEqual(bookmarkFixture.stoppedURLs, [folder])
    }

    func testStaleExternalBookmarkIsRecoveryOnlyAndNeverOffersCreation() throws {
        let store = try makeStore()
        let bookmarkFixture = ViewModelBookmarkFixture()
        let bookmark = Data("stale-bookmark".utf8)
        bookmarkFixture.bookmark = bookmark
        bookmarkFixture.resolvedBookmarks[bookmark] = (bookmarkFixture.makeFolder(withDatabase: false), true)
        let model = WorkspaceViewModel(
            openWorkspace: { .createAvailable },
            createWorkspace: { store },
            workspaceLocationBookmarks: bookmarkFixture.makeStore(),
            separateLocalWorkspace: .disabledForTesting
        )

        model.start()

        XCTAssertTrue(model.workspaceRequiresRecovery)
        XCTAssertFalse(model.canCreateWorkspace)
    }

    func testCancelledExternalFolderSelectionRemainsRecoveryOnlyWithoutReplacingBookmark() throws {
        let store = try makeStore()
        let bookmarkFixture = ViewModelBookmarkFixture()
        let priorBookmark = Data("prior-bookmark".utf8)
        bookmarkFixture.bookmark = priorBookmark
        let model = WorkspaceViewModel(
            openWorkspace: { .createAvailable },
            createWorkspace: { store },
            workspaceLocationBookmarks: bookmarkFixture.makeStore(),
            separateLocalWorkspace: .disabledForTesting
        )

        model.chooseExistingWorkspaceFolder(nil)

        XCTAssertEqual(bookmarkFixture.bookmark, priorBookmark)
        XCTAssertTrue(model.workspaceRequiresRecovery)
        XCTAssertFalse(model.canCreateWorkspace)
    }

    func testExternalFolderWithoutTaskTwoKeySupportReturnsToRecoveryAndReleasesLease() throws {
        let store = try makeStore()
        let bookmarkFixture = ViewModelBookmarkFixture()
        let folder = bookmarkFixture.makeFolder(withDatabase: true)
        let model = WorkspaceViewModel(
            openWorkspace: { .createAvailable },
            createWorkspace: { store },
            workspaceLocationBookmarks: bookmarkFixture.makeStore(),
            openExternalWorkspace: { _ in .recoveryRequired },
            separateLocalWorkspace: .disabledForTesting
        )

        model.chooseExistingWorkspaceFolder(folder)

        XCTAssertTrue(model.workspaceRequiresRecovery)
        XCTAssertFalse(model.canCreateWorkspace)
        XCTAssertEqual(bookmarkFixture.startedURLs, [folder])
        XCTAssertEqual(bookmarkFixture.stoppedURLs, [folder])
    }

    func testFailedExternalStoreCloseRetainsLeaseAndSurfacesRecovery() throws {
        let store = try makeStore()
        let bookmarkFixture = ViewModelBookmarkFixture()
        let folder = bookmarkFixture.makeFolder(withDatabase: true)
        let model = WorkspaceViewModel(
            openWorkspace: { .createAvailable },
            createWorkspace: { store },
            workspaceLocationBookmarks: bookmarkFixture.makeStore(),
            openExternalWorkspace: { _ in .ready(store) },
            closeWorkspaceStore: { _ in throw WorkspaceStoreError.injectedFailure },
            separateLocalWorkspace: .disabledForTesting
        )

        model.chooseExistingWorkspaceFolder(folder)
        model.closeWorkspace()

        XCTAssertTrue(model.workspaceRequiresRecovery)
        XCTAssertFalse(model.workspaceReady)
        XCTAssertEqual(bookmarkFixture.stoppedURLs, [])
        XCTAssertTrue(model.statusMessage.contains("could not close safely"))
    }

    func testCancelledReselectionKeepsAnActiveExternalLeaseOpen() throws {
        let store = try makeStore()
        let bookmarkFixture = ViewModelBookmarkFixture()
        let folder = bookmarkFixture.makeFolder(withDatabase: true)
        let model = WorkspaceViewModel(
            openWorkspace: { .createAvailable },
            createWorkspace: { store },
            workspaceLocationBookmarks: bookmarkFixture.makeStore(),
            openExternalWorkspace: { _ in .ready(store) },
            separateLocalWorkspace: .disabledForTesting
        )
        model.chooseExistingWorkspaceFolder(folder)

        model.chooseExistingWorkspaceFolder(nil)

        XCTAssertTrue(model.workspaceReady)
        XCTAssertEqual(bookmarkFixture.stoppedURLs, [])
        XCTAssertTrue(model.statusMessage.contains("remains open"))
    }

    func testRouteSelectionRejectsAnAbsentOpportunityWithoutMutatingTheCurrentSelection() throws {
        let store = try makeStore()
        let first = try store.create(CreateOpportunity(title: "First", company: "Rekon Labs"))
        let second = try store.create(CreateOpportunity(title: "Second", company: "Rekon Labs"))
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, separateLocalWorkspace: .disabledForTesting)

        model.start()
        let activityCountBeforeNavigation = model.activityCount
        XCTAssertTrue(model.selectRouteOpportunity(id: second.id))
        XCTAssertEqual(model.selectedOpportunityID, second.id)

        XCTAssertFalse(model.selectRouteOpportunity(id: "missing-opportunity"))

        XCTAssertEqual(model.selectedOpportunityID, second.id)
        XCTAssertEqual(model.selectedOpportunity?.id, second.id)
        XCTAssertNotEqual(model.selectedOpportunityID, first.id)
        XCTAssertEqual(model.activityCount, activityCountBeforeNavigation)
    }

    func testCreateValidationKeepsWorkspaceUnchanged() throws {
        let store = try makeStore()
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, separateLocalWorkspace: .disabledForTesting)

        model.start()
        model.createOpportunity()

        XCTAssertEqual(model.statusMessage, "Enter a job title and company.")
        XCTAssertEqual(model.opportunityCount, 0)
    }

    func testInvalidJobURLShowsAddOpportunitySaveErrorWithoutWriting() throws {
        let store = try makeStore()
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, separateLocalWorkspace: .disabledForTesting)

        model.start()
        model.title = "Product Manager"
        model.company = "Rekon Labs"
        model.jobURL = "jobs.example.com/product-manager"
        model.createOpportunity()

        XCTAssertEqual(model.addOpportunitySaveError, "Enter an absolute http or https job URL with a host.")
        XCTAssertEqual(try store.opportunities(), [])
        XCTAssertEqual(try store.activityEvents(), [])

        model.jobURL = "https://jobs.example.com/product-manager"
        model.createOpportunity()

        XCTAssertNil(model.addOpportunitySaveError)
        XCTAssertEqual(try store.opportunities().count, 1)
    }

    func testInvalidCompensationShowsAddOpportunitySaveErrorWithoutWriting() throws {
        let store = try makeStore()
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, separateLocalWorkspace: .disabledForTesting)

        model.start()
        model.title = "Product Manager"
        model.company = "Rekon Labs"
        model.compensationMinimum = "200000"
        model.compensationMaximum = "150000"
        model.createOpportunity()

        XCTAssertEqual(model.addOpportunitySaveError, "Compensation amounts must be non-negative, and the minimum cannot exceed the maximum.")
        XCTAssertEqual(try store.opportunities(), [])
        XCTAssertEqual(try store.activityEvents(), [])
    }

    func testCreateAcceptsUSDFormattedCompensationAmounts() throws {
        let store = try makeStore()
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, separateLocalWorkspace: .disabledForTesting)

        model.start()
        model.title = "Product Manager"
        model.company = "Rekon Labs"
        model.compensationMinimum = "$285,000"
        model.compensationMaximum = "$385,000"
        model.createOpportunity()

        let saved = try XCTUnwrap(store.opportunities().first)
        XCTAssertEqual(saved.compensationMinimum, 285_000)
        XCTAssertEqual(saved.compensationMaximum, 385_000)
        XCTAssertNil(model.addOpportunitySaveError)
    }

    func testSavingOverviewAcceptsUSDFormattedCompensationAmounts() throws {
        let store = try makeStore()
        let opportunity = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs"))
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, separateLocalWorkspace: .disabledForTesting)

        model.start()
        model.select(opportunity)
        model.selectedCompensationMinimum = "$285,000"
        model.selectedCompensationMaximum = "$385,000"
        model.saveSelectedOpportunity()

        let saved = try XCTUnwrap(store.opportunities().first)
        XCTAssertEqual(saved.compensationMinimum, 285_000)
        XCTAssertEqual(saved.compensationMaximum, 385_000)
        XCTAssertEqual(saved.compensationPayPeriod, .year)
        XCTAssertEqual(model.statusMessage, "Opportunity updated locally.")
    }

    func testSavingOverviewRejectsMalformedFormattedCompensationWithoutWriting() throws {
        let store = try makeStore()
        let opportunity = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs", notes: "Original note"))
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, separateLocalWorkspace: .disabledForTesting)

        model.start()
        model.select(opportunity)
        let activityCountBeforeSave = try store.activityEvents().count
        model.selectedCompensationMinimum = "$285,00"
        model.selectedNotes = "Changed note"
        model.saveSelectedOpportunity()

        let saved = try XCTUnwrap(store.opportunities().first)
        XCTAssertNil(saved.compensationMinimum)
        XCTAssertEqual(saved.notes, "Original note")
        XCTAssertEqual(try store.activityEvents().count, activityCountBeforeSave)
        XCTAssertEqual(model.statusMessage, "Compensation amounts must be non-negative, and the minimum cannot exceed the maximum.")
    }

    func testSuccessfulCreateUpdatesVisibleLocalCount() throws {
        let store = try makeStore()
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, separateLocalWorkspace: .disabledForTesting)

        model.start()
        model.title = "Product Manager"
        model.company = "Rekon Labs"
        model.createOpportunity()

        XCTAssertEqual(model.opportunityCount, 1)
        XCTAssertEqual(model.activityCount, 1)
        XCTAssertEqual(model.statusMessage, "Saved locally.")
    }

    func testStartupLoadsAnOpportunityWithAReconciliationReviewTask() throws {
        let store = try makeStore()
        let opportunity = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs", jobURL: "https://jobs.example.com/role"))
        let result = try store.recordReconciliationResult(RecordReconciliationResult(opportunityID: opportunity.id, url: opportunity.jobURL, outcome: .needsManualReview, classification: .offlineUnchecked, reason: .offlineUnchecked, evidence: "Offline; check not run"))
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, separateLocalWorkspace: .disabledForTesting)

        model.start()

        XCTAssertEqual(model.selectedOpportunity?.id, opportunity.id)
        XCTAssertEqual(model.selectedReconciliationTask?.id, result.reviewTaskID)
        XCTAssertEqual(model.selectedReconciliationResults.map(\.id), [result.id])
    }

    func testSuccessfulCreateResetsDateDraftsBeforeTheNextOpportunity() throws {
        let store = try makeStore()
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, separateLocalWorkspace: .disabledForTesting)
        let priorDate = Date(timeIntervalSince1970: 1_704_067_200)
        model.start()
        model.title = "First opportunity"
        model.company = "Rekon Labs"
        model.applicationDate = priorDate
        model.responseEffectiveDate = priorDate
        model.stageChangedAt = priorDate

        model.createOpportunity()

        XCTAssertNotEqual(model.applicationDate, priorDate)
        XCTAssertNotEqual(model.responseEffectiveDate, priorDate)
        XCTAssertNotEqual(model.stageChangedAt, priorDate)
    }

    func testSecondSuccessfulCreatePersistsFreshDatesAfterDraftReset() throws {
        let store = try makeStore()
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, separateLocalWorkspace: .disabledForTesting)
        let priorDate = Date(timeIntervalSince1970: 1_704_067_200)
        model.start()
        model.title = "First opportunity"
        model.company = "Rekon Labs"
        model.applicationDate = priorDate
        model.hasApplicationDate = true
        model.responseState = .awaitingResponse
        model.responseEffectiveDate = priorDate
        model.stageChangedAt = priorDate
        model.createOpportunity()

        model.title = "Second opportunity"
        model.company = "Rekon Labs"
        model.hasApplicationDate = true
        model.responseState = .awaitingResponse
        model.createOpportunity()

        let second = try XCTUnwrap((try store.opportunities()).first { $0.title == "Second opportunity" })
        let response = try XCTUnwrap(try store.responseHistory(forOpportunityID: second.id).first)
        let stage = try XCTUnwrap(try store.stageHistory(forOpportunityID: second.id).first)
        XCTAssertNotEqual(second.applicationDate, priorDate)
        XCTAssertNotEqual(response.occurredAt, priorDate)
        XCTAssertNotEqual(stage.occurredAt, priorDate)
    }

    func testCreatePersistsJobDescriptionAndNotes() throws {
        let store = try makeStore()
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, separateLocalWorkspace: .disabledForTesting)
        model.showClosedOpportunities = true
        defer { model.showClosedOpportunities = true }
        model.start()
        model.title = "Product Manager"
        model.company = "Rekon Labs"
        model.jobDescription = "Own the roadmap"
        model.notes = "Referral from Morgan"

        model.createOpportunity()

        XCTAssertEqual(model.opportunities.first?.jobDescription, "Own the roadmap")
        XCTAssertEqual(model.opportunities.first?.notes, "Referral from Morgan")
    }

    func testFreshLaunchShowsVisibleWorkspaceCreationState() {
        let model = WorkspaceViewModel(openWorkspace: { .createAvailable }, createWorkspace: { throw WorkspaceStoreError.injectedFailure }, separateLocalWorkspace: .disabledForTesting)

        model.start()

        XCTAssertEqual(model.statusMessage, "Create a local workspace to begin tracking opportunities.")
        XCTAssertTrue(model.canCreateWorkspace)
        XCTAssertFalse(model.workspaceReady)
    }

    func testCreateFailureImmediatelyRefreshesToRecoveryRequiredState() {
        var opens = 0
        let model = WorkspaceViewModel(
            openWorkspace: {
                opens += 1
                return opens == 1 ? .createAvailable : .recoveryRequired
            },
            createWorkspace: { throw WorkspaceStoreError.injectedFailure },
            separateLocalWorkspace: .disabledForTesting
        )

        model.start()
        model.createWorkspaceIfNeeded()

        XCTAssertEqual(opens, 2)
        XCTAssertTrue(model.workspaceRequiresRecovery)
        XCTAssertFalse(model.canCreateWorkspace)
        XCTAssertFalse(model.workspaceReady)
        XCTAssertEqual(model.statusMessage, "Existing workspace material needs recovery. Nothing was replaced or removed.")
    }

    func testExistingWorkspaceMissingKeyDoesNotOfferReplacement() {
        let model = WorkspaceViewModel(openWorkspace: { .recoveryRequired }, createWorkspace: { throw WorkspaceStoreError.injectedFailure }, separateLocalWorkspace: .disabledForTesting)

        model.start()

        XCTAssertEqual(model.statusMessage, "Existing workspace material needs recovery. Nothing was replaced or removed.")
        XCTAssertFalse(model.canCreateWorkspace)
        XCTAssertFalse(model.workspaceReady)
        XCTAssertTrue(model.workspaceRequiresRecovery)
    }

    func testRecoveryRequiredCanBeRecheckedWithoutCreatingOrReplacingAnything() {
        var opens = 0
        let model = WorkspaceViewModel(
            openWorkspace: {
                opens += 1
                return .recoveryRequired
            },
            createWorkspace: { throw WorkspaceStoreError.injectedFailure },
            separateLocalWorkspace: .disabledForTesting
        )

        model.start()
        model.retryWorkspaceOpen()

        XCTAssertEqual(opens, 2)
        XCTAssertTrue(model.workspaceRequiresRecovery)
        XCTAssertFalse(model.canCreateWorkspace)
        XCTAssertFalse(model.workspaceReady)
        XCTAssertEqual(model.statusMessage, "Existing workspace material needs recovery. Nothing was replaced or removed.")
    }

    func testRecoveryCreatesSeparateLocalWorkspaceWithoutConsultingPreservedWorkspace() throws {
        let bookmarkFixture = ViewModelBookmarkFixture()
        let preservedBookmark = Data("preserved-bookmark".utf8)
        bookmarkFixture.bookmark = preservedBookmark
        let separate = SeparateWorkspaceFixture()
        var productionOpenCount = 0
        var productionCreateCount = 0
        let model = WorkspaceViewModel(
            openWorkspace: {
                productionOpenCount += 1
                return .recoveryRequired
            },
            createWorkspace: {
                productionCreateCount += 1
                throw WorkspaceStoreError.injectedFailure
            },
            workspaceLocationBookmarks: bookmarkFixture.makeStore(),
            separateLocalWorkspace: separate.dependencies
        )
        model.start()
        XCTAssertTrue(model.workspaceRequiresRecovery)
        let bookmarkLoadsBeforeCreation = bookmarkFixture.loadCount

        model.createSeparateLocalWorkspace()
        model.title = "Separate role"
        model.company = "Rekon Labs"
        model.createOpportunity()

        XCTAssertTrue(model.workspaceReady)
        XCTAssertTrue(model.usingSeparateLocalWorkspace)
        XCTAssertEqual(model.opportunities.map(\.title), ["Separate role"])
        XCTAssertEqual(separate.persistedIdentity, separate.createdIdentities.first)
        XCTAssertEqual(separate.allocatedIdentities.count, 1)
        XCTAssertEqual(separate.createdIdentities.count, 1)
        XCTAssertEqual(productionCreateCount, 0)
        XCTAssertEqual(bookmarkFixture.bookmark, preservedBookmark)
        XCTAssertEqual(bookmarkFixture.loadCount, bookmarkLoadsBeforeCreation)
        XCTAssertEqual(bookmarkFixture.saveCount, 0)
        XCTAssertEqual(productionOpenCount, 0)
    }

    func testRelaunchPrefersSelectedSeparateWorkspaceAndRetainsOpportunity() throws {
        let bookmarkFixture = ViewModelBookmarkFixture()
        bookmarkFixture.bookmark = Data("preserved-bookmark".utf8)
        let separate = SeparateWorkspaceFixture()
        let first = WorkspaceViewModel(
            openWorkspace: { .recoveryRequired },
            createWorkspace: { throw WorkspaceStoreError.injectedFailure },
            workspaceLocationBookmarks: bookmarkFixture.makeStore(),
            separateLocalWorkspace: separate.dependencies
        )
        first.start()
        first.createSeparateLocalWorkspace()
        first.title = "Persisted role"
        first.company = "Rekon Labs"
        first.createOpportunity()
        first.teardown()
        let bookmarkLoadsBeforeRelaunch = bookmarkFixture.loadCount
        var productionOpenCount = 0

        let relaunched = WorkspaceViewModel(
            openWorkspace: {
                productionOpenCount += 1
                return .recoveryRequired
            },
            createWorkspace: { throw WorkspaceStoreError.injectedFailure },
            workspaceLocationBookmarks: bookmarkFixture.makeStore(),
            separateLocalWorkspace: separate.dependencies
        )
        relaunched.start()

        XCTAssertTrue(relaunched.workspaceReady)
        XCTAssertTrue(relaunched.usingSeparateLocalWorkspace)
        XCTAssertEqual(relaunched.opportunities.map(\.title), ["Persisted role"])
        XCTAssertEqual(separate.openedIdentities, [try XCTUnwrap(separate.persistedIdentity)])
        XCTAssertEqual(productionOpenCount, 0)
        XCTAssertEqual(bookmarkFixture.loadCount, bookmarkLoadsBeforeRelaunch)
        XCTAssertEqual(bookmarkFixture.saveCount, 0)
    }

    func testSeparateWorkspaceCreationFailureReusesPersistedIdentityWithoutFallback() {
        let bookmarkFixture = ViewModelBookmarkFixture()
        bookmarkFixture.bookmark = Data("preserved-bookmark".utf8)
        let separate = SeparateWorkspaceFixture()
        separate.creationFailure = WorkspaceStoreError.injectedFailure
        var productionOpenCount = 0
        var productionCreateCount = 0
        let model = WorkspaceViewModel(
            openWorkspace: {
                productionOpenCount += 1
                return .recoveryRequired
            },
            createWorkspace: {
                productionCreateCount += 1
                throw WorkspaceStoreError.injectedFailure
            },
            workspaceLocationBookmarks: bookmarkFixture.makeStore(),
            separateLocalWorkspace: separate.dependencies
        )
        model.start()
        let bookmarkLoadsBeforeCreation = bookmarkFixture.loadCount

        model.createSeparateLocalWorkspace()
        model.createSeparateLocalWorkspace()

        XCTAssertFalse(model.workspaceReady)
        XCTAssertTrue(model.usingSeparateLocalWorkspace)
        XCTAssertEqual(separate.allocatedIdentities.count, 1)
        XCTAssertEqual(separate.createdIdentities.count, 2)
        XCTAssertEqual(Set(separate.createdIdentities).count, 1)
        XCTAssertEqual(separate.openedIdentities, separate.createdIdentities)
        XCTAssertEqual(productionOpenCount, 0)
        XCTAssertEqual(productionCreateCount, 0)
        XCTAssertEqual(bookmarkFixture.loadCount, bookmarkLoadsBeforeCreation)
        XCTAssertEqual(bookmarkFixture.saveCount, 0)
    }

    func testReturnToPreservedRecoveryClosesSeparateStoreAndChangesOnlySelector() throws {
        let bookmarkFixture = ViewModelBookmarkFixture()
        let preservedBookmark = Data("preserved-bookmark".utf8)
        bookmarkFixture.bookmark = preservedBookmark
        let separate = SeparateWorkspaceFixture()
        var closeCount = 0
        let model = WorkspaceViewModel(
            openWorkspace: { .recoveryRequired },
            createWorkspace: { throw WorkspaceStoreError.injectedFailure },
            workspaceLocationBookmarks: bookmarkFixture.makeStore(),
            closeWorkspaceStore: {
                closeCount += 1
                try $0.close()
            },
            separateLocalWorkspace: separate.dependencies
        )
        model.start()
        model.createSeparateLocalWorkspace()
        let bookmarkLoadsBeforeReturn = bookmarkFixture.loadCount

        model.returnToPreservedWorkspaceRecovery()

        XCTAssertEqual(closeCount, 1)
        XCTAssertEqual(separate.clearSelectionCount, 1)
        XCTAssertNil(separate.persistedIdentity)
        XCTAssertFalse(model.workspaceReady)
        XCTAssertFalse(model.usingSeparateLocalWorkspace)
        XCTAssertTrue(model.workspaceRequiresRecovery)
        XCTAssertEqual(bookmarkFixture.bookmark, preservedBookmark)
        XCTAssertEqual(bookmarkFixture.loadCount, bookmarkLoadsBeforeReturn)
        XCTAssertEqual(bookmarkFixture.saveCount, 0)
    }

    func testSeparateWorkspaceRecoveryGuardsPreservedFolderSelection() {
        let bookmarkFixture = ViewModelBookmarkFixture()
        let preservedBookmark = Data("preserved-bookmark".utf8)
        bookmarkFixture.bookmark = preservedBookmark
        let selectedFolder = bookmarkFixture.makeFolder(withDatabase: true)
        let separate = SeparateWorkspaceFixture()
        separate.creationFailure = WorkspaceStoreError.injectedFailure
        let model = WorkspaceViewModel(
            openWorkspace: { .recoveryRequired },
            createWorkspace: { throw WorkspaceStoreError.injectedFailure },
            workspaceLocationBookmarks: bookmarkFixture.makeStore(),
            separateLocalWorkspace: separate.dependencies
        )
        model.start()
        model.createSeparateLocalWorkspace()
        let bookmarkLoadsBeforeSelection = bookmarkFixture.loadCount

        model.chooseExistingWorkspaceFolder(selectedFolder)

        XCTAssertTrue(model.usingSeparateLocalWorkspace)
        XCTAssertEqual(separate.persistedIdentity, separate.identity)
        XCTAssertEqual(bookmarkFixture.bookmark, preservedBookmark)
        XCTAssertEqual(bookmarkFixture.loadCount, bookmarkLoadsBeforeSelection)
        XCTAssertEqual(bookmarkFixture.saveCount, 0)
        XCTAssertTrue(model.statusMessage.contains("Return to the preserved workspace"))
    }

    func testSelectorClearFailureAfterCloseIsNonReadyAndRetryableAtSameIdentity() throws {
        let bookmarkFixture = ViewModelBookmarkFixture()
        let preservedBookmark = Data("preserved-bookmark".utf8)
        bookmarkFixture.bookmark = preservedBookmark
        let separate = SeparateWorkspaceFixture()
        separate.clearFailure = WorkspaceStoreError.injectedFailure
        var closeCount = 0
        let model = WorkspaceViewModel(
            openWorkspace: { .recoveryRequired },
            createWorkspace: { throw WorkspaceStoreError.injectedFailure },
            workspaceLocationBookmarks: bookmarkFixture.makeStore(),
            closeWorkspaceStore: {
                closeCount += 1
                try $0.close()
            },
            separateLocalWorkspace: separate.dependencies
        )
        model.start()
        model.createSeparateLocalWorkspace()
        let selectedIdentity = separate.persistedIdentity
        let bookmarkLoadsBeforeReturn = bookmarkFixture.loadCount

        model.returnToPreservedWorkspaceRecovery()

        XCTAssertEqual(closeCount, 1)
        XCTAssertFalse(model.workspaceReady)
        XCTAssertTrue(model.usingSeparateLocalWorkspace)
        XCTAssertEqual(separate.persistedIdentity, selectedIdentity)
        XCTAssertEqual(bookmarkFixture.bookmark, preservedBookmark)
        XCTAssertEqual(bookmarkFixture.loadCount, bookmarkLoadsBeforeReturn)
        XCTAssertEqual(bookmarkFixture.saveCount, 0)
        XCTAssertTrue(model.statusMessage.contains("Retry returning"))

        separate.clearFailure = nil
        model.returnToPreservedWorkspaceRecovery()

        XCTAssertNil(separate.persistedIdentity)
        XCTAssertFalse(model.usingSeparateLocalWorkspace)
        XCTAssertTrue(model.workspaceRequiresRecovery)
    }

    func testRecheckToRecoveryRequiredClearsLiveWorkspaceDataAndBlocksMutation() throws {
        let store = try makeStore()
        var opens = 0
        let model = WorkspaceViewModel(
            openWorkspace: {
                opens += 1
                return opens == 1 ? .ready(store) : .recoveryRequired
            },
            createWorkspace: { store },
            separateLocalWorkspace: .disabledForTesting
        )
        model.start()
        model.title = "Product Manager"
        model.company = "Rekon Labs"
        model.createOpportunity()
        let savedOpportunity = try XCTUnwrap(model.opportunities.first)

        model.retryWorkspaceOpen()
        model.title = "Must not save"
        model.company = "Rekon Labs"
        model.createOpportunity()

        XCTAssertFalse(model.workspaceReady)
        XCTAssertTrue(model.workspaceRequiresRecovery)
        XCTAssertEqual(model.opportunityCount, 0)
        XCTAssertEqual(model.activityCount, 0)
        XCTAssertTrue(model.opportunities.isEmpty)
        XCTAssertTrue(model.activityEvents.isEmpty)
        XCTAssertTrue(model.needsAttention.isEmpty)
        XCTAssertNil(model.selectedOpportunity)
        XCTAssertEqual(model.selectedOpportunityID, "")
        XCTAssertEqual(try store.opportunities(), [savedOpportunity])
        XCTAssertEqual(try store.activityEvents().map(\.kind), ["opportunity_created"])
        XCTAssertEqual(model.statusMessage, "Create or reopen the local workspace first.")
    }

    func testCorruptWorkspaceDoesNotOfferReplacement() {
        let model = WorkspaceViewModel(openWorkspace: { .corrupt }, createWorkspace: { throw WorkspaceStoreError.injectedFailure }, separateLocalWorkspace: .disabledForTesting)

        model.start()

        XCTAssertEqual(model.statusMessage, "The local workspace is unreadable. It has not been replaced; keep its files intact.")
        XCTAssertFalse(model.canCreateWorkspace)
    }

    func testDeleteRefreshesVisibleRecordsAndKeepsOnlyActivityKind() throws {
        let store = try makeStore()
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, separateLocalWorkspace: .disabledForTesting)
        model.start()
        model.title = "Product Manager"
        model.company = "Rekon Labs"
        model.createOpportunity()

        model.deleteOpportunity(try XCTUnwrap(model.opportunities.first))

        XCTAssertEqual(model.opportunityCount, 0)
        XCTAssertEqual(model.activityEvents.map(\.kind), ["opportunity_created", "opportunity_deleted"])
        XCTAssertEqual(model.statusMessage, "Opportunity deleted locally.")
    }

    func testStartRestoresLatestLocalImportReport() throws {
        let store = try makeStore()
        let preview = try CSVOpportunityImporter.preview(data: Data("title,company\nProduct Manager,Rekon Labs\n".utf8))
        let report = try store.importCSV(try store.csvImportPlan(for: preview), invalidCount: preview.invalidRowCount)
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, separateLocalWorkspace: .disabledForTesting)

        model.start()

        let restored = try XCTUnwrap(model.csvImportReport)
        XCTAssertEqual(restored.id, report.id)
        XCTAssertEqual(restored.importedCount, report.importedCount)
        XCTAssertEqual(restored.updatedCount, report.updatedCount)
        XCTAssertEqual(restored.skippedCount, report.skippedCount)
        XCTAssertEqual(restored.duplicateKeptCount, report.duplicateKeptCount)
        XCTAssertEqual(restored.invalidCount, report.invalidCount)
        XCTAssertEqual(restored.failedCount, report.failedCount)
        XCTAssertEqual(restored.sourceBasename, report.sourceBasename)
        XCTAssertEqual(restored.mappingSummary, report.mappingSummary)
        XCTAssertEqual(restored.createdAt.timeIntervalSince1970, report.createdAt.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(model.csvImportReportRows.map(\.title), ["Product Manager"])
        XCTAssertEqual(model.csvImportReportRows.map(\.company), ["Rekon Labs"])
    }

    func testCSVPreviewRequiresExplicitValidationBeforeRowsAreReadyForReview() throws {
        let store = try makeStore()
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("rekon-csv-preview-\(UUID().uuidString).csv")
        try Data("title,company\nProduct Manager,Rekon Labs\n".utf8).write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, separateLocalWorkspace: .disabledForTesting)

        model.start()
        model.previewCSV(at: fileURL)

        XCTAssertNotNil(model.csvPreview)
        XCTAssertTrue(model.csvImportPlan.isEmpty)

        model.validateCSVMapping()

        XCTAssertEqual(model.csvImportPlan.count, 1)
    }

    func testExportReturnsCSVAndRecordsOnlyAnAuditEvent() throws {
        let store = try makeStore()
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, separateLocalWorkspace: .disabledForTesting)
        model.start()
        model.title = "Product Manager"
        model.company = "Rekon Labs"
        model.createOpportunity()

        let csv = try XCTUnwrap(model.exportOpportunitiesCSV())

        XCTAssertTrue(csv.contains("\"Product Manager\""))
        XCTAssertEqual(model.activityEvents.last?.kind, "opportunities_exported")
        XCTAssertEqual(model.statusMessage, "Unencrypted CSV export is ready. Save it only where you trust the storage.")
    }

    func testActivitySearchMatchesLocalActionAndRelatedOpportunity() throws {
        let store = try makeStore()
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, separateLocalWorkspace: .disabledForTesting)
        model.start()
        model.title = "Product Manager"
        model.company = "Rekon Labs"
        model.createOpportunity()

        model.activitySearch = "rekon"

        XCTAssertEqual(model.filteredActivityEvents.map(\.kind), ["opportunity_created"])
    }

    func testActivitySearchMatchesMultipleWordsInAnEventLabel() throws {
        let store = try makeStore()
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, separateLocalWorkspace: .disabledForTesting)
        model.start()
        model.title = "Product Manager"
        model.company = "Rekon Labs"
        model.createOpportunity()

        model.activitySearch = "opportunity created"

        XCTAssertEqual(model.filteredActivityEvents.map(\.kind), ["opportunity_created"])
    }

    func testPipelineVisibilitySettingCanHideClosedOpportunities() throws {
        let store = try makeStore()
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, separateLocalWorkspace: .disabledForTesting)
        model.showClosedOpportunities = true
        defer { model.showClosedOpportunities = true }
        model.start()
        model.title = "Active role"
        model.company = "Rekon Labs"
        model.createOpportunity()
        model.title = "Closed role"
        model.company = "Rekon Labs"
        model.stage = .closed
        model.createOpportunity()

        model.showClosedOpportunities = false

        XCTAssertEqual(model.filteredOpportunities.map(\.title), ["Active role"])
    }

    func testSavingSelectedOpportunityUpdatesItsVisibleRecord() throws {
        let store = try makeStore()
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, separateLocalWorkspace: .disabledForTesting)
        model.start()
        model.title = "Product Manager"
        model.company = "Rekon Labs"
        model.actionType = .other
        model.actionCustomText = "Send follow-up"
        model.hasDueDate = true
        model.createOpportunity()

        model.open(model.needsAttention[0])
        model.selectedTitle = "Senior Product Manager"
        model.selectedActionType = .other
        model.selectedActionCustomText = "Prepare recruiter call"
        model.saveSelectedOpportunity()

        XCTAssertEqual(model.opportunities.first?.title, "Senior Product Manager")
        XCTAssertEqual(model.needsAttention.first?.title, "Prepare recruiter call")
        XCTAssertEqual(model.activityEvents.last?.kind, "opportunity_updated")
    }

    func testSavingAnOverviewDraftPersistsTheEditedValue() throws {
        let store = try makeStore()
        let opportunity = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs"))
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, separateLocalWorkspace: .disabledForTesting)

        model.start()
        XCTAssertTrue(model.selectRouteOpportunity(id: opportunity.id))
        model.selectedTitle = "Senior Product Manager"

        model.saveRouteOpportunity(id: opportunity.id)

        let saved = try XCTUnwrap(store.opportunities().first)
        XCTAssertEqual(saved.title, "Senior Product Manager")
    }

    func testSavingOverviewWithoutEditingStructuredCompensationPreservesLegacyText() throws {
        let store = try makeStore()
        let opportunity = try store.create(CreateOpportunity(
            title: "Product Manager", company: "Rekon Labs", compensation: "150k base"
        ))
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, separateLocalWorkspace: .disabledForTesting)

        model.start()
        model.select(opportunity)
        model.selectedNotes = "Met the recruiter."
        model.saveSelectedOpportunity()

        let saved = try XCTUnwrap(store.opportunities().first)
        XCTAssertEqual(saved.notes, "Met the recruiter.")
        XCTAssertEqual(saved.compensation, "150k base")
        XCTAssertNil(saved.compensationMinimum)
        XCTAssertNil(saved.compensationMaximum)
        XCTAssertNil(saved.compensationPayPeriod)
    }

    func testSavingOverviewWithoutEditingActionControlsPreservesLegacyActionText() throws {
        let databaseURL = FileManager.default.temporaryDirectory.appendingPathComponent("rekon-view-model-\(UUID().uuidString).sqlite")
        let database = try EncryptedDatabase.open(url: databaseURL, key: Data(repeating: 5, count: 32))
        let store = try WorkspaceStore(database: database, actorID: "test", correlationID: "test")
        let opportunity = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs"))
        let legacyAction = "  Ask Morgan for a referral  "
        try database.execute(
            "UPDATE opportunities SET next_action = ?, action_type = ?, action_custom_text = ? WHERE id = ?",
            values: [.text(legacyAction), .text(OpportunityActionType.other.rawValue), .text(legacyAction), .text(opportunity.id)]
        )
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, separateLocalWorkspace: .disabledForTesting)

        model.start()
        model.select(opportunity)
        model.selectedNotes = "Met the recruiter."
        model.saveSelectedOpportunity()

        let saved = try XCTUnwrap(store.opportunities().first)
        XCTAssertEqual(saved.notes, "Met the recruiter.")
        XCTAssertEqual(saved.nextAction, legacyAction)
        XCTAssertEqual(saved.actionType, .other)
        XCTAssertEqual(saved.actionCustomText, legacyAction)
    }

    func testOpenQueueActionSelectsOpportunityAndRecordsActivity() throws {
        let store = try makeStore()
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, separateLocalWorkspace: .disabledForTesting)
        model.start()
        model.title = "Product Manager"
        model.company = "Rekon Labs"
        model.actionType = .other
        model.actionCustomText = "Send follow-up"
        model.createOpportunity()

        model.open(try XCTUnwrap(model.needsAttention.first))

        XCTAssertEqual(model.selectedOpportunity?.title, "Product Manager")
        XCTAssertEqual(model.activityEvents.last?.kind, "task_opened")
    }

    func testOpeningReconciliationReviewActionTargetsThatOpportunityAndRecordsActivity() throws {
        let store = try makeStore()
        let first = try store.create(CreateOpportunity(title: "First", company: "Rekon Labs", jobURL: "https://jobs.example.com/first"))
        let second = try store.create(CreateOpportunity(title: "Second", company: "Rekon Labs"))
        _ = try store.recordReconciliationResult(RecordReconciliationResult(
            opportunityID: first.id,
            url: first.jobURL,
            outcome: .needsManualReview,
            classification: .offlineUnchecked,
            reason: .offlineUnchecked,
            evidence: "Offline — check not run"
        ))
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, separateLocalWorkspace: .disabledForTesting)
        model.start()
        model.select(second)

        XCTAssertTrue(model.openReconciliationReviewAction(forOpportunityID: first.id))

        XCTAssertEqual(model.selectedOpportunityID, first.id)
        XCTAssertEqual(model.activityEvents.last?.kind, "task_opened")
    }

    func testClosureConfirmationUsesTheExplicitOpportunityID() throws {
        let store = try makeStore()
        let first = try store.create(CreateOpportunity(title: "First", company: "Rekon Labs", jobURL: "https://jobs.example.com/first"))
        let second = try store.create(CreateOpportunity(title: "Second", company: "Rekon Labs"))
        _ = try store.recordReconciliationResult(RecordReconciliationResult(
            opportunityID: first.id,
            url: first.jobURL,
            outcome: .closedSuggested,
            classification: .confirmed,
            reason: .manualReview,
            confidence: .medium,
            evidence: "Posting closed"
        ))
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, separateLocalWorkspace: .disabledForTesting)
        model.start()
        model.select(second)

        XCTAssertTrue(model.confirmReconciliationClosure(forOpportunityID: first.id))

        XCTAssertEqual(model.opportunity(id: first.id)?.stage, .closed)
        XCTAssertNotEqual(model.opportunity(id: second.id)?.stage, .closed)
        XCTAssertEqual(model.selectedOpportunityID, first.id)
    }

    func testReconcileOverviewBackDepartureStaysBlockedUntilPublicURLCheckCancellationCompletes() async throws {
        let store = try makeStore()
        let first = try store.create(CreateOpportunity(title: "First", company: "Rekon Labs", jobURL: "https://jobs.example.com/first"))
        let second = try store.create(CreateOpportunity(title: "Second", company: "Rekon Labs", jobURL: "https://jobs.example.com/second"))
        let checker = BlockingFixturePublicURLChecker(request: PublicURLRequest(originalURL: first.jobURL, hostname: "jobs.example.com", requestTarget: "/first"))
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, publicURLChecker: checker, separateLocalWorkspace: .disabledForTesting)
        model.start()
        model.select(first)

        model.checkSelectedPublicURL()
        await checker.waitForStart()
        XCTAssertTrue(model.isCheckingSelectedPublicURL)
        // Reconcile → Overview keeps the same record, while Back must still
        // respect the shared route-departure gate.
        XCTAssertTrue(model.navigateToRouteOpportunity(id: first.id))
        XCTAssertFalse(model.canLeaveOpportunityRoute())
        XCTAssertFalse(model.navigateToRouteOpportunity(id: second.id))
        XCTAssertEqual(model.selectedOpportunityID, first.id)

        model.cancelSelectedPublicURLCheck()
        await checker.waitForCancellation()
        for _ in 0..<20 where model.isCheckingSelectedPublicURL { await Task.yield() }

        XCTAssertFalse(model.isCheckingSelectedPublicURL)
        XCTAssertTrue(model.canLeaveOpportunityRoute())
        XCTAssertTrue(model.navigateToRouteOpportunity(id: second.id))
        XCTAssertEqual(model.selectedOpportunityID, second.id)
    }

    func testQueueRescheduleChangesOnlyTheSelectedTaskAndRecordsActivity() throws {
        let store = try makeStore()
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, separateLocalWorkspace: .disabledForTesting)
        model.start()
        model.title = "Product Manager"
        model.company = "Rekon Labs"
        model.actionType = .other
        model.actionCustomText = "Send follow-up"
        model.hasDueDate = true
        model.dueAt = Date(timeIntervalSince1970: 1_704_067_200)
        model.createOpportunity()
        let task = try XCTUnwrap(model.needsAttention.first)
        let rescheduled = Date(timeIntervalSince1970: 1_704_240_000)

        model.reschedule(task, to: rescheduled)

        XCTAssertEqual(model.needsAttention.first?.id, task.id)
        XCTAssertEqual(model.needsAttention.first?.dueAt, rescheduled)
        XCTAssertEqual(model.activityEvents.last?.kind, "task_rescheduled")
    }

    func testSelectedOpportunityShowsCompletedTaskState() throws {
        let store = try makeStore()
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, separateLocalWorkspace: .disabledForTesting)
        model.start()
        model.title = "Product Manager"
        model.company = "Rekon Labs"
        model.actionType = .other
        model.actionCustomText = "Send follow-up"
        model.createOpportunity()
        let task = try XCTUnwrap(model.needsAttention.first)

        model.open(task)
        model.complete(task)

        XCTAssertEqual(model.selectedTask?.id, task.id)
        XCTAssertTrue(model.selectedTask?.isComplete == true)
    }

    func testSelectedOpportunityShowsStageHistory() throws {
        let store = try makeStore()
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, separateLocalWorkspace: .disabledForTesting)
        model.start()
        model.title = "Product Manager"
        model.company = "Rekon Labs"
        model.createOpportunity()

        let opportunity = try XCTUnwrap(model.opportunities.first)
        model.changeStage(opportunity, to: .screening)

        XCTAssertEqual(model.selectedStageHistory.map(\.toStage), [.saved, .screening])
    }

    func testContactsCanBeFilteredAndShownAsLinkedOrSameEmployerDiscovery() throws {
        let store = try makeStore()
        let first = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs"))
        let second = try store.create(CreateOpportunity(title: "Director", company: "Rekon Labs"))
        let linked = try store.createContact(CreateContact(name: "Alex Morgan", employer: "Rekon Labs", title: "Recruiter"))
        let discovery = try store.createContact(CreateContact(name: "Jordan Lee", employer: "Rekon Labs", title: "VP People"))
        try store.linkContact(contactID: linked.id, toOpportunityID: first.id)
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, separateLocalWorkspace: .disabledForTesting)

        model.start()
        model.contactSearch = "Jordan"
        XCTAssertEqual(model.filteredContacts, [discovery])

        model.select(first)
        XCTAssertEqual(model.selectedContacts, [linked])
        XCTAssertEqual(model.selectedSameEmployerContacts, [discovery])
        XCTAssertEqual(model.selectedOpportunity?.id, first.id)
        XCTAssertEqual(model.opportunities.map(\.id), [first.id, second.id])
    }

    func testContactEmployerPickerShowsMatchingOpportunitiesOnlyAfterExplicitLinks() throws {
        let store = try makeStore()
        let first = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs"))
        let second = try store.create(CreateOpportunity(title: "Director", company: "rekon labs"))
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, separateLocalWorkspace: .disabledForTesting)

        model.start()
        XCTAssertEqual(model.contactEmployerSuggestions, ["Rekon Labs"])
        model.contactName = "Alex Morgan"
        model.selectContactEmployer("Rekon Labs")
        model.createContact()

        XCTAssertEqual(Set(model.selectedContactEmployerOpportunities.map(\.id)), Set([first.id, second.id]))
        XCTAssertEqual(model.selectedContactOpportunities, [])

        model.linkSelectedContact(to: first)
        XCTAssertEqual(model.selectedContactOpportunities.map(\.id), [first.id])
        XCTAssertEqual(model.selectedContactUnlinkedEmployerOpportunities.map(\.id), [second.id])

        model.unlinkSelectedContact(from: first)
        XCTAssertEqual(model.selectedContactOpportunities, [])
    }

    func testContactEmployerTypeaheadIsBlankUntilTypedAndCapsCanonicalMatches() throws {
        let store = try makeStore()
        for company in ["Albatross", "Almanac", "Alpha", "Alpine", "Altana", "Alto", "Altruist", "Beta"] {
            _ = try store.create(CreateOpportunity(title: "Director", company: company))
        }
        _ = try store.create(CreateOpportunity(title: "Director", company: "Café Labs"))
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, separateLocalWorkspace: .disabledForTesting)

        model.start()
        model.contactEmployerSearch = "  "
        XCTAssertEqual(model.filteredContactEmployerSuggestions, [])

        model.contactEmployerSearch = "al"
        XCTAssertEqual(model.filteredContactEmployerSuggestions, ["Albatross", "Almanac", "Alpha", "Alpine", "Altana", "Alto"])

        model.contactEmployerSearch = "cafe labs"
        XCTAssertEqual(model.filteredContactEmployerSuggestions, ["Café Labs"])
        XCTAssertNil(model.contactEmployerAddCandidate)
    }

    func testContactEmployerTypeaheadAddsOnlyANonmatchingTypedEmployer() throws {
        let store = try makeStore()
        let opportunity = try store.create(CreateOpportunity(title: "Director", company: "Rekon Labs"))
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, separateLocalWorkspace: .disabledForTesting)

        model.start()
        model.contactEmployerSearch = "  rekon labs  "
        XCTAssertNil(model.contactEmployerAddCandidate)

        model.contactEmployerSearch = "  New Company  "
        XCTAssertEqual(model.contactEmployerAddCandidate, "New Company")
        model.beginNewContactEmployer(named: "New Company")

        XCTAssertTrue(model.isAddingNewContactEmployer)
        XCTAssertEqual(model.contactEmployer, "New Company")
        XCTAssertEqual(model.selectedContactOpportunities, [])

        model.selectContactEmployer("rekon labs")
        XCTAssertEqual(model.contactEmployer, "Rekon Labs")
        XCTAssertEqual(model.selectedContactOpportunities, [])
        XCTAssertEqual(opportunity.company, "Rekon Labs")
    }

    func testContactProfileURLShowsHTTPWarningAndRejectsMalformedInputWithoutWriting() throws {
        let store = try makeStore()
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, separateLocalWorkspace: .disabledForTesting)

        model.start()
        model.contactName = "Alex Morgan"
        model.contactProfileURL = "http://profiles.example.com/alex"
        XCTAssertEqual(model.contactProfileURLWarning, "This profile URL uses HTTP rather than HTTPS.")

        model.contactProfileURL = "profiles.example.com/alex"
        XCTAssertEqual(model.contactProfileURLWarning, "Use an absolute http or https profile URL with a public hostname.")
        model.createContact()

        XCTAssertEqual(model.contacts, [])
        XCTAssertEqual(model.statusMessage, "Enter an absolute http or https profile URL with a public hostname.")
    }

    func testInvalidContactFieldsExposeASaveErrorWithoutWriting() throws {
        let store = try makeStore()
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, separateLocalWorkspace: .disabledForTesting)

        model.start()
        model.contactName = "Alex Morgan"
        model.contactEmail = "alex@"
        XCTAssertEqual(model.contactEmailWarning, "Enter an email address with a local part, @, and domain.")
        model.createContact()

        XCTAssertEqual(model.contactSaveError, "Enter an email address with a local part, @, and domain.")
        XCTAssertEqual(try store.contacts(), [])

        model.contactEmail = "alex@example.com"
        model.contactProfileURL = "https://microsoft"
        model.createContact()

        XCTAssertEqual(model.contactSaveError, "Enter an absolute http or https profile URL with a public hostname.")
        XCTAssertEqual(try store.contacts(), [])
    }

    func testSelectedContactCanLogAndDisplayALocalInteraction() throws {
        let store = try makeStore()
        let opportunity = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs"))
        let contact = try store.createContact(CreateContact(name: "Alex Morgan", employer: "Rekon Labs"))
        try store.linkContact(contactID: contact.id, toOpportunityID: opportunity.id)
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, separateLocalWorkspace: .disabledForTesting)

        model.start()
        model.selectContact(contact)
        model.interactionKind = .call
        model.interactionSummary = "Discussed the product role."
        model.interactionOccurredAt = Date(timeIntervalSince1970: 1_704_067_200)
        model.interactionHasNextTouch = true
        model.interactionNextTouchAt = Date(timeIntervalSince1970: 1_704_153_600)
        model.interactionOpportunityID = opportunity.id
        let occurredAt = model.interactionOccurredAt
        let nextTouchAt = model.interactionNextTouchAt
        model.recordSelectedContactInteraction()

        XCTAssertEqual(model.selectedContactInteractions.map(\.summary), ["Discussed the product role."])
        XCTAssertEqual(model.selectedContactLastTouch, occurredAt)
        XCTAssertEqual(model.selectedContactNextTouch, nextTouchAt)
        XCTAssertEqual(model.statusMessage, "Interaction saved locally.")
    }

    func testSelectedOpportunityShowsItsCrossRecordContactHistory() throws {
        let store = try makeStore()
        let opportunity = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs"))
        let contact = try store.createContact(CreateContact(name: "Alex Morgan"))
        try store.linkContact(contactID: contact.id, toOpportunityID: opportunity.id)
        _ = try store.recordContactInteraction(CreateContactInteraction(contactID: contact.id, opportunityID: opportunity.id, kind: .meeting, summary: "Met the hiring manager.", occurredAt: Date(timeIntervalSince1970: 1_704_067_200)))
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, separateLocalWorkspace: .disabledForTesting)

        model.start()
        model.select(opportunity)

        XCTAssertEqual(model.selectedOpportunityInteractions.map(\.contactName), ["Alex Morgan"])
        XCTAssertEqual(model.selectedOpportunityInteractions.map(\.summary), ["Met the hiring manager."])
    }

    func testExplicitPublicURLCheckPersistsAndRefreshesTheSelectedResult() async throws {
        let store = try makeStore()
        let opportunity = try store.create(CreateOpportunity(
            title: "Platform Engineer",
            company: "Rekon Labs",
            jobURL: "https://jobs.example.com/role"
        ))
        let checker = FixturePublicURLChecker(
            preparation: .eligible(PublicURLRequest(
                originalURL: opportunity.jobURL,
                hostname: "jobs.example.com",
                requestTarget: "/role"
            )),
            completion: PublicURLCheckCompletion(
                terminalState: .completed,
                outcome: .stillOpen,
                classification: .confirmed,
                confidence: .high,
                evidence: "The visible posting title and active application marker matched.",
                httpStatus: 200
            )
        )
        let model = WorkspaceViewModel(
            openWorkspace: { .ready(store) },
            createWorkspace: { store },
            publicURLChecker: checker,
            separateLocalWorkspace: .disabledForTesting
        )
        model.start()
        model.select(opportunity)

        model.checkSelectedPublicURL()
        await checker.waitForCheck()
        await Task.yield()

        XCTAssertFalse(model.isCheckingSelectedPublicURL)
        XCTAssertEqual(model.selectedReconciliationResults.first?.outcome, .stillOpen)
        XCTAssertEqual(model.selectedReconciliationResults.first?.httpStatus, 200)
        XCTAssertEqual(model.statusMessage, "Public URL check completed. Review the limited local evidence.")
    }

    func testIneligiblePublicURLCheckRecordsManualReviewWithoutCallingTransport() async throws {
        let store = try makeStore()
        let opportunity = try store.create(CreateOpportunity(
            title: "Platform Engineer",
            company: "Rekon Labs",
            jobURL: "http://jobs.example.com/role"
        ))
        let checker = FixturePublicURLChecker(
            preparation: .ineligible(PublicURLCheckCompletion(
                terminalState: .failed,
                outcome: .needsManualReview,
                classification: .failed,
                reason: .sourceFailed,
                evidence: "The saved posting URL is not eligible for a bounded public HTTPS check.",
                redactedErrorCode: "url_ineligible"
            )),
            completion: nil
        )
        let model = WorkspaceViewModel(
            openWorkspace: { .ready(store) },
            createWorkspace: { store },
            publicURLChecker: checker,
            separateLocalWorkspace: .disabledForTesting
        )
        model.start()
        model.select(opportunity)

        model.checkSelectedPublicURL()
        await Task.yield()

        XCTAssertEqual(checker.checkCount, 0)
        XCTAssertEqual(model.selectedReconciliationResults.first?.redactedErrorCode, "url_ineligible")
        XCTAssertNotNil(model.selectedReconciliationTask)
    }

    func testOpeningUnavailableDocumentMarksItForRelinkingWithoutLaunchingIt() throws {
        let store = try makeStore()
        let opportunity = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs"))
        let reference = try store.recordDocumentReference(RecordDocumentReference(
            opportunityID: opportunity.id,
            kind: .resume,
            filename: "resume.pdf",
            contentType: "application/pdf",
            sourceHash: String(repeating: "a", count: 64),
            byteCount: 8,
            bookmarkData: Data("missing".utf8)
        ))
        let fixture = DocumentOpenFixture(data: Data("%PDF-1.7".utf8), resolveError: .unavailable)
        var didOpen = false
        let model = WorkspaceViewModel(
            openWorkspace: { .ready(store) },
            createWorkspace: { store },
            documentReferenceBookmarks: fixture.makeStore(),
            openDocumentURL: { _ in didOpen = true; return true },
            separateLocalWorkspace: .disabledForTesting
        )
        model.start()

        model.openDocumentReference(reference)

        XCTAssertFalse(didOpen)
        XCTAssertEqual(try store.documentReferences(forOpportunityID: opportunity.id).first?.availability, .relinkRequired)
        XCTAssertEqual(model.statusMessage, "This document needs to be relinked before it can be opened.")
    }

    func testRelinkRequiredDocumentNeverUsesItsRetainedBookmarkUntilExplicitlyRelinked() throws {
        let store = try makeStore()
        let opportunity = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs"))
        let data = Data("%PDF-1.7".utf8)
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let reference = try store.recordDocumentReference(RecordDocumentReference(
            opportunityID: opportunity.id,
            kind: .resume,
            filename: "resume.pdf",
            contentType: "application/pdf",
            sourceHash: hash,
            byteCount: data.count,
            bookmarkData: Data("retained-but-disabled".utf8)
        ))
        try store.markDocumentReferenceRelinkRequired(id: reference.id)
        let relinkRequired = try XCTUnwrap(store.documentReferences(forOpportunityID: opportunity.id).first)
        let fixture = DocumentOpenFixture(data: data)
        var didOpen = false
        let model = WorkspaceViewModel(
            openWorkspace: { .ready(store) },
            createWorkspace: { store },
            documentReferenceBookmarks: fixture.makeStore(),
            openDocumentURL: { _ in didOpen = true; return true },
            separateLocalWorkspace: .disabledForTesting
        )
        model.start()

        model.openDocumentReference(relinkRequired)

        XCTAssertFalse(didOpen)
        XCTAssertEqual(fixture.startAccessCount, 0)
        XCTAssertEqual(model.statusMessage, "This document needs to be relinked before it can be opened.")
    }

    func testOpeningVerifiedDocumentHoldsThenReleasesItsLease() throws {
        let store = try makeStore()
        let opportunity = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs"))
        let data = Data("%PDF-1.7".utf8)
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let reference = try store.recordDocumentReference(RecordDocumentReference(
            opportunityID: opportunity.id,
            kind: .resume,
            filename: "resume.pdf",
            contentType: "application/pdf",
            sourceHash: hash,
            byteCount: data.count,
            bookmarkData: Data("available".utf8)
        ))
        let fixture = DocumentOpenFixture(data: data)
        var wasLeaseActiveDuringOpen = false
        let model = WorkspaceViewModel(
            openWorkspace: { .ready(store) },
            createWorkspace: { store },
            documentReferenceBookmarks: fixture.makeStore(),
            openDocumentURL: { _ in wasLeaseActiveDuringOpen = fixture.isAccessing; return true },
            separateLocalWorkspace: .disabledForTesting
        )
        model.start()

        model.openDocumentReference(reference)

        XCTAssertTrue(wasLeaseActiveDuringOpen)
        XCTAssertFalse(fixture.isAccessing)
        XCTAssertEqual(fixture.stopAccessCount, 1)
        XCTAssertEqual(model.statusMessage, "Opened the verified local document reference.")
    }

    private func makeStore() throws -> WorkspaceStore {
        let databaseURL = FileManager.default.temporaryDirectory.appendingPathComponent("rekon-view-model-\(UUID().uuidString).sqlite")
        let database = try EncryptedDatabase.open(url: databaseURL, key: Data(repeating: 5, count: 32))
        return try WorkspaceStore(database: database, actorID: "test", correlationID: "test")
    }
}

private actor GatedPortableArchiveWorker: PortableArchiveWorking {
    private(set) var hasStarted = false
    private var isReleased = false

    func createArchive(_ request: PortableArchiveRequest) async throws -> PortableArchiveCatalogueRow {
        hasStarted = true
        while !isReleased {
            await Task.yield()
        }
        return PortableArchiveCatalogueRow(
            archiveID: request.archiveID,
            displayFilename: request.destinationURL.lastPathComponent,
            formatVersion: 1,
            createdAt: request.createdAt,
            expiresAt: request.createdAt.addingTimeInterval(30 * 24 * 60 * 60),
            verificationState: "Verified",
            ciphertextChecksum: Data(repeating: 1, count: 32),
            signingKeyFingerprint: Data(repeating: 2, count: 32)
        )
    }

    func release() {
        isReleased = true
    }
}

@MainActor
private final class FixturePublicURLChecker: PublicURLChecking {
    let preparation: PublicURLPreparation
    let completion: PublicURLCheckCompletion?
    private(set) var checkCount = 0
    private var didCheck = false

    init(preparation: PublicURLPreparation, completion: PublicURLCheckCompletion?) {
        self.preparation = preparation
        self.completion = completion
    }

    func prepare(_ savedURL: String) -> PublicURLPreparation {
        preparation
    }

    func check(_ request: PublicURLRequest, opportunityTitle: String) async -> PublicURLCheckCompletion {
        checkCount += 1
        didCheck = true
        return completion!
    }

    func waitForCheck() async {
        while !didCheck {
            await Task.yield()
        }
    }
}

@MainActor
private final class BlockingFixturePublicURLChecker: PublicURLChecking {
    private let request: PublicURLRequest
    private var didStart = false
    private var didCancel = false

    init(request: PublicURLRequest) {
        self.request = request
    }

    func prepare(_ savedURL: String) -> PublicURLPreparation { .eligible(request) }

    func check(_ request: PublicURLRequest, opportunityTitle: String) async -> PublicURLCheckCompletion {
        didStart = true
        while !Task.isCancelled { await Task.yield() }
        didCancel = true
        return PublicURLCheckCompletion(
            terminalState: .cancelled,
            outcome: .needsManualReview,
            classification: .offlineUnchecked,
            reason: .offlineUnchecked,
            evidence: "Check cancelled locally."
        )
    }

    func waitForStart() async {
        while !didStart { await Task.yield() }
    }

    func waitForCancellation() async {
        while !didCancel { await Task.yield() }
    }
}

@MainActor
private final class ViewModelBookmarkFixture {
    var bookmark: Data?
    var resolvedBookmarks: [Data: (URL, Bool)] = [:]
    private var databaseFolderPaths: Set<String> = []
    private(set) var startedURLs: [URL] = []
    private(set) var stoppedURLs: [URL] = []
    private(set) var loadCount = 0
    private(set) var saveCount = 0

    func makeFolder(withDatabase: Bool) -> URL {
        let folder = URL(fileURLWithPath: "/fixture/\(UUID().uuidString)", isDirectory: true)
        if withDatabase { databaseFolderPaths.insert(folder.standardizedFileURL.path) }
        return folder
    }

    func makeStore() -> WorkspaceLocationBookmarkStore {
        WorkspaceLocationBookmarkStore(dependencies: .init(
            loadBookmark: { [weak self] in
                self?.loadCount += 1
                return self?.bookmark
            },
            saveBookmark: { [weak self] bookmark in
                self?.saveCount += 1
                self?.bookmark = bookmark
            },
            createBookmark: { url in Data("bookmark:\(url.lastPathComponent)".utf8) },
            resolveBookmark: { [weak self] bookmark in
                guard let result = self?.resolvedBookmarks[bookmark] else { throw ViewModelBookmarkFixtureError.unresolvable }
                return result
            },
            startAccessing: { [weak self] url in self?.startedURLs.append(url); return true },
            stopAccessing: { [weak self] url in self?.stoppedURLs.append(url) },
            validateWorkspace: { [weak self] url in
                self?.databaseFolderPaths.contains(url.standardizedFileURL.path) == true ? nil : .missingWorkspaceDatabase
            }
        ))
    }
}

@MainActor
private final class SeparateWorkspaceFixture {
    let identity = UUID(uuidString: "A11CE000-0000-4000-8000-000000000001")!
    var persistedIdentity: UUID?
    var creationFailure: Error?
    var clearFailure: Error?
    private(set) var allocatedIdentities: [UUID] = []
    private(set) var createdIdentities: [UUID] = []
    private(set) var openedIdentities: [UUID] = []
    private(set) var clearSelectionCount = 0
    private let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("rekon-separate-\(UUID().uuidString).sqlite")
    private let key = Data(repeating: 31, count: 32)

    var dependencies: SeparateLocalWorkspaceDependencies {
        SeparateLocalWorkspaceDependencies(
            selectedIdentity: { [weak self] in self?.persistedIdentity },
            allocateAndPersistIdentity: { [weak self] in
                guard let self else { throw WorkspaceStoreError.injectedFailure }
                if let persistedIdentity { return persistedIdentity }
                allocatedIdentities.append(identity)
                persistedIdentity = identity
                return identity
            },
            open: { [weak self] identity in
                guard let self else { return .unavailable }
                openedIdentities.append(identity)
                guard FileManager.default.fileExists(atPath: databaseURL.path) else { return .createAvailable }
                let database = try EncryptedDatabase.open(url: databaseURL, key: key, createIfMissing: false)
                return .ready(try WorkspaceStore(database: database, actorID: "test", correlationID: "test"))
            },
            create: { [weak self] identity in
                guard let self else { throw WorkspaceStoreError.injectedFailure }
                createdIdentities.append(identity)
                if let creationFailure { throw creationFailure }
                let database = try EncryptedDatabase.open(url: databaseURL, key: key)
                return try WorkspaceStore(database: database, actorID: "test", correlationID: "test")
            },
            clearSelection: { [weak self] in
                if let clearFailure = self?.clearFailure { throw clearFailure }
                self?.clearSelectionCount += 1
                self?.persistedIdentity = nil
            }
        )
    }
}

private enum ViewModelBookmarkFixtureError: Error {
    case unresolvable
}

@MainActor
private final class DocumentOpenFixture {
    let data: Data
    let url = URL(fileURLWithPath: "/fixture/resume.pdf")
    let resolveError: DocumentReferenceBookmarkError?
    private(set) var isAccessing = false
    private(set) var startAccessCount = 0
    private(set) var stopAccessCount = 0

    init(data: Data, resolveError: DocumentReferenceBookmarkError? = nil) {
        self.data = data
        self.resolveError = resolveError
    }

    func makeStore() -> DocumentReferenceBookmarkStore {
        DocumentReferenceBookmarkStore(dependencies: .init(
            createBookmark: { _ in Data("unused".utf8) },
            resolveBookmark: { [weak self] _ in
                guard let self else { throw DocumentReferenceBookmarkError.unavailable }
                if let resolveError { throw resolveError }
                return (url, false)
            },
            startAccessing: { [weak self] _ in self?.startAccessCount += 1; self?.isAccessing = true; return true },
            stopAccessing: { [weak self] _ in self?.isAccessing = false; self?.stopAccessCount += 1 },
            inspectFile: { [weak self] _ in
                guard let self else { return nil }
                return DocumentReferenceFileInspection(isRegularFile: true, byteCount: self.data.count)
            },
            readData: { [weak self] _ in self?.data ?? Data() }
        ))
    }
}

@MainActor
private final class PortableArchiveRestoreTestTracker {
    var startedURLs: [URL] = []
    var stoppedURLs: [URL] = []
}

private enum RestoreSentinelError: LocalizedError {
    case untrustedInput

    var errorDescription: String? {
        "sentinel verifier failure for /private/tmp/untrusted.rekonarchive"
    }
}

private actor PortableArchiveRestoreTestGate {
    private var continuations: [CheckedContinuation<Void, Never>] = []
    private var blockedCount = 0

    func wait() async {
        blockedCount += 1
        await withCheckedContinuation { continuations.append($0) }
    }

    func waitUntilBlocked(count: Int) async {
        while blockedCount < count { await Task.yield() }
    }

    func releaseOne() {
        guard !continuations.isEmpty else { return }
        continuations.removeFirst().resume()
    }
}

private actor PortableArchiveRestoreAttemptCounter {
    private var count = 0

    func next() -> Int {
        count += 1
        return count
    }
}

@MainActor
private extension SeparateLocalWorkspaceDependencies {
    static var disabledForTesting: SeparateLocalWorkspaceDependencies {
        SeparateLocalWorkspaceDependencies(
            selectedIdentity: { nil },
            allocateAndPersistIdentity: { throw WorkspaceStoreError.injectedFailure },
            open: { _ in .unavailable },
            create: { _ in throw WorkspaceStoreError.injectedFailure },
            clearSelection: {}
        )
    }
}
