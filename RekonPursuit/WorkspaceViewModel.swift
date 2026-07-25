import Combine
import Foundation

@MainActor
final class WorkspaceViewModel: ObservableObject {
    @Published var title = ""
    @Published var company = ""
    @Published var stage: PipelineStage = .saved
    @Published var nextAction = ""
    @Published var dueAt = Date.now
    @Published var hasDueDate = false
    @Published private(set) var opportunityCount = 0
    @Published private(set) var activityCount = 0
    @Published private(set) var needsAttentionCount = 0
    @Published private(set) var needsAttention: [TaskReminder] = []
    @Published private(set) var opportunities: [Opportunity] = []
    @Published private(set) var activityEvents: [ActivityEvent] = []
    @Published private(set) var selectedStageHistory: [StageHistoryEntry] = []
    @Published private(set) var selectedTask: TaskReminder?
    @Published var opportunitySearch = ""
    @Published var stageFilter = "All stages"
    @Published var selectedTitle = ""
    @Published var selectedCompany = ""
    @Published var jobURL = ""
    @Published var selectedJobURL = ""
    @Published var selectedStage: PipelineStage = .saved
    @Published var selectedNextAction = ""
    @Published var selectedDueAt = Date.now
    @Published var selectedHasDueDate = false
    @Published var contactName = ""
    @Published var contactEmployer = ""
    @Published var contactTitle = ""
    @Published var contactEmail = ""
    @Published var contactProfileURL = ""
    @Published var contactRelationshipContext = ""
    @Published var contactNotes = ""
    @Published var contactSearch = ""
    @Published var contactEmployerFilter = "All employers"
    @Published var selectedContactID = ""
    @Published var selectedOpportunityID = ""
    @Published var interactionSummary = ""
    @Published var interactionKind: InteractionKind = .note
    @Published var interactionOccurredAt = Date.now
    @Published var interactionHasNextTouch = false
    @Published var interactionNextTouchAt = Date.now
    @Published var interactionOpportunityID = ""
    @Published private(set) var contacts: [Contact] = []
    @Published private(set) var selectedContacts: [Contact] = []
    @Published private(set) var selectedSameEmployerContacts: [Contact] = []
    @Published private(set) var selectedOpportunityInteractions: [OpportunityInteraction] = []
    @Published private(set) var selectedContactInteractions: [ContactInteraction] = []
    @Published private(set) var selectedContactOpportunities: [Opportunity] = []
    @Published private(set) var selectedContactLastTouch: Date?
    @Published private(set) var selectedContactNextTouch: Date?
    @Published var postingStatus: PostingStatus = .stillOpen
    @Published var postingEvidence = ""
    @Published private(set) var selectedPostingChecks: [PostingCheck] = []
    @Published private(set) var csvPreview: CSVImportPreview?
    @Published private(set) var csvImportPlan: [CSVImportPlanRow] = []
    @Published private(set) var csvImportReport: CSVImportReport?
    @Published private(set) var statusMessage = "Opening local workspace…"
    @Published private(set) var canCreateWorkspace = false
    @Published private(set) var workspaceReady = false

    private let openWorkspace: () throws -> WorkspaceOpenState
    private let createWorkspace: () throws -> WorkspaceStore
    private var store: WorkspaceStore?

    init(
        openWorkspace: @escaping () throws -> WorkspaceOpenState,
        createWorkspace: @escaping () throws -> WorkspaceStore
    ) {
        self.openWorkspace = openWorkspace
        self.createWorkspace = createWorkspace
    }

    convenience init() {
        let session = WorkspaceSession(root: Self.defaultWorkspaceRoot())
        self.init(openWorkspace: session.open, createWorkspace: session.create)
    }

    func start() {
        do {
            apply(try openWorkspace())
        } catch {
            statusMessage = "The local workspace could not be opened."
        }
    }

    func createWorkspaceIfNeeded() {
        do {
            store = try createWorkspace()
            refreshCounts()
            statusMessage = "Local workspace created."
            canCreateWorkspace = false
            workspaceReady = true
        } catch {
            statusMessage = "The local workspace could not be created."
        }
    }

