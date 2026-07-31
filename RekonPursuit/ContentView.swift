import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum BootstrapCopy {
    nonisolated static let status = "Local-only foundation"
}

struct CSVExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    var text: String
    init(text: String) { self.text = text }
    init(configuration: ReadConfiguration) throws {
        text = String(data: configuration.file.regularFileContents ?? Data(), encoding: .utf8) ?? ""
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

struct ContentView: View {
    @StateObject private var model: WorkspaceViewModel
    private let homeDashboardNow: Date
    private let homeDashboardCalendar: Calendar
    @State private var navigation = DailyNavigationState()
    @State private var opportunityRoute: OpportunityRoute?
    @State private var pipelineQuery = ""
    @State private var pipelineStageFilter = "All stages"
    @State private var pipelineIncludesClosed = false
    @State private var showsPipelineBoard = false
    @State private var pipelineAnchorID: String?
    @State private var pipelineHorizontalLane: PipelineBoardLane?
    @State private var addOpportunityOrigin: AddOpportunityOrigin?
    @State private var pendingDeletion: Opportunity?
    @State private var pendingContactDeletion: Contact?
    @State private var taskToReschedule: TaskReminder?
    @State private var rescheduledDueAt = Date.now
    @State private var showsDocumentReferenceImporter = false
    @State private var documentReferenceToRelink: DocumentReference?
    @State private var closureConfirmationID: String?

    init(
        model: WorkspaceViewModel,
        homeDashboardNow: Date = .now,
        homeDashboardCalendar: Calendar = .current
    ) {
        _model = StateObject(wrappedValue: model)
        self.homeDashboardNow = homeDashboardNow
        self.homeDashboardCalendar = homeDashboardCalendar
    }

    var body: some View {
        AppShellView(
            selection: Binding(
                get: { navigation.route },
                set: { selectDestination($0) }
            ),
            detailTitle: detailTitle,
            selectDestination: selectDestination
        ) {
            if !model.workspaceReady {
                WorkspaceOnboardingView(model: model)
            } else if let route = opportunityRoute {
                routedOpportunityView(route)
            } else {
                dailyDestination
            }
        }
        .onAppear { model.start() }
        .onDisappear { model.teardown() }
        .sheet(isPresented: Binding(
            get: { closureConfirmationID != nil },
            set: { if !$0 { closureConfirmationID = nil } }
        )) {
            if let id = closureConfirmationID {
                ClosureConfirmationView(model: model, opportunityID: id) { closureConfirmationID = nil }
            }
        }
        .alert("Delete opportunity?", isPresented: Binding(
            get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let pendingDeletion { model.deleteOpportunity(pendingDeletion) }
                pendingDeletion = nil
                if case let .overview(id) = opportunityRoute, model.selectedOpportunityID == id { opportunityRoute = nil }
            }
            Button("Cancel", role: .cancel) { pendingDeletion = nil }
        } message: {
            Text("This removes the opportunity and its pending actions from the active tracker. A redacted local deletion record is retained.")
        }
        .alert("Delete contact?", isPresented: Binding(
            get: { pendingContactDeletion != nil }, set: { if !$0 { pendingContactDeletion = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let pendingContactDeletion { model.deleteContact(pendingContactDeletion) }
                pendingContactDeletion = nil
            }
            Button("Cancel", role: .cancel) { pendingContactDeletion = nil }
        } message: { Text("This removes the contact from active lists and links. A redacted local deletion record is retained.") }
        .sheet(isPresented: Binding(
            get: { taskToReschedule != nil },
            set: { if !$0 { taskToReschedule = nil } }
        )) {
            if let task = taskToReschedule {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Reschedule action").font(.title2.bold())
                    Text(task.title).foregroundStyle(.secondary)
                    DatePicker("New due date", selection: $rescheduledDueAt, displayedComponents: [.date, .hourAndMinute])
                        .accessibilityLabel("New due date")
                        .accessibilityIdentifier("home-reschedule-due-date")
                    HStack {
                        Button("Cancel") { taskToReschedule = nil }.keyboardShortcut(.cancelAction)
                        Spacer()
                        Button("Save locally") { model.reschedule(task, to: rescheduledDueAt); taskToReschedule = nil }
                            .keyboardShortcut(.defaultAction)
                    }
                }
                .padding(24).frame(width: 380)
            }
        }
        .fileImporter(isPresented: $showsDocumentReferenceImporter, allowedContentTypes: [.pdf, UTType(filenameExtension: "docx") ?? .data], allowsMultipleSelection: false) { result in
            if case let .success(urls) = result, let url = urls.first {
                if let documentReferenceToRelink {
                    model.relinkDocumentReference(documentReferenceToRelink, at: url)
                    self.documentReferenceToRelink = nil
                } else {
                    model.attachDocumentReference(at: url)
                }
            }
            if case .failure = result { documentReferenceToRelink = nil }
        }
    }

    @ViewBuilder private var dailyDestination: some View {
        Group {
            switch navigation.route {
            case .home: HomeView(model: model, open: openAttentionTask, addOpportunity: { beginAddOpportunity(origin: .home) }, reschedule: { task in taskToReschedule = task; rescheduledDueAt = task.dueAt ?? .now }, now: homeDashboardNow, calendar: homeDashboardCalendar)
            case .pipeline:
                PipelineView(
                    model: model,
                    query: $pipelineQuery,
                    stage: $pipelineStageFilter,
                    includesClosed: $pipelineIncludesClosed,
                    showsBoard: $showsPipelineBoard,
                    anchorID: $pipelineAnchorID,
                    horizontalLane: $pipelineHorizontalLane,
                    open: openOpportunity,
                    delete: { pendingDeletion = $0 },
                    addOpportunity: beginPipelineAddOpportunity,
                    importCSV: {
                        addOpportunityOrigin = nil
                        navigation.handle(.pipelineImport)
                    }
                )
            case .addOpportunity: AddOpportunityView(model: model, cancel: cancelAddOpportunity)
            case .importCSV: CSVImportView(model: model, chooseFile: chooseCSVFile, open: openOpportunity, finish: { addOpportunityOrigin = nil; navigation.select(.pipeline) })
            case .contacts: ContactsView(model: model, open: openOpportunity, delete: { pendingContactDeletion = $0 })
            case .activityAI: GlobalActivityView(model: model)
            case .settings: SettingsView(model: model)
            }
        }
    }

    @ViewBuilder private func routedOpportunityView(_ route: OpportunityRoute) -> some View {
        switch route {
        case let .overview(id):
            OpportunityOverviewView(model: model, opportunityID: id, back: returnToPipeline, showHistory: { openRoute(.history(id)) }, showReconcile: { openRoute(.reconcile(id)) }, chooseDocument: { showsDocumentReferenceImporter = true }, relinkDocument: { reference in documentReferenceToRelink = reference; showsDocumentReferenceImporter = true })
        case let .history(id):
            OpportunityHistoryView(model: model, opportunityID: id, back: { returnFromOpportunitySubroute(.history(id)) })
        case let .reconcile(id):
            ReconcilePostingView(model: model, opportunityID: id, back: { returnFromOpportunitySubroute(.reconcile(id)) }, confirmClosure: { closureConfirmationID = id })
        }
    }

    private func openOpportunity(_ opportunity: Opportunity) {
        addOpportunityOrigin = nil
        pipelineAnchorID = opportunity.id
        openRoute(.overview(opportunity.id))
    }

    private func openAttentionTask(_ task: TaskReminder) {
        guard model.navigateToRouteOpportunity(id: task.opportunityID) else { return }
        guard model.open(task) else { return }
        addOpportunityOrigin = nil
        pipelineAnchorID = task.opportunityID
        opportunityRoute = task.requiresClosureConfirmation ? .reconcile(task.opportunityID) : .overview(task.opportunityID)
        navigation.select(.pipeline)
    }

    private func openRoute(_ route: OpportunityRoute) {
        guard model.navigateToRouteOpportunity(id: route.opportunityID) else { return }
        addOpportunityOrigin = nil
        opportunityRoute = route
    }

    private func beginPipelineAddOpportunity() {
        if showsPipelineBoard {
            let context = PipelineBoardReturnContext(
                query: pipelineQuery,
                stageFilter: pipelineStageFilter,
                includesClosed: pipelineIncludesClosed,
                selectedOrAnchoredOpportunityID: pipelineAnchorID,
                horizontalScrollLane: pipelineHorizontalLane
            )
            beginAddOpportunity(origin: .pipelineBoard(context))
        } else {
            beginAddOpportunity(origin: .pipelineTable)
        }
    }

    private func beginAddOpportunity(origin: AddOpportunityOrigin) {
        addOpportunityOrigin = AddOpportunityOrigin.replacing(addOpportunityOrigin, with: origin)
        navigation.select(.addOpportunity)
    }

    private func cancelAddOpportunity() {
        let origin = addOpportunityOrigin
        let destination = origin?.cancelDestination ?? AddOpportunityOrigin.home.cancelDestination
        model.discardNewOpportunityDraft()
        showsPipelineBoard = destination.showsBoard
        if let context = destination.boardContext {
            pipelineQuery = context.query
            pipelineStageFilter = context.stageFilter
            pipelineIncludesClosed = context.includesClosed
            pipelineAnchorID = context.selectedOrAnchoredOpportunityID
            pipelineHorizontalLane = context.horizontalScrollLane
        }
        navigation.select(destination.route)
        addOpportunityOrigin = nil
    }

    private var detailTitle: String {
        guard let opportunityRoute else { return AppDestination(navigation.route).rawValue }
        switch opportunityRoute {
        case .overview: return "Opportunity"
        case .history: return "Activity & history"
        case .reconcile: return "Reconcile posting"
        }
    }

    private func selectDestination(_ destination: DailyRoute) {
        guard opportunityRoute != nil else {
            addOpportunityOrigin = nil
            navigation.select(destination)
            return
        }
        guard model.canLeaveOpportunityRoute() else { return }
        opportunityRoute = nil
        addOpportunityOrigin = nil
        navigation.select(destination)
    }

    private func returnToPipeline() {
        guard model.canLeaveOpportunityRoute() else { return }
        opportunityRoute = nil
        addOpportunityOrigin = nil
        navigation.select(.pipeline)
    }

    private func returnFromOpportunitySubroute(_ route: OpportunityRoute) {
        guard let parent = route.parentRoute(recordIsAvailable: model.opportunity(id: route.opportunityID) != nil) else {
            returnToPipeline()
            return
        }
        openRoute(parent)
    }

    private func chooseCSVFile() {
        let panel = NSOpenPanel()
        panel.title = "Choose CSV file"
        panel.message = "Select a UTF-8 CSV file to preview before importing."
        panel.prompt = "Choose CSV"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.commaSeparatedText, .plainText]
        panel.begin { response in if response == .OK, let url = panel.url { model.previewCSV(at: url) } }
    }

}

private struct WorkspaceOnboardingView: View {
    @ObservedObject var model: WorkspaceViewModel
    var body: some View {
        VStack(spacing: 20) {
            Image("RekonEmblem").resizable().scaledToFit().frame(width: 88, height: 88)
            Text("Welcome to Rekon Pursuit").font(.largeTitle.bold())
            Text("A private, local-first workspace for your job search.").foregroundStyle(RekonTheme.secondaryText)
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Text(model.statusMessage).accessibilityIdentifier("workspace-gate-status")
                    if model.usingSeparateLocalWorkspace {
                        Button("Retry separate local workspace") { model.createSeparateLocalWorkspace() }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("retry-separate-local-workspace")
                        Button("Return to preserved workspace recovery") { model.returnToPreservedWorkspaceRecovery() }
                            .accessibilityIdentifier("return-to-preserved-workspace-recovery")
                    } else if model.canCreateWorkspace {
                        Button("Create local workspace") { model.createWorkspaceIfNeeded() }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("create-local-workspace")
                    } else if model.workspaceRequiresRecovery {
                        Text("Recovery is required before this workspace can be opened. Rekon Pursuit kept existing local material unchanged and will not create over it.").foregroundStyle(.secondary)
                        Text("Only recovery actions are available until you choose or create a safe local workspace.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("recovery-only-workspace-gate")
                        Button("Recheck local workspace") { model.retryWorkspaceOpen() }.accessibilityIdentifier("recheck-local-workspace")
                        Button("Choose existing workspace folder…", action: chooseExistingWorkspaceFolder)
                            .accessibilityIdentifier("choose-existing-workspace-folder")
                        Button("Create separate local workspace") { model.createSeparateLocalWorkspace() }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("create-separate-local-workspace")
                    } else {
                        Button("Retry opening workspace") { model.retryWorkspaceOpen() }.accessibilityIdentifier("retry-local-workspace")
                    }
                }
                .padding(8)
            }
            .frame(maxWidth: 480)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(36)
        .accessibilityIdentifier("workspace-onboarding")
    }

    private func chooseExistingWorkspaceFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose Existing Rekon Pursuit Workspace"
        panel.message = "Choose the folder that directly contains workspace.sqlite."
        panel.prompt = "Choose workspace"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        let selectedURL = panel.runModal() == .OK ? panel.url : nil
        model.chooseExistingWorkspaceFolder(selectedURL)
    }
}

