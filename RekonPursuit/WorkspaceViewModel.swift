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
    @Published private(set) var selectedResponseHistory: [ResponseHistoryEntry] = []
    @Published private(set) var selectedTask: TaskReminder?
    @Published var opportunitySearch = ""
    @Published var stageFilter = "All stages"
    @Published var selectedTitle = ""
    @Published var selectedCompany = ""
    @Published var jobURL = ""
    @Published var jobDescription = ""
    @Published var notes = ""
    @Published var compensation = ""
    @Published var location = ""
    @Published var workArrangement: WorkArrangement = .notSpecified
    @Published var applicationDate = Date.now
    @Published var hasApplicationDate = false
    @Published var responseState: ResponseState = .noResponseRecorded
    @Published var responseEffectiveDate = Date.now
    @Published var stageChangedAt = Date.now
    @Published var selectedJobURL = ""
    @Published var selectedJobDescription = ""
    @Published var selectedNotes = ""
    @Published var selectedCompensation = ""
    @Published var selectedLocation = ""
    @Published var selectedWorkArrangement: WorkArrangement = .notSpecified
    @Published var selectedApplicationDate = Date.now
    @Published var selectedHasApplicationDate = false
    @Published var selectedResponseState: ResponseState = .noResponseRecorded
    @Published var selectedResponseEffectiveDate = Date.now
    @Published var selectedStageChangedAt = Date.now
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
    @Published private(set) var csvImportReportRows: [CSVImportReportRow] = []
    @Published private(set) var statusMessage = "Opening local workspace…"
    @Published private(set) var canCreateWorkspace = false
    @Published private(set) var workspaceReady = false
    @Published private(set) var workspaceRequiresRecovery = false

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
            apply(.unavailable)
        }
    }

    func createWorkspaceIfNeeded() {
        do {
            apply(.ready(try createWorkspace()))
            statusMessage = "Local workspace created."
        } catch {
            // Creation can fail after retaining database or Keychain artifacts.
            // Re-open immediately so the UI presents the resulting safe state
            // (normally recovery-required) instead of offering another create.
            do {
                apply(try openWorkspace())
            } catch {
                apply(.unavailable)
            }
        }
    }

    func retryWorkspaceOpen() {
        start()
    }

    func createOpportunity() {
        guard let store = readyStore() else { return }
        do {
            _ = try store.create(CreateOpportunity(title: title, company: company, stage: stage, nextAction: nextAction, dueAt: nextAction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !hasDueDate ? nil : dueAt, jobURL: jobURL, jobDescription: jobDescription, notes: notes, compensation: compensation, location: location, workArrangement: workArrangement, applicationDate: hasApplicationDate ? applicationDate : nil, responseState: responseState, responseEffectiveDate: responseEffectiveDate, stageChangedAt: stageChangedAt))
            title = ""
            company = ""
            jobURL = ""
            jobDescription = ""
            notes = ""
            compensation = ""
            location = ""
            workArrangement = .notSpecified
            applicationDate = .now
            hasApplicationDate = false
            responseState = .noResponseRecorded
            responseEffectiveDate = .now
            stageChangedAt = .now
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
        guard let store = readyStore() else { return }
        do {
            try store.deleteOpportunity(id: opportunity.id)
            refreshCounts()
            statusMessage = "Opportunity deleted locally."
        } catch {
            statusMessage = "The opportunity could not be deleted."
        }
    }

    func complete(_ task: TaskReminder) {
        guard let store = readyStore() else { return }
        do {
            try store.completeTask(id: task.id)
            refreshCounts()
            statusMessage = "Action completed locally."
        } catch {
            statusMessage = "The action could not be completed."
        }
    }

    func snoozeOneDay(_ task: TaskReminder) {
        guard let store = readyStore() else { return }
        do {
            try store.snoozeTask(id: task.id)
            refreshCounts()
            statusMessage = "Action snoozed for one day."
        } catch {
            statusMessage = "The action could not be rescheduled."
        }
    }

    func reschedule(_ task: TaskReminder, to dueAt: Date) {
        guard let store = readyStore() else { return }
        do {
            try store.rescheduleTask(id: task.id, dueAt: dueAt)
            refreshCounts()
            statusMessage = "Action rescheduled locally."
        } catch {
            statusMessage = "The action could not be rescheduled."
        }
    }

    func changeStage(_ opportunity: Opportunity, to stage: PipelineStage) {
        guard let store = readyStore() else { return }
        do {
            try store.changeStage(opportunityID: opportunity.id, to: stage)
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
        guard let store = readyStore() else { return }
        do {
            try store.openTask(id: task.id)
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
        refreshResponseHistory()
        refreshSelectedTask()
        refreshRelationshipMemory()
        refreshSelectedPostingChecks()
    }

    func saveSelectedOpportunity() {
        guard let store = readyStore(), !selectedOpportunityID.isEmpty else { return }
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
                notes: selectedNotes,
                compensation: selectedCompensation,
                location: selectedLocation,
                workArrangement: selectedWorkArrangement,
                applicationDate: selectedHasApplicationDate ? selectedApplicationDate : nil,
                responseState: selectedResponseState,
                responseEffectiveDate: selectedResponseEffectiveDate,
                stageChangedAt: selectedStageChangedAt
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
        guard let store = readyStore() else { return }
        guard let task = needsAttention.first(where: { $0.opportunityID == selectedOpportunityID }) else {
            statusMessage = "Add a next action before rescheduling it."
            return
        }
        do {
            try store.rescheduleTask(id: task.id, dueAt: selectedDueAt)
            refreshCounts()
            statusMessage = "Action rescheduled locally."
        } catch {
            statusMessage = "The action could not be rescheduled."
        }
    }

    func createContact() {
        guard let store = readyStore() else { return }
        do {
            _ = try store.createContact(contactCommand())
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
        guard let store = readyStore(), !selectedContactID.isEmpty else { return }
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
        guard let store = readyStore() else { return }
        do {
            try store.deleteContact(id: contact.id)
            if selectedContactID == contact.id { clearContactDraft() }
            refreshCounts()
            statusMessage = "Contact deleted locally."
        } catch {
            statusMessage = "The contact could not be deleted."
        }
    }

    func link(_ contact: Contact) {
        guard let store = readyStore(), !selectedOpportunityID.isEmpty else { return }
        do {
            try store.linkContact(contactID: contact.id, toOpportunityID: selectedOpportunityID)
            refreshCounts()
            statusMessage = "Contact linked locally."
        } catch {
            statusMessage = "The contact could not be linked."
        }
    }

    func unlink(_ contact: Contact) {
        guard let store = readyStore(), !selectedOpportunityID.isEmpty else { return }
        do {
            try store.unlinkContact(contactID: contact.id, fromOpportunityID: selectedOpportunityID)
            refreshCounts()
            statusMessage = "Contact unlinked locally."
        } catch {
            statusMessage = "The contact could not be unlinked."
        }
    }

    func recordPostingCheck() {
        guard let store = readyStore(), !selectedOpportunityID.isEmpty else { return }
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
        guard let store = readyStore() else { return nil }
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
        guard let store = readyStore() else { return }
        do {
            try store.createEncryptedBackup(at: url)
            refreshCounts()
            statusMessage = "Encrypted same-Mac backup saved locally. Keep it with access to this Mac's Keychain."
        } catch let error as LocalizedError {
            statusMessage = error.errorDescription ?? "The encrypted backup could not be created."
        } catch {
            statusMessage = "The encrypted backup could not be created."
        }
    }

    func restoreEncryptedBackup(from url: URL) {
        guard let store = readyStore() else { return }
        defer {
            if url == stagedRestoreURL {
                try? FileManager.default.removeItem(at: url)
                stagedRestoreURL = nil
            }
        }
        do {
            try store.close()
            apply(.ready(try restoreWorkspace(url)))
            statusMessage = "Encrypted backup restored locally."
        } catch {
            self.store = nil
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
        guard let store = readyStore(), !selectedOpportunityID.isEmpty else {
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
        guard let store = readyStore() else { return }
        do {
            try store.markDocumentReferenceFinalSent(id: reference.id)
            refreshCounts()
            statusMessage = "Final-sent metadata saved locally."
        } catch {
            statusMessage = "The document reference could not be marked final."
        }
    }

    func recordSelectedContactInteraction() {
        guard let store = readyStore(), !selectedContactID.isEmpty else { return }
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
        guard let store = readyStore() else { return }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do {
            csvPreview = try CSVOpportunityImporter.preview(data: Data(contentsOf: url), sourceBasename: url.lastPathComponent)
            csvImportPlan = try store.csvImportPlan(for: csvPreview!)
            statusMessage = "CSV map ready. Confirm the columns, validate rows, then review duplicates."
        } catch {
            csvPreview = nil
            csvImportPlan = []
            statusMessage = "The CSV file could not be read. Check its UTF-8 formatting."
        }
    }

    func importCSVPreview() {
        guard let store = readyStore(), let preview = csvPreview else { return }
        do {
            csvImportReport = try store.importCSV(csvImportPlan, invalidCount: preview.invalidRowCount, invalidRows: preview.rows.filter { !$0.isValid }, sourceBasename: preview.sourceBasename, mapping: preview.mapping)
            csvImportReportRows = try store.importReportRows(for: csvImportReport!.id)
            csvPreview = nil
            csvImportPlan = []
            refreshCounts()
            statusMessage = "CSV import saved locally."
        } catch {
            statusMessage = "The CSV rows could not be imported."
        }
    }

    func setCSVDecision(_ decision: CSVDuplicateDecision, for rowID: Int) {
        guard workspaceReady, store != nil else {
            statusMessage = "Create or reopen the local workspace first."
            return
        }
        guard let index = csvImportPlan.firstIndex(where: { $0.id == rowID }) else { return }
        csvImportPlan[index].decision = decision
        if decision != .updateSelectedFields { csvImportPlan[index].selectedFields = [] }
    }

    func setCSVMapping(_ field: CSVImportField, to column: Int?) {
        guard var preview = csvPreview else { return }
        preview.mapping.removeValue(forKey: field)
        if let column { preview.mapping[field] = column }
        csvPreview = preview
        csvImportPlan = []
        statusMessage = CSVOpportunityImporter.mappingIsValid(preview.mapping) ? "Mapping changed. Validate to review rows again." : "Map both Job title and Company; each source column can be used once."
    }

    func validateCSVMapping() {
        guard let preview = csvPreview, CSVOpportunityImporter.mappingIsValid(preview.mapping), let store = readyStore() else { statusMessage = "Map both Job title and Company using separate columns."; return }
        do { csvImportPlan = try store.csvImportPlan(for: preview); statusMessage = "Validation complete. Choose an action for each possible duplicate." }
        catch { statusMessage = "The mapped CSV could not be validated." }
    }

    func setCSVSelectedField(_ field: CSVImportField, selected: Bool, for rowID: Int) {
        guard let index = csvImportPlan.firstIndex(where: { $0.id == rowID }) else { return }
        if selected { csvImportPlan[index].selectedFields.insert(field) } else { csvImportPlan[index].selectedFields.remove(field) }
    }

    private func apply(_ state: WorkspaceOpenState) {
        if case .ready = state {
            // A ready state replaces its store below.
        } else {
            clearWorkspaceDerivedState()
        }
        switch state {
        case let .ready(store):
            self.store = store
            refreshCounts()
            statusMessage = "Local workspace ready."
            canCreateWorkspace = false
            workspaceReady = true
            workspaceRequiresRecovery = false
        case .createAvailable:
            statusMessage = "Create a local workspace to begin tracking opportunities."
            canCreateWorkspace = true
            workspaceReady = false
            workspaceRequiresRecovery = false
        case .recoveryRequired:
            statusMessage = "Existing workspace material needs recovery. Nothing was replaced or removed."
            canCreateWorkspace = false
            workspaceReady = false
            workspaceRequiresRecovery = true
        case .locked:
            statusMessage = "Unlock your Mac to reopen the local workspace."
            canCreateWorkspace = false
            workspaceReady = false
            workspaceRequiresRecovery = false
        case .denied:
            statusMessage = "Keychain access was denied. Allow access to reopen the local workspace."
            canCreateWorkspace = false
            workspaceReady = false
            workspaceRequiresRecovery = false
        case .corrupt:
            statusMessage = "The local workspace is unreadable. It has not been replaced; keep its files intact."
            canCreateWorkspace = false
            workspaceReady = false
            workspaceRequiresRecovery = true
        case .unavailable:
            statusMessage = "The local workspace could not be opened."
            canCreateWorkspace = false
            workspaceReady = false
            workspaceRequiresRecovery = false
        }
    }

    private func readyStore() -> WorkspaceStore? {
        guard workspaceReady, let store else {
            statusMessage = "Create or reopen the local workspace first."
            return nil
        }
        return store
    }

    private func clearWorkspaceDerivedState() {
        store = nil
        opportunityCount = 0
        activityCount = 0
        needsAttentionCount = 0
        needsAttention = []
        opportunities = []
        activityEvents = []
        selectedOpportunityID = ""
        selectedStageHistory = []
        selectedResponseHistory = []
        selectedTask = nil
        loadSelectedOpportunity()
        contacts = []
        selectedContacts = []
        selectedSameEmployerContacts = []
        selectedOpportunityInteractions = []
        selectedContactInteractions = []
        selectedContactOpportunities = []
        selectedContactLastTouch = nil
        selectedContactNextTouch = nil
        clearContactDraft()
        postingStatus = .stillOpen
        postingEvidence = ""
        selectedPostingChecks = []
        selectedDocumentReferences = []
        csvPreview = nil
        csvImportPlan = []
        csvImportReport = nil
        csvImportReportRows = []
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
            refreshResponseHistory()
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
            csvImportReportRows = try csvImportReport.map { try store?.importReportRows(for: $0.id) ?? [] } ?? []
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
            selectedCompensation = ""
            selectedLocation = ""
            selectedWorkArrangement = .notSpecified
            selectedHasApplicationDate = false
            selectedResponseState = .noResponseRecorded
            selectedResponseEffectiveDate = Date.now
            selectedStageChangedAt = Date.now
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
        selectedCompensation = opportunity.compensation ?? ""
        selectedLocation = opportunity.location ?? ""
        selectedWorkArrangement = opportunity.workArrangement
        selectedHasApplicationDate = opportunity.applicationDate != nil
        selectedApplicationDate = opportunity.applicationDate ?? Date.now
        selectedResponseState = opportunity.responseState
        selectedResponseEffectiveDate = Date.now
        selectedStageChangedAt = opportunity.stageChangedAt ?? opportunity.createdAt
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

    private func refreshResponseHistory() {
        do {
            selectedResponseHistory = selectedOpportunityID.isEmpty ? [] : try store?.responseHistory(forOpportunityID: selectedOpportunityID) ?? []
        } catch {
            statusMessage = "The response history could not be read."
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