    func createOpportunity() {
        guard let store else {
            statusMessage = "Create or reopen the local workspace first."
            return
        }
        do {
            _ = try store.create(CreateOpportunity(title: title, company: company, stage: stage, nextAction: nextAction, dueAt: nextAction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !hasDueDate ? nil : dueAt, jobURL: jobURL))
            title = ""
            company = ""
            jobURL = ""
            nextAction = ""
            hasDueDate = false
            refreshCounts()
            statusMessage = "Saved locally."
        } catch let error as LocalizedError {
            statusMessage = error.errorDescription ?? "The opportunity could not be saved."
        } catch {
            statusMessage = "The opportunity could not be saved."
        }
    }

    func deleteOpportunity(_ opportunity: Opportunity) {
        do {
            try store?.deleteOpportunity(id: opportunity.id)
            refreshCounts()
            statusMessage = "Opportunity deleted locally."
        } catch {
            statusMessage = "The opportunity could not be deleted."
        }
    }

    func complete(_ task: TaskReminder) {
        do {
            try store?.completeTask(id: task.id)
            refreshCounts()
            statusMessage = "Action completed locally."
        } catch {
            statusMessage = "The action could not be completed."
        }
    }

    func snoozeOneDay(_ task: TaskReminder) {
        do {
            try store?.snoozeTask(id: task.id)
            refreshCounts()
            statusMessage = "Action snoozed for one day."
        } catch {
            statusMessage = "The action could not be rescheduled."
        }
    }

    func reschedule(_ task: TaskReminder, to dueAt: Date) {
        do {
            try store?.rescheduleTask(id: task.id, dueAt: dueAt)
            refreshCounts()
            statusMessage = "Action rescheduled locally."
        } catch {
            statusMessage = "The action could not be rescheduled."
        }
    }

    func changeStage(_ opportunity: Opportunity, to stage: PipelineStage) {
        do {
            try store?.changeStage(opportunityID: opportunity.id, to: stage)
            refreshCounts()
            statusMessage = "Stage updated locally."
        } catch {
            statusMessage = "The stage could not be updated."
        }
    }

    var filteredOpportunities: [Opportunity] {
        opportunities.filter { opportunity in
            let matchesStage = stageFilter == "All stages" || opportunity.stage.rawValue == stageFilter
            let query = opportunitySearch.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesSearch = query.isEmpty || opportunity.title.localizedCaseInsensitiveContains(query) || opportunity.company.localizedCaseInsensitiveContains(query)
            return matchesStage && matchesSearch
        }
    }

    var selectedOpportunity: Opportunity? {
        opportunities.first { $0.id == selectedOpportunityID }
    }

    var selectedActivityEvents: [ActivityEvent] {
        activityEvents.filter { $0.opportunityID == selectedOpportunityID }
    }

    var filteredContacts: [Contact] {
        let query = contactSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        return contacts.filter { contact in
            let matchesEmployer = contactEmployerFilter == "All employers" || contact.employer == contactEmployerFilter
            let matchesSearch = query.isEmpty || [contact.name, contact.employer, contact.title, contact.email].contains { $0.localizedCaseInsensitiveContains(query) }
            return matchesEmployer && matchesSearch
        }
    }

    var contactEmployers: [String] {
        Array(Set(contacts.map(\.employer).filter { !$0.isEmpty })).sorted()
    }

    var selectedContact: Contact? {
        contacts.first { $0.id == selectedContactID }
    }

    func open(_ task: TaskReminder) {
        do {
            try store?.openTask(id: task.id)
            selectedOpportunityID = task.opportunityID
            refreshCounts()
            statusMessage = "Opened opportunity locally."
        } catch {
            statusMessage = "The opportunity could not be opened."
        }
    }

    func select(_ opportunity: Opportunity) {
        selectedOpportunityID = opportunity.id
        loadSelectedOpportunity()
        refreshStageHistory()
        refreshSelectedTask()
        refreshRelationshipMemory()
        refreshSelectedPostingChecks()
    }