private struct OpportunityOverviewView: View {
    @ObservedObject var model: WorkspaceViewModel
    let opportunityID: String
    let back: () -> Void
    let showHistory: () -> Void
    let showReconcile: () -> Void
    let chooseDocument: () -> Void
    let relinkDocument: (DocumentReference) -> Void
    var body: some View {
        Group {
            if let opportunity = model.opportunity(id: opportunityID), model.selectedOpportunityID == opportunityID {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            Button("Back to Pipeline", systemImage: "chevron.left", action: back)
                            Spacer()
                            Menu("More") { Button("Activity & history", action: showHistory); Button("Reconcile posting", action: showReconcile) }
                        }
                        VStack(alignment: .leading, spacing: 3) { Text(opportunity.title).font(.largeTitle.bold()); Text(opportunity.company).foregroundStyle(RekonTheme.secondaryText) }
                        GroupBox("Opportunity") {
                            Form {
                                TextField("Job title", text: $model.selectedTitle).accessibilityIdentifier("selected-opportunity-title")
                                TextField("Company", text: $model.selectedCompany)
                                TextField("Job URL (optional)", text: $model.selectedJobURL)
                                if let warning = model.selectedJobURLWarning { Text(warning).font(.caption).foregroundStyle(.orange) }
                                Text("Job description").font(.caption).foregroundStyle(.secondary)
                                TextEditor(text: $model.selectedJobDescription).frame(minHeight: 110)
                                Text("Notes").font(.caption).foregroundStyle(.secondary)
                                TextEditor(text: $model.selectedNotes).frame(minHeight: 90)
                                Section("Compensation") {
                                    if !model.selectedCompensation.isEmpty { Text("Imported: \(model.selectedCompensation)").font(.caption).foregroundStyle(.secondary) }
                                    TextField("Minimum (USD)", text: $model.selectedCompensationMinimum)
                                    TextField("Maximum (USD)", text: $model.selectedCompensationMaximum)
                                    Picker("Pay period", selection: $model.selectedCompensationPayPeriod) { ForEach(CompensationPayPeriod.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                                    if let formatted = model.formattedCompensation(for: opportunity) { Text(formatted).font(.caption).foregroundStyle(.secondary) }
                                }
                                TextField("Location (optional)", text: $model.selectedLocation)
                                Picker("Work arrangement", selection: $model.selectedWorkArrangement) { ForEach(WorkArrangement.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                                Picker("Stage", selection: $model.selectedStage) { ForEach(PipelineStage.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                                Picker("Next action", selection: $model.selectedActionType) { ForEach(OpportunityActionType.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                                if model.selectedActionType == .other { TextField("Other action", text: $model.selectedActionCustomText) }
                                Toggle("Add a due date", isOn: $model.selectedHasDueDate)
                                if model.selectedHasDueDate { DatePicker("Due", selection: $model.selectedDueAt, displayedComponents: [.date, .hourAndMinute]) }
                                HStack { Button("Save changes locally") { model.saveRouteOpportunity(id: opportunityID) }.accessibilityIdentifier("save-opportunity-changes"); Button("Reschedule action") { model.rescheduleRouteTask(id: opportunityID) }.disabled(model.selectedNextAction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
                            }
                        }
                        CompactDocumentsView(model: model, opportunityID: opportunityID, chooseDocument: chooseDocument, relinkDocument: relinkDocument)
                    }
                    .padding(28).frame(maxWidth: 880, alignment: .leading)
                }
            } else { MissingOpportunityView(back: back) }
        }
    }
}

private struct CompactDocumentsView: View {
    @ObservedObject var model: WorkspaceViewModel
    let opportunityID: String
    let chooseDocument: () -> Void
    let relinkDocument: (DocumentReference) -> Void
    var body: some View {
        GroupBox("Documents") {
            if model.selectedOpportunityID == opportunityID {
                HStack {
                    if model.selectedDocumentReferences.isEmpty { Text("No résumé or cover-letter references attached.").foregroundStyle(.secondary) }
                    else { Text("\(model.selectedDocumentReferences.count) reference\(model.selectedDocumentReferences.count == 1 ? "" : "s") attached").foregroundStyle(.secondary) }
                    Spacer()
                    Menu("Manage") {
                        Picker("Reference type", selection: $model.documentReferenceKind) { ForEach(DocumentReferenceKind.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                        Button("Choose PDF or DOCX…", action: chooseDocument).accessibilityIdentifier("choose-document-reference")
                        ForEach(model.selectedDocumentReferences, id: \.id) { reference in
                            Text(reference.filename)
                            Text(reference.availability == .available ? "Available" : "Relink required").foregroundStyle(.secondary)
                            if reference.availability == .available { Button("Open \(reference.filename)") { model.openDocumentReference(reference) } }
                            Button("Relink \(reference.filename)") { relinkDocument(reference) }
                            Button("Remove \(reference.filename)", role: .destructive) { model.removeDocumentReference(reference) }
                            if reference.finalSentAt == nil { Button("Mark \(reference.filename) final sent") { _ = model.selectRouteOpportunity(id: opportunityID); model.markDocumentReferenceFinalSent(reference) } }
                        }
                    }
                }
            }
        }
    }
}

private struct OpportunityHistoryView: View {
    @ObservedObject var model: WorkspaceViewModel
    let opportunityID: String
    let back: () -> Void
    var body: some View {
        Group {
            if let opportunity = model.opportunity(id: opportunityID), model.selectedOpportunityID == opportunityID {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Button("Back to \(opportunity.title)", systemImage: "chevron.left", action: back)
                        Text("Activity & history").font(.largeTitle.bold())
                        Text("\(opportunity.title) · \(opportunity.company)").foregroundStyle(RekonTheme.secondaryText)
                        HistorySection(title: "Stage history", empty: "No stage changes recorded.") { ForEach(model.selectedStageHistory, id: \.id) { Text("\($0.fromStage?.rawValue ?? "Created") → \($0.toStage.rawValue) · \($0.occurredAt.formatted(date: .abbreviated, time: .shortened))") } }
                        HistorySection(title: "Response history", empty: "No response has been recorded.") { ForEach(model.selectedResponseHistory, id: \.id) { Text("\($0.fromState.rawValue) → \($0.toState.rawValue) · \($0.occurredAt.formatted(date: .abbreviated, time: .shortened))") } }
                        HistorySection(title: "Activity", empty: "No activity for this opportunity yet.") { ForEach(model.selectedActivityEvents, id: \.id) { Text("\($0.kind.replacingOccurrences(of: "_", with: " ").capitalized) · \($0.occurredAt.formatted(date: .abbreviated, time: .shortened))") } }
                        HistorySection(title: "Contacts", empty: "No contacts are linked to this opportunity.") { ForEach(model.selectedContacts, id: \.id) { Text([ $0.name, $0.title, $0.employer ].filter { !$0.isEmpty }.joined(separator: " · ")) } }
                        HistorySection(title: "Relationship interactions", empty: "No contact interactions are recorded for this opportunity yet.") {
                            ForEach(model.selectedOpportunityInteractions, id: \.id) { interaction in
                                VStack(alignment: .leading) {
                                    Text("\(interaction.contactName ?? "Prior note") · \(interaction.kind.rawValue)").font(.headline)
                                    Text(interaction.summary)
                                    if let next = interaction.nextTouchAt { Text("Next touch: \(next.formatted(date: .abbreviated, time: .shortened))").foregroundStyle(.secondary) }
                                }
                            }
                        }
                    }.padding(28).frame(maxWidth: 880, alignment: .leading)
                }
            } else { MissingOpportunityView(back: back) }
        }
    }
}

private struct HistorySection<Content: View>: View {
    let title: String; let empty: String; @ViewBuilder let content: () -> Content
    var body: some View { GroupBox(title) { VStack(alignment: .leading, spacing: 8) { content() }.font(.callout) } }
}

private struct ReconcilePostingView: View {
    @ObservedObject var model: WorkspaceViewModel
    let opportunityID: String
    let back: () -> Void
    let confirmClosure: () -> Void
    var body: some View {
        Group {
            if let opportunity = model.opportunity(id: opportunityID), model.selectedOpportunityID == opportunityID {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Button("Back to \(opportunity.title)", systemImage: "chevron.left", action: back)
                        Text("Reconcile posting").font(.largeTitle.bold())
                        Text("Review this opening without changing its stage automatically.").foregroundStyle(RekonTheme.secondaryText)
                        GroupBox("Public posting check") {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("A check never follows redirects, signs in, retries automatically, or changes the opportunity stage.").font(.caption).foregroundStyle(.secondary)
                                if let url = URL(string: model.selectedJobURL), !model.selectedJobURL.isEmpty {
                                    HStack {
                                        Link("Open job posting", destination: url)
                                        Spacer()
                                        if model.isCheckingSelectedPublicURL {
                                            ProgressView()
                                            Button("Cancel") {
                                                _ = model.selectRouteOpportunity(id: opportunityID)
                                                model.cancelSelectedPublicURLCheck()
                                            }
                                            .accessibilityIdentifier("cancel-public-url-check")
                                        } else {
                                            Button("Check public URL") {
                                                _ = model.selectRouteOpportunity(id: opportunityID)
                                                model.checkSelectedPublicURL()
                                            }
                                            .disabled(!model.canCheckSelectedPublicURL)
                                            .accessibilityIdentifier("check-public-url")
                                        }
                                    }
                                } else { Text("Add a job URL to review this opening.").foregroundStyle(.secondary) }
                            }
                        }
                        GroupBox("Manual review") {
                            Form {
                                Picker("Local outcome", selection: $model.reconciliationOutcome) { ForEach(ReconciliationOutcome.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                                Picker("Classification", selection: $model.reconciliationClassification) { ForEach(ReconciliationClassification.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                                Picker("Reason", selection: $model.reconciliationReason) { ForEach(ReconciliationReason.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                                Picker("Confidence", selection: $model.reconciliationConfidence) { ForEach(ReconciliationConfidence.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                                TextField("Evidence or error reviewed", text: $model.reconciliationEvidence, axis: .vertical)
                                HStack { Button("Record local review") { _ = model.selectRouteOpportunity(id: opportunityID); model.recordReconciliation() }; Button("Record offline — check not run") { _ = model.selectRouteOpportunity(id: opportunityID); model.reconciliationOutcome = .needsManualReview; model.reconciliationClassification = .offlineUnchecked; model.reconciliationReason = .offlineUnchecked; model.reconciliationEvidence = "Offline — check not run"; model.recordReconciliation() }; Button("Confirm closure…", action: confirmClosure) }
                                if let task = model.selectedReconciliationTask {
                                    HStack {
                                        Button("Open review action") { _ = model.openReconciliationReviewAction(forOpportunityID: opportunityID) }
                                            .accessibilityIdentifier("open-reconciliation-review-action")
                                        Text(task.isComplete ? "Review action completed" : "Review action open")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        if !model.selectedReconciliationResults.isEmpty { HistorySection(title: "Reconciliation history", empty: "") { ForEach(model.selectedReconciliationResults, id: \.id) { result in VStack(alignment: .leading, spacing: 3) { Text("\(result.outcome.rawValue) · \(result.classification.rawValue) · \(result.recordedAt.formatted(date: .abbreviated, time: .shortened))").font(.headline); Text(result.evidence.isEmpty ? result.error : result.evidence); Text("Closure: \(result.closureConfirmedAt == nil ? (result.outcome == .closedSuggested ? "Awaiting confirmation" : "Not closed") : "Confirmed")").font(.caption).foregroundStyle(.secondary) } } } }
                    }.padding(28).frame(maxWidth: 880, alignment: .leading)
                }
            } else { MissingOpportunityView(back: back) }
        }
    }
}

private struct ClosureConfirmationView: View {
    @ObservedObject var model: WorkspaceViewModel
    let opportunityID: String
    let dismiss: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Confirm closure").font(.title2.bold())
            if model.selectedOpportunityID == opportunityID, let result = model.selectedClosureSuggestion { Text("\(result.url)\n\(result.evidence)\n\(result.recordedAt.formatted(date: .abbreviated, time: .shortened))") } else { Text("Record an unconfirmed Closed suggested result before confirming closure.") }
            Text("This changes the stage to Closed and completes only the dedicated reconciliation review action.")
            HStack { Button("Keep active", action: dismiss); Button("Confirm closure") { if model.confirmReconciliationClosure(forOpportunityID: opportunityID) { dismiss() } }.keyboardShortcut(.defaultAction).disabled(model.selectedClosureSuggestion == nil) }
        }.padding().frame(minWidth: 420)
    }
}

private struct MissingOpportunityView: View { let back: () -> Void; var body: some View { ContentUnavailableView("Opportunity unavailable", systemImage: "exclamationmark.triangle", description: Text("It may have been deleted while this screen was open.")); Button("Return to Pipeline", action: back) } }

struct FlexibleCenteredContent<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 14) {
                Spacer(minLength: 24)
                content()
                Spacer(minLength: 24)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct AddOpportunityView: View {
    @ObservedObject var model: WorkspaceViewModel
    let cancel: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Add opportunity").font(.largeTitle.bold())
                Form {
                    TextField("Job title", text: $model.title).accessibilityIdentifier("opportunity-title")
                    TextField("Company", text: $model.company).accessibilityIdentifier("opportunity-company")
                    TextField("Job URL (optional)", text: $model.jobURL)
                    if let warning = model.jobURLWarning { Text(warning).font(.caption).foregroundStyle(.orange).accessibilityIdentifier("add-opportunity-url-warning") }
                    Text("Job description").font(.caption).foregroundStyle(.secondary)
                    TextEditor(text: $model.jobDescription).frame(minHeight: 110)
                    Text("Notes").font(.caption).foregroundStyle(.secondary)
                    TextEditor(text: $model.notes).frame(minHeight: 90)
                    Section("Job details") {
                        TextField("Minimum (USD)", text: $model.compensationMinimum)
                        TextField("Maximum (USD)", text: $model.compensationMaximum)
                        Picker("Pay period", selection: $model.compensationPayPeriod) { ForEach(CompensationPayPeriod.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                        TextField("Location (optional)", text: $model.location)
                        Picker("Work arrangement", selection: $model.workArrangement) { ForEach(WorkArrangement.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                        Toggle("Add applied date", isOn: $model.hasApplicationDate)
                        if model.hasApplicationDate { DatePicker("Applied date", selection: $model.applicationDate, displayedComponents: .date) }
                        Picker("Current response", selection: $model.responseState) { ForEach(ResponseState.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                    }
                    Picker("Stage", selection: $model.stage) { ForEach(PipelineStage.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                    Picker("Next action", selection: $model.actionType) { ForEach(OpportunityActionType.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                    if model.actionType == .other { TextField("Other action", text: $model.actionCustomText).accessibilityIdentifier("opportunity-next-action") }
                    Toggle("Add a due date", isOn: $model.hasDueDate)
                    if model.hasDueDate { DatePicker("Due", selection: $model.dueAt, displayedComponents: [.date, .hourAndMinute]) }
                    HStack {
                        Button("Save opportunity locally") { model.createOpportunity() }
                            .accessibilityIdentifier("save-opportunity")
                            .keyboardShortcut(.defaultAction)
                            .disabled(model.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.company.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Button("Cancel", action: cancel)
                            .accessibilityIdentifier("cancel-add-opportunity")
                            .keyboardShortcut(.cancelAction)
                        if let error = model.addOpportunitySaveError {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .accessibilityIdentifier("add-opportunity-save-error")
                        }
                    }
                }
            }.padding(28).frame(maxWidth: 860, alignment: .leading)
        }
    }
}

private struct CSVImportView: View {
    @ObservedObject var model: WorkspaceViewModel; let chooseFile: () -> Void; let open: (Opportunity) -> Void; let finish: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Import CSV").font(.largeTitle.bold())
                Text("Choose a file, map its columns, review exceptions, then import it locally.")
                    .foregroundStyle(.secondary)
                if let preview = model.csvPreview {
                    if model.csvImportPlan.isEmpty {
                        GroupBox("1. Map columns") {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Map Job title and Company to different source columns. Other fields are optional.")
                                    .font(.caption).foregroundStyle(.secondary)
                                ForEach(CSVImportField.allCases) { field in
                                    Picker(field.label + (field.required ? " *" : ""), selection: Binding(
                                        get: { preview.mapping[field] },
                                        set: { model.setCSVMapping(field, to: $0) }
                                    )) {
                                        Text("Not mapped").tag(Int?.none)
                                        ForEach(Array(preview.headers.enumerated()), id: \.offset) { index, header in
                                            Text(header).tag(Int?.some(index))
                                        }
                                    }
                                }
                                HStack {
                                    Button("Cancel") { model.cancelCSVPreview(); finish() }
                                    Spacer()
                                    Button("Validate mapped rows") { model.validateCSVMapping() }
                                        .buttonStyle(RekonPrimaryButtonStyle())
                                        .disabled(!CSVOpportunityImporter.mappingIsValid(preview.mapping))
                                }
                            }
                        }
                    } else {
                        GroupBox("2. Review rows and duplicates") {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Review only exceptions before committing the mapped rows to this local workspace.")
                                    .font(.caption).foregroundStyle(.secondary)
                                ForEach(model.csvImportPlan) { row in
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text([row.row.opportunity?.title ?? row.row.values[.title] ?? "Untitled", row.row.opportunity?.company ?? row.row.values[.company] ?? "Unknown employer"].joined(separator: " · "))
                                        if row.isDuplicate {
                                            Text("Possible duplicate: \(row.candidateTitle ?? "existing opportunity") · \(row.candidateCompany ?? "")")
                                                .font(.caption).foregroundStyle(.secondary)
                                            Picker("Duplicate decision", selection: Binding(
                                                get: { row.decision },
                                                set: { value in if let value { model.setCSVDecision(value, for: row.id) } }
                                            )) {
                                                Text("Choose a decision").tag(CSVDuplicateDecision?.none)
                                                Text("Update selected fields").tag(CSVDuplicateDecision?.some(.updateSelectedFields))
                                                Text("Keep as separate opportunity").tag(CSVDuplicateDecision?.some(.keepSeparate))
                                                Text("Skip this row").tag(CSVDuplicateDecision?.some(.skip))
                                            }
                                        }
                                    }
                                    Divider()
                                }
                                HStack {
                                    Button("Back to mapping") { model.returnToCSVMapping() }
                                    Button("Cancel") { model.cancelCSVPreview(); finish() }
                                    Spacer()
                                    Button("Import reviewed rows") { model.importCSVPreview() }
                                        .buttonStyle(RekonPrimaryButtonStyle())
                                        .disabled(model.csvImportPlan.contains { $0.decision == nil || ($0.decision == .updateSelectedFields && $0.selectedFields.isEmpty) })
                                        .accessibilityIdentifier("import-reviewed-csv")
                                }
                            }
                        }
                    }
                } else if let report = model.csvImportReport {
                    CSVImportCompletionView(report: report, rows: model.csvImportReportRows, startOver: chooseFile, done: finish)
                } else {
                    GroupBox("1. Choose CSV file") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Rekon Pursuit reads a UTF-8 CSV locally. Nothing is imported until you review and confirm it.")
                                .foregroundStyle(.secondary)
                            Button("Choose CSV file…", action: chooseFile)
                                .buttonStyle(RekonPrimaryButtonStyle())
                                .accessibilityIdentifier("choose-csv-file")
                        }
                    }
                }
            }
            .padding(28).frame(maxWidth: 960, alignment: .leading)
        }
    }
}

private struct CSVImportCompletionView: View {
    let report: CSVImportReport
    let rows: [CSVImportReportRow]
    let startOver: () -> Void
    let done: () -> Void

    private var exceptions: [CSVImportReportRow] { rows.filter { $0.outcome != "created" } }

    var body: some View {
        GroupBox("3. Import complete") {
            VStack(alignment: .leading, spacing: 12) {
                Text("\(report.sourceBasename) imported locally.").font(.headline)
                Text("Created \(report.importedCount) · Updated \(report.updatedCount) · Kept separate \(report.duplicateKeptCount) · Skipped \(report.skippedCount) · Invalid \(report.invalidCount) · Failed \(report.failedCount)")
                    .foregroundStyle(.secondary)
                HStack {
                    Button("View imported opportunities in Pipeline", action: done)
                        .buttonStyle(RekonPrimaryButtonStyle())
                    Button("Start another import", action: startOver)
                    Spacer()
                    Button("Done", action: done)
                }
                if !exceptions.isEmpty {
                    DisclosureGroup("View detailed report (\(exceptions.count) exceptions)") {
                        ForEach(exceptions) { row in
                            VStack(alignment: .leading, spacing: 4) {
                                Text([row.title.isEmpty ? "Untitled" : row.title, row.company.isEmpty ? "Unknown employer" : row.company].joined(separator: " · "))
                                Text("\(row.outcome.capitalized)\(row.reason.isEmpty ? "" : ": \(row.reason)")")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
    }
}

private struct ContactsView: View {
    @ObservedObject var model: WorkspaceViewModel; let open: (Opportunity) -> Void; let delete: (Contact) -> Void
    @State private var relationshipContextExpanded = false
    @State private var notesExpanded = false
    @State private var showsOpportunityRelationships = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Contacts").font(.largeTitle.bold())
                GroupBox("Contacts") {
                    VStack(alignment: .leading) {
                        HStack {
                            TextField("Search contacts", text: $model.contactSearch).accessibilityIdentifier("contact-search")
                            Picker("Employer", selection: $model.contactEmployerFilter) {
                                Text("All employers").tag("All employers")
                                ForEach(model.contactEmployers, id: \.self) { Text($0).tag($0) }
                            }
                        }
                        ForEach(model.filteredContacts, id: \.id) { contact in
                            HStack {
                                Button { model.selectContact(contact) } label: {
                                    VStack(alignment: .leading) {
                                        Text(contact.name)
                                        Text([contact.title, contact.employer].filter { !$0.isEmpty }.joined(separator: " · "))
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }.buttonStyle(.plain)
                                Spacer()
                                Button("Delete", role: .destructive) { delete(contact) }
                            }
                        }
                    }
                }
                GroupBox(model.selectedContact == nil ? "New contact" : "Contact record") {
                    Form {
                        TextField("Name", text: $model.contactName).accessibilityIdentifier("contact-name")
                        if model.isAddingNewContactEmployer {
                            TextField("New employer (optional)", text: $model.contactEmployer)
                            Button("Choose tracked employer") { model.chooseTrackedContactEmployer() }
                        } else {
                            TextField("Search tracked employers", text: $model.contactEmployerSearch)
                                .accessibilityIdentifier("contact-employer-search")
                            if !model.contactEmployer.isEmpty {
                                HStack {
                                    Text("Employer: \(model.contactEmployer)").foregroundStyle(.secondary)
                                    Button("Clear") { model.chooseTrackedContactEmployer() }
                                }
                            }
                            if !model.contactEmployerSearch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                VStack(alignment: .leading, spacing: 0) {
                                    ForEach(model.filteredContactEmployerSuggestions, id: \.self) { employer in
                                        Button {
                                            model.selectContactEmployer(employer)
                                        } label: {
                                            Text(employer)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.vertical, 6)
                                                .padding(.horizontal, 8)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    if let candidate = model.contactEmployerAddCandidate {
                                        if !model.filteredContactEmployerSuggestions.isEmpty { Divider() }
                                        Button {
                                            model.beginNewContactEmployer(named: candidate)
                                        } label: {
                                            Text("Add \(candidate) as new employer")
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.vertical, 6)
                                                .padding(.horizontal, 8)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .background(Color.primary.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                        TextField("Title (optional)", text: $model.contactTitle)
                        TextField("Email (optional)", text: $model.contactEmail)
                        if let warning = model.contactEmailWarning { Text(warning).font(.caption).foregroundStyle(.orange) }
                        TextField("Profile URL (optional)", text: $model.contactProfileURL)
                        if let warning = model.contactProfileURLWarning { Text(warning).font(.caption).foregroundStyle(.orange) }
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Relationship context (optional)").font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                Button(relationshipContextExpanded ? "Collapse" : "Expand") { relationshipContextExpanded.toggle() }
                            }
                            TextEditor(text: $model.contactRelationshipContext)
                                .frame(minHeight: relationshipContextExpanded ? 120 : 48, maxHeight: relationshipContextExpanded ? 180 : 48)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Notes (optional)").font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                Button(notesExpanded ? "Collapse" : "Expand") { notesExpanded.toggle() }
                            }
                            TextEditor(text: $model.contactNotes)
                                .frame(minHeight: notesExpanded ? 120 : 48, maxHeight: notesExpanded ? 180 : 48)
                        }
                        HStack {
                            Button("New contact") { model.beginNewContact() }
                            Spacer()
                            Button(model.selectedContact == nil ? "Save contact locally" : "Save changes locally") {
                                if model.selectedContact == nil { model.createContact() } else { model.saveSelectedContact() }
                            }
                            .disabled(model.contactName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityIdentifier("save-contact")
                            if let error = model.contactSaveError {
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                                    .accessibilityIdentifier("contact-save-error")
                            }
                        }
                    }
                }
                if model.selectedContact != nil {
                    Button("Manage linked opportunities (\(model.selectedContactOpportunities.count))") {
                        showsOpportunityRelationships = true
                    }
                    .accessibilityIdentifier("manage-contact-opportunities")
                }
            }
            .padding(28).frame(maxWidth: 920, alignment: .leading)
        }
        .sheet(isPresented: $showsOpportunityRelationships) {
            ContactOpportunityManagementSheet(model: model, open: open)
        }
    }
}

private struct ContactOpportunityManagementSheet: View {
    @ObservedObject var model: WorkspaceViewModel
    let open: (Opportunity) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Linked opportunities").font(.title2.bold())
            if model.selectedContactOpportunities.isEmpty {
                Text("This contact is not linked to an opportunity yet.").foregroundStyle(.secondary)
            } else {
                ForEach(model.selectedContactOpportunities, id: \.id) { opportunity in
                    HStack {
                        Button("\(opportunity.title) · \(opportunity.company)") { open(opportunity) }
                        Spacer()
                        Button("Unlink") { model.unlinkSelectedContact(from: opportunity) }
                    }
                }
            }

            if !model.contactEmployer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !model.selectedContactUnlinkedEmployerOpportunities.isEmpty {
                Divider()
                Text("Other opportunities at \(model.contactEmployer)").font(.headline)
                Text("Link only the opportunities this person is connected to.")
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(model.selectedContactUnlinkedEmployerOpportunities, id: \.id) { opportunity in
                    HStack {
                        Button("\(opportunity.title) · \(opportunity.company)") { open(opportunity) }
                        Spacer()
                        Button("Link") { model.linkSelectedContact(to: opportunity) }
                    }
                }
            }

            HStack {
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 560)
    }
}

private struct GlobalActivityView: View {
    @ObservedObject var model: WorkspaceViewModel
    @State private var aiLedgerFilter = AIUsageLedgerFilter()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Activity & AI")
                    .font(.largeTitle.bold())

                GroupBox("Local activity ledger") {
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("Search activity", text: $model.activitySearch)
                            .accessibilityIdentifier("activity-search")
                        if model.filteredActivityEvents.isEmpty {
                            Text(model.activityEvents.isEmpty ? "No local activity yet." : "No activity matches that search.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(model.filteredActivityEvents, id: \.id) { event in
                                Text("\(event.kind.replacingOccurrences(of: "_", with: " ").capitalized) · \(event.occurredAt.formatted(date: .abbreviated, time: .shortened))")
                            }
                        }
                    }
                }

                GroupBox("AI usage ledger") {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("No AI requests have run. Local and cloud AI execution, model activity, and cost calculation are unavailable in this MVP.")
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("ai-ledger-empty-state")

                        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                            GridRow {
                                Picker("Time", selection: $aiLedgerFilter.time) {
                                    ForEach(AIUsageLedgerFilter.Time.allCases, id: \.self) { time in
                                        Text(time.label).tag(time)
                                    }
                                }
                                .accessibilityIdentifier("ai-ledger-time-filter")

                                TextField("Feature", text: $aiLedgerFilter.featureQuery)
                                    .accessibilityIdentifier("ai-ledger-feature-filter")
                            }
                            GridRow {
                                Picker("Opportunity", selection: $aiLedgerFilter.opportunityID) {
                                    Text("All opportunities").tag(nil as String?)
                                    ForEach(model.opportunities, id: \.id) { opportunity in
                                        Text("\(opportunity.title) · \(opportunity.company)").tag(Optional(opportunity.id))
                                    }
                                }
                                .accessibilityIdentifier("ai-ledger-opportunity-filter")

                                Picker("Route", selection: $aiLedgerFilter.route) {
                                    ForEach(AIUsageLedgerFilter.Route.allCases, id: \.self) { route in
                                        Text(route.label).tag(route)
                                    }
                                }
                                .accessibilityIdentifier("ai-ledger-route-filter")
                            }
                            GridRow {
                                TextField("Model", text: $aiLedgerFilter.modelQuery)
                                    .accessibilityIdentifier("ai-ledger-model-filter")

                                Picker("Completion", selection: $aiLedgerFilter.completion) {
                                    ForEach(AIUsageLedgerFilter.Completion.allCases, id: \.self) { completion in
                                        Text(completion.label).tag(completion)
                                    }
                                }
                                .accessibilityIdentifier("ai-ledger-completion-filter")
                            }
                            GridRow {
                                TextField("Minimum cost (USD)", text: $aiLedgerFilter.minimumCostUSD)
                                    .accessibilityIdentifier("ai-ledger-min-cost-filter")
                                TextField("Maximum cost (USD)", text: $aiLedgerFilter.maximumCostUSD)
                                    .accessibilityIdentifier("ai-ledger-max-cost-filter")
                            }
                        }

                        if let validationMessage = aiLedgerFilter.costRangeValidationMessage {
                            Text(validationMessage)
                                .foregroundStyle(.red)
                        } else if !aiLedgerFilter.isDefault {
                            Text("Zero entries match the current filters.")
                                .foregroundStyle(.secondary)
                        }

                        Button("Clear filters") {
                            aiLedgerFilter.reset()
                        }
                        .disabled(aiLedgerFilter.isDefault)
                        .accessibilityIdentifier("ai-ledger-clear-filters")
                    }
                    .frame(maxWidth: 760, alignment: .leading)
                }
            }
            .padding(28)
            .frame(maxWidth: 920, alignment: .leading)
        }
    }
}

private struct SettingsView: View {
    @ObservedObject var model: WorkspaceViewModel
    @State private var generatedRecoveryKey: RecoveryKey?
    @State private var reentry = ""
    @State private var recoveryKeyCopied = false
    @State private var archiveRecoveryReentry = ""
    @State private var isPresentingArchiveCreation = false
    @State private var protectedExportReentry = ""
    @State private var isPresentingProtectedExport = false
    @State private var retainedDataPurgeReentry = ""
    @State private var isPresentingRetainedDataPurge = false
    @State private var portableArchiveRestoreKey = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Settings").font(.largeTitle.bold())
                GroupBox("Workspace") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Workspace data stays on this Mac and is retained until you delete it. Deleted records leave the active workspace immediately; earlier encrypted archives may retain them until their displayed expiry.")
                            .foregroundStyle(.secondary)
                        if model.usingSeparateLocalWorkspace {
                            Text("You are using a separate local workspace. Your preserved workspace remains unchanged.").foregroundStyle(.secondary)
                            Button("Return to preserved workspace recovery") { model.returnToPreservedWorkspaceRecovery() }.accessibilityIdentifier("return-to-preserved-workspace-recovery")
                        }
                    }
                }
                GroupBox("Recovery & archives") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(model.recoveryEnrollmentEnabled ? (model.portableArchiveCatalogue.isEmpty ? "Portable recovery is set up. No portable archive exists yet." : "Portable recovery is set up. Archive expiry is checked when this workspace opens or becomes active; it is not a background service.") : "Portable recovery is not set up. No portable archive exists.")
                            .foregroundStyle(.secondary)
                        if !model.recoveryEnrollmentEnabled {
                            Button("Set up recovery key") {
                                generatedRecoveryKey = try? RecoveryKey.generate()
                                recoveryKeyCopied = false
                            }
                                .accessibilityIdentifier("set-up-recovery-key")
                        } else {
                            Button("Create recovery archive") { isPresentingArchiveCreation = true }
                                .accessibilityIdentifier("create-portable-archive")
                                .disabled(model.isCreatingPortableArchive || model.isRestoringPortableArchive)
                            Button("Export protected copy") { isPresentingProtectedExport = true }
                                .accessibilityIdentifier("create-protected-export")
                                .disabled(model.isCreatingProtectedExport || model.isCreatingPortableArchive || model.isRestoringPortableArchive)
                            Button("Purge deleted data from retained archives") { isPresentingRetainedDataPurge = true }
                                .buttonStyle(RekonSecondaryButtonStyle())
                                .accessibilityIdentifier("purge-retained-archive-data")
                                .disabled(model.portableArchiveCatalogue.isEmpty || model.isPurgingRetainedArchiveData || model.isCreatingPortableArchive || model.isRestoringPortableArchive)
                            if model.isPurgingRetainedArchiveData {
                                ProgressView("Purging retained archive data…")
                                    .controlSize(.small)
                                Button("Cancel purge") { model.cancelRetainedDataPurge() }
                                    .buttonStyle(RekonSecondaryButtonStyle())
                            }
                            if let status = model.retainedDataPurgeStatus {
                                Text(retainedDataPurgeStatusText(status))
                                    .font(.footnote)
                                    .foregroundStyle(status.state == .complete ? Color.secondary : Color.orange)
                            }
                            if model.isCreatingProtectedExport {
                                ProgressView("Preparing protected export…").controlSize(.small)
                            }
                            if model.isCreatingPortableArchive {
                                ProgressView("Creating and verifying archive…")
                                    .controlSize(.small)
                                    .accessibilityIdentifier("portable-archive-progress")
                            }
                            if model.portableArchiveCatalogue.isEmpty {
                                Text("No portable archive exists yet.").font(.footnote).foregroundStyle(.secondary)
                            } else {
                                ForEach(model.portableArchiveCatalogue, id: \.archiveID) { archive in
                                    Text(archiveSummary(archive))
                                        .font(.footnote).foregroundStyle(.secondary)
                                }
                            }
                        }
                        Divider()
                        Text("Restore a portable archive creates an inactive local candidate. It does not replace or open your current workspace.")
                            .font(.footnote).foregroundStyle(.secondary)
                        Button("Restore portable archive") { model.choosePortableArchiveForRestore() }
                            .buttonStyle(RekonSecondaryButtonStyle())
                            .accessibilityIdentifier("restore-portable-archive")
                            .disabled(model.isCreatingPortableArchive || model.isRestoringPortableArchive)
                        if model.isRestoringPortableArchive {
                            ProgressView(model.portableArchiveRestoreState == .verifying ? "Verifying portable archive…" : "Restore in progress…")
                                .controlSize(.small)
                        }
                        if case .ready = model.portableArchiveRestoreState {
                            Text("Restored workspace ready. It remains inactive; a future workspace-open action is required.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
                GroupBox("Document references") {
                    Text(documentReferenceSummaryText)
                        .foregroundStyle(.secondary)
                }
                GroupBox("AI and connections") {
                    Text("The local Activity & AI ledger is read-only and empty in this MVP. No AI requests, costs, model runtime, cloud connection, Gmail, or Calendar integration is configured.")
                        .foregroundStyle(.secondary)
                }
            }.padding(28).frame(maxWidth: 920, alignment: .leading)
        }
        .sheet(isPresented: Binding(get: { generatedRecoveryKey != nil }, set: { if !$0 { generatedRecoveryKey = nil; reentry = ""; recoveryKeyCopied = false } })) {
            if let generatedRecoveryKey {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Record your recovery key").font(.title2.bold())
                    Text("Rekon Pursuit cannot reset or recover this key. Record it outside the app; it will not be shown again.").foregroundStyle(.secondary)
                    Text(generatedRecoveryKey.displayValue).font(.system(.body, design: .monospaced)).textSelection(.disabled)
                    VStack(alignment: .leading, spacing: 6) {
                        Button("Copy recovery key") {
                            let pasteboard = NSPasteboard.general
                            pasteboard.clearContents()
                            recoveryKeyCopied = pasteboard.setString(generatedRecoveryKey.displayValue, forType: .string)
                        }
                        .accessibilityIdentifier("copy-recovery-key")
                        Text("Clipboard history and other apps may retain this recovery key.").font(.footnote).foregroundStyle(.secondary)
                        if recoveryKeyCopied {
                            Text("Recovery key copied to the clipboard.").font(.footnote).foregroundStyle(.secondary)
                                .accessibilityIdentifier("recovery-key-copied-confirmation")
                        }
                    }
                    TextField("Re-enter the complete recovery key", text: $reentry).textFieldStyle(.roundedBorder)
                    HStack {
                        Button("Cancel", role: .cancel) { self.generatedRecoveryKey = nil; reentry = ""; recoveryKeyCopied = false }
                        Spacer()
                        Button("Confirm setup") {
                            if model.enrollRecoveryKey(reentry: reentry, expected: generatedRecoveryKey) { self.generatedRecoveryKey = nil; reentry = ""; recoveryKeyCopied = false }
                        }.keyboardShortcut(.defaultAction)
                    }
                }.padding(24).frame(width: 520)
            }
        }
        .sheet(isPresented: $isPresentingArchiveCreation) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Create portable recovery archive").font(.title2.bold())
                Text("Re-enter your recovery key. The archive will be encrypted, verified, and retained in this workspace for its 30-day recovery window.").foregroundStyle(.secondary)
                TextField("Re-enter the complete recovery key", text: $archiveRecoveryReentry).textFieldStyle(.roundedBorder)
                HStack {
                    Button("Cancel", role: .cancel) { isPresentingArchiveCreation = false; archiveRecoveryReentry = "" }
                    Spacer()
                    Button("Create recovery archive") { model.createPortableArchive(reentry: archiveRecoveryReentry); isPresentingArchiveCreation = false; archiveRecoveryReentry = "" }
                        .disabled(model.isCreatingPortableArchive)
                        .keyboardShortcut(.defaultAction)
                }
            }.padding(24).frame(width: 520)
        }
        .sheet(isPresented: $isPresentingProtectedExport) {
            VStack(alignment: .leading, spacing: 16) {
                if let message = model.protectedExportErrorMessage {
                    Text(message)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("protected-export-error")
                }
                if let review = model.protectedExportReview {
                    Text("Confirm protected export").font(.title2.bold())
                    Text("A new encrypted .rekonexport file will be created. It contains your active tracker data only; document file access is excluded and requires relinking.").foregroundStyle(.secondary)
                    LabeledContent("Filename", value: review.displayFilename)
                    LabeledContent("Destination", value: "Selected local folder")
                    LabeledContent("Data", value: "Active tracker workspace data")
                    Text("Re-enter the recovery key to confirm.").font(.footnote).foregroundStyle(.secondary)
                    TextField("Recovery key", text: $protectedExportReentry).textFieldStyle(.roundedBorder)
                    HStack {
                        Button("Cancel", role: .cancel) { model.cancelProtectedExport(); isPresentingProtectedExport = false; protectedExportReentry = "" }
                        Spacer()
                        Button("Confirm and export") { model.confirmProtectedExport(reentry: protectedExportReentry); protectedExportReentry = "" }
                            .disabled(model.isCreatingProtectedExport)
                            .keyboardShortcut(.defaultAction)
                    }
                } else {
                    Text("Export protected copy").font(.title2.bold())
                    Text("Choose a destination, then review the encrypted export before it is written. Your recovery key is used only for this action.").foregroundStyle(.secondary)
                    TextField("Recovery key", text: $protectedExportReentry).textFieldStyle(.roundedBorder)
                    HStack {
                        Button("Cancel", role: .cancel) { model.cancelProtectedExport(); isPresentingProtectedExport = false; protectedExportReentry = "" }
                        Spacer()
                        Button("Choose destination and review") { model.reviewProtectedExport(reentry: protectedExportReentry) }
                            .disabled(model.isCreatingProtectedExport)
                            .keyboardShortcut(.defaultAction)
                    }
                }
            }.padding(24).frame(width: 540)
                .onChange(of: model.protectedExportReview) { _, review in
                    if review != nil { protectedExportReentry = "" }
                }
        }
        .sheet(isPresented: $isPresentingRetainedDataPurge) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Purge deleted data from retained archives").font(.title2.bold())
                Text("This permanently removes data that you already deleted from eligible, verified Rekon Pursuit recovery archives. It cannot be undone. External archives and expired archives are not changed.")
                    .foregroundStyle(.secondary)
                Text("Re-enter your recovery key to confirm. Rekon Pursuit creates and verifies a replacement before it removes an eligible predecessor archive.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                TextField("Recovery key", text: $retainedDataPurgeReentry)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button("Cancel", role: .cancel) {
                        retainedDataPurgeReentry = ""
                        isPresentingRetainedDataPurge = false
                    }
                    Spacer()
                    Button("Purge retained archive data", role: .destructive) {
                        model.purgeRetainedArchiveData(reentry: retainedDataPurgeReentry)
                        retainedDataPurgeReentry = ""
                        isPresentingRetainedDataPurge = false
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(24)
            .frame(width: 560)
        }
        .sheet(isPresented: Binding(
            get: {
                switch model.portableArchiveRestoreState {
                case .awaitingRecoveryKey, .verifying, .awaitingConfirmation, .restoring: true
                case .idle, .ready, .failed: false
                }
            },
            set: { if !$0 { portableArchiveRestoreKey = ""; model.cancelPortableArchiveRestore() } }
        )) {
            VStack(alignment: .leading, spacing: 16) {
                switch model.portableArchiveRestoreState {
                case .awaitingRecoveryKey:
                    Text("Restore portable archive").font(.title2.bold())
                    Text("Enter the recovery key to verify the archive. The key is used only for this restore attempt.")
                        .foregroundStyle(.secondary)
                    TextField("Recovery key", text: $portableArchiveRestoreKey)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Button("Cancel", role: .cancel) { portableArchiveRestoreKey = ""; model.cancelPortableArchiveRestore() }
                        Spacer()
                        Button("Verify archive") {
                            model.verifyPortableArchiveForRestore(portableArchiveRestoreKey)
                            portableArchiveRestoreKey = ""
                        }
                        .keyboardShortcut(.defaultAction)
                    }
                case .verifying:
                    ProgressView("Verifying portable archive…")
                    Button("Cancel", role: .cancel) { model.cancelPortableArchiveRestore() }
                case let .awaitingConfirmation(archive):
                    Text("Confirm restore").font(.title2.bold())
                    Text("The archive has been verified. Review its identity before creating an inactive restored workspace.")
                        .foregroundStyle(.secondary)
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                        GridRow { Text("Archive ID").foregroundStyle(.secondary); Text(archive.archiveID.uuidString) }
                        GridRow { Text("Created").foregroundStyle(.secondary); Text(archive.createdAt.formatted(date: .abbreviated, time: .shortened)) }
                        GridRow { Text("Signing fingerprint").foregroundStyle(.secondary); Text(archive.signingKeyFingerprint.map { String(format: "%02x", $0) }.joined()) }
                    }.font(.footnote.monospaced())
                    HStack {
                        Button("Cancel", role: .cancel) { model.cancelPortableArchiveRestore() }
                        Spacer()
                        Button("Confirm restore") { model.confirmPortableArchiveRestore() }
                            .keyboardShortcut(.defaultAction)
                    }
                case .restoring:
                    ProgressView("Creating inactive restored workspace…")
                case .idle, .ready, .failed:
                    EmptyView()
                }
            }
            .padding(24)
            .frame(width: 560)
        }
        .alert("Portable archive restore", isPresented: Binding(
            get: {
                if case .failed = model.portableArchiveRestoreState { return true }
                return false
            },
            set: { if !$0 { model.dismissPortableArchiveRestoreFailure() } }
        )) {
            Button("Choose another archive") {
                model.dismissPortableArchiveRestoreFailure()
                model.choosePortableArchiveForRestore()
            }
            Button("Dismiss", role: .cancel) { model.dismissPortableArchiveRestoreFailure() }
        } message: {
            if case let .failed(failure) = model.portableArchiveRestoreState {
                Text(failure.message)
            }
        }
    }

    private var documentReferenceSummaryText: String {
        let summary = model.documentReferenceSummary
        if summary.availableCount == 0, summary.relinkRequiredCount == 0 {
            return "No document references are attached to active opportunities."
        }
        return "\(summary.availableCount) available · \(summary.relinkRequiredCount) require relinking"
    }

    private func retainedDataPurgeStatusText(_ status: RetainedDataPurgeStatus) -> String {
        switch status.state {
        case .complete:
            return "Deleted retained data purge completed \(status.finishedAt?.formatted(date: .abbreviated, time: .shortened) ?? "")."
        case .cancelled:
            return "The last retained-data purge was cancelled; any unfinished source archives were preserved."
        case .incomplete, .blocked:
            return "The last retained-data purge was incomplete. Review retained archives before retrying."
        case .running:
            return "A prior retained-data purge was interrupted and marked incomplete. It did not resume automatically."
        }
    }

    private func archiveSummary(_ archive: PortableArchiveCatalogueRow) -> String {
        let lifecycle: String
        switch archive.lifecycleState {
        case .verified:
            lifecycle = archive.verificationState
        case .expiredPendingRemoval, .expiredPrepared:
            lifecycle = "Expired — removal pending"
        case .expiredRetryable:
            lifecycle = "Expired — retry pending"
        case .expiredBlocked:
            lifecycle = "Expired — removal blocked"
        case .expiredMissing:
            lifecycle = "Expired — file unavailable"
        case .expiredManualRemovalRequired:
            lifecycle = "Expired — manual removal required"
        case .expiredQuarantined:
            lifecycle = "Expired — quarantined"
        }
        return "\(archive.displayFilename) · created \(archive.createdAt.formatted(date: .abbreviated, time: .shortened)) · expires \(archive.expiresAt.formatted(date: .abbreviated, time: .omitted)) · \(lifecycle)"
    }
}
