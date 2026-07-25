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

    func testMissingKeyShowsRecoveryMessage() {
        let model = WorkspaceViewModel(openWorkspace: { .missingKey }, createWorkspace: { throw WorkspaceStoreError.injectedFailure })

        model.start()

        XCTAssertEqual(model.statusMessage, "Workspace key is unavailable. Create a new local workspace only if you intend to start over.")
        XCTAssertTrue(model.canCreateWorkspace)
        XCTAssertFalse(model.workspaceReady)
    }

    func testExistingWorkspaceMissingKeyDoesNotOfferReplacement() {
        let model = WorkspaceViewModel(openWorkspace: { .missingExistingKey }, createWorkspace: { throw WorkspaceStoreError.injectedFailure })

        model.start()

        XCTAssertEqual(model.statusMessage, "Workspace key is unavailable. The existing local workspace has not been replaced.")
        XCTAssertFalse(model.canCreateWorkspace)
        XCTAssertFalse(model.workspaceReady)
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

    private func makeStore() throws -> WorkspaceStore {
        let databaseURL = FileManager.default.temporaryDirectory.appendingPathComponent("rekon-view-model-\(UUID().uuidString).sqlite")
        let database = try EncryptedDatabase.open(url: databaseURL, key: Data(repeating: 5, count: 32))
        return try WorkspaceStore(database: database, actorID: "test", correlationID: "test")
    }
}