    func saveSelectedOpportunity() {
        guard let store, !selectedOpportunityID.isEmpty else { return }
        do {
            try store.updateOpportunity(
                id: selectedOpportunityID,
                title: selectedTitle,
                company: selectedCompany,
                stage: selectedStage,
                nextAction: selectedNextAction,
                dueAt: selectedNextAction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !selectedHasDueDate ? nil : selectedDueAt,
                jobURL: selectedJobURL
            )
            refreshCounts()
            statusMessage = "Opportunity updated locally."
        } catch let error as LocalizedError {
            statusMessage = error.errorDescription ?? "The opportunity could not be updated."
        } catch {
            statusMessage = "The opportunity could not be updated."
        }
    }

    func rescheduleSelectedTask() {
        guard let task = needsAttention.first(where: { $0.opportunityID == selectedOpportunityID }) else {
            statusMessage = "Add a next action before rescheduling it."
            return
        }
        do {
            try store?.rescheduleTask(id: task.id, dueAt: selectedDueAt)
            refreshCounts()
            statusMessage = "Action rescheduled locally."
        } catch {
            statusMessage = "The action could not be rescheduled."
        }
    }

    func createContact() {
        do {
            _ = try store?.createContact(contactCommand())
            clearContactDraft()
            refreshCounts()
            statusMessage = "Contact saved locally."
        } catch let error as LocalizedError {
            statusMessage = error.errorDescription ?? "The contact could not be saved."
        } catch {
            statusMessage = "The contact could not be saved."
        }
    }

    func selectContact(_ contact: Contact) {
        selectedContactID = contact.id
        contactName = contact.name
        contactEmployer = contact.employer
        contactTitle = contact.title
        contactEmail = contact.email
        contactProfileURL = contact.profileURL
        contactRelationshipContext = contact.relationshipContext
        contactNotes = contact.notes
        refreshSelectedContactInteraction()
    }

    func beginNewContact() {
        clearContactDraft()
    }

    func saveSelectedContact() {
        guard let store, !selectedContactID.isEmpty else { return }
        do {
            _ = try store.updateContact(id: selectedContactID, command: contactCommand())
            refreshCounts()
            statusMessage = "Contact updated locally."
        } catch let error as LocalizedError {
            statusMessage = error.errorDescription ?? "The contact could not be updated."
        } catch {
            statusMessage = "The contact could not be updated."
        }
    }

    func deleteContact(_ contact: Contact) {
        do {
            try store?.deleteContact(id: contact.id)
            if selectedContactID == contact.id { clearContactDraft() }
            refreshCounts()
            statusMessage = "Contact deleted locally."
        } catch {
            statusMessage = "The contact could not be deleted."
        }
    }

    func link(_ contact: Contact) {
        guard !selectedOpportunityID.isEmpty else { return }
        do {
            try store?.linkContact(contactID: contact.id, toOpportunityID: selectedOpportunityID)
            refreshCounts()
            statusMessage = "Contact linked locally."
        } catch {
            statusMessage = "The contact could not be linked."
        }
    }

    func unlink(_ contact: Contact) {
        guard !selectedOpportunityID.isEmpty else { return }
        do {
            try store?.unlinkContact(contactID: contact.id, fromOpportunityID: selectedOpportunityID)
            refreshCounts()
            statusMessage = "Contact unlinked locally."
        } catch {
            statusMessage = "The contact could not be unlinked."
        }
    }

    func recordPostingCheck() {
        guard let store, !selectedOpportunityID.isEmpty else { return }
        do {
            _ = try store.recordPostingCheck(RecordPostingCheck(opportunityID: selectedOpportunityID, url: selectedJobURL, status: postingStatus, evidence: postingEvidence))
            postingEvidence = ""
            refreshCounts()
            statusMessage = "Reconciliation saved locally. The opportunity stage was not changed."
        } catch let error as LocalizedError {
            statusMessage = error.errorDescription ?? "The reconciliation could not be saved."
        } catch {
            statusMessage = "The reconciliation could not be saved."
        }
    }

