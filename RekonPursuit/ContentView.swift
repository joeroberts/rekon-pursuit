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
    @StateObject private var model = WorkspaceViewModel()
    @State private var navigation = DailyNavigationState()
    @State private var opportunityRoute: OpportunityRoute?
    @State private var showsPipelineBoard = false
    @State private var pipelineAnchorID: String?
    @State private var pendingDeletion: Opportunity?
    @State private var pendingContactDeletion: Contact?
    @State private var taskToReschedule: TaskReminder?
    @State private var rescheduledDueAt = Date.now
    @State private var showsDocumentReferenceImporter = false
    @State private var showsBackupImporter = false
    @State private var pendingRestoreURL: URL?
    @State private var showsUnencryptedExportWarning = false
    @State private var showsCSVExporter = false
    @State private var exportDocument: CSVExportDocument?
    @State private var closureConfirmationID: String?

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
        .fileImporter(isPresented: $showsBackupImporter, allowedContentTypes: [.data], allowsMultipleSelection: false) { result in
            if case let .success(urls) = result, let url = urls.first { pendingRestoreURL = model.stageEncryptedBackupForRestore(from: url) }
        }
        .fileImporter(isPresented: $showsDocumentReferenceImporter, allowedContentTypes: [.pdf, UTType(filenameExtension: "docx") ?? .data], allowsMultipleSelection: false) { result in
            if case let .success(urls) = result, let url = urls.first { model.attachDocumentReference(at: url) }
        }
        .fileExporter(isPresented: $showsCSVExporter, document: exportDocument, contentType: .commaSeparatedText, defaultFilename: "rekon-pursuit-opportunities") { result in
            if case .success = result { model.noteExportSaved() }
            exportDocument = nil
        }
        .alert("Export unencrypted CSV?", isPresented: $showsUnencryptedExportWarning) {
            Button("Export unencrypted CSV") {
                if let csv = model.exportOpportunitiesCSV() { exportDocument = CSVExportDocument(text: csv); showsCSVExporter = true }
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This file will contain your job titles, companies, actions, dates, and job URLs in plain text. Save it only to storage you trust.") }
        .alert("Replace current workspace?", isPresented: Binding(
            get: { pendingRestoreURL != nil }, set: { if !$0 { pendingRestoreURL = nil; model.discardStagedBackupRestore() } }
        )) {
            Button("Restore and replace", role: .destructive) {
                if let pendingRestoreURL { model.restoreEncryptedBackup(from: pendingRestoreURL) }
                pendingRestoreURL = nil
            }
            Button("Cancel", role: .cancel) { pendingRestoreURL = nil; model.discardStagedBackupRestore() }
        } message: { Text("This replaces the current local workspace with the selected same-Mac encrypted backup. Your current workspace is kept if the restore fails.") }
    }

    @ViewBuilder private var dailyDestination: some View {
        switch navigation.route {
        case .home: HomeView(model: model, open: openAttentionTask, addOpportunity: { navigation.handle(.homeEmptyStateAdd) }, reschedule: { task in taskToReschedule = task; rescheduledDueAt = task.dueAt ?? .now })
        case .pipeline: PipelineView(model: model, showsBoard: $showsPipelineBoard, anchorID: $pipelineAnchorID, open: openOpportunity, delete: { pendingDeletion = $0 }, addOpportunity: { navigation.handle(.pipelineAdd) }, importCSV: { navigation.handle(.pipelineImport) })
        case .addOpportunity: AddOpportunityView(model: model)
        case .importCSV: CSVImportView(model: model, chooseFile: chooseCSVFile, open: openOpportunity, finish: { navigation.select(.pipeline) })
        case .contacts: ContactsView(model: model, open: openOpportunity, delete: { pendingContactDeletion = $0 })
        case .activityAI: GlobalActivityView(model: model)
        case .settings: SettingsView(model: model, export: { showsUnencryptedExportWarning = true }, backup: createBackup, restore: { showsBackupImporter = true })
        }
    }

    @ViewBuilder private func routedOpportunityView(_ route: OpportunityRoute) -> some View {
        switch route {
        case let .overview(id):
            OpportunityOverviewView(model: model, opportunityID: id, back: returnToPipeline, showHistory: { openRoute(.history(id)) }, showReconcile: { openRoute(.reconcile(id)) }, chooseDocument: { showsDocumentReferenceImporter = true })
        case let .history(id):
            OpportunityHistoryView(model: model, opportunityID: id, back: { returnFromOpportunitySubroute(.history(id)) })
        case let .reconcile(id):
            ReconcilePostingView(model: model, opportunityID: id, back: { returnFromOpportunitySubroute(.reconcile(id)) }, confirmClosure: { closureConfirmationID = id })
        }
    }

    private func openOpportunity(_ opportunity: Opportunity) {
        pipelineAnchorID = opportunity.id
        openRoute(.overview(opportunity.id))
    }

    private func openAttentionTask(_ task: TaskReminder) {
        guard model.navigateToRouteOpportunity(id: task.opportunityID) else { return }
        guard model.open(task) else { return }
        pipelineAnchorID = task.opportunityID
        opportunityRoute = .overview(task.opportunityID)
        navigation.select(.pipeline)
    }

    private func openRoute(_ route: OpportunityRoute) {
        guard model.navigateToRouteOpportunity(id: route.opportunityID) else { return }
        opportunityRoute = route
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
            navigation.select(destination)
            return
        }
        guard model.canLeaveOpportunityRoute() else { return }
        opportunityRoute = nil
        navigation.select(destination)
    }

    private func returnToPipeline() {
        guard model.canLeaveOpportunityRoute() else { return }
        opportunityRoute = nil
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

    private func createBackup() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "rekon-pursuit-backup.rekonbackup"
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url { model.createEncryptedBackup(at: url) }
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

private struct PipelineView: View {
    @ObservedObject var model: WorkspaceViewModel
    @Binding var showsBoard: Bool
    @Binding var anchorID: String?
    let open: (Opportunity) -> Void
    let delete: (Opportunity) -> Void
    let addOpportunity: () -> Void
    let importCSV: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Pipeline").font(.largeTitle.bold())
                Spacer()
                Button("Import CSV", action: importCSV)
                    .buttonStyle(RekonSecondaryButtonStyle())
                    .accessibilityIdentifier("pipeline-import-csv")
                Button("Add opportunity", action: addOpportunity)
                    .buttonStyle(RekonPrimaryButtonStyle())
                    .accessibilityIdentifier("pipeline-add-opportunity")
            }
            HStack {
                TextField("Search opportunities", text: $model.opportunitySearch).accessibilityIdentifier("opportunity-search")
                Picker("Stage", selection: $model.stageFilter) {
                    Text("All stages").tag("All stages")
                    ForEach(PipelineStage.allCases, id: \.self) { Text($0.rawValue).tag($0.rawValue) }
                }
                .frame(width: 170)
                Picker("View", selection: $showsBoard) { Text("Table").tag(false); Text("Board").tag(true) }.pickerStyle(.segmented).frame(width: 145)
            }
            if model.filteredOpportunities.isEmpty {
                FlexibleCenteredContent {
                    ContentUnavailableView("No opportunities match", systemImage: "briefcase", description: Text("Try another search or add an opportunity."))
                    Button("Add opportunity", action: addOpportunity)
                        .buttonStyle(RekonPrimaryButtonStyle())
                }
            } else if showsBoard {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal) {
                        HStack(alignment: .top, spacing: 14) {
                            ForEach(PipelineStage.allCases, id: \.self) { stage in
                                ScrollViewReader { laneProxy in
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(stage.rawValue).font(.headline)
                                        ScrollView {
                                            ForEach(model.filteredOpportunities.filter { $0.stage == stage }, id: \.id) { opportunity in
                                                OpportunityCard(opportunity: opportunity) { anchorID = opportunity.id; open(opportunity) }
                                                    .id(opportunity.id)
                                            }
                                        }
                                    }
                                    .onAppear {
                                        guard let anchorID, let opportunity = model.opportunity(id: anchorID), opportunity.stage == stage else { return }
                                        laneProxy.scrollTo(anchorID, anchor: .center)
                                    }
                                    .onChange(of: anchorID) { _, id in
                                        guard let id, let opportunity = model.opportunity(id: id), opportunity.stage == stage else { return }
                                        laneProxy.scrollTo(id, anchor: .center)
                                    }
                                }
                                .id(stage)
                                .frame(width: 210, alignment: .leading)
                            }
                        }.padding(.bottom, 4)
                    }
                    .onAppear {
                        guard let anchorID, let opportunity = model.opportunity(id: anchorID) else { return }
                        proxy.scrollTo(opportunity.stage, anchor: .center)
                    }
                }
            } else {
                ScrollViewReader { proxy in
                    List {
                        ForEach(model.filteredOpportunities, id: \.id) { opportunity in
                            HStack {
                                Button { anchorID = opportunity.id; open(opportunity) } label: { OpportunityRow(opportunity: opportunity) }
                                    .buttonStyle(.plain)
                                Spacer()
                                Button("Delete", role: .destructive) { delete(opportunity) }
                            }
                            .id(opportunity.id)
                        }
                    }
                    .listStyle(.inset)
                    .onAppear { if let anchorID { proxy.scrollTo(anchorID, anchor: .center) } }
                }
            }
        }
        .padding(28).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct OpportunityRow: View {
    let opportunity: Opportunity
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(opportunity.title).font(.headline)
            Text("\(opportunity.company) · \(opportunity.stage.rawValue)").font(.caption).foregroundStyle(RekonTheme.secondaryText)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 3)
    }
}

