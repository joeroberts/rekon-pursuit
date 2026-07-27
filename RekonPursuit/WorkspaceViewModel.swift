import Combine
import CryptoKit
import Foundation

private enum SeparateLocalWorkspaceConfiguration {
    static let activeIdentityPreferenceKey = "active-separate-local-workspace-identity"

    static func root(for identity: UUID) -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RekonLabs", isDirectory: true)
            .appendingPathComponent("RekonPursuitLocalWorkspaces", isDirectory: true)
            .appendingPathComponent(identity.uuidString.lowercased(), isDirectory: true)
    }
}

private enum SeparateLocalWorkspaceSelectionError: Error {
    case identityPersistenceFailed
}

@MainActor
struct SeparateLocalWorkspaceDependencies {
    let selectedIdentity: () -> UUID?
    let allocateAndPersistIdentity: () throws -> UUID
    let open: (UUID) throws -> WorkspaceOpenState
    let create: (UUID) throws -> WorkspaceStore
    let clearSelection: () throws -> Void

    fileprivate static func live() -> SeparateLocalWorkspaceDependencies {
        let defaults = UserDefaults.standard
        let preferenceKey = SeparateLocalWorkspaceConfiguration.activeIdentityPreferenceKey
        return SeparateLocalWorkspaceDependencies(
            selectedIdentity: {
                guard let rawValue = defaults.string(forKey: preferenceKey) else { return nil }
                return UUID(uuidString: rawValue)
            },
            allocateAndPersistIdentity: {
                if let rawValue = defaults.string(forKey: preferenceKey),
                   let identity = UUID(uuidString: rawValue) {
                    return identity
                }
                let identity = UUID()
                defaults.set(identity.uuidString, forKey: preferenceKey)
                guard defaults.string(forKey: preferenceKey) == identity.uuidString else {
                    throw SeparateLocalWorkspaceSelectionError.identityPersistenceFailed
                }
                return identity
            },
            open: { identity in
                let session = WorkspaceSession(
                    root: SeparateLocalWorkspaceConfiguration.root(for: identity),
                    keyStore: KeychainWorkspaceKeyStore(separateLocalWorkspace: identity)
                )
                return try session.open()
            },
            create: { identity in
                let session = WorkspaceSession(
                    root: SeparateLocalWorkspaceConfiguration.root(for: identity),
                    keyStore: KeychainWorkspaceKeyStore(separateLocalWorkspace: identity)
                )
                return try session.create()
            },
            clearSelection: {
                defaults.removeObject(forKey: preferenceKey)
                guard defaults.object(forKey: preferenceKey) == nil else {
                    throw SeparateLocalWorkspaceSelectionError.identityPersistenceFailed
                }
            }
        )
    }
}

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
    @Published var compensationMinimum = ""
    @Published var compensationMaximum = ""
    @Published var compensationPayPeriod: CompensationPayPeriod = .year
    @Published var location = ""
    @Published var workArrangement: WorkArrangement = .notSpecified
    @Published var applicationDate = Date.now
    @Published var hasApplicationDate = false
    @Published var responseState: ResponseState = .noResponseRecorded
    @Published var responseEffectiveDate = Date.now
    @Published var stageChangedAt = Date.now
    @Published var actionType: OpportunityActionType = .noAction
    @Published var actionCustomText = ""
    @Published var selectedJobURL = ""
    @Published var selectedJobDescription = ""
    @Published var selectedNotes = ""
    @Published var selectedCompensation = ""
    @Published var selectedCompensationMinimum = "" {
        didSet { markSelectedStructuredCompensationEdited() }
    }
    @Published var selectedCompensationMaximum = "" {
        didSet { markSelectedStructuredCompensationEdited() }
    }
    @Published var selectedCompensationPayPeriod: CompensationPayPeriod = .year {
        didSet { markSelectedStructuredCompensationEdited() }
    }
    @Published private(set) var selectedStructuredCompensationEdited = false
    @Published var selectedLocation = ""
    @Published var selectedWorkArrangement: WorkArrangement = .notSpecified
    @Published var selectedApplicationDate = Date.now
    @Published var selectedHasApplicationDate = false
    @Published var selectedResponseState: ResponseState = .noResponseRecorded
    @Published var selectedResponseEffectiveDate = Date.now
    @Published var selectedStageChangedAt = Date.now
    @Published var selectedStage: PipelineStage = .saved
    @Published var selectedNextAction = ""
    @Published var selectedActionType: OpportunityActionType = .noAction {
        didSet { markSelectedTypedActionEdited() }
    }
    @Published var selectedActionCustomText = "" {
        didSet { markSelectedTypedActionEdited() }
    }
    @Published private(set) var selectedTypedActionEdited = false
    @Published var selectedDueAt = Date.now
    @Published var selectedHasDueDate = false
    @Published var contactName = ""
    @Published var contactEmployer = ""
    @Published var contactEmployerSearch = ""
    @Published var isAddingNewContactEmployer = false
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
    @Published private(set) var selectedContactEmployerOpportunities: [Opportunity] = []
    @Published private(set) var selectedContactLastTouch: Date?
    @Published private(set) var selectedContactNextTouch: Date?
    @Published var reconciliationOutcome: ReconciliationOutcome = .stillOpen
    @Published var reconciliationClassification: ReconciliationClassification = .confirmed
    @Published var reconciliationReason: ReconciliationReason = .manualReview
    @Published var reconciliationConfidence: ReconciliationConfidence = .medium
    @Published var reconciliationEvidence = ""
    @Published private(set) var selectedReconciliationResults: [ReconciliationResult] = []
    @Published private(set) var selectedReconciliationTask: TaskReminder?
    @Published private(set) var selectedReconciliationTaskCompletion: [String: Bool] = [:]
    @Published private(set) var checkingPublicURLOpportunityIDs: Set<String> = []
    @Published var documentReferenceKind: DocumentReferenceKind = .resume
    @Published private(set) var selectedDocumentReferences: [DocumentReference] = []
    @Published private(set) var csvPreview: CSVImportPreview?
    @Published private(set) var csvImportPlan: [CSVImportPlanRow] = []
    @Published private(set) var csvImportReport: CSVImportReport?
    @Published private(set) var csvImportReportRows: [CSVImportReportRow] = []
    @Published private(set) var addOpportunitySaveError: String?
    @Published private(set) var contactSaveError: String?
    @Published private(set) var statusMessage = "Opening local workspace…"
    @Published private(set) var canCreateWorkspace = false
    @Published private(set) var workspaceReady = false
    @Published private(set) var workspaceRequiresRecovery = false
    @Published private(set) var usingSeparateLocalWorkspace = false

    private let openWorkspace: () throws -> WorkspaceOpenState
    private let openExternalWorkspace: (URL) throws -> WorkspaceOpenState
    private let closeWorkspaceStore: (WorkspaceStore) throws -> Void
    private let createWorkspace: () throws -> WorkspaceStore
    private let restoreWorkspace: (URL) throws -> WorkspaceStore
    private let workspaceLocationBookmarks: WorkspaceLocationBookmarkStore
    private let separateLocalWorkspace: SeparateLocalWorkspaceDependencies
    private let publicURLChecker: PublicURLChecking
    private var store: WorkspaceStore?
    private var activeSeparateLocalWorkspaceIdentity: UUID?
    private var externalWorkspaceLease: WorkspaceAccessLease?
    private var stagedRestoreURL: URL?
    private var publicURLCheckTasks: [String: Task<Void, Never>] = [:]
    private var isLoadingSelectedOpportunity = false

    init(
        openWorkspace: @escaping () throws -> WorkspaceOpenState,
        createWorkspace: @escaping () throws -> WorkspaceStore,
        restoreWorkspace: @escaping (URL) throws -> WorkspaceStore = { _ in throw WorkspaceStoreError.injectedFailure },
        workspaceLocationBookmarks: WorkspaceLocationBookmarkStore = WorkspaceLocationBookmarkStore(),
        openExternalWorkspace: @escaping (URL) throws -> WorkspaceOpenState = { _ in .recoveryRequired },
        closeWorkspaceStore: @escaping (WorkspaceStore) throws -> Void = { try $0.close() },
        publicURLChecker: PublicURLChecking = PublicURLChecker(),
        separateLocalWorkspace: SeparateLocalWorkspaceDependencies
    ) {
        self.openWorkspace = openWorkspace
        self.openExternalWorkspace = openExternalWorkspace
        self.closeWorkspaceStore = closeWorkspaceStore
        self.createWorkspace = createWorkspace
        self.restoreWorkspace = restoreWorkspace
        self.workspaceLocationBookmarks = workspaceLocationBookmarks
        self.publicURLChecker = publicURLChecker
        self.separateLocalWorkspace = separateLocalWorkspace
    }

    convenience init() {
        let session = WorkspaceSession(root: Self.defaultWorkspaceRoot())
        self.init(
            openWorkspace: session.open,
            createWorkspace: session.create,
            restoreWorkspace: session.restore,
            separateLocalWorkspace: .live()
        )
    }

    func start() {
        if externalWorkspaceLease != nil || (usingSeparateLocalWorkspace && store != nil) {
            do {
                try closeCurrentWorkspace()
            } catch {
                presentWorkspaceCloseFailure()
                return
            }
        }
        if let identity = separateLocalWorkspace.selectedIdentity() {
            activeSeparateLocalWorkspaceIdentity = identity
            usingSeparateLocalWorkspace = true
            do {
                apply(try separateLocalWorkspace.open(identity))
            } catch {
                apply(.unavailable)
            }
            return
        }
        activeSeparateLocalWorkspaceIdentity = nil
        usingSeparateLocalWorkspace = false
        switch workspaceLocationBookmarks.resolve() {
        case let .available(lease):
            openExternalWorkspace(with: lease)
        case .stale:
            apply(.recoveryRequired)
            statusMessage = "The selected workspace folder needs recovery. Choose the existing workspace folder again; nothing was created or replaced."
        case .missing:
            do {
                apply(try openWorkspace())
            } catch {
                apply(.unavailable)
            }
        }
    }

    func createWorkspaceIfNeeded() {
        if usingSeparateLocalWorkspace {
            createSeparateLocalWorkspace()
            return
        }
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

    func createSeparateLocalWorkspace() {
        do {
            let identity: UUID
            if let activeSeparateLocalWorkspaceIdentity {
                identity = activeSeparateLocalWorkspaceIdentity
            } else {
                identity = try separateLocalWorkspace.allocateAndPersistIdentity()
                activeSeparateLocalWorkspaceIdentity = identity
            }
            usingSeparateLocalWorkspace = true
            apply(.ready(try separateLocalWorkspace.create(identity)))
            statusMessage = "Separate local workspace created."
        } catch {
            guard let identity = activeSeparateLocalWorkspaceIdentity ?? separateLocalWorkspace.selectedIdentity() else {
                apply(.unavailable)
                statusMessage = "The separate local workspace identity could not be saved."
                return
            }
            activeSeparateLocalWorkspaceIdentity = identity
            usingSeparateLocalWorkspace = true
            do {
                apply(try separateLocalWorkspace.open(identity))
                if !workspaceReady {
                    statusMessage = "The separate local workspace could not be created. Retry to continue with the same local workspace."
                }
            } catch {
                apply(.unavailable)
                statusMessage = "The separate local workspace could not be opened. Its identity remains selected for recovery."
            }
        }
    }

    func returnToPreservedWorkspaceRecovery() {
        guard usingSeparateLocalWorkspace else { return }
        do {
            try closeCurrentWorkspace()
        } catch {
            statusMessage = "The separate local workspace could not close safely. The preserved workspace was not selected."
            return
        }
        do {
            try separateLocalWorkspace.clearSelection()
        } catch {
            apply(.unavailable)
            usingSeparateLocalWorkspace = true
            statusMessage = "The separate local workspace closed, but its selection could not be cleared. Retry returning to the preserved workspace."
            return
        }
        activeSeparateLocalWorkspaceIdentity = nil
        usingSeparateLocalWorkspace = false
        apply(.recoveryRequired)
        statusMessage = "Returned to the preserved workspace recovery state. No workspace data was changed."
    }

    func retryWorkspaceOpen() {
        start()
    }

    func chooseExistingWorkspaceFolder(_ url: URL?) {
        guard !usingSeparateLocalWorkspace else {
            statusMessage = "Return to the preserved workspace recovery state before choosing its folder."
            return
        }
        guard let url else {
            if hasActiveExternalWorkspace {
                statusMessage = "Workspace selection was cancelled. The current external workspace remains open."
            } else {
                apply(.recoveryRequired)
                statusMessage = "Workspace selection was cancelled. Choose the existing workspace folder to continue recovery."
            }
            return
        }
        do {
            let lease = try workspaceLocationBookmarks.validateAndSave(url: url) {
                try self.closeExternalWorkspaceForTransition()
            }
            openExternalWorkspace(with: lease)
        } catch {
            if hasActiveExternalWorkspace {
                statusMessage = "The selected folder could not be used. The current external workspace remains open."
            } else {
                apply(.recoveryRequired)
                statusMessage = "Choose an existing workspace folder that directly contains workspace.sqlite. Nothing was created or replaced."
            }
        }
    }

    func closeWorkspace() {
        do {
            try closeCurrentWorkspace()
        } catch {
            presentWorkspaceCloseFailure()
            return
        }
        clearWorkspaceDerivedState()
        workspaceReady = false
        canCreateWorkspace = false
        workspaceRequiresRecovery = true
        statusMessage = "Workspace closed. Choose an existing workspace folder to recover it."
    }

    func teardown() {
        guard (try? closeCurrentWorkspace()) != nil else { return }
        clearWorkspaceDerivedState()
    }

    func createOpportunity() {
        guard let store = readyStore() else { return }
        do {
            let actionTitle = actionDraftTitle(type: actionType, customText: actionCustomText)
            _ = try store.create(CreateOpportunity(title: title, company: company, stage: stage, nextAction: actionTitle, dueAt: actionTitle.isEmpty || !hasDueDate ? nil : dueAt, jobURL: jobURL, jobDescription: jobDescription, notes: notes, compensation: compensation, compensationMinimum: compensationDraftValue(compensationMinimum), compensationMaximum: compensationDraftValue(compensationMaximum), compensationPayPeriod: compensationMinimum.isEmpty && compensationMaximum.isEmpty ? nil : compensationPayPeriod, location: location, workArrangement: workArrangement, applicationDate: hasApplicationDate ? applicationDate : nil, responseState: responseState, responseEffectiveDate: responseEffectiveDate, stageChangedAt: stageChangedAt, actionType: actionType, actionCustomText: actionCustomText))
            title = ""
            company = ""
            jobURL = ""
            jobDescription = ""
            notes = ""
            compensation = ""
            compensationMinimum = ""
            compensationMaximum = ""
            compensationPayPeriod = .year
            location = ""
            workArrangement = .notSpecified
            applicationDate = .now
            hasApplicationDate = false
            responseState = .noResponseRecorded
            responseEffectiveDate = .now
            stageChangedAt = .now
            nextAction = ""
            actionType = .noAction
            actionCustomText = ""
            hasDueDate = false
            refreshCounts()
            addOpportunitySaveError = nil
            statusMessage = "Saved locally."
        } catch let error as LocalizedError {
            let message = error.errorDescription ?? "The opportunity could not be saved."
            addOpportunitySaveError = message
            statusMessage = message
        } catch {
            let message = "The opportunity could not be saved."
            addOpportunitySaveError = message
            statusMessage = message
        }
    }

    func deleteOpportunity(_ opportunity: Opportunity) {
        guard let store = readyStore() else { return }
        do {
            publicURLCheckTasks[opportunity.id]?.cancel()
            try store.deleteOpportunity(id: opportunity.id)
            publicURLCheckTasks[opportunity.id] = nil
            checkingPublicURLOpportunityIDs.remove(opportunity.id)
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

    func opportunity(id: String) -> Opportunity? {
        opportunities.first { $0.id == id }
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

    var contactEmployerSuggestions: [String] {
        var canonicalEmployers: [String: String] = [:]
        for opportunity in opportunities {
            let employer = opportunity.company.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalized = normalizedEmployerName(employer)
            if !employer.isEmpty, canonicalEmployers[normalized] == nil {
                canonicalEmployers[normalized] = employer
            }
        }
        return canonicalEmployers.values.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    var filteredContactEmployerSuggestions: [String] {
        let query = contactEmployerSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        let normalizedQuery = normalizedEmployerName(query)
        return Array(contactEmployerSuggestions
            .filter { normalizedEmployerName($0).contains(normalizedQuery) }
            .prefix(6))
    }

    var contactEmployerAddCandidate: String? {
        let query = contactEmployerSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return nil }
        let normalizedQuery = normalizedEmployerName(query)
        let hasExactMatch = contactEmployerSuggestions.contains {
            normalizedEmployerName($0) == normalizedQuery
        }
        return hasExactMatch ? nil : query
    }

    var contactProfileURLWarning: String? { profileURLWarning(for: contactProfileURL) }

    var selectedContact: Contact? {
        contacts.first { $0.id == selectedContactID }
    }

    @discardableResult
    func open(_ task: TaskReminder) -> Bool {
        guard let store = readyStore() else { return false }
        do {
            try store.openTask(id: task.id)
            selectedOpportunityID = task.opportunityID
            refreshCounts()
            statusMessage = "Opened opportunity locally."
            return true
        } catch {
            statusMessage = "The opportunity could not be opened."
            return false
        }
    }

    func select(_ opportunity: Opportunity) {
        selectedOpportunityID = opportunity.id
        loadSelectedOpportunity()
        refreshStageHistory()
        refreshResponseHistory()
        refreshSelectedTask()
        refreshRelationshipMemory()
        refreshSelectedReconciliation()
    }

    /// Selects an existing opportunity for an ephemeral UI route. Returning a
    /// result lets navigation safely fall back to the Pipeline when a record
    /// was deleted while another route was visible.
    @discardableResult
    func selectRouteOpportunity(id: String) -> Bool {
        guard let opportunity = opportunities.first(where: { $0.id == id }) else { return false }
        select(opportunity)
        return true
    }

    /// Cross-record navigation is paused while the bounded R5 check owns a
    /// record. This keeps a completion, cancellation, or closure action from
    /// being redirected through the former global selected-record state.
    @discardableResult
    func navigateToRouteOpportunity(id: String) -> Bool {
        guard checkingPublicURLOpportunityIDs.isEmpty || checkingPublicURLOpportunityIDs.contains(id) else {
            statusMessage = "Finish or cancel the active public URL check before opening another opportunity."
            return false
        }
        return selectRouteOpportunity(id: id)
    }

    /// A sidebar change may leave the current opportunity route only when no
    /// bounded R5 URL check is still responsible for a selected record.
    @discardableResult
    func canLeaveOpportunityRoute() -> Bool {
        guard checkingPublicURLOpportunityIDs.isEmpty else {
            statusMessage = "Finish or cancel the active public URL check before leaving this opportunity."
            return false
        }
        return true
    }

    func saveSelectedOpportunity() {
        guard let store = readyStore(), !selectedOpportunityID.isEmpty else { return }
        do {
            let actionTitle = selectedTypedActionEdited
                ? actionDraftTitle(type: selectedActionType, customText: selectedActionCustomText)
                : selectedNextAction
            try store.updateOpportunity(
                id: selectedOpportunityID,
                title: selectedTitle,
                company: selectedCompany,
                stage: selectedStage,
                nextAction: actionTitle,
                dueAt: actionTitle.isEmpty || !selectedHasDueDate ? nil : selectedDueAt,
                jobURL: selectedJobURL,
                jobDescription: selectedJobDescription,
                notes: selectedNotes,
                compensation: selectedCompensation,
                compensationMinimum: compensationDraftValue(selectedCompensationMinimum),
                compensationMaximum: compensationDraftValue(selectedCompensationMaximum),
                compensationPayPeriod: selectedCompensationMinimum.isEmpty && selectedCompensationMaximum.isEmpty ? nil : selectedCompensationPayPeriod,
                structuredCompensationEdited: selectedStructuredCompensationEdited,
                location: selectedLocation,
                workArrangement: selectedWorkArrangement,
                applicationDate: selectedHasApplicationDate ? selectedApplicationDate : nil,
                responseState: selectedResponseState,
                responseEffectiveDate: selectedResponseEffectiveDate,
                stageChangedAt: selectedStageChangedAt,
                actionType: selectedActionType,
                actionCustomText: selectedActionCustomText,
                typedActionEdited: selectedTypedActionEdited
            )
            refreshCounts()
            statusMessage = "Opportunity updated locally."
        } catch let error as LocalizedError {
            statusMessage = error.errorDescription ?? "The opportunity could not be updated."
        } catch {
            statusMessage = "The opportunity could not be updated."
        }
    }

    /// Saves the draft already loaded for an opportunity route. Route actions
    /// must not reselect the record first because selection reloads the stored
    /// values and would discard the user's unsaved edits.
    func saveRouteOpportunity(id: String) {
        guard selectedOpportunityID == id else {
            statusMessage = "Open the opportunity again before saving changes."
            return
        }
        saveSelectedOpportunity()
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

    /// Reschedules the task for the draft already loaded by an opportunity
    /// route without reloading that route's unsaved fields.
    func rescheduleRouteTask(id: String) {
        guard selectedOpportunityID == id else {
            statusMessage = "Open the opportunity again before rescheduling its action."
            return
        }
        rescheduleSelectedTask()
    }

    func createContact() {
        guard let store = readyStore() else { return }
        do {
            let contact = try store.createContact(contactCommand())
            refreshCounts()
            selectContact(contact)
            contactSaveError = nil
            statusMessage = "Contact saved locally."
        } catch let error as LocalizedError {
            let message = error.errorDescription ?? "The contact could not be saved."
            contactSaveError = message
            statusMessage = message
        } catch {
            let message = "The contact could not be saved."
            contactSaveError = message
            statusMessage = message
        }
    }

    func selectContact(_ contact: Contact) {
        selectedContactID = contact.id
        contactName = contact.name
        contactEmployer = contact.employer
        contactEmployerSearch = contact.employer
        isAddingNewContactEmployer = !contact.employer.isEmpty && !contactEmployerSuggestions.contains {
            $0.compare(contact.employer, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
        contactTitle = contact.title
        contactEmail = contact.email
        contactProfileURL = contact.profileURL
        contactRelationshipContext = contact.relationshipContext
        contactNotes = contact.notes
        contactSaveError = nil
        refreshSelectedContactInteraction()
    }

    func beginNewContact() {
        clearContactDraft()
    }

    func selectContactEmployer(_ employer: String) {
        let trimmedEmployer = employer.trimmingCharacters(in: .whitespacesAndNewlines)
        contactEmployer = contactEmployerSuggestions.first {
            normalizedEmployerName($0) == normalizedEmployerName(trimmedEmployer)
        } ?? trimmedEmployer
        contactEmployerSearch = contactEmployer
        isAddingNewContactEmployer = false
    }

    func beginNewContactEmployer() {
        contactEmployer = ""
        contactEmployerSearch = ""
        isAddingNewContactEmployer = true
    }

    func beginNewContactEmployer(named employer: String) {
        let trimmedEmployer = employer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmployer.isEmpty else {
            beginNewContactEmployer()
            return
        }
        contactEmployer = trimmedEmployer
        contactEmployerSearch = trimmedEmployer
        isAddingNewContactEmployer = true
    }

    func chooseTrackedContactEmployer() {
        contactEmployer = ""
        contactEmployerSearch = ""
        isAddingNewContactEmployer = false
    }

    func saveSelectedContact() {
        guard let store = readyStore(), !selectedContactID.isEmpty else { return }
        do {
            let contact = try store.updateContact(id: selectedContactID, command: contactCommand())
            refreshCounts()
            selectContact(contact)
            contactSaveError = nil
            statusMessage = "Contact updated locally."
        } catch let error as LocalizedError {
            let message = error.errorDescription ?? "The contact could not be updated."
            contactSaveError = message
            statusMessage = message
        } catch {
            let message = "The contact could not be updated."
            contactSaveError = message
            statusMessage = message
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

    func linkSelectedContact(to opportunity: Opportunity) {
        guard let store = readyStore(), !selectedContactID.isEmpty else { return }
        do {
            try store.linkContact(contactID: selectedContactID, toOpportunityID: opportunity.id)
            refreshCounts()
            statusMessage = "Contact linked locally."
        } catch {
            statusMessage = "The contact could not be linked."
        }
    }

    func unlinkSelectedContact(from opportunity: Opportunity) {
        guard let store = readyStore(), !selectedContactID.isEmpty else { return }
        do {
            try store.unlinkContact(contactID: selectedContactID, fromOpportunityID: opportunity.id)
            refreshCounts()
            statusMessage = "Contact unlinked locally."
        } catch {
            statusMessage = "The contact could not be unlinked."
        }
    }

    func recordReconciliation() {
        guard let store = readyStore(), !selectedOpportunityID.isEmpty else { return }
        do {
            _ = try store.recordReconciliationResult(RecordReconciliationResult(opportunityID: selectedOpportunityID, url: selectedJobURL, outcome: reconciliationOutcome, classification: reconciliationClassification, reason: reconciliationReason, confidence: reconciliationOutcome == .needsManualReview && reconciliationClassification == .offlineUnchecked ? nil : reconciliationConfidence, evidence: reconciliationEvidence))
            reconciliationEvidence = ""
            refreshCounts()
            statusMessage = "Local review recorded. No online check ran."
        } catch let error as LocalizedError { statusMessage = error.errorDescription ?? "The local review could not be saved." }
        catch { statusMessage = "The local review could not be saved." }
    }

    var isCheckingSelectedPublicURL: Bool {
        checkingPublicURLOpportunityIDs.contains(selectedOpportunityID)
    }

    var canCheckSelectedPublicURL: Bool {
        guard let opportunity = selectedOpportunity else { return false }
        guard opportunity.stage != .closed,
              let scheme = URLComponents(string: opportunity.jobURL)?.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return false
        }
        if case .malformed = publicURLChecker.prepare(opportunity.jobURL) { return false }
        return true
    }

    func checkSelectedPublicURL() {
        guard let store = readyStore(),
              let opportunity = selectedOpportunity,
              canCheckSelectedPublicURL else {
            statusMessage = "Select an active opportunity with a saved job URL."
            return
        }
        let urlSnapshot = opportunity.jobURL
        switch publicURLChecker.prepare(urlSnapshot) {
        case .malformed:
            statusMessage = "The saved job URL is malformed. Correct it before checking."
        case let .ineligible(completion):
            do {
                let start = try store.beginPublicURLCheck(opportunityID: opportunity.id, urlSnapshot: urlSnapshot)
                guard start.isNew else {
                    statusMessage = "A public URL check is already running for this opportunity or host."
                    return
                }
                _ = try store.finishPublicURLCheck(operationID: start.operation.id, completion: completion)
                refreshCounts()
                statusMessage = "No network request ran. Review the local eligibility result."
            } catch let error as LocalizedError {
                statusMessage = error.errorDescription ?? "The public URL check could not be started."
            } catch {
                statusMessage = "The public URL check could not be started."
            }
        case let .eligible(request):
            do {
                let start = try store.beginPublicURLCheck(opportunityID: opportunity.id, urlSnapshot: urlSnapshot)
                guard start.isNew else {
                    statusMessage = "A public URL check is already running for this opportunity or host."
                    return
                }
                checkingPublicURLOpportunityIDs.insert(opportunity.id)
                statusMessage = "Checking the saved public URL once…"
                publicURLCheckTasks[opportunity.id] = Task { [weak self] in
                    guard let self else { return }
                    let completion = await publicURLChecker.check(request, opportunityTitle: opportunity.title)
                    do {
                        _ = try store.finishPublicURLCheck(operationID: start.operation.id, completion: completion)
                        checkingPublicURLOpportunityIDs.remove(opportunity.id)
                        publicURLCheckTasks[opportunity.id] = nil
                        refreshCounts()
                        statusMessage = completion.terminalState == .cancelled
                            ? "Public URL check cancelled. Manual review remains available."
                            : "Public URL check completed. Review the limited local evidence."
                    } catch {
                        checkingPublicURLOpportunityIDs.remove(opportunity.id)
                        publicURLCheckTasks[opportunity.id] = nil
                        refreshCounts()
                        statusMessage = "The public URL check ended, but its local result could not be saved."
                    }
                }
            } catch let error as LocalizedError {
                statusMessage = error.errorDescription ?? "The public URL check could not be started."
            } catch {
                statusMessage = "The public URL check could not be started."
            }
        }
    }

    func cancelSelectedPublicURLCheck() {
        guard isCheckingSelectedPublicURL else { return }
        publicURLCheckTasks[selectedOpportunityID]?.cancel()
        statusMessage = "Cancelling the public URL check…"
    }

    @discardableResult
    func openReconciliationReviewAction(forOpportunityID opportunityID: String) -> Bool {
        guard navigateToRouteOpportunity(id: opportunityID) else { return false }
        guard let task = selectedReconciliationTask else {
            statusMessage = "No reconciliation review action is available for this opportunity."
            return false
        }
        return open(task)
    }

    @discardableResult
    func confirmReconciliationClosure(forOpportunityID opportunityID: String) -> Bool {
        guard selectRouteOpportunity(id: opportunityID) else {
            statusMessage = "The opportunity could not be found."
            return false
        }
        return confirmReconciliationClosure()
    }

    @discardableResult
    func confirmReconciliationClosure() -> Bool {
        guard let store = readyStore(), !selectedOpportunityID.isEmpty else { return false }
        do {
            try store.confirmReconciliationClosure(forOpportunityID: selectedOpportunityID)
            refreshCounts()
            statusMessage = "Closure confirmed locally."
            return true
        } catch let error as LocalizedError {
            statusMessage = error.errorDescription ?? "Closure could not be confirmed."
            return false
        } catch {
            statusMessage = "Closure could not be confirmed."
            return false
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

    func openImportedOpportunity(_ id: String) {
        guard opportunities.contains(where: { $0.id == id }) else { return }
        selectedOpportunityID = id
        loadSelectedOpportunity()
        statusMessage = "Opened the local opportunity from the import report."
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
        publicURLCheckTasks.values.forEach { $0.cancel() }
        publicURLCheckTasks = [:]
        checkingPublicURLOpportunityIDs = []
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
        selectedDocumentReferences = []
        csvPreview = nil
        csvImportPlan = []
        csvImportReport = nil
        csvImportReportRows = []
    }

    private func openExternalWorkspace(with lease: WorkspaceAccessLease) {
        externalWorkspaceLease = lease
        do {
            let state = try openExternalWorkspace(lease.url)
            if case .ready = state {
                apply(state)
            } else {
                try closeExternalWorkspaceForTransition()
                apply(state == .createAvailable ? .recoveryRequired : state)
            }
        } catch {
            do {
                try closeExternalWorkspaceForTransition()
                apply(.recoveryRequired)
            } catch {
                presentWorkspaceCloseFailure()
            }
        }
    }

    private var hasActiveExternalWorkspace: Bool {
        externalWorkspaceLease != nil
    }

    private func closeExternalWorkspaceForTransition() throws {
        guard externalWorkspaceLease != nil else { return }
        if let store {
            try closeWorkspaceStore(store)
            self.store = nil
        }
        externalWorkspaceLease?.close()
        externalWorkspaceLease = nil
    }

    private func closeCurrentWorkspace() throws {
        if externalWorkspaceLease != nil {
            try closeExternalWorkspaceForTransition()
        } else if let store {
            try closeWorkspaceStore(store)
            self.store = nil
        }
    }

    private func presentWorkspaceCloseFailure() {
        workspaceReady = false
        canCreateWorkspace = false
        workspaceRequiresRecovery = true
        statusMessage = "The external workspace could not close safely. It remains open; retry recovery before switching."
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
            refreshSelectedReconciliation()
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

    private func refreshSelectedReconciliation() {
        do {
            selectedReconciliationResults = selectedOpportunityID.isEmpty ? [] : try store?.reconciliationResults(forOpportunityID: selectedOpportunityID) ?? []
            selectedReconciliationTask = selectedOpportunityID.isEmpty ? nil : try store?.reconciliationReviewTask(forOpportunityID: selectedOpportunityID)
            selectedReconciliationTaskCompletion = Dictionary(uniqueKeysWithValues: try Set(selectedReconciliationResults.compactMap(\.reviewTaskID)).map { taskID in
                (taskID, try store?.taskReminder(id: taskID)?.isComplete ?? false)
            })
        } catch { statusMessage = "The reconciliation history could not be read." }
    }

    var selectedClosureSuggestion: ReconciliationResult? {
        selectedReconciliationResults.first { $0.outcome == .closedSuggested && $0.closureConfirmedAt == nil }
    }

    func reconciliationReviewTaskState(for result: ReconciliationResult) -> String {
        guard let taskID = result.reviewTaskID else { return "Not needed" }
        return selectedReconciliationTaskCompletion[taskID] == true ? "Complete" : "Open"
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
        contactEmployerSearch = ""
        isAddingNewContactEmployer = false
        contactTitle = ""
        contactEmail = ""
        contactProfileURL = ""
        contactRelationshipContext = ""
        contactNotes = ""
        contactSaveError = nil
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
                selectedContactEmployerOpportunities = []
                selectedContactLastTouch = nil
                selectedContactNextTouch = nil
                return
            }
            selectedContactInteractions = try store.contactInteractions(forContactID: selectedContactID)
            selectedContactOpportunities = try store.opportunities(forContactID: selectedContactID)
            selectedContactEmployerOpportunities = try store.opportunities(forEmployer: selectedContact?.employer ?? "")
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
        isLoadingSelectedOpportunity = true
        defer {
            isLoadingSelectedOpportunity = false
            selectedStructuredCompensationEdited = false
            selectedTypedActionEdited = false
        }
        guard let opportunity = opportunities.first(where: { $0.id == selectedOpportunityID }) else {
            selectedTitle = ""
            selectedCompany = ""
            selectedJobURL = ""
            selectedJobDescription = ""
            selectedNotes = ""
            selectedCompensation = ""
            selectedCompensationMinimum = ""
            selectedCompensationMaximum = ""
            selectedCompensationPayPeriod = .year
            selectedLocation = ""
            selectedWorkArrangement = .notSpecified
            selectedHasApplicationDate = false
            selectedResponseState = .noResponseRecorded
            selectedResponseEffectiveDate = Date.now
            selectedStageChangedAt = Date.now
            selectedStage = .saved
            selectedNextAction = ""
            selectedActionType = .noAction
            selectedActionCustomText = ""
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
        selectedCompensationMinimum = opportunity.compensationMinimum.map(compensationDraftText) ?? ""
        selectedCompensationMaximum = opportunity.compensationMaximum.map(compensationDraftText) ?? ""
        selectedCompensationPayPeriod = opportunity.compensationPayPeriod ?? .year
        selectedLocation = opportunity.location ?? ""
        selectedWorkArrangement = opportunity.workArrangement
        selectedHasApplicationDate = opportunity.applicationDate != nil
        selectedApplicationDate = opportunity.applicationDate ?? Date.now
        selectedResponseState = opportunity.responseState
        selectedResponseEffectiveDate = Date.now
        selectedStageChangedAt = opportunity.stageChangedAt ?? opportunity.createdAt
        selectedStage = opportunity.stage
        selectedNextAction = opportunity.nextAction
        selectedActionType = opportunity.actionType
        selectedActionCustomText = opportunity.actionCustomText ?? ""
        selectedHasDueDate = opportunity.dueAt != nil
        selectedDueAt = opportunity.dueAt ?? Date.now
    }

    var jobURLWarning: String? { urlWarning(for: jobURL) }
    var selectedJobURLWarning: String? { urlWarning(for: selectedJobURL) }

    func formattedCompensation(for opportunity: Opportunity) -> String? {
        guard opportunity.compensationMinimum != nil || opportunity.compensationMaximum != nil else { return opportunity.compensation }
        let formatter = FloatingPointFormatStyle<Double>.Currency(code: "USD").precision(.fractionLength(0))
        let values = [opportunity.compensationMinimum.map { $0.formatted(formatter) }, opportunity.compensationMaximum.map { $0.formatted(formatter) }].compactMap { $0 }
        return values.joined(separator: " – ") + (opportunity.compensationPayPeriod.map { " / \($0.rawValue.lowercased())" } ?? "")
    }

    private func compensationDraftValue(_ value: String) throws -> Double? {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        let numericValue = value.hasPrefix("$") ? String(value.dropFirst()) : value
        let amountPattern = "^-?(?:(?:\\d{1,3}(?:,\\d{3})+)|\\d+)(?:\\.\\d+)?$"
        guard numericValue.range(of: amountPattern, options: .regularExpression) != nil,
              let parsed = Double(numericValue.replacingOccurrences(of: ",", with: "")) else {
            throw WorkspaceStoreError.invalidCompensation
        }
        return parsed
    }

    private func compensationDraftText(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(value)
    }

    private func markSelectedStructuredCompensationEdited() {
        guard !isLoadingSelectedOpportunity else { return }
        selectedStructuredCompensationEdited = true
    }

    private func markSelectedTypedActionEdited() {
        guard !isLoadingSelectedOpportunity else { return }
        selectedTypedActionEdited = true
    }

    private func actionDraftTitle(type: OpportunityActionType, customText: String) -> String {
        type == .other ? customText.trimmingCharacters(in: .whitespacesAndNewlines) : (type == .noAction ? "" : type.rawValue)
    }

    private func normalizedEmployerName(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private func urlWarning(for value: String) -> String? {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        guard let components = URLComponents(string: value), let scheme = components.scheme?.lowercased(), let host = components.host, !host.isEmpty, ["http", "https"].contains(scheme) else {
            return "Use an absolute http or https URL with a host. Imported legacy URLs are preserved until changed."
        }
        return scheme == "http" ? "This job URL uses HTTP rather than HTTPS." : nil
    }

    private func profileURLWarning(for value: String) -> String? {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        guard let components = URLComponents(string: value), let scheme = components.scheme?.lowercased(), let host = components.host, host.contains("."), ["http", "https"].contains(scheme) else {
            return "Use an absolute http or https profile URL with a public hostname."
        }
        return scheme == "http" ? "This profile URL uses HTTP rather than HTTPS." : nil
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