    func recordSelectedContactInteraction() {
        guard let store, !selectedContactID.isEmpty else { return }
        do {
            _ = try store.recordContactInteraction(CreateContactInteraction(
                contactID: selectedContactID,
                opportunityID: interactionOpportunityID.isEmpty ? nil : interactionOpportunityID,
                kind: interactionKind,
                summary: interactionSummary,
                occurredAt: interactionOccurredAt,
                nextTouchAt: interactionHasNextTouch ? interactionNextTouchAt : nil
            ))
            clearInteractionDraft()
            refreshCounts()
            statusMessage = "Interaction saved locally."
        } catch let error as LocalizedError {
            statusMessage = error.errorDescription ?? "The interaction could not be saved."
        } catch {
            statusMessage = "The interaction could not be saved."
        }
    }

    func previewCSV(at url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do {
            csvPreview = try CSVOpportunityImporter.preview(data: Data(contentsOf: url))
            csvImportPlan = try store?.csvImportPlan(for: csvPreview!) ?? []
            statusMessage = "CSV preview ready. Review before importing."
        } catch {
            csvPreview = nil
            csvImportPlan = []
            statusMessage = "The CSV file could not be read. It needs title and company columns."
        }
    }

    func importCSVPreview() {
        guard let preview = csvPreview, let store else { return }
        do {
            csvImportReport = try store.importCSV(csvImportPlan, invalidCount: preview.invalidRowCount)
            csvPreview = nil
            csvImportPlan = []
            refreshCounts()
            statusMessage = "CSV import saved locally."
        } catch {
            statusMessage = "The CSV rows could not be imported."
        }
    }

    func setCSVDecision(_ decision: CSVDuplicateDecision, for rowID: Int) {
        guard let index = csvImportPlan.firstIndex(where: { $0.id == rowID }) else { return }
        csvImportPlan[index].decision = decision
    }

    private func apply(_ state: WorkspaceOpenState) {
        switch state {
        case let .ready(store):
            self.store = store
            refreshCounts()
            statusMessage = "Local workspace ready."
            canCreateWorkspace = false
            workspaceReady = true
        case .missingKey:
            statusMessage = "Workspace key is unavailable. Create a new local workspace only if you intend to start over."
            canCreateWorkspace = true
            workspaceReady = false
        case .missingExistingKey:
            statusMessage = "Workspace key is unavailable. The existing local workspace has not been replaced."
            canCreateWorkspace = false
            workspaceReady = false
        case .locked:
            statusMessage = "Unlock your Mac to reopen the local workspace."
            canCreateWorkspace = false
            workspaceReady = false
        case .denied:
            statusMessage = "Keychain access was denied. Allow access to reopen the local workspace."
            canCreateWorkspace = false
            workspaceReady = false
        case .corrupt:
            statusMessage = "The local workspace is unreadable. It has not been replaced; keep its files intact."
            canCreateWorkspace = false
            workspaceReady = false
        case .unavailable:
            statusMessage = "The local workspace could not be opened."
            canCreateWorkspace = false
            workspaceReady = false
        }
    }

    private func refreshCounts() {
        do {
            opportunityCount = try store?.opportunities().count ?? 0
            opportunities = try store?.opportunities() ?? []
            if selectedOpportunityID.isEmpty || !opportunities.contains(where: { $0.id == selectedOpportunityID }) {
                selectedOpportunityID = opportunities.first?.id ?? ""
            }
            loadSelectedOpportunity()
            refreshStageHistory()
            refreshSelectedTask()
            refreshRelationshipMemory()
            refreshSelectedPostingChecks()
            contacts = try store?.contacts() ?? []
            refreshSelectedContactInteraction()
            activityCount = try store?.activityEvents().count ?? 0
            activityEvents = try store?.activityEvents() ?? []
            needsAttention = try store?.needsAttention() ?? []
            needsAttentionCount = needsAttention.count
            csvImportReport = try store?.importReports().last
        } catch {
            statusMessage = "The local workspace could not be read."
        }
    }

