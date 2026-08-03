import CryptoKit
import Foundation
import XCTest
@testable import RekonPursuit

@MainActor
final class WorkspaceViewModelTests: XCTestCase {
    func testHomeDashboardSnapshotUsesRealWorkspaceDataAndLocalCalendarWeek() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1_746_576_000) // 2025-05-12T12:00:00Z
        let thisWeek = Date(timeIntervalSince1970: 1_746_403_200) // 2025-05-10T12:00:00Z
        let previousWeek = Date(timeIntervalSince1970: 1_745_798_400)
        let opportunities = [
            Opportunity(id: "saved", title: "Saved role", company: "Rekon Labs", createdAt: now, stage: .saved),
            Opportunity(id: "applied-this-week", title: "Recent application", company: "Rekon Labs", createdAt: now, stage: .applied, applicationDate: thisWeek),
            Opportunity(id: "applied-last-week", title: "Older application", company: "Rekon Labs", createdAt: now, stage: .applied, applicationDate: previousWeek),
            Opportunity(id: "interview", title: "Interview role", company: "Rekon Labs", createdAt: now, stage: .interviewing),
            Opportunity(id: "closed", title: "Closed role", company: "Rekon Labs", createdAt: now, stage: .closed)
        ]
        let tasks = [
            TaskReminder(id: "task", opportunityID: "interview", title: "Prepare interview", dueAt: now, isComplete: false)
        ]

        let snapshot = HomeDashboardSnapshot(opportunities: opportunities, attentionTasks: tasks, now: now, calendar: calendar)

        XCTAssertEqual(snapshot.activeOpportunityCount, 4)
        XCTAssertEqual(snapshot.appliedThisWeekCount, 1)
        XCTAssertEqual(snapshot.interviewCount, 1)
        XCTAssertTrue(snapshot.upcomingOpportunities.isEmpty)
    }

    func testHomeDashboardSnapshotOrdersAttentionAndDoesNotFabricateEmptyState() {
        let now = Date(timeIntervalSince1970: 1_746_576_000)
        let tasks = [
            TaskReminder(id: "undated", opportunityID: "one", title: "Undated", dueAt: nil, isComplete: false),
            TaskReminder(id: "later", opportunityID: "one", title: "Later", dueAt: now.addingTimeInterval(3_600), isComplete: false),
            TaskReminder(id: "earlier", opportunityID: "one", title: "Earlier", dueAt: now.addingTimeInterval(-3_600), isComplete: false),
            TaskReminder(id: "complete", opportunityID: "one", title: "Complete", dueAt: now, isComplete: true)
        ]
        let snapshot = HomeDashboardSnapshot(opportunities: [], attentionTasks: tasks, now: now, calendar: .current)

        XCTAssertEqual(snapshot.attentionTasks.map(\.id), ["earlier", "undated"])
        XCTAssertTrue(snapshot.upcomingOpportunities.isEmpty)
        XCTAssertEqual(snapshot.activeOpportunityCount, 0)
        XCTAssertEqual(snapshot.appliedThisWeekCount, 0)
        XCTAssertEqual(snapshot.interviewCount, 0)
    }

    func testHomeDashboardSnapshotSeparatesFutureScheduledActionsFromAttention() {
        let now = Date(timeIntervalSince1970: 1_746_576_000)
        let opportunities = [
            Opportunity(id: "tomorrow", title: "Platform Engineer", company: "Apex Cloud", createdAt: now, nextAction: "Phone screen", dueAt: now.addingTimeInterval(86_400)),
            Opportunity(id: "later", title: "Staff Engineer", company: "Rekon Labs", createdAt: now, nextAction: "Final interview", dueAt: now.addingTimeInterval(3 * 86_400)),
            Opportunity(id: "past", title: "Past role", company: "Rekon Labs", createdAt: now, nextAction: "Follow up", dueAt: now.addingTimeInterval(-3_600)),
            Opportunity(id: "blank", title: "Blank action", company: "Rekon Labs", createdAt: now, nextAction: " ", dueAt: now.addingTimeInterval(86_400)),
            Opportunity(id: "outside-week", title: "Later role", company: "Rekon Labs", createdAt: now, nextAction: "Panel interview", dueAt: now.addingTimeInterval(8 * 86_400)),
            Opportunity(id: "closed", title: "Closed role", company: "Rekon Labs", createdAt: now, stage: .closed, nextAction: "Meeting", dueAt: now.addingTimeInterval(2 * 86_400))
        ]
        let tasks = [
            TaskReminder(id: "overdue", opportunityID: "past", title: "Follow up", dueAt: now.addingTimeInterval(-3_600), isComplete: false)
        ]

        let snapshot = HomeDashboardSnapshot(opportunities: opportunities, attentionTasks: tasks, now: now, calendar: .current)

        XCTAssertEqual(snapshot.attentionTasks.map(\.id), ["overdue"])
        XCTAssertEqual(snapshot.upcomingOpportunities.map(\.id), ["tomorrow", "later"])
    }

    func testHomeDashboardSnapshotCountsAnApplicationAcrossCalendarYearWeekBoundary() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2025, month: 1, day: 1, hour: 12))!
        let mondayOfThatWeek = calendar.date(from: DateComponents(year: 2024, month: 12, day: 30, hour: 12))!
        let snapshot = HomeDashboardSnapshot(
            opportunities: [
                Opportunity(id: "boundary", title: "Boundary", company: "Rekon Labs", createdAt: now, stage: .applied, applicationDate: mondayOfThatWeek)
            ],
            attentionTasks: [],
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.appliedThisWeekCount, 1)
    }

    func testHomeDashboardReadDoesNotMutateStoreRecordsOrActivityEvidence() throws {
        let store = try makeStore()
        _ = try store.create(CreateOpportunity(
            title: "Read-only role",
            company: "Rekon Labs",
            nextAction: "Follow up",
            dueAt: Date(timeIntervalSince1970: 1_746_576_000)
        ))
        let opportunitiesBefore = try store.opportunities()
        let tasksBefore = try store.needsAttention()
        let eventsBefore = try store.activityEvents()

        _ = HomeDashboardSnapshot(
            opportunities: try store.opportunities(),
            attentionTasks: try store.needsAttention(),
            now: Date(timeIntervalSince1970: 1_746_576_000),
            calendar: .current
        )

        XCTAssertEqual(try store.opportunities(), opportunitiesBefore)
        XCTAssertEqual(try store.needsAttention(), tasksBefore)
        XCTAssertEqual(try store.activityEvents(), eventsBefore)
    }

    func testHomeActionsPersistAndWriteAuditEvidenceAcrossFreshViewModels() throws {
        let commandNow = Date(timeIntervalSince1970: 1_746_576_000)
        let store = try makeStore(now: commandNow)
        let opportunity = try store.create(CreateOpportunity(
            title: "Persisted role",
            company: "Rekon Labs",
            nextAction: "Follow up",
            dueAt: Date(timeIntervalSince1970: 1_746_576_000)
        ))
        let first = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, separateLocalWorkspace: .disabledForTesting)
        first.start()
        guard let task = first.needsAttention.first else {
            return XCTFail("Expected the stored next action to appear on Home.")
        }
        let eventCountBefore = try store.activityEvents().count

        let rescheduledDueAt = try XCTUnwrap(task.dueAt?.addingTimeInterval(3 * 86_400))
        first.reschedule(task, to: rescheduledDueAt)
        let reopenedAfterReschedule = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, separateLocalWorkspace: .disabledForTesting)
        reopenedAfterReschedule.start()
        guard let rescheduled = reopenedAfterReschedule.needsAttention.first else {
            return XCTFail("Expected rescheduled action after reopening the workspace.")
        }
        XCTAssertEqual(rescheduled.dueAt, rescheduledDueAt)

        reopenedAfterReschedule.snoozeOneDay(rescheduled)
        let reopenedAfterSnooze = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, separateLocalWorkspace: .disabledForTesting)
        reopenedAfterSnooze.start()
        guard let snoozed = reopenedAfterSnooze.needsAttention.first else {
            return XCTFail("Expected snoozed action after reopening the workspace.")
        }
        XCTAssertEqual(snoozed.opportunityID, opportunity.id)
        XCTAssertEqual(snoozed.dueAt, commandNow.addingTimeInterval(86_400))

        reopenedAfterSnooze.complete(snoozed)
        let reopenedAfterComplete = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, separateLocalWorkspace: .disabledForTesting)
        reopenedAfterComplete.start()
        XCTAssertTrue(reopenedAfterComplete.needsAttention.isEmpty)
        XCTAssertGreaterThan(try store.activityEvents().count, eventCountBefore)
    }

    private func makeVerifiedPortableArchive() -> VerifiedPortableArchive {
        VerifiedPortableArchive(
            archiveID: UUID(),
            createdAt: Date(timeIntervalSince1970: 1_704_067_200),
            expiresAt: Date(timeIntervalSince1970: 1_706_659_200),
            ciphertextChecksum: Data(repeating: 1, count: 32),
            signingKeyFingerprint: Data(repeating: 2, count: 32)
        )
    }

    func testRefreshIncludesLifecycleAwareDocumentReferenceSummary() throws {
        let store = try makeStore()
        let opportunity = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs"))
        _ = try store.recordDocumentReference(RecordDocumentReference(
            opportunityID: opportunity.id,
            kind: .resume,
            filename: "resume.pdf",
            contentType: "application/pdf",
            sourceHash: String(repeating: "a", count: 64),
            byteCount: 1,
            bookmarkData: Data([0x01])
        ))
        _ = try store.recordDocumentReference(RecordDocumentReference(
            opportunityID: opportunity.id,
            kind: .coverLetter,
            filename: "cover.pdf",
            contentType: "application/pdf",
            sourceHash: String(repeating: "b", count: 64),
            byteCount: 1
        ))
        let model = WorkspaceViewModel(
            openWorkspace: { .ready(store) },
            createWorkspace: { store },
            separateLocalWorkspace: .disabledForTesting
        )

        model.start()

        XCTAssertEqual(model.documentReferenceSummary, .init(availableCount: 1, relinkRequiredCount: 1))
    }

    func testSelectingOpportunityRefreshesOnlyThatOpportunitiesDocumentReferences() throws {
        let store = try makeStore()
        let first = try store.create(CreateOpportunity(title: "First", company: "Rekon Labs"))
        let second = try store.create(CreateOpportunity(title: "Second", company: "Rekon Labs"))
        _ = try store.recordDocumentReference(RecordDocumentReference(
            opportunityID: first.id,
            kind: .resume,
            filename: "first.pdf",
            contentType: "application/pdf",
            sourceHash: String(repeating: "a", count: 64),
            byteCount: 1,
            bookmarkData: Data([0x01])
        ))
        _ = try store.recordDocumentReference(RecordDocumentReference(
            opportunityID: second.id,
            kind: .coverLetter,
            filename: "second.pdf",
            contentType: "application/pdf",
            sourceHash: String(repeating: "b", count: 64),
            byteCount: 1,
            bookmarkData: Data([0x02])
        ))
        let model = WorkspaceViewModel(
            openWorkspace: { .ready(store) },
            createWorkspace: { store },
            separateLocalWorkspace: .disabledForTesting
        )

        model.start()
        model.select(second)

        XCTAssertEqual(model.selectedDocumentReferences.map(\.filename), ["second.pdf"])
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

    func testProtectedExportReviewFailureRemainsVisibleForCorrection() async throws {
        let store = try makeStore()
        let recoveryKey = try RecoveryKey.generate()
        try store.enroll(recoveryKey: recoveryKey)
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("existing-protected-export-\(UUID().uuidString).rekonexport")
        try Data("existing export".utf8).write(to: destination)
        defer { try? FileManager.default.removeItem(at: destination) }
        let model = WorkspaceViewModel(
            openWorkspace: { .ready(store) },
            createWorkspace: { store },
            protectedExportDestination: { destination },
            separateLocalWorkspace: .disabledForTesting
        )
        model.start()

        model.reviewProtectedExport(reentry: recoveryKey.displayValue)
        while model.isCreatingProtectedExport { await Task.yield() }

        XCTAssertNil(model.protectedExportReview)
        XCTAssertEqual(model.protectedExportErrorMessage, "That filename already exists. Choose a new filename; Rekon Pursuit will not replace a file.")
    }

    func testCancellingReviewedProtectedExportClearsReviewWithoutWritingOrChangingActiveWorkspace() async throws {
        let store = try makeStore()
        let recoveryKey = try RecoveryKey.generate()
        try store.enroll(recoveryKey: recoveryKey)
        let activeOpportunity = try store.create(CreateOpportunity(title: "Protected export cancellation", company: "Rekon Labs"))
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("cancel-reviewed-export-\(UUID().uuidString).rekonexport")
        defer { try? FileManager.default.removeItem(at: destination) }
        let model = WorkspaceViewModel(
            openWorkspace: { .ready(store) },
            createWorkspace: { store },
            protectedExportDestination: { destination },
            separateLocalWorkspace: .disabledForTesting
        )
        model.start()
        let activeIDsBeforeCancellation = model.opportunities.map(\.id)

        model.reviewProtectedExport(reentry: recoveryKey.displayValue)
        while model.isCreatingProtectedExport { await Task.yield() }
        XCTAssertNotNil(model.protectedExportReview)
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))

        model.cancelProtectedExport()

        XCTAssertNil(model.protectedExportReview)
        XCTAssertNil(model.protectedExportErrorMessage)
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
        XCTAssertTrue(model.workspaceReady)
        XCTAssertEqual(model.opportunities.map(\.id), activeIDsBeforeCancellation)
        XCTAssertEqual(model.opportunities.first?.id, activeOpportunity.id)
    }

    func testProtectedExportInvalidFilenameUsesExactCorrectionMessage() async throws {
        let fixture = try makeProtectedExportFeedbackModel(faultMode: .none, destinationName: "invalid-name.txt")
        defer { fixture.close() }

        fixture.model.reviewProtectedExport(reentry: fixture.recoveryKey.displayValue)
        await waitForProtectedExportFeedbackOperation(on: fixture.model)

        assertProtectedExportFeedback(
            on: fixture.model,
            message: "Choose a new file name ending in .rekonexport.",
            retainedReview: false
        )
    }

    func testProtectedExportUnavailableSelectedLeafConfirmUsesExactCorrectionMessage() async throws {
        let fixture = try makeProtectedExportFeedbackModel(faultMode: .directLeafUnavailable)
        defer { fixture.close() }

        fixture.model.reviewProtectedExport(reentry: fixture.recoveryKey.displayValue)
        await waitForProtectedExportFeedbackOperation(on: fixture.model)
        XCTAssertNotNil(fixture.model.protectedExportReview)

        fixture.model.confirmProtectedExport(reentry: fixture.recoveryKey.displayValue)
        await waitForProtectedExportFeedbackOperation(on: fixture.model)

        assertProtectedExportFeedback(
            on: fixture.model,
            message: "Rekon Pursuit can’t use that folder. Choose another local folder and review the export again.",
            retainedReview: true
        )
    }

    func testProtectedExportPostCreateFailureRetainsMayRemainFeedback() async throws {
        let fixture = try makeProtectedExportFeedbackModel(faultMode: .afterOutputCreation)
        defer { fixture.close() }

        fixture.model.reviewProtectedExport(reentry: fixture.recoveryKey.displayValue)
        await waitForProtectedExportFeedbackOperation(on: fixture.model)
        XCTAssertNotNil(fixture.model.protectedExportReview)

        fixture.model.confirmProtectedExport(reentry: fixture.recoveryKey.displayValue)
        await waitForProtectedExportFeedbackOperation(on: fixture.model)

        assertProtectedExportFeedback(
            on: fixture.model,
            message: "Final export writing or verification failed. The selected file may remain; treat it as unusable and remove it yourself.",
            retainedReview: true
        )
    }

    private func makeProtectedExportFeedbackStore(
        faultMode: ProtectedExportWorkerFaultMode
    ) throws -> ProtectedExportFeedbackModelStore {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("protected-export-feedback-model-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let database = try EncryptedDatabase.open(
            url: root.appendingPathComponent("workspace.sqlite"),
            key: Data(repeating: 22, count: 32),
            createIfMissing: true
        )
        let worker = ProtectedExportWorker(
            configuration: database.portableArchiveConnectionConfiguration(),
            faultMode: faultMode
        )
        let store = try WorkspaceStore(
            database: database,
            actorID: "protected-export-feedback-model",
            correlationID: "protected-export-feedback-model",
            protectedExportWorker: worker
        )
        let recoveryKey = try RecoveryKey.generate()
        try store.enroll(recoveryKey: recoveryKey)
        _ = try store.create(CreateOpportunity(title: "Protected export feedback", company: "Rekon Labs"))
        return .init(root: root, store: store, recoveryKey: recoveryKey)
    }

    private func makeProtectedExportFeedbackModel(
        faultMode: ProtectedExportWorkerFaultMode,
        destinationName: String = "feedback.rekonexport"
    ) throws -> ProtectedExportFeedbackModelFixture {
        let storeFixture = try makeProtectedExportFeedbackStore(faultMode: faultMode)
        let destination = storeFixture.root.appendingPathComponent(destinationName)
        let model = WorkspaceViewModel(
            openWorkspace: { .ready(storeFixture.store) },
            createWorkspace: { storeFixture.store },
            protectedExportDestination: { destination },
            separateLocalWorkspace: .disabledForTesting
        )
        model.start()
        return .init(storeFixture: storeFixture, model: model, destination: destination)
    }

    private func waitForProtectedExportFeedbackOperation(on model: WorkspaceViewModel) async {
        while model.isCreatingProtectedExport { await Task.yield() }
    }

    private func assertProtectedExportFeedback(
        on model: WorkspaceViewModel,
        message: String,
        retainedReview: Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(model.protectedExportErrorMessage, message, file: file, line: line)
        XCTAssertEqual(model.statusMessage, message, file: file, line: line)
        XCTAssertNil(model.protectedExportSuccess, file: file, line: line)
        let presentation = SettingsRootModalPresentation(
            portableArchiveRestoreState: model.portableArchiveRestoreState,
            protectedExportErrorMessage: model.protectedExportErrorMessage,
            protectedExportSuccess: model.protectedExportSuccess
        )
        XCTAssertFalse(presentation.isProtectedExportSuccessPresented, file: file, line: line)
        XCTAssertEqual(presentation.protectedExportErrorMessage, message, file: file, line: line)
        if retainedReview {
            XCTAssertNotNil(model.protectedExportReview, file: file, line: line)
        } else {
            XCTAssertNil(model.protectedExportReview, file: file, line: line)
        }
    }

    @MainActor
    private struct ProtectedExportFeedbackModelStore {
        let root: URL
        let store: WorkspaceStore
        let recoveryKey: RecoveryKey

        func close() {
            try? store.close()
            try? FileManager.default.removeItem(at: root)
        }
    }

    @MainActor
    private struct ProtectedExportFeedbackModelFixture {
        let storeFixture: ProtectedExportFeedbackModelStore
        let model: WorkspaceViewModel
        let destination: URL
        var recoveryKey: RecoveryKey { storeFixture.recoveryKey }

        func close() {
            storeFixture.close()
        }
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

    func testDeleteRemovesTheOpportunityFromThePipelineProjection() throws {
        let store = try makeStore()
        let visible = try store.create(CreateOpportunity(title: "Visible role", company: "Rekon Labs"))
        _ = try store.create(CreateOpportunity(title: "Other role", company: "Rekon Labs"))
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, separateLocalWorkspace: .disabledForTesting)
        model.start()

        XCTAssertEqual(
            model.filteredOpportunities(query: "", stage: "All stages", includesClosed: false).map(\.id),
            [visible.id, model.opportunities[1].id]
        )

        model.deleteOpportunity(visible)

        XCTAssertFalse(model.opportunities.contains { $0.id == visible.id })
        XCTAssertFalse(
            model.filteredOpportunities(query: "", stage: "All stages", includesClosed: false).contains { $0.id == visible.id },
            "Deletion must remove the record from the canonical Pipeline projection, not merely hide its table row."
        )
        XCTAssertFalse(try store.opportunities().contains { $0.id == visible.id })
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

    func testPipelineProjectionMatchesEveryCaseInsensitiveTokenAcrossTitleAndCompany() throws {
        let store = try makeStore()
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, separateLocalWorkspace: .disabledForTesting)
        model.start()
        model.title = "Senior Product Manager"
        model.company = "Northstar Labs"
        model.createOpportunity()
        model.title = "Designer"
        model.company = "Northstar Labs"
        model.createOpportunity()
        model.title = "Senior Product Manager"
        model.company = "Other employer"
        model.createOpportunity()

        XCTAssertEqual(
            model.filteredOpportunities(query: "northstar senior", stage: "All stages", includesClosed: false).map(\.title),
            ["Senior Product Manager"]
        )
        XCTAssertEqual(
            model.filteredOpportunities(query: "SENIOR northSTAR", stage: "All stages", includesClosed: false).map(\.title),
            ["Senior Product Manager"]
        )
        XCTAssertTrue(model.filteredOpportunities(query: "northstar missing", stage: "All stages", includesClosed: false).isEmpty)
    }

    func testPipelineProjectionUsesExplicitClosedVisibilityAndDoesNotMutateWorkspace() throws {
        let store = try makeStore()
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, separateLocalWorkspace: .disabledForTesting)
        model.start()
        model.title = "Saved role"
        model.company = "Rekon Labs"
        model.createOpportunity()
        model.title = "Screening role"
        model.company = "Rekon Labs"
        model.stage = .screening
        model.createOpportunity()
        model.title = "Closed role"
        model.company = "Rekon Labs"
        model.stage = .closed
        model.createOpportunity()

        let opportunityIDs = model.opportunities.map(\.id)
        let activityIDs = model.activityEvents.map(\.id)
        let storedIDs = try store.opportunities().map(\.id)

        XCTAssertEqual(
            model.filteredOpportunities(query: "", stage: PipelineStage.screening.rawValue, includesClosed: false).map(\.title),
            ["Screening role"]
        )
        XCTAssertEqual(
            model.filteredOpportunities(query: "", stage: "All stages", includesClosed: false).map(\.title),
            ["Saved role", "Screening role"]
        )
        XCTAssertEqual(
            model.filteredOpportunities(query: "", stage: "All stages", includesClosed: true).map(\.title),
            ["Saved role", "Screening role", "Closed role"]
        )

        XCTAssertEqual(model.opportunities.map(\.id), opportunityIDs)
        XCTAssertEqual(model.activityEvents.map(\.id), activityIDs)
        XCTAssertEqual(try store.opportunities().map(\.id), storedIDs)
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

    func testNeedsAttentionMarksReconciliationReviewForExplicitClosure() throws {
        let store = try makeStore()
        let opportunity = try store.create(CreateOpportunity(
            title: "Product Manager",
            company: "Rekon Labs",
            jobURL: "https://jobs.example.com/product-manager"
        ))
        _ = try store.recordReconciliationResult(RecordReconciliationResult(
            opportunityID: opportunity.id,
            url: opportunity.jobURL,
            outcome: .needsManualReview,
            classification: .offlineUnchecked,
            reason: .offlineUnchecked,
            evidence: "Offline — check not run"
        ))

        let task = try XCTUnwrap(store.needsAttention().first { $0.opportunityID == opportunity.id })

        XCTAssertTrue(task.requiresClosureConfirmation)
        XCTAssertThrowsError(try store.completeTask(id: task.id)) { error in
            guard case WorkspaceStoreError.reconciliationTaskRequiresClosure = error else {
                return XCTFail("Expected reconciliation-task closure protection, got \(error)")
            }
        }
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

    func testChangeStageAppliesCommittedProjectionAndSelectedHistory() throws {
        let store = try makeStore()
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, separateLocalWorkspace: .disabledForTesting)
        model.start()
        model.title = "Product Manager"
        model.company = "Rekon Labs"
        model.createOpportunity()
        let opportunity = try XCTUnwrap(model.opportunities.first)

        let result = model.changeStage(opportunity, to: .screening)

        XCTAssertEqual(result, .persisted(opportunityID: opportunity.id, from: .saved, to: .screening))
        XCTAssertEqual(model.opportunities.first?.stage, .screening)
        XCTAssertEqual(model.selectedStageHistory.last?.toStage, .screening)
        XCTAssertEqual(model.opportunityCount, model.opportunities.count)
        XCTAssertEqual(model.activityCount, model.activityEvents.count)
        XCTAssertEqual(model.needsAttentionCount, model.needsAttention.count)
        XCTAssertEqual(model.statusMessage, "Stage updated locally.")
    }

    func testChangeStagePersistedResultUpdatesEveryProjectionAndCountFromTheCommittedTransaction() throws {
        let store = try makeStore()
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, separateLocalWorkspace: .disabledForTesting)
        model.start()
        model.title = "Persisted role"
        model.company = "Rekon Labs"
        model.actionType = .other
        model.actionCustomText = "Follow up"
        model.hasDueDate = true
        model.dueAt = Date(timeIntervalSince1970: 1_704_067_200)
        model.createOpportunity()
        let opportunity = try XCTUnwrap(model.opportunities.first)
        let activityCountBefore = model.activityEvents.count

        XCTAssertEqual(model.changeStage(opportunity, to: .screening), .persisted(opportunityID: opportunity.id, from: .saved, to: .screening))

        XCTAssertEqual(model.opportunities.first(where: { $0.id == opportunity.id })?.stage, .screening)
        XCTAssertEqual(model.activityEvents.count, activityCountBefore + 1)
        XCTAssertEqual(model.activityEvents.last?.kind, "opportunity_stage_changed")
        XCTAssertEqual(model.activityEvents.last?.opportunityID, opportunity.id)
        XCTAssertEqual(model.selectedStageHistory.last?.fromStage, .saved)
        XCTAssertEqual(model.selectedStageHistory.last?.toStage, .screening)
        XCTAssertEqual(model.opportunityCount, model.opportunities.count)
        XCTAssertEqual(model.activityCount, model.activityEvents.count)
        XCTAssertEqual(model.needsAttentionCount, model.needsAttention.count)
        XCTAssertEqual(model.statusMessage, "Stage updated locally.")
    }

    func testChangeStageMapsEveryNonPersistedOutcomeWithoutChangingBoardProjectionOrSelection() throws {
        let store = try makeStore()
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, separateLocalWorkspace: .disabledForTesting)
        model.start()
        model.title = "Product Manager"
        model.company = "Rekon Labs"
        model.createOpportunity()
        let opportunity = try XCTUnwrap(model.opportunities.first)
        model.select(opportunity)
        let projectionBefore = model.opportunities
        let historyBefore = model.selectedStageHistory
        let selectionBefore = model.selectedOpportunityID

        XCTAssertEqual(model.changeStage(opportunity, to: .saved), .noOp(opportunityID: opportunity.id, stage: .saved))
        XCTAssertEqual(model.opportunities, projectionBefore)
        XCTAssertEqual(model.selectedStageHistory, historyBefore)
        XCTAssertEqual(model.selectedOpportunityID, selectionBefore)
        XCTAssertEqual(model.statusMessage, "This opportunity is already in that stage.")

        let unavailable = Opportunity(id: "missing", title: "Missing", company: "Missing", createdAt: Date.now)
        XCTAssertEqual(model.changeStage(unavailable, to: .screening), .unavailable(opportunityID: unavailable.id))
        XCTAssertEqual(model.opportunities, projectionBefore)
        XCTAssertEqual(model.selectedStageHistory, historyBefore)
        XCTAssertEqual(model.selectedOpportunityID, selectionBefore)
        XCTAssertEqual(model.statusMessage, "That opportunity is no longer available locally.")
    }

    func testChangeStageNoOpAndUnavailableRetainCompleteSelectedProjectionAndCounts() throws {
        let store = try makeStore()
        let first = try store.create(CreateOpportunity(title: "First", company: "Rekon Labs", nextAction: "Follow up", dueAt: Date(timeIntervalSince1970: 1_704_067_200)))
        _ = try store.create(CreateOpportunity(title: "Second", company: "Rekon Labs"))
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, separateLocalWorkspace: .disabledForTesting)
        model.start()
        model.select(first)
        let baseline = stageMoveBaseline(model)

        XCTAssertEqual(model.changeStage(first, to: .saved), .noOp(opportunityID: first.id, stage: .saved))
        assertStageMoveBaseline(stageMoveBaseline(model), equals: baseline)
        XCTAssertEqual(model.statusMessage, "This opportunity is already in that stage.")

        let missing = Opportunity(id: "missing", title: "Missing", company: "Rekon Labs", createdAt: Date(timeIntervalSince1970: 1_704_067_200))
        XCTAssertEqual(model.changeStage(missing, to: .screening), .unavailable(opportunityID: missing.id))
        assertStageMoveBaseline(stageMoveBaseline(model), equals: baseline)
        XCTAssertEqual(model.statusMessage, "That opportunity is no longer available locally.")
    }

    func testChangeStageReturnsUnavailableWhenNoReadyStoreExists() {
        let model = WorkspaceViewModel(openWorkspace: { .unavailable }, createWorkspace: { throw WorkspaceStoreError.injectedFailure }, separateLocalWorkspace: .disabledForTesting)
        let opportunity = Opportunity(id: "missing", title: "Missing", company: "Missing", createdAt: Date.now)

        XCTAssertEqual(model.changeStage(opportunity, to: .screening), .unavailable(opportunityID: opportunity.id))
        XCTAssertEqual(model.statusMessage, "That opportunity is no longer available locally.")
    }

    func testChangeStageMapsBlockedAndFailureWithoutChangingProjectionOrSelection() throws {
        let blockedStore = try makeStore()
        let blockedOpportunity = try blockedStore.create(CreateOpportunity(
            title: "Product Manager",
            company: "Rekon Labs",
            jobURL: "https://jobs.example.com/product-manager"
        ))
        _ = try blockedStore.recordReconciliationResult(RecordReconciliationResult(
            opportunityID: blockedOpportunity.id,
            url: blockedOpportunity.jobURL,
            outcome: .needsManualReview,
            classification: .offlineUnchecked,
            reason: .offlineUnchecked,
            evidence: "Offline — check not run"
        ))
        let blockedModel = WorkspaceViewModel(openWorkspace: { .ready(blockedStore) }, createWorkspace: { blockedStore }, separateLocalWorkspace: .disabledForTesting)
        blockedModel.start()
        blockedModel.select(blockedOpportunity)
        let blockedProjectionBefore = blockedModel.opportunities
        let blockedHistoryBefore = blockedModel.selectedStageHistory

        XCTAssertEqual(
            blockedModel.changeStage(blockedOpportunity, to: .closed),
            .reconciliationBlocked(opportunityID: blockedOpportunity.id, target: .closed)
        )
        XCTAssertEqual(blockedModel.opportunities, blockedProjectionBefore)
        XCTAssertEqual(blockedModel.selectedStageHistory, blockedHistoryBefore)
        XCTAssertEqual(blockedModel.statusMessage, "Confirm reconciliation before closing this opportunity.")

        let failingStore = try makeStore(stageMoveFailurePoint: .beforeProjectionRead)
        let failingModel = WorkspaceViewModel(openWorkspace: { .ready(failingStore) }, createWorkspace: { failingStore }, separateLocalWorkspace: .disabledForTesting)
        failingModel.start()
        failingModel.title = "Failure role"
        failingModel.company = "Rekon Labs"
        failingModel.createOpportunity()
        let failingOpportunity = try XCTUnwrap(failingModel.opportunities.first)
        failingModel.select(failingOpportunity)
        let failingProjectionBefore = failingModel.opportunities
        let failingHistoryBefore = failingModel.selectedStageHistory
        let failingSelectionBefore = failingModel.selectedOpportunityID

        XCTAssertEqual(
            failingModel.changeStage(failingOpportunity, to: .screening),
            .failed(opportunityID: failingOpportunity.id)
        )
        XCTAssertEqual(failingModel.opportunities, failingProjectionBefore)
        XCTAssertEqual(failingModel.selectedStageHistory, failingHistoryBefore)
        XCTAssertEqual(failingModel.selectedOpportunityID, failingSelectionBefore)
        XCTAssertEqual(failingModel.statusMessage, "The local stage was not changed.")
    }

    func testChangeStageBlockedAndFailedRetainCompleteSelectedProjectionAttentionAndCounts() throws {
        let blockedStore = try makeStore()
        let blocked = try blockedStore.create(CreateOpportunity(
            title: "Blocked",
            company: "Rekon Labs",
            nextAction: "Confirm review",
            dueAt: Date(timeIntervalSince1970: 1_704_067_200),
            jobURL: "https://jobs.example.com/blocked"
        ))
        _ = try blockedStore.recordReconciliationResult(RecordReconciliationResult(
            opportunityID: blocked.id,
            url: blocked.jobURL,
            outcome: .needsManualReview,
            classification: .offlineUnchecked,
            reason: .offlineUnchecked,
            evidence: "Offline — check not run"
        ))
        let blockedModel = WorkspaceViewModel(openWorkspace: { .ready(blockedStore) }, createWorkspace: { blockedStore }, separateLocalWorkspace: .disabledForTesting)
        blockedModel.start()
        blockedModel.select(blocked)
        let blockedBaseline = stageMoveBaseline(blockedModel)

        XCTAssertEqual(blockedModel.changeStage(blocked, to: .closed), .reconciliationBlocked(opportunityID: blocked.id, target: .closed))
        assertStageMoveBaseline(stageMoveBaseline(blockedModel), equals: blockedBaseline)
        XCTAssertEqual(blockedModel.statusMessage, "Confirm reconciliation before closing this opportunity.")

        let failingStore = try makeStore(stageMoveFailurePoint: .beforeProjectionRead)
        let failing = try failingStore.create(CreateOpportunity(title: "Failure", company: "Rekon Labs", nextAction: "Follow up", dueAt: Date(timeIntervalSince1970: 1_704_067_200)))
        let failingModel = WorkspaceViewModel(openWorkspace: { .ready(failingStore) }, createWorkspace: { failingStore }, separateLocalWorkspace: .disabledForTesting)
        failingModel.start()
        failingModel.select(failing)
        let failedBaseline = stageMoveBaseline(failingModel)

        XCTAssertEqual(failingModel.changeStage(failing, to: .screening), .failed(opportunityID: failing.id))
        assertStageMoveBaseline(stageMoveBaseline(failingModel), equals: failedBaseline)
        XCTAssertEqual(failingModel.statusMessage, "The local stage was not changed.")
    }

    func testChangeStageOfNonselectedOpportunityRetainsSelectedHistoryCache() throws {
        let store = try makeStore()
        let selected = try store.create(CreateOpportunity(title: "Selected", company: "Rekon Labs"))
        let moved = try store.create(CreateOpportunity(title: "Moved", company: "Rekon Labs"))
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, separateLocalWorkspace: .disabledForTesting)
        model.start()
        model.select(selected)
        let selectedHistoryBefore = model.selectedStageHistory
        let selectedDetailBefore = model.selectedOpportunity

        XCTAssertEqual(model.changeStage(moved, to: .screening), .persisted(opportunityID: moved.id, from: .saved, to: .screening))

        XCTAssertEqual(model.opportunities.first(where: { $0.id == moved.id })?.stage, .screening)
        XCTAssertEqual(model.selectedOpportunityID, selected.id)
        XCTAssertEqual(model.selectedOpportunity, selectedDetailBefore)
        XCTAssertEqual(model.selectedStageHistory, selectedHistoryBefore)
        XCTAssertEqual(model.opportunityCount, model.opportunities.count)
        XCTAssertEqual(model.activityCount, model.activityEvents.count)
        XCTAssertEqual(model.needsAttentionCount, model.needsAttention.count)
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
        model.contactLinkedInURL = "http://profiles.example.com/alex"
        XCTAssertEqual(model.contactLinkedInURLWarning, "This profile URL uses HTTP rather than HTTPS.")

        model.contactLinkedInURL = "profiles.example.com/alex"
        XCTAssertEqual(model.contactLinkedInURLWarning, "Use an absolute http or https profile URL with a public hostname.")
        model.createContact()

        XCTAssertEqual(model.contacts, [])
        XCTAssertEqual(model.statusMessage, "Enter an absolute http or https social profile URL with a public hostname.")
    }

    func testInvalidContactFieldsExposeASaveErrorWithoutWriting() throws {
        let store = try makeStore()
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, separateLocalWorkspace: .disabledForTesting)

        model.start()
        model.contactName = "Alex Morgan"
        model.contactWorkEmail = "alex@"
        XCTAssertEqual(model.contactWorkEmailWarning, "Enter a work email address with a local part, @, and domain.")
        model.createContact()

        XCTAssertEqual(model.contactSaveError, "Enter a work email address with a local part, @, and domain.")
        XCTAssertEqual(try store.contacts(), [])

        model.contactWorkEmail = "alex@example.com"
        model.contactLinkedInURL = "https://microsoft"
        model.createContact()

        XCTAssertEqual(model.contactSaveError, "Enter an absolute http or https social profile URL with a public hostname.")
        XCTAssertEqual(try store.contacts(), [])
    }

    func testContactEmailHandlerDelimitersExposeWarningsWithoutWriting() throws {
        // This catches editor warning validation diverging from store validation
        // and allowing a handler delimiter through either email field.
        let store = try makeStore()
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, separateLocalWorkspace: .disabledForTesting)
        let unsafeAddresses = [
            "victim@example.test?cc=attacker.example.test",
            "victim#tag@example.test",
            "victim/name@example.test",
            "victim&other@example.test"
        ]

        model.start()
        let contactsBeforeRejections = try store.contacts()
        let activitiesBeforeRejections = try store.activityEvents()
        for address in unsafeAddresses {
            model.contactName = "Rejected email"
            model.contactWorkEmail = address
            model.contactPersonalEmail = ""
            XCTAssertEqual(model.contactWorkEmailWarning, "Enter a work email address with a local part, @, and domain.")
            model.createContact()
            XCTAssertEqual(model.contactSaveError, "Enter a work email address with a local part, @, and domain.")
            XCTAssertEqual(try store.contacts(), contactsBeforeRejections)
            XCTAssertEqual(try store.activityEvents(), activitiesBeforeRejections)

            model.contactWorkEmail = ""
            model.contactPersonalEmail = address
            XCTAssertEqual(model.contactPersonalEmailWarning, "Enter a personal email address with a local part, @, and domain.")
            model.createContact()
            XCTAssertEqual(model.contactSaveError, "Enter a personal email address with a local part, @, and domain.")
            XCTAssertEqual(try store.contacts(), contactsBeforeRejections)
            XCTAssertEqual(try store.activityEvents(), activitiesBeforeRejections)
        }
    }

    func testContactActionURLBuildsAnExactMailtoTarget() throws {
        // This catches a contact email action that opens a web URL or omits
        // the exact recipient path, or adds query/fragment handler components.
        let address = "alex.morgan+jobs@example-domain.com"
        let url = try XCTUnwrap(ContactActionURL.email(address))
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))

        XCTAssertEqual(url.absoluteString, "mailto:\(address)")
        XCTAssertEqual(components.scheme, "mailto")
        XCTAssertEqual(components.path, address)
        XCTAssertNil(components.query)
        XCTAssertNil(components.fragment)
    }

    func testContactActionURLRejectsUnsafeEmailTargets() {
        // This catches malformed address or handler syntax reaching the system
        // mail opener even if untrusted text bypasses the editor and store.
        let unsafeAddresses = [
            "victim@example.test?cc=attacker.example.test",
            "victim#tag@example.test",
            "victim/name@example.test",
            "victim&other@example.test",
            "victim@example.test@attacker.test",
            "victim @example.test",
            "victim\n@example.test",
            "@example.test",
            "victim@",
            "victim@example",
            "victim@example..test",
            "victim@-example.test",
            "victim@example-.test"
        ]

        for address in unsafeAddresses {
            XCTAssertNil(ContactActionURL.email(address), "accepted unsafe address: \(address)")
        }
    }

    func testContactActionURLBuildsTelephoneTargetWithExtension() {
        // This catches a telephone action that leaves display punctuation in
        // its target, drops a leading plus, or loses the dialable extension.
        XCTAssertEqual(
            ContactActionURL.phone("+1 (212) 555-0102 ext. 7")?.absoluteString,
            "tel:+12125550102;ext=7"
        )
    }

    func testContactActionURLRejectsAnUnusableTelephoneValue() {
        // This catches a displayed non-dialable value accidentally becoming
        // an action with an invalid system-handler target.
        XCTAssertNil(ContactActionURL.phone("(ext.)"))
    }

    func testContactActionURLPreservesSavedSocialTargets() {
        // This catches a social action that rewrites or selects a URL other
        // than the validated value saved for the contact channel.
        XCTAssertEqual(
            ContactActionURL.social("https://www.linkedin.com/in/alex-morgan")?.absoluteString,
            "https://www.linkedin.com/in/alex-morgan"
        )
        XCTAssertEqual(
            ContactActionURL.social("https://www.instagram.com/alex.morgan")?.absoluteString,
            "https://www.instagram.com/alex.morgan"
        )
        XCTAssertEqual(
            ContactActionURL.social("https://www.facebook.com/alex.morgan")?.absoluteString,
            "https://www.facebook.com/alex.morgan"
        )
    }

    func testContactActionURLAllowsOnlyPublicWebSocialTargets() {
        // This catches a legacy or otherwise unvalidated social value sending
        // a non-web URL to the system URL handler.
        XCTAssertEqual(
            ContactActionURL.social("https://www.linkedin.com/in/alex-morgan")?.absoluteString,
            "https://www.linkedin.com/in/alex-morgan"
        )
        XCTAssertEqual(
            ContactActionURL.social("http://profiles.example.test/alex")?.absoluteString,
            "http://profiles.example.test/alex"
        )
        XCTAssertEqual(
            ContactActionURL.social("http://8.8.8.8/profile")?.absoluteString,
            "http://8.8.8.8/profile"
        )

        let unsafeAddresses = [
            "file:///Users/example/private.txt",
            "mailto:alex@example.com",
            "tel:+12125550102",
            "rekon://profile/alex",
            "/profiles/alex",
            "https://localhost/profile/alex",
            "https://localhost.localdomain/profile",
            "https://printer.local/profile",
            "https://intranet/profile/alex",
            "https://127.0.0.1/profile",
            "https://127.1/profile",
            "https://10.0.0.1/profile",
            "https://172.16.0.1/profile",
            "https://192.168.0.1/profile",
            "https://169.254.169.254/latest/meta-data",
            "https://[::1]/profile",
            "https://[fe80::1]/profile",
            "https://[fd00::1]/profile"
        ]

        for address in unsafeAddresses {
            XCTAssertNil(ContactActionURL.social(address), "accepted unsafe social URL: \(address)")
        }
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

    func testVD206ContactSelectionAndNewDraftDoNotWrite() throws {
        // This catches a regression where merely selecting, restoring, or
        // clearing a Contacts draft persists fields, links, or audit evidence.
        let store = try makeStore()
        let linkedOpportunity = try store.create(CreateOpportunity(title: "Linked opportunity", company: "Fixture North"))
        let contact = try store.createContact(CreateContact(
            name: "Contacts Primary",
            employer: "Fixture North",
            title: "Recruiter",
            workEmail: "primary@example.test",
            personalEmail: "primary.personal@example.test",
            mobilePhone: "+1 212 555 0101",
            officePhone: "+1 212 555 0102",
            linkedInURL: "https://profiles.example.test/primary",
            instagramURL: "https://instagram.example.test/primary",
            facebookURL: "https://facebook.example.test/primary",
            relationshipContext: "Warm introduction",
            notes: "Persisted note"
        ))
        try store.linkContact(contactID: contact.id, toOpportunityID: linkedOpportunity.id)
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, separateLocalWorkspace: .disabledForTesting)

        model.start()
        let persistedContacts = model.contacts
        let persistedOpportunities = model.opportunities
        let persistedActivities = model.activityEvents
        let selectedOpportunityID = model.selectedOpportunityID

        model.selectContact(contact)
        XCTAssertEqual(model.contactName, "Contacts Primary")
        XCTAssertEqual(model.contactEmployer, "Fixture North")
        XCTAssertEqual(model.contactTitle, "Recruiter")
        XCTAssertEqual(model.contactWorkEmail, "primary@example.test")
        XCTAssertEqual(model.contactPersonalEmail, "primary.personal@example.test")
        XCTAssertEqual(model.contactMobilePhone, "+1 212 555 0101")
        XCTAssertEqual(model.contactOfficePhone, "+1 212 555 0102")
        XCTAssertEqual(model.contactLinkedInURL, "https://profiles.example.test/primary")
        XCTAssertEqual(model.contactInstagramURL, "https://instagram.example.test/primary")
        XCTAssertEqual(model.contactFacebookURL, "https://facebook.example.test/primary")
        XCTAssertEqual(model.contactRelationshipContext, "Warm introduction")
        XCTAssertEqual(model.contactNotes, "Persisted note")
        XCTAssertEqual(model.selectedContactOpportunities.map(\.id), [linkedOpportunity.id])
        XCTAssertEqual(model.activityEvents, persistedActivities)

        // ContactsView owns cancellation state. Re-selecting the persisted
        // contact is the existing model primitive that cancels an edit draft.
        model.contactName = "Unsaved replacement"
        model.contactEmployer = "Unsaved employer"
        model.contactTitle = "Unsaved title"
        model.contactWorkEmail = "unsaved@example.test"
        model.contactPersonalEmail = "unsaved.personal@example.test"
        model.contactMobilePhone = "+1 212 555 0191"
        model.contactOfficePhone = "+1 212 555 0192"
        model.contactLinkedInURL = "https://profiles.example.test/unsaved"
        model.contactInstagramURL = "https://instagram.example.test/unsaved"
        model.contactFacebookURL = "https://facebook.example.test/unsaved"
        model.contactRelationshipContext = "Unsaved context"
        model.contactNotes = "Unsaved replacement note"
        model.selectContact(contact)
        XCTAssertEqual(model.contactName, "Contacts Primary")
        XCTAssertEqual(model.contactEmployer, "Fixture North")
        XCTAssertEqual(model.contactTitle, "Recruiter")
        XCTAssertEqual(model.contactWorkEmail, "primary@example.test")
        XCTAssertEqual(model.contactPersonalEmail, "primary.personal@example.test")
        XCTAssertEqual(model.contactMobilePhone, "+1 212 555 0101")
        XCTAssertEqual(model.contactOfficePhone, "+1 212 555 0102")
        XCTAssertEqual(model.contactLinkedInURL, "https://profiles.example.test/primary")
        XCTAssertEqual(model.contactInstagramURL, "https://instagram.example.test/primary")
        XCTAssertEqual(model.contactFacebookURL, "https://facebook.example.test/primary")
        XCTAssertEqual(model.contactRelationshipContext, "Warm introduction")
        XCTAssertEqual(model.contactNotes, "Persisted note")

        let afterEditCancel = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, separateLocalWorkspace: .disabledForTesting)
        afterEditCancel.start()
        XCTAssertEqual(afterEditCancel.contacts, persistedContacts)
        XCTAssertEqual(afterEditCancel.activityEvents, persistedActivities)
        afterEditCancel.selectContact(contact)
        XCTAssertEqual(afterEditCancel.selectedContactOpportunities.map(\.id), [linkedOpportunity.id])

        // A selected contact is restored with the same primitive when a new
        // contact draft is cancelled; no save or link command is dispatched.
        model.beginNewContact()
        model.contactName = "Cancelled new contact"
        model.contactEmployer = "Cancelled employer"
        model.contactTitle = "Cancelled title"
        model.contactWorkEmail = "cancelled@example.test"
        model.contactPersonalEmail = "cancelled.personal@example.test"
        model.contactMobilePhone = "+1 212 555 0171"
        model.contactOfficePhone = "+1 212 555 0172"
        model.contactLinkedInURL = "https://profiles.example.test/cancelled"
        model.contactInstagramURL = "https://instagram.example.test/cancelled"
        model.contactFacebookURL = "https://facebook.example.test/cancelled"
        model.contactRelationshipContext = "Cancelled context"
        model.contactNotes = "Cancelled note"
        model.selectContact(contact)
        XCTAssertEqual(model.selectedContactID, contact.id)
        XCTAssertEqual(model.contactName, "Contacts Primary")
        XCTAssertEqual(model.contactEmployer, "Fixture North")
        XCTAssertEqual(model.contactTitle, "Recruiter")
        XCTAssertEqual(model.contactWorkEmail, "primary@example.test")
        XCTAssertEqual(model.contactPersonalEmail, "primary.personal@example.test")
        XCTAssertEqual(model.contactMobilePhone, "+1 212 555 0101")
        XCTAssertEqual(model.contactOfficePhone, "+1 212 555 0102")
        XCTAssertEqual(model.contactLinkedInURL, "https://profiles.example.test/primary")
        XCTAssertEqual(model.contactInstagramURL, "https://instagram.example.test/primary")
        XCTAssertEqual(model.contactFacebookURL, "https://facebook.example.test/primary")
        XCTAssertEqual(model.contactRelationshipContext, "Warm introduction")
        XCTAssertEqual(model.contactNotes, "Persisted note")

        // With no selected record, the new-contact primitive itself clears
        // only the draft and leaves persisted Contacts state untouched.
        model.beginNewContact()
        XCTAssertEqual(model.selectedContactID, "")
        XCTAssertEqual(model.contactName, "")
        XCTAssertEqual(model.contactEmployer, "")
        XCTAssertEqual(model.contactTitle, "")
        XCTAssertEqual(model.contactWorkEmail, "")
        XCTAssertEqual(model.contactPersonalEmail, "")
        XCTAssertEqual(model.contactMobilePhone, "")
        XCTAssertEqual(model.contactOfficePhone, "")
        XCTAssertEqual(model.contactLinkedInURL, "")
        XCTAssertEqual(model.contactInstagramURL, "")
        XCTAssertEqual(model.contactFacebookURL, "")
        XCTAssertEqual(model.contactRelationshipContext, "")
        XCTAssertEqual(model.contactNotes, "")
        XCTAssertEqual(model.contacts, persistedContacts)
        XCTAssertEqual(model.opportunities, persistedOpportunities)
        XCTAssertEqual(model.selectedOpportunityID, selectedOpportunityID)
        XCTAssertEqual(model.activityEvents, persistedActivities)

        let afterNewCancel = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, separateLocalWorkspace: .disabledForTesting)
        afterNewCancel.start()
        XCTAssertEqual(afterNewCancel.contacts, persistedContacts)
        XCTAssertEqual(afterNewCancel.activityEvents, persistedActivities)
        afterNewCancel.selectContact(contact)
        XCTAssertEqual(afterNewCancel.selectedContactOpportunities.map(\.id), [linkedOpportunity.id])
    }

    func testVD206ContactSearchMatchesBothEmailsAndPhones() throws {
        // This catches a Contacts search projection that omits one of the
        // persisted email or telephone channels.
        let store = try makeStore()
        let contacts = try [
            CreateContact(name: "Work email", workEmail: "work-match@example.test"),
            CreateContact(name: "Personal email", personalEmail: "personal-match@example.test"),
            CreateContact(name: "Mobile phone", mobilePhone: "+1 212 555 0191"),
            CreateContact(name: "Office phone", officePhone: "+1 212 555 0192")
        ].map(store.createContact)
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, separateLocalWorkspace: .disabledForTesting)
        model.start()

        for (query, expectedID) in [("work-match", contacts[0].id), ("personal-match", contacts[1].id), ("0191", contacts[2].id), ("0192", contacts[3].id)] {
            model.contactSearch = query
            XCTAssertEqual(model.filteredContacts.map(\.id), [expectedID])
        }
    }

    func testVD206ContactFailuresRetainDraftAndAssociations() throws {
        // This catches a failed Contacts command that clears the visible draft
        // or association projection, or mutates encrypted storage despite a
        // rejected validation/store operation.
        let fixture = try makeReopenableContactStore()
        let linkedOpportunity = try fixture.store.create(CreateOpportunity(title: "Linked opportunity", company: "Fixture North"))
        let unlinkedOpportunity = try fixture.store.create(CreateOpportunity(title: "Unlinked opportunity", company: "Fixture North"))
        let contact = try fixture.store.createContact(CreateContact(name: "Contacts Primary", employer: "Fixture North", title: "Recruiter"))
        try fixture.store.linkContact(contactID: contact.id, toOpportunityID: linkedOpportunity.id)
        let model = WorkspaceViewModel(openWorkspace: { .ready(fixture.store) }, createWorkspace: { fixture.store }, separateLocalWorkspace: .disabledForTesting)

        model.start()
        let contactsBeforeInvalidInput = model.contacts
        let activitiesBeforeInvalidInput = model.activityEvents
        model.contactName = "Invalid email"
        model.contactWorkEmail = "invalid@"
        model.createContact()
        XCTAssertEqual(model.contacts, contactsBeforeInvalidInput)
        XCTAssertEqual(model.activityEvents, activitiesBeforeInvalidInput)
        XCTAssertEqual(model.contactSaveError, "Enter a work email address with a local part, @, and domain.")

        model.contactWorkEmail = "valid@example.test"
        model.contactLinkedInURL = "profiles.example.test/invalid"
        model.createContact()
        XCTAssertEqual(model.contacts, contactsBeforeInvalidInput)
        XCTAssertEqual(model.activityEvents, activitiesBeforeInvalidInput)
        XCTAssertEqual(model.contactSaveError, "Enter an absolute http or https social profile URL with a public hostname.")

        model.selectContact(contact)
        let linkedIDsBeforeFailure = model.selectedContactOpportunities.map(\.id)
        let activityIDsBeforeFailure = model.activityEvents.map(\.id)
        try fixture.store.close()

        model.contactTitle = "Unpersisted title"
        model.saveSelectedContact()
        XCTAssertEqual(model.contactTitle, "Unpersisted title")
        let saveFailure = try XCTUnwrap(model.contactSaveError)
        XCTAssertFalse(saveFailure.isEmpty)
        XCTAssertEqual(model.statusMessage, saveFailure)
        XCTAssertTrue(saveFailure.contains("Database is closed."))

        model.contactName = "Unpersisted create"
        model.createContact()
        XCTAssertEqual(model.contactName, "Unpersisted create")
        let createFailure = try XCTUnwrap(model.contactSaveError)
        XCTAssertFalse(createFailure.isEmpty)
        XCTAssertEqual(model.statusMessage, createFailure)
        XCTAssertTrue(createFailure.contains("Database is closed."))

        model.linkSelectedContact(to: unlinkedOpportunity)
        XCTAssertEqual(model.selectedContactOpportunities.map(\.id), linkedIDsBeforeFailure)
        XCTAssertEqual(model.statusMessage, "The contact could not be linked.")

        model.unlinkSelectedContact(from: linkedOpportunity)
        XCTAssertEqual(model.selectedContactOpportunities.map(\.id), linkedIDsBeforeFailure)
        XCTAssertEqual(model.statusMessage, "The contact could not be unlinked.")

        let reopenedStore = try reopenContactStore(databaseURL: fixture.databaseURL, key: fixture.key)
        defer { try? reopenedStore.close() }
        XCTAssertEqual(try reopenedStore.contacts(), [contact])
        XCTAssertEqual(try reopenedStore.opportunities(forContactID: contact.id).map(\.id), [linkedOpportunity.id])
        XCTAssertEqual(try reopenedStore.activityEvents().map(\.id), activityIDsBeforeFailure)
    }

    func testVD206ContactAuditAndRelaunchContracts() throws {
        // This catches Contacts save/link/unlink/delete paths that skip their
        // local activity evidence, fail to survive a fresh model, or leave a
        // deleted contact selected with stale relationship caches.
        let store = try makeStore()
        let opportunity = try store.create(CreateOpportunity(title: "Managed opportunity", company: "Fixture North"))
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, separateLocalWorkspace: .disabledForTesting)

        model.start()
        model.contactName = "Contacts Primary"
        model.contactEmployer = "Fixture North"
        model.contactTitle = "Recruiter"
        model.createContact()
        let contact = try XCTUnwrap(model.selectedContact)
        XCTAssertTrue(model.activityEvents.contains { $0.kind == "contact_created" && $0.contactID == contact.id })

        let afterCreate = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, separateLocalWorkspace: .disabledForTesting)
        afterCreate.start()
        XCTAssertEqual(afterCreate.contacts.map(\.id), [contact.id])

        model.contactTitle = "Senior Recruiter"
        model.saveSelectedContact()
        XCTAssertTrue(model.activityEvents.contains { $0.kind == "contact_updated" && $0.contactID == contact.id })
        let afterUpdate = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, separateLocalWorkspace: .disabledForTesting)
        afterUpdate.start()
        XCTAssertEqual(afterUpdate.contacts.first?.title, "Senior Recruiter")

        model.linkSelectedContact(to: opportunity)
        XCTAssertEqual(model.selectedContactOpportunities.map(\.id), [opportunity.id])
        XCTAssertTrue(model.activityEvents.contains { $0.kind == "contact_linked" && $0.contactID == contact.id && $0.opportunityID == opportunity.id })
        let afterLink = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, separateLocalWorkspace: .disabledForTesting)
        afterLink.start()
        afterLink.selectContact(contact)
        XCTAssertEqual(afterLink.selectedContactOpportunities.map(\.id), [opportunity.id])

        model.unlinkSelectedContact(from: opportunity)
        XCTAssertEqual(model.selectedContactOpportunities, [])
        XCTAssertTrue(model.activityEvents.contains { $0.kind == "contact_unlinked" && $0.contactID == contact.id && $0.opportunityID == opportunity.id })
        let afterUnlink = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, separateLocalWorkspace: .disabledForTesting)
        afterUnlink.start()
        afterUnlink.selectContact(contact)
        XCTAssertEqual(afterUnlink.selectedContactOpportunities, [])

        model.linkSelectedContact(to: opportunity)
        model.deleteContact(contact)
        XCTAssertTrue(model.activityEvents.contains { $0.kind == "contact_deleted" && $0.contactID == contact.id })
        XCTAssertEqual(model.contacts, [])
        XCTAssertNil(model.selectedContact)
        XCTAssertEqual(model.selectedContactID, "")
        XCTAssertEqual(model.selectedContactOpportunities, [])
        XCTAssertEqual(model.selectedContactEmployerOpportunities, [])
        XCTAssertEqual(model.selectedContactInteractions, [])
        XCTAssertNil(model.selectedContactLastTouch)
        XCTAssertNil(model.selectedContactNextTouch)
        XCTAssertEqual(model.contactName, "")
        XCTAssertEqual(model.contactEmployer, "")
        XCTAssertEqual(model.contactEmployerSearch, "")
        XCTAssertFalse(model.isAddingNewContactEmployer)
        XCTAssertEqual(model.contactTitle, "")
        XCTAssertEqual(model.contactWorkEmail, "")
        XCTAssertEqual(model.contactPersonalEmail, "")
        XCTAssertEqual(model.contactMobilePhone, "")
        XCTAssertEqual(model.contactOfficePhone, "")
        XCTAssertEqual(model.contactLinkedInURL, "")
        XCTAssertEqual(model.contactInstagramURL, "")
        XCTAssertEqual(model.contactFacebookURL, "")
        XCTAssertEqual(model.contactRelationshipContext, "")
        XCTAssertEqual(model.contactNotes, "")

        let afterDelete = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store }, separateLocalWorkspace: .disabledForTesting)
        afterDelete.start()
        XCTAssertEqual(afterDelete.contacts, [])
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

    func testVD207SettingsRootModalBindingsDismissWithoutChangingActiveWorkspace() throws {
        let store = try makeStore()
        let activeOpportunity = try store.create(
            CreateOpportunity(title: "Root modal safety", company: "Rekon Labs")
        )
        let archiveURL = URL(fileURLWithPath: "/private/tmp/vd207-root-modal.rekonarchive")
        let restoreDependencies = PortableArchiveRestoreDependencies(
            chooseArchive: { archiveURL },
            beginAccess: { _ in true },
            endAccess: { _ in },
            verify: { _, _ in throw PortableArchiveRestoreError.restoreFailed },
            restore: { _ in throw PortableArchiveRestoreError.restoreFailed }
        )
        let model = WorkspaceViewModel(
            openWorkspace: { .ready(store) },
            createWorkspace: { store },
            portableArchiveRestore: restoreDependencies,
            separateLocalWorkspace: .disabledForTesting
        )
        model.start()
        let activeOpportunityIDs = model.opportunities.map(\.id)

        model.choosePortableArchiveForRestore()
        let awaiting = SettingsRootModalPresentation(
            portableArchiveRestoreState: model.portableArchiveRestoreState,
            protectedExportErrorMessage: model.protectedExportErrorMessage
        )
        XCTAssertTrue(awaiting.isPortableArchiveRestoreSheetPresented)
        XCTAssertFalse(awaiting.isPortableArchiveRestoreFailureAlertPresented)
        var clearedRestoreEntryCount = 0
        SettingsRootModalBindings.dismissPortableArchiveRestore(
            clearRestoreEntry: { clearedRestoreEntryCount += 1 },
            cancelPortableArchiveRestore: { model.cancelPortableArchiveRestore() }
        )
        XCTAssertEqual(clearedRestoreEntryCount, 1)
        XCTAssertEqual(model.portableArchiveRestoreState, .idle)
        XCTAssertEqual(model.opportunities.map(\.id), activeOpportunityIDs)
        XCTAssertEqual(model.opportunities.first?.id, activeOpportunity.id)

        model.choosePortableArchiveForRestore()
        model.verifyPortableArchiveForRestore("")
        let failed = SettingsRootModalPresentation(
            portableArchiveRestoreState: model.portableArchiveRestoreState,
            protectedExportErrorMessage: model.protectedExportErrorMessage
        )
        XCTAssertFalse(failed.isPortableArchiveRestoreSheetPresented)
        XCTAssertTrue(failed.isPortableArchiveRestoreFailureAlertPresented)
        XCTAssertEqual(
            failed.portableArchiveRestoreFailureMessage,
            "Enter the complete recovery key, including its checksum."
        )
        var dismissedRestoreFailureCount = 0
        SettingsRootModalBindings.dismissPortableArchiveRestoreFailure(
            dismissPortableArchiveRestoreFailure: {
                dismissedRestoreFailureCount += 1
                model.dismissPortableArchiveRestoreFailure()
            }
        )
        XCTAssertEqual(dismissedRestoreFailureCount, 1)
        XCTAssertEqual(model.portableArchiveRestoreState, .idle)
        XCTAssertEqual(model.opportunities.map(\.id), activeOpportunityIDs)

        model.reviewProtectedExport(reentry: "")
        let protectedExportError = SettingsRootModalPresentation(
            portableArchiveRestoreState: model.portableArchiveRestoreState,
            protectedExportErrorMessage: model.protectedExportErrorMessage
        )
        XCTAssertEqual(
            protectedExportError.protectedExportErrorMessage,
            "Enter the complete recovery key, including its checksum."
        )
        model.cancelProtectedExport()
        XCTAssertNil(
            SettingsRootModalPresentation(
                portableArchiveRestoreState: model.portableArchiveRestoreState,
                protectedExportErrorMessage: model.protectedExportErrorMessage
            ).protectedExportErrorMessage
        )
        XCTAssertEqual(model.opportunities.map(\.id), activeOpportunityIDs)
    }

    func testVerifiedProtectedExportPublishesSafeSuccessAndRootPresentationOnlyAfterRealWriting() async throws {
        let store = try makeStore()
        let recoveryKey = try RecoveryKey.generate()
        try store.enroll(recoveryKey: recoveryKey)
        let activeOpportunity = try store.create(
            CreateOpportunity(title: "Protected export success", company: "Rekon Labs")
        )
        let destination = temporaryProtectedExportDestination()
        defer { try? FileManager.default.removeItem(at: destination) }
        let model = WorkspaceViewModel(
            openWorkspace: { .ready(store) },
            createWorkspace: { store },
            protectedExportDestination: { destination },
            separateLocalWorkspace: .disabledForTesting
        )
        model.start()
        let activeIDs = model.opportunities.map(\.id)

        XCTAssertNil(model.protectedExportSuccess)
        model.reviewProtectedExport(reentry: recoveryKey.displayValue)
        while model.isCreatingProtectedExport { await Task.yield() }
        XCTAssertNil(model.protectedExportSuccess)
        XCTAssertNotNil(model.protectedExportReview)

        model.confirmProtectedExport(reentry: recoveryKey.displayValue)
        while model.isCreatingProtectedExport { await Task.yield() }

        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
        let success = try XCTUnwrap(model.protectedExportSuccess)
        XCTAssertEqual(success.displayFilename, destination.lastPathComponent)
        XCTAssertFalse(success.displayFilename.contains("/"))
        XCTAssertEqual(model.opportunities.map(\.id), activeIDs)
        XCTAssertEqual(model.opportunities.first?.id, activeOpportunity.id)

        let presentation = protectedExportRootPresentation(for: model)
        XCTAssertTrue(presentation.isProtectedExportSuccessPresented)
        XCTAssertEqual(presentation.protectedExportSuccessDisplayFilename, destination.lastPathComponent)
        XCTAssertEqual(presentation.protectedExportSuccessDestinationLabel, "Selected local folder")

        SettingsRootModalBindings.dismissProtectedExportSuccess {
            model.dismissProtectedExportSuccess()
        }

        XCTAssertFalse(protectedExportRootPresentation(for: model).isProtectedExportSuccessPresented)
        XCTAssertNil(model.protectedExportSuccess)
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
        XCTAssertEqual(model.opportunities.map(\.id), activeIDs)
    }

    func testProtectedExportSuccessRemainsNilForEveryNonSuccessBranch() async throws {
        do {
            let (store, recoveryKey) = try protectedExportReadyStore()
            let destination = temporaryProtectedExportDestination()
            defer { try? FileManager.default.removeItem(at: destination) }
            let model = WorkspaceViewModel(
                openWorkspace: { .ready(store) },
                createWorkspace: { store },
                protectedExportDestination: { destination },
                separateLocalWorkspace: .disabledForTesting
            )
            model.start()
            let activeIDs = model.opportunities.map(\.id)

            XCTAssertNil(model.protectedExportSuccess)
            model.reviewProtectedExport(reentry: recoveryKey.displayValue)
            while model.isCreatingProtectedExport { await Task.yield() }
            model.confirmProtectedExport(reentry: "invalid re-entry")

            assertNoProtectedExportSuccess(model, activeIDs: activeIDs)
            XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
            XCTAssertFalse(model.protectedExportErrorMessage?.isEmpty ?? true)
        }

        do {
            let (store, recoveryKey) = try protectedExportReadyStore()
            let model = WorkspaceViewModel(
                openWorkspace: { .ready(store) },
                createWorkspace: { store },
                protectedExportDestination: { nil },
                separateLocalWorkspace: .disabledForTesting
            )
            model.start()
            let activeIDs = model.opportunities.map(\.id)

            model.reviewProtectedExport(reentry: recoveryKey.displayValue)

            assertNoProtectedExportSuccess(model, activeIDs: activeIDs)
            XCTAssertNil(model.protectedExportReview)
        }

        do {
            let (store, recoveryKey) = try protectedExportReadyStore()
            let destination = temporaryProtectedExportDestination()
            let preservedBytes = Data("preserved review output".utf8)
            try preservedBytes.write(to: destination)
            defer { try? FileManager.default.removeItem(at: destination) }
            let model = WorkspaceViewModel(
                openWorkspace: { .ready(store) },
                createWorkspace: { store },
                protectedExportDestination: { destination },
                separateLocalWorkspace: .disabledForTesting
            )
            model.start()
            let activeIDs = model.opportunities.map(\.id)

            model.reviewProtectedExport(reentry: recoveryKey.displayValue)
            while model.isCreatingProtectedExport { await Task.yield() }

            assertNoProtectedExportSuccess(model, activeIDs: activeIDs)
            XCTAssertEqual(try Data(contentsOf: destination), preservedBytes)
            XCTAssertFalse(model.protectedExportErrorMessage?.isEmpty ?? true)
        }

        do {
            let (store, recoveryKey) = try protectedExportReadyStore()
            let destination = temporaryProtectedExportDestination()
            defer { try? FileManager.default.removeItem(at: destination) }
            let model = WorkspaceViewModel(
                openWorkspace: { .ready(store) },
                createWorkspace: { store },
                protectedExportDestination: { destination },
                separateLocalWorkspace: .disabledForTesting
            )
            model.start()
            let activeIDs = model.opportunities.map(\.id)

            model.reviewProtectedExport(reentry: recoveryKey.displayValue)
            while model.isCreatingProtectedExport { await Task.yield() }
            model.title = "A source revision after review"
            model.company = "Rekon Labs"
            model.createOpportunity()
            model.confirmProtectedExport(reentry: recoveryKey.displayValue)
            while model.isCreatingProtectedExport { await Task.yield() }

            assertNoProtectedExportSuccess(model, activeIDs: model.opportunities.map(\.id))
            XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
            XCTAssertFalse(model.protectedExportErrorMessage?.isEmpty ?? true)
            XCTAssertNotEqual(model.opportunities.map(\.id), activeIDs)
        }

        do {
            let (store, recoveryKey) = try protectedExportReadyStore()
            let destination = temporaryProtectedExportDestination()
            defer { try? FileManager.default.removeItem(at: destination) }
            let model = WorkspaceViewModel(
                openWorkspace: { .ready(store) },
                createWorkspace: { store },
                protectedExportDestination: { destination },
                separateLocalWorkspace: .disabledForTesting
            )
            model.start()
            let activeIDs = model.opportunities.map(\.id)

            model.reviewProtectedExport(reentry: recoveryKey.displayValue)
            while model.isCreatingProtectedExport { await Task.yield() }
            let preservedBytes = Data("preserved write output".utf8)
            try preservedBytes.write(to: destination)
            model.confirmProtectedExport(reentry: recoveryKey.displayValue)
            while model.isCreatingProtectedExport { await Task.yield() }

            assertNoProtectedExportSuccess(model, activeIDs: activeIDs)
            XCTAssertEqual(try Data(contentsOf: destination), preservedBytes)
            XCTAssertFalse(model.protectedExportErrorMessage?.isEmpty ?? true)
        }

        do {
            let (store, recoveryKey) = try protectedExportReadyStore()
            let firstDestination = temporaryProtectedExportDestination()
            let secondDestination = temporaryProtectedExportDestination()
            defer {
                try? FileManager.default.removeItem(at: firstDestination)
                try? FileManager.default.removeItem(at: secondDestination)
            }
            var nextDestination = firstDestination
            let model = WorkspaceViewModel(
                openWorkspace: { .ready(store) },
                createWorkspace: { store },
                protectedExportDestination: { nextDestination },
                separateLocalWorkspace: .disabledForTesting
            )
            model.start()
            let activeIDs = model.opportunities.map(\.id)

            try await createVerifiedProtectedExport(on: model, recoveryKey: recoveryKey)
            XCTAssertNotNil(model.protectedExportSuccess)
            nextDestination = secondDestination
            model.reviewProtectedExport(reentry: recoveryKey.displayValue)

            assertNoProtectedExportSuccess(model, activeIDs: activeIDs)
            XCTAssertFalse(FileManager.default.fileExists(atPath: secondDestination.path))
        }

        do {
            let (store, recoveryKey) = try protectedExportReadyStore()
            let destination = temporaryProtectedExportDestination()
            defer { try? FileManager.default.removeItem(at: destination) }
            let model = WorkspaceViewModel(
                openWorkspace: { .ready(store) },
                createWorkspace: { store },
                protectedExportDestination: { destination },
                separateLocalWorkspace: .disabledForTesting
            )
            model.start()
            let activeIDs = model.opportunities.map(\.id)

            try await createVerifiedProtectedExport(on: model, recoveryKey: recoveryKey)
            model.cancelProtectedExport()

            assertNoProtectedExportSuccess(model, activeIDs: activeIDs)
            XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
        }
    }

    func testCancellingConfirmedProtectedExportInvalidatesInFlightOperation() async throws {
        let (store, recoveryKey) = try protectedExportReadyStore()
        let destination = temporaryProtectedExportDestination()
        defer { try? FileManager.default.removeItem(at: destination) }
        let gate = GatedProtectedExportCreate()
        let model = WorkspaceViewModel(
            openWorkspace: { .ready(store) },
            createWorkspace: { store },
            protectedExportDestination: { destination },
            protectedExportCreate: { store, review, key in
                try await gate.create(store: store, review: review, recoveryKey: key)
            },
            separateLocalWorkspace: .disabledForTesting
        )
        model.start()
        let activeIDs = model.opportunities.map(\.id)

        model.reviewProtectedExport(reentry: recoveryKey.displayValue)
        while model.isCreatingProtectedExport { await Task.yield() }
        XCTAssertNotNil(model.protectedExportReview)

        model.confirmProtectedExport(reentry: recoveryKey.displayValue)
        await gate.waitUntilStarted()
        model.cancelProtectedExport()
        await gate.release()
        while model.isCreatingProtectedExport { await Task.yield() }

        assertNoProtectedExportSuccess(model, activeIDs: activeIDs)
        XCTAssertNil(model.protectedExportReview)
        XCTAssertNil(model.protectedExportErrorMessage)
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
    }

    func testProtectedExportSuccessClearsForEveryWorkspaceTransition() async throws {
        do {
            let (source, recoveryKey) = try protectedExportReadyStore()
            let replacement = try makeStore()
            let destination = temporaryProtectedExportDestination()
            defer { try? FileManager.default.removeItem(at: destination) }
            var opens = 0
            let model = WorkspaceViewModel(
                openWorkspace: { opens += 1; return .ready(opens == 1 ? source : replacement) },
                createWorkspace: { replacement },
                protectedExportDestination: { destination },
                separateLocalWorkspace: .disabledForTesting
            )
            model.start()
            try await createVerifiedProtectedExport(on: model, recoveryKey: recoveryKey)
            model.start()
            assertNoProtectedExportSuccess(model, activeIDs: [])
        }

        do {
            let (source, recoveryKey) = try protectedExportReadyStore()
            let replacement = try makeStore()
            let destination = temporaryProtectedExportDestination()
            defer { try? FileManager.default.removeItem(at: destination) }
            let model = WorkspaceViewModel(
                openWorkspace: { .ready(source) },
                createWorkspace: { replacement },
                protectedExportDestination: { destination },
                separateLocalWorkspace: .disabledForTesting
            )
            model.start()
            try await createVerifiedProtectedExport(on: model, recoveryKey: recoveryKey)
            model.createWorkspaceIfNeeded()
            assertNoProtectedExportSuccess(model, activeIDs: [])
        }

        do {
            let (source, recoveryKey) = try protectedExportReadyStore()
            let destination = temporaryProtectedExportDestination()
            defer { try? FileManager.default.removeItem(at: destination) }
            let separate = SeparateWorkspaceFixture()
            let model = WorkspaceViewModel(
                openWorkspace: { .ready(source) },
                createWorkspace: { source },
                protectedExportDestination: { destination },
                separateLocalWorkspace: separate.dependencies
            )
            model.start()
            try await createVerifiedProtectedExport(on: model, recoveryKey: recoveryKey)
            model.createSeparateLocalWorkspace()
            assertNoProtectedExportSuccess(model, activeIDs: [])
        }

        do {
            let separate = SeparateWorkspaceFixture()
            let (source, recoveryKey) = try protectedExportReadyStore()
            let destination = temporaryProtectedExportDestination()
            defer { try? FileManager.default.removeItem(at: destination) }
            let model = WorkspaceViewModel(
                openWorkspace: { .recoveryRequired },
                createWorkspace: { source },
                protectedExportDestination: { destination },
                separateLocalWorkspace: separate.dependencies
            )
            model.start()
            model.createSeparateLocalWorkspace()
            let separateStore = try XCTUnwrap(separate.lastCreatedStore)
            try separateStore.enroll(recoveryKey: recoveryKey)
            model.title = "Separate protected export"
            model.company = "Rekon Labs"
            model.createOpportunity()
            try await createVerifiedProtectedExport(on: model, recoveryKey: recoveryKey)
            model.returnToPreservedWorkspaceRecovery()
            assertNoProtectedExportSuccess(model, activeIDs: [])
        }

        do {
            let (source, recoveryKey) = try protectedExportReadyStore()
            let restored = try makeStore()
            let destination = temporaryProtectedExportDestination()
            let restoreInput = temporaryProtectedExportDestination()
            defer {
                try? FileManager.default.removeItem(at: destination)
                try? FileManager.default.removeItem(at: restoreInput)
            }
            let model = WorkspaceViewModel(
                openWorkspace: { .ready(source) },
                createWorkspace: { source },
                restoreWorkspace: { _ in restored },
                protectedExportDestination: { destination },
                separateLocalWorkspace: .disabledForTesting
            )
            model.start()
            try await createVerifiedProtectedExport(on: model, recoveryKey: recoveryKey)
            model.restoreEncryptedBackup(from: restoreInput)
            assertNoProtectedExportSuccess(model, activeIDs: [])
        }

        do {
            let fixture = try makeReopenableContactStore()
            let source = fixture.store
            let recoveryKey = try RecoveryKey.generate()
            try source.enroll(recoveryKey: recoveryKey)
            let sourceOpportunity = try source.create(
                CreateOpportunity(title: "Failed restore source", company: "Rekon Labs")
            )
            let destination = temporaryProtectedExportDestination()
            let restoreInput = temporaryProtectedExportDestination()
            defer {
                try? FileManager.default.removeItem(at: destination)
                try? FileManager.default.removeItem(at: restoreInput)
            }
            var opens = 0
            let model = WorkspaceViewModel(
                openWorkspace: {
                    opens += 1
                    if opens == 1 { return .ready(source) }
                    return .ready(try self.reopenContactStore(databaseURL: fixture.databaseURL, key: fixture.key))
                },
                createWorkspace: { source },
                restoreWorkspace: { _ in throw WorkspaceStoreError.injectedFailure },
                protectedExportDestination: { destination },
                separateLocalWorkspace: .disabledForTesting
            )
            model.start()
            try await createVerifiedProtectedExport(on: model, recoveryKey: recoveryKey)
            model.restoreEncryptedBackup(from: restoreInput)
            assertNoProtectedExportSuccess(model, activeIDs: [sourceOpportunity.id])
        }

        do {
            let (source, recoveryKey) = try protectedExportReadyStore()
            let external = try makeStore()
            let destination = temporaryProtectedExportDestination()
            defer { try? FileManager.default.removeItem(at: destination) }
            let bookmarks = ViewModelBookmarkFixture()
            let folder = bookmarks.makeFolder(withDatabase: true)
            let model = WorkspaceViewModel(
                openWorkspace: { .ready(source) },
                createWorkspace: { source },
                workspaceLocationBookmarks: bookmarks.makeStore(),
                protectedExportDestination: { destination },
                openExternalWorkspace: { _ in .ready(external) },
                separateLocalWorkspace: .disabledForTesting
            )
            model.start()
            try await createVerifiedProtectedExport(on: model, recoveryKey: recoveryKey)
            model.chooseExistingWorkspaceFolder(folder)
            assertNoProtectedExportSuccess(model, activeIDs: [])
        }

        do {
            let (source, recoveryKey) = try protectedExportReadyStore()
            let destination = temporaryProtectedExportDestination()
            defer { try? FileManager.default.removeItem(at: destination) }
            let model = WorkspaceViewModel(
                openWorkspace: { .ready(source) },
                createWorkspace: { source },
                protectedExportDestination: { destination },
                separateLocalWorkspace: .disabledForTesting
            )
            model.start()
            try await createVerifiedProtectedExport(on: model, recoveryKey: recoveryKey)
            model.chooseExistingWorkspaceFolder(nil)
            assertNoProtectedExportSuccess(model, activeIDs: [])
        }

        do {
            let (source, recoveryKey) = try protectedExportReadyStore()
            let destination = temporaryProtectedExportDestination()
            defer { try? FileManager.default.removeItem(at: destination) }
            let model = WorkspaceViewModel(
                openWorkspace: { .ready(source) },
                createWorkspace: { source },
                protectedExportDestination: { destination },
                separateLocalWorkspace: .disabledForTesting
            )
            model.start()
            try await createVerifiedProtectedExport(on: model, recoveryKey: recoveryKey)
            model.closeWorkspace()
            assertNoProtectedExportSuccess(model, activeIDs: [])
        }

        do {
            let (source, recoveryKey) = try protectedExportReadyStore()
            let destination = temporaryProtectedExportDestination()
            defer { try? FileManager.default.removeItem(at: destination) }
            let model = WorkspaceViewModel(
                openWorkspace: { .ready(source) },
                createWorkspace: { source },
                protectedExportDestination: { destination },
                separateLocalWorkspace: .disabledForTesting
            )
            model.start()
            try await createVerifiedProtectedExport(on: model, recoveryKey: recoveryKey)
            model.teardown()
            assertNoProtectedExportSuccess(model, activeIDs: [])
        }
    }

    private func protectedExportReadyStore() throws -> (store: WorkspaceStore, recoveryKey: RecoveryKey) {
        let store = try makeStore()
        let recoveryKey = try RecoveryKey.generate()
        try store.enroll(recoveryKey: recoveryKey)
        _ = try store.create(CreateOpportunity(title: "Protected export source", company: "Rekon Labs"))
        return (store, recoveryKey)
    }

    private func temporaryProtectedExportDestination() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("protected-export-\(UUID().uuidString).rekonexport")
    }

    private func createVerifiedProtectedExport(
        on model: WorkspaceViewModel,
        recoveryKey: RecoveryKey
    ) async throws {
        model.reviewProtectedExport(reentry: recoveryKey.displayValue)
        while model.isCreatingProtectedExport { await Task.yield() }
        XCTAssertNotNil(model.protectedExportReview)
        model.confirmProtectedExport(reentry: recoveryKey.displayValue)
        while model.isCreatingProtectedExport { await Task.yield() }
        XCTAssertNotNil(model.protectedExportSuccess)
    }

    private func protectedExportRootPresentation(
        for model: WorkspaceViewModel
    ) -> SettingsRootModalPresentation {
        SettingsRootModalPresentation(
            portableArchiveRestoreState: model.portableArchiveRestoreState,
            protectedExportErrorMessage: model.protectedExportErrorMessage,
            protectedExportSuccess: model.protectedExportSuccess
        )
    }

    private func assertNoProtectedExportSuccess(
        _ model: WorkspaceViewModel,
        activeIDs: [String],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertNil(model.protectedExportSuccess, file: file, line: line)
        XCTAssertFalse(protectedExportRootPresentation(for: model).isProtectedExportSuccessPresented, file: file, line: line)
        XCTAssertEqual(model.opportunities.map(\.id), activeIDs, file: file, line: line)
    }

    private func makeStore(
        now: Date? = nil,
        stageMoveFailurePoint: StageMoveFailurePoint? = nil
    ) throws -> WorkspaceStore {
        let databaseURL = FileManager.default.temporaryDirectory.appendingPathComponent("rekon-view-model-\(UUID().uuidString).sqlite")
        let database = try EncryptedDatabase.open(url: databaseURL, key: Data(repeating: 5, count: 32))
        return try WorkspaceStore(
            database: database,
            now: now,
            actorID: "test",
            correlationID: "test",
            stageMoveFailurePoint: stageMoveFailurePoint
        )
    }

    private func makeReopenableContactStore() throws -> (store: WorkspaceStore, databaseURL: URL, key: Data) {
        let databaseURL = FileManager.default.temporaryDirectory.appendingPathComponent("rekon-vd206-contact-\(UUID().uuidString).sqlite")
        let key = Data(repeating: 6, count: 32)
        let database = try EncryptedDatabase.open(url: databaseURL, key: key)
        let store = try WorkspaceStore(database: database, actorID: "test", correlationID: "vd206-contact")
        return (store, databaseURL, key)
    }

    private func reopenContactStore(databaseURL: URL, key: Data) throws -> WorkspaceStore {
        let database = try EncryptedDatabase.open(url: databaseURL, key: key, createIfMissing: false)
        return try WorkspaceStore(database: database, actorID: "test", correlationID: "vd206-contact-reopen")
    }

    private func stageMoveBaseline(_ model: WorkspaceViewModel) -> StageMoveModelBaseline {
        StageMoveModelBaseline(
            opportunities: model.opportunities,
            activityEvents: model.activityEvents,
            needsAttention: model.needsAttention,
            opportunityCount: model.opportunityCount,
            activityCount: model.activityCount,
            needsAttentionCount: model.needsAttentionCount,
            selectedOpportunityID: model.selectedOpportunityID,
            selectedOpportunity: model.selectedOpportunity,
            selectedStageHistory: model.selectedStageHistory
        )
    }

    private func assertStageMoveBaseline(
        _ actual: StageMoveModelBaseline,
        equals expected: StageMoveModelBaseline,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(actual.opportunities, expected.opportunities, file: file, line: line)
        XCTAssertEqual(actual.activityEvents, expected.activityEvents, file: file, line: line)
        XCTAssertEqual(actual.needsAttention, expected.needsAttention, file: file, line: line)
        XCTAssertEqual(actual.opportunityCount, expected.opportunityCount, file: file, line: line)
        XCTAssertEqual(actual.activityCount, expected.activityCount, file: file, line: line)
        XCTAssertEqual(actual.needsAttentionCount, expected.needsAttentionCount, file: file, line: line)
        XCTAssertEqual(actual.selectedOpportunityID, expected.selectedOpportunityID, file: file, line: line)
        XCTAssertEqual(actual.selectedOpportunity, expected.selectedOpportunity, file: file, line: line)
        XCTAssertEqual(actual.selectedStageHistory, expected.selectedStageHistory, file: file, line: line)
    }
}

