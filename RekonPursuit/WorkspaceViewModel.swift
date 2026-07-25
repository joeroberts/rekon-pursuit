import Combine
import CryptoKit
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
    @Published var activitySearch = ""
    @Published var showClosedOpportunities = UserDefaults.standard.object(forKey: "showClosedOpportunities") as? Bool ?? true {
        didSet { UserDefaults.standard.set(showClosedOpportunities, forKey: "showClosedOpportunities") }
    }
    @Published private(set) var selectedStageHistory: [StageHistoryEntry] = []
    @Published private(set) var selectedTask: TaskReminder?
    @Published var opportunitySearch = ""
    @Published var stageFilter = "All stages"
    @Published var selectedTitle = ""
    @Published var selectedCompany = ""
    @Published var jobURL = ""
    @Published var jobDescription = ""
    @Published var notes = ""
    @Published var selectedJobURL = ""
    @Published var selectedJobDescription = ""
    @Published var selectedNotes = ""
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
    @Published var documentReferenceKind: DocumentReferenceKind = .resume
    @Published private(set) var selectedDocumentReferences: [DocumentReference] = []
    @Published private(set) var csvPreview: CSVImportPreview?
    @Published private(set) var csvImportPlan: [CSVImportPlanRow] = []
    @Published private(set) var csvImportReport: CSVImportReport?
    @Published private(set) var statusMessage = "Opening local workspace…"
    @Published private(set) var canCreateWorkspace = false
    @Published private(set) var workspaceReady = false

    private let openWorkspace: () throws -> WorkspaceOpenState
    private let createWorkspace: () throws -> WorkspaceStore
    private let restoreWorkspace: (URL) throws -> WorkspaceStore
    private var store: WorkspaceStore?
    private var stagedRestoreURL: URL?

    init(
        openWorkspace: @escaping () throws -> WorkspaceOpenState,
        createWorkspace: @escaping () throws -> WorkspaceStore,
        restoreWorkspace: @escaping (URL) throws -> WorkspaceStore = { _ in throw WorkspaceStoreError.injectedFailure }
    ) {
        self.openWorkspace = openWorkspace
        self.createWorkspace = createWorkspace
        self.restoreWorkspace = restoreWorkspace
    }

    convenience init() {
        let session = WorkspaceSession(root: Self.defaultWorkspaceRoot())
        self.init(openWorkspace: session.open, createWorkspace: session.create, restoreWorkspace: session.restore)
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
            _ = try store.create(CreateOpportunity(title: title, company: company, stage: stage, nextAction: nextAction, dueAt: nextAction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !hasDueDate ? nil : dueAt, jobURL: jobURL, jobDescription: jobDescription, notes: notes))
            title = ""
            company = ""
            jobURL = ""
            jobDescription = ""
            notes = ""
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
            return matchesStage && matchesSearch && (showClosedOpportunities || opportunity.stage != .closed)
        }
    }

    var selectedOpportunity: Opportunity? {
        opportunities.first { $0.id == selectedOpportunityID }
    }

    var selectedActivityEvents: [ActivityEvent] {
        activityEvents.filter { $0.opportunityID == selectedOpportunityID }
    }

    var filteredActivityEvents: [ActivityEvent] {
        let query = activitySearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return activityEvents }
        return activityEvents.filter { event in
            event.kind.localizedCaseInsensitiveContains(query) ||
            opportunities.first(where: { $0.id == event.opportunityID }).map { $0.title.localizedCaseInsensitiveContains(query) || $0.company.localizedCaseInsensitiveContains(query) } == true
        }
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
                jobURL: selectedJobURL,
                jobDescription: selectedJobDescription,
                notes: selectedNotes
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

    func exportOpportunitiesCSV() -> String? {
        guard let store else {
            statusMessage = "Create or reopen the local workspace first."
            return nil
        }
        do {
            try store.recordOpportunitiesExport()
            refreshCounts()
            statusMessage = "Unencrypted CSV export is ready. Save it only where you trust the storage."
            return OpportunityCSVExport.render(opportunities)
        } catch {
            statusMessage = "The CSV export could not be prepared."
            return nil
        }
    }

    func noteExportSaved() {
        statusMessage = "Unencrypted CSV export saved."
    }

    func createEncryptedBackup(at url: URL) {
        do {
            try store?.createEncryptedBackup(at: url)
            refreshCounts()
            statusMessage = "Encrypted same-Mac backup saved locally. Keep it with access to this Mac's Keychain."
        } catch let error as LocalizedError {
            statusMessage = error.errorDescription ?? "The encrypted backup could not be created."
        } catch {
            statusMessage = "The encrypted backup could not be created."
        }
    }

    func restoreEncryptedBackup(from url: URL) {
        defer {
            if url == stagedRestoreURL {
                try? FileManager.default.removeItem(at: url)
                stagedRestoreURL = nil
            }
        }
        do {
            try store?.close()
            store = try restoreWorkspace(url)
            refreshCounts()
            statusMessage = "Encrypted backup restored locally."
        } catch {
            store = nil
            start()
            statusMessage = "The encrypted backup could not be restored. Your existing workspace was kept."
        }
    }

    func stageEncryptedBackupForRestore(from url: URL) -> URL? {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        let stagedURL = FileManager.default.temporaryDirectory.appendingPathComponent("rekon-restore-\(UUID().uuidString).rekonbackup")
        do {
            if let stagedRestoreURL { try? FileManager.default.removeItem(at: stagedRestoreURL) }
            try FileManager.default.copyItem(at: url, to: stagedURL)
            stagedRestoreURL = stagedURL
            return stagedURL
        } catch {
            statusMessage = "The encrypted backup could not be prepared for restore."
            return nil
        }
    }

    func discardStagedBackupRestore() {
        if let stagedRestoreURL { try? FileManager.default.removeItem(at: stagedRestoreURL) }
        stagedRestoreURL = nil
    }

    func attachDocumentReference(at url: URL) {
        guard let store, !selectedOpportunityID.isEmpty else {
            statusMessage = "Select an opportunity before attaching a document reference."
            return
        }
        let extensionValue = url.pathExtension.lowercased()
        guard extensionValue == "pdf" || extensionValue == "docx" else {
            statusMessage = "Choose a PDF or DOCX file."
            return
        }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            guard data.count <= 25_000_000 else {
                statusMessage = "Choose a PDF or DOCX smaller than 25 MB."
                return
            }
            let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            let contentType = extensionValue == "pdf" ? "application/pdf" : "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
            _ = try store.recordDocumentReference(RecordDocumentReference(opportunityID: selectedOpportunityID, kind: documentReferenceKind, filename: url.lastPathComponent, contentType: contentType, sourceHash: hash, byteCount: data.count))
            refreshCounts()
            statusMessage = "Document reference saved locally. The file was not copied, edited, or uploaded."
        } catch {
            statusMessage = "The document reference could not be attached."
        }
    }

    func markDocumentReferenceFinalSent(_ reference: DocumentReference) {
        do {
            try store?.markDocumentReferenceFinalSent(id: reference.id)
            refreshCounts()
            statusMessage = "Final-sent metadata saved locally."
        } catch {
            statusMessage = "The document reference could not be marked final."
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
            refreshSelectedDocumentReferences()
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

    private func refreshSelectedDocumentReferences() {
        do {
            selectedDocumentReferences = selectedOpportunityID.isEmpty ? [] : try store?.documentReferences(forOpportunityID: selectedOpportunityID) ?? []
        } catch {
            statusMessage = "The document references could not be read."
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
            selectedJobDescription = ""
            selectedNotes = ""
            selectedStage = .saved
            selectedNextAction = ""
            selectedHasDueDate = false
            selectedDueAt = Date.now
            return
        }
        selectedTitle = opportunity.title
        selectedCompany = opportunity.company
        selectedJobURL = opportunity.jobURL
        selectedJobDescription = opportunity.jobDescription
        selectedNotes = opportunity.notes
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