    func refreshRelationshipMemory() {
        do {
            selectedContacts = selectedOpportunityID.isEmpty ? [] : try store?.contacts(forOpportunityID: selectedOpportunityID) ?? []
            selectedSameEmployerContacts = selectedOpportunityID.isEmpty ? [] : try store?.sameEmployerContacts(forOpportunityID: selectedOpportunityID) ?? []
            selectedOpportunityInteractions = selectedOpportunityID.isEmpty ? [] : try store?.opportunityInteractions(forOpportunityID: selectedOpportunityID) ?? []
        } catch {
            statusMessage = "The relationship history could not be read."
        }
    }

    private func refreshSelectedPostingChecks() {
        do {
            selectedPostingChecks = selectedOpportunityID.isEmpty ? [] : try store?.postingChecks(forOpportunityID: selectedOpportunityID) ?? []
        } catch {
            statusMessage = "The reconciliation history could not be read."
        }
    }

    private func contactCommand() -> CreateContact {
        CreateContact(name: contactName, employer: contactEmployer, title: contactTitle, email: contactEmail, profileURL: contactProfileURL, relationshipContext: contactRelationshipContext, notes: contactNotes)
    }

    private func clearContactDraft() {
        selectedContactID = ""
        contactName = ""
        contactEmployer = ""
        contactTitle = ""
        contactEmail = ""
        contactProfileURL = ""
        contactRelationshipContext = ""
        contactNotes = ""
        clearInteractionDraft()
    }

    private func clearInteractionDraft() {
        interactionSummary = ""
        interactionKind = .note
        interactionOccurredAt = Date.now
        interactionHasNextTouch = false
        interactionNextTouchAt = Date.now
        interactionOpportunityID = ""
    }

    private func refreshSelectedContactInteraction() {
        do {
            guard let store, !selectedContactID.isEmpty else {
                selectedContactInteractions = []
                selectedContactOpportunities = []
                selectedContactLastTouch = nil
                selectedContactNextTouch = nil
                return
            }
            selectedContactInteractions = try store.contactInteractions(forContactID: selectedContactID)
            selectedContactOpportunities = try store.opportunities(forContactID: selectedContactID)
            selectedContactLastTouch = try store.lastTouch(forContactID: selectedContactID)
            selectedContactNextTouch = try store.nextTouch(forContactID: selectedContactID)
            if !interactionOpportunityID.isEmpty && !selectedContactOpportunities.contains(where: { $0.id == interactionOpportunityID }) {
                interactionOpportunityID = ""
            }
        } catch {
            statusMessage = "The contact interaction history could not be read."
        }
    }

    private func loadSelectedOpportunity() {
        guard let opportunity = opportunities.first(where: { $0.id == selectedOpportunityID }) else {
            selectedTitle = ""
            selectedCompany = ""
            selectedJobURL = ""
            selectedStage = .saved
            selectedNextAction = ""
            selectedHasDueDate = false
            selectedDueAt = Date.now
            return
        }
        selectedTitle = opportunity.title
        selectedCompany = opportunity.company
        selectedJobURL = opportunity.jobURL
        selectedStage = opportunity.stage
        selectedNextAction = opportunity.nextAction
        selectedHasDueDate = opportunity.dueAt != nil
        selectedDueAt = opportunity.dueAt ?? Date.now
    }

    private func refreshStageHistory() {
        do {
            selectedStageHistory = selectedOpportunityID.isEmpty ? [] : try store?.stageHistory(forOpportunityID: selectedOpportunityID) ?? []
        } catch {
            statusMessage = "The stage history could not be read."
        }
    }

    private func refreshSelectedTask() {
        do {
            selectedTask = selectedOpportunityID.isEmpty ? nil : try store?.latestTask(forOpportunityID: selectedOpportunityID)
        } catch {
            statusMessage = "The task state could not be read."
        }
    }

    private static func defaultWorkspaceRoot() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RekonLabs", isDirectory: true)
            .appendingPathComponent("RekonPursuit", isDirectory: true)
    }
}