@MainActor
private struct StageMoveModelBaseline {
    let opportunities: [Opportunity]
    let activityEvents: [ActivityEvent]
    let needsAttention: [TaskReminder]
    let opportunityCount: Int
    let activityCount: Int
    let needsAttentionCount: Int
    let selectedOpportunityID: String
    let selectedOpportunity: Opportunity?
    let selectedStageHistory: [StageHistoryEntry]
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

private actor GatedProtectedExportCreate {
    private var didStart = false
    private var startContinuations: [CheckedContinuation<Void, Never>] = []
    private var releaseContinuations: [CheckedContinuation<Void, Never>] = []
    private var isReleased = false

    func create(
        store: WorkspaceStore,
        review: ProtectedExportReview,
        recoveryKey: RecoveryKey
    ) async throws -> ProtectedExportReceipt {
        didStart = true
        let continuations = startContinuations
        startContinuations = []
        continuations.forEach { $0.resume() }
        if !isReleased {
            await withCheckedContinuation { releaseContinuations.append($0) }
        }
        throw WorkspaceStoreError.injectedFailure
    }

    func waitUntilStarted() async {
        guard !didStart else { return }
        await withCheckedContinuation { startContinuations.append($0) }
    }

    func release() {
        isReleased = true
        let continuations = releaseContinuations
        releaseContinuations = []
        continuations.forEach { $0.resume() }
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
    private(set) var lastCreatedStore: WorkspaceStore?
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
                let store = try WorkspaceStore(database: database, actorID: "test", correlationID: "test")
                lastCreatedStore = store
                return store
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
