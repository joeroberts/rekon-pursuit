import Foundation
import XCTest
@testable import RekonPursuit

@MainActor
final class WorkspaceViewModelTests: XCTestCase {
    func testCreateValidationKeepsWorkspaceUnchanged() throws {
        let store = try makeStore()
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store })

        model.start()
        model.createOpportunity()

        XCTAssertEqual(model.statusMessage, "Enter a job title and company.")
        XCTAssertEqual(model.opportunityCount, 0)
    }

    func testSuccessfulCreateUpdatesVisibleLocalCount() throws {
        let store = try makeStore()
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store })

        model.start()
        model.title = "Product Manager"
        model.company = "Rekon Labs"
        model.createOpportunity()

        XCTAssertEqual(model.opportunityCount, 1)
        XCTAssertEqual(model.activityCount, 1)
        XCTAssertEqual(model.statusMessage, "Saved locally.")
    }

    func testSuccessfulCreateResetsDateDraftsBeforeTheNextOpportunity() throws {
        let store = try makeStore()
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store })
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
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store })
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
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store })
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
        let model = WorkspaceViewModel(openWorkspace: { .createAvailable }, createWorkspace: { throw WorkspaceStoreError.injectedFailure })

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
            createWorkspace: { throw WorkspaceStoreError.injectedFailure }
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
        let model = WorkspaceViewModel(openWorkspace: { .recoveryRequired }, createWorkspace: { throw WorkspaceStoreError.injectedFailure })

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
            createWorkspace: { throw WorkspaceStoreError.injectedFailure }
        )

        model.start()
        model.retryWorkspaceOpen()

        XCTAssertEqual(opens, 2)
        XCTAssertTrue(model.workspaceRequiresRecovery)
        XCTAssertFalse(model.canCreateWorkspace)
        XCTAssertFalse(model.workspaceReady)
        XCTAssertEqual(model.statusMessage, "Existing workspace material needs recovery. Nothing was replaced or removed.")
    }

    func testRecheckToRecoveryRequiredClearsLiveWorkspaceDataAndBlocksMutation() throws {
        let store = try makeStore()
        var opens = 0
        let model = WorkspaceViewModel(
            openWorkspace: {
                opens += 1
                return opens == 1 ? .ready(store) : .recoveryRequired
            },
            createWorkspace: { store }
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
        let model = WorkspaceViewModel(openWorkspace: { .corrupt }, createWorkspace: { throw WorkspaceStoreError.injectedFailure })

        model.start()

        XCTAssertEqual(model.statusMessage, "The local workspace is unreadable. It has not been replaced; keep its files intact.")
        XCTAssertFalse(model.canCreateWorkspace)
    }

    func testDeleteRefreshesVisibleRecordsAndKeepsOnlyActivityKind() throws {
        let store = try makeStore()
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store })
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
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store })

        model.start()

        XCTAssertEqual(model.csvImportReport, report)
    }

    func testExportReturnsCSVAndRecordsOnlyAnAuditEvent() throws {
        let store = try makeStore()
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store })
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
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store })
        model.start()
        model.title = "Product Manager"
        model.company = "Rekon Labs"
        model.createOpportunity()

        model.activitySearch = "rekon"

        XCTAssertEqual(model.filteredActivityEvents.map(\.kind), ["opportunity_created"])
    }

    func testPipelineVisibilitySettingCanHideClosedOpportunities() throws {
        let store = try makeStore()
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store })
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
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store })
        model.start()
        model.title = "Product Manager"
        model.company = "Rekon Labs"
        model.nextAction = "Send follow-up"
        model.hasDueDate = true
        model.createOpportunity()

        model.open(model.needsAttention[0])
        model.selectedTitle = "Senior Product Manager"
        model.selectedNextAction = "Prepare recruiter call"
        model.saveSelectedOpportunity()

        XCTAssertEqual(model.opportunities.first?.title, "Senior Product Manager")
        XCTAssertEqual(model.needsAttention.first?.title, "Prepare recruiter call")
        XCTAssertEqual(model.activityEvents.last?.kind, "opportunity_updated")
    }

    func testOpenQueueActionSelectsOpportunityAndRecordsActivity() throws {
        let store = try makeStore()
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store })
        model.start()
        model.title = "Product Manager"
        model.company = "Rekon Labs"
        model.nextAction = "Send follow-up"
        model.createOpportunity()

        model.open(try XCTUnwrap(model.needsAttention.first))

        XCTAssertEqual(model.selectedOpportunity?.title, "Product Manager")
        XCTAssertEqual(model.activityEvents.last?.kind, "task_opened")
    }

    func testQueueRescheduleChangesOnlyTheSelectedTaskAndRecordsActivity() throws {
        let store = try makeStore()
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store })
        model.start()
        model.title = "Product Manager"
        model.company = "Rekon Labs"
        model.nextAction = "Send follow-up"
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
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store })
        model.start()
        model.title = "Product Manager"
        model.company = "Rekon Labs"
        model.nextAction = "Send follow-up"
        model.createOpportunity()
        let task = try XCTUnwrap(model.needsAttention.first)

        model.open(task)
        model.complete(task)

        XCTAssertEqual(model.selectedTask?.id, task.id)
        XCTAssertTrue(model.selectedTask?.isComplete == true)
    }

    func testSelectedOpportunityShowsStageHistory() throws {
        let store = try makeStore()
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store })
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
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store })

        model.start()
        model.contactSearch = "Jordan"
        XCTAssertEqual(model.filteredContacts, [discovery])

        model.select(first)
        XCTAssertEqual(model.selectedContacts, [linked])
        XCTAssertEqual(model.selectedSameEmployerContacts, [discovery])
        XCTAssertEqual(model.selectedOpportunity?.id, first.id)
        XCTAssertEqual(model.opportunities.map(\.id), [first.id, second.id])
    }

    func testSelectedContactCanLogAndDisplayALocalInteraction() throws {
        let store = try makeStore()
        let opportunity = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs"))
        let contact = try store.createContact(CreateContact(name: "Alex Morgan", employer: "Rekon Labs"))
        try store.linkContact(contactID: contact.id, toOpportunityID: opportunity.id)
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store })

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
        let model = WorkspaceViewModel(openWorkspace: { .ready(store) }, createWorkspace: { store })

        model.start()
        model.select(opportunity)

        XCTAssertEqual(model.selectedOpportunityInteractions.map(\.contactName), ["Alex Morgan"])
        XCTAssertEqual(model.selectedOpportunityInteractions.map(\.summary), ["Met the hiring manager."])
    }

    private func makeStore() throws -> WorkspaceStore {
        let databaseURL = FileManager.default.temporaryDirectory.appendingPathComponent("rekon-view-model-\(UUID().uuidString).sqlite")
        let database = try EncryptedDatabase.open(url: databaseURL, key: Data(repeating: 5, count: 32))
        return try WorkspaceStore(database: database, actorID: "test", correlationID: "test")
    }
}