private struct OpportunityCard: View {
    let opportunity: Opportunity
    let open: () -> Void
    var body: some View {
        Button(action: open) { OpportunityRow(opportunity: opportunity).padding(10).background(RekonTheme.surface, in: RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(RekonTheme.border, lineWidth: 1)) }
            .buttonStyle(.plain)
    }
}

private struct OpportunityOverviewView: View {
    @ObservedObject var model: WorkspaceViewModel
    let opportunityID: String
    let back: () -> Void
    let showHistory: () -> Void
    let showReconcile: () -> Void
    let chooseDocument: () -> Void
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
                        CompactDocumentsView(model: model, opportunityID: opportunityID, chooseDocument: chooseDocument)
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
                                    HStack { Link("Open job posting", destination: url); Spacer(); if model.isCheckingSelectedPublicURL { ProgressView(); Button("Cancel") { _ = model.selectRouteOpportunity(id: opportunityID); model.cancelSelectedPublicURLCheck() } } else { Button("Check public URL") { _ = model.selectRouteOpportunity(id: opportunityID); model.checkSelectedPublicURL() }.disabled(!model.canCheckSelectedPublicURL).accessibilityIdentifier("check-public-url") } }
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

private struct HomeView: View {
    @ObservedObject var model: WorkspaceViewModel; let open: (TaskReminder) -> Void; let addOpportunity: () -> Void; let reschedule: (TaskReminder) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Home").font(.largeTitle.bold()).accessibilityIdentifier("home-content")
            Text("Needs Attention").font(.title2.bold())
            if model.needsAttention.isEmpty {
                FlexibleCenteredContent {
                    ContentUnavailableView("No next actions", systemImage: "checkmark.circle", description: Text("Add an opportunity when you are ready."))
                    Button("Add an opportunity", action: addOpportunity)
                        .buttonStyle(RekonPrimaryButtonStyle())
                        .accessibilityIdentifier("show-add-opportunity")
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(model.needsAttention, id: \.id) { task in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(task.title).font(.headline)
                                    Text(task.dueAt?.formatted(date: .abbreviated, time: .shortened) ?? "No due date")
                                        .foregroundStyle(RekonTheme.secondaryText)
                                }
                                Spacer()
                                Button("Open") { open(task) }
                                Button("Snooze 1 day") { model.snoozeOneDay(task) }
                                Button("Reschedule…") { reschedule(task) }
                                Button("Complete") { model.complete(task) }
                            }
                            .padding()
                            .background(RekonTheme.surface, in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(RekonTheme.border, lineWidth: 1))
                        }
                    }
                }
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct FlexibleCenteredContent<Content: View>: View {
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Add opportunity").font(.largeTitle.bold())
                Form {
                    TextField("Job title", text: $model.title).accessibilityIdentifier("opportunity-title")
                    TextField("Company", text: $model.company).accessibilityIdentifier("opportunity-company")
                    TextField("Job URL (optional)", text: $model.jobURL)
                    if let warning = model.jobURLWarning { Text(warning).font(.caption).foregroundStyle(.orange) }
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

private struct GlobalActivityView: View { @ObservedObject var model: WorkspaceViewModel; var body: some View { ScrollView { VStack(alignment: .leading, spacing: 16) { Text("Activity & AI").font(.largeTitle.bold()); GroupBox("Local activity ledger") { TextField("Search activity", text: $model.activitySearch).accessibilityIdentifier("activity-search"); if model.filteredActivityEvents.isEmpty { Text(model.activityEvents.isEmpty ? "No local activity yet." : "No activity matches that search.").foregroundStyle(.secondary) } else { ForEach(model.filteredActivityEvents, id: \.id) { Text("\($0.kind.replacingOccurrences(of: "_", with: " ").capitalized) · \($0.occurredAt.formatted(date: .abbreviated, time: .shortened))") } } }; GroupBox("AI usage and cost") { Text("No AI requests have been made. Cloud AI, local-model execution, and cost tracking are intentionally unavailable in this MVP.").foregroundStyle(.secondary) } }.padding(28).frame(maxWidth: 920, alignment: .leading) } } }

private struct SettingsView: View { @ObservedObject var model: WorkspaceViewModel; let export: () -> Void; let backup: () -> Void; let restore: () -> Void; var body: some View { ScrollView { VStack(alignment: .leading, spacing: 16) { Text("Settings").font(.largeTitle.bold()); GroupBox("Workspace") { VStack(alignment: .leading, spacing: 10) { Toggle("Show closed opportunities in the pipeline", isOn: $model.showClosedOpportunities).accessibilityIdentifier("show-closed-opportunities"); if model.usingSeparateLocalWorkspace { Text("You are using a separate local workspace. Your preserved workspace remains unchanged.").foregroundStyle(.secondary); Button("Return to preserved workspace recovery") { model.returnToPreservedWorkspaceRecovery() }.accessibilityIdentifier("return-to-preserved-workspace-recovery") } } }; GroupBox("Data and recovery") { Text("CSV exports are unencrypted. Encrypted backups can be restored on this Mac after a clear replacement confirmation.").foregroundStyle(.secondary); HStack { Button("Export opportunities as CSV…", action: export).disabled(model.opportunities.isEmpty); Button("Create encrypted backup…", action: backup); Button("Restore encrypted backup…", action: restore) } }; GroupBox("AI and connections") { Text("Cloud AI, local-model execution, Gmail, and Google Calendar are disabled in this MVP. No network connections are configured.").foregroundStyle(.secondary) } }.padding(28).frame(maxWidth: 920, alignment: .leading) } } }
