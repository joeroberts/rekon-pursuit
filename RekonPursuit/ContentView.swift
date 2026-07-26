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
    @State private var page: AppDestination = .needsAttention
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
            selection: $page,
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
        switch page {
        case .needsAttention: NeedsAttentionView(model: model, open: openAttentionTask, addOpportunity: { page = .addOpportunity }, reschedule: { task in taskToReschedule = task; rescheduledDueAt = task.dueAt ?? .now })
        case .pipeline: PipelineView(model: model, showsBoard: $showsPipelineBoard, anchorID: $pipelineAnchorID, open: openOpportunity, delete: { pendingDeletion = $0 })
        case .addOpportunity: AddOpportunityView(model: model)
        case .importCSV: CSVImportView(model: model, chooseFile: chooseCSVFile, open: openOpportunity)
        case .contacts: ContactsView(model: model, open: openOpportunity, delete: { pendingContactDeletion = $0 })
        case .activityAndAI: GlobalActivityView(model: model)
        case .settings: SettingsView(model: model, export: { showsUnencryptedExportWarning = true }, backup: createBackup, restore: { showsBackupImporter = true })
        }
    }

    @ViewBuilder private func routedOpportunityView(_ route: OpportunityRoute) -> some View {
        switch route {
        case let .overview(id):
            OpportunityOverviewView(model: model, opportunityID: id, back: returnToPipeline, showHistory: { openRoute(.history(id)) }, showReconcile: { openRoute(.reconcile(id)) }, chooseDocument: { showsDocumentReferenceImporter = true })
        case let .history(id):
            OpportunityHistoryView(model: model, opportunityID: id, back: { openRoute(.overview(id)) })
        case let .reconcile(id):
            ReconcilePostingView(model: model, opportunityID: id, back: { openRoute(.overview(id)) }, confirmClosure: { closureConfirmationID = id })
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
        page = .pipeline
    }

    private func openRoute(_ route: OpportunityRoute) {
        guard model.navigateToRouteOpportunity(id: route.opportunityID) else { return }
        opportunityRoute = route
    }

    private var detailTitle: String {
        guard let opportunityRoute else { return page.rawValue }
        switch opportunityRoute {
        case .overview: return "Opportunity"
        case .history: return "Activity & history"
        case .reconcile: return "Reconcile posting"
        }
    }

    private func selectDestination(_ destination: AppDestination) {
        guard opportunityRoute != nil else {
            page = destination
            return
        }
        guard model.canLeaveOpportunityRoute() else { return }
        opportunityRoute = nil
        page = destination
    }

    private func returnToPipeline() {
        guard model.canLeaveOpportunityRoute() else { return }
        opportunityRoute = nil
        page = .pipeline
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
                    if model.canCreateWorkspace {
                        Button("Create local workspace") { model.createWorkspaceIfNeeded() }
                            .buttonStyle(.borderedProminent).accessibilityIdentifier("create-local-workspace")
                    } else if model.workspaceRequiresRecovery {
                        Text("Recovery is required before this workspace can be opened. Rekon Pursuit kept existing local material unchanged and will not create over it.").foregroundStyle(.secondary)
                        Button("Recheck local workspace") { model.retryWorkspaceOpen() }.accessibilityIdentifier("recheck-local-workspace")
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
}

private struct PipelineView: View {
    @ObservedObject var model: WorkspaceViewModel
    @Binding var showsBoard: Bool
    @Binding var anchorID: String?
    let open: (Opportunity) -> Void
    let delete: (Opportunity) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Pipeline").font(.largeTitle.bold())
                Spacer()
                Text("Select an opportunity to review it.").foregroundStyle(RekonTheme.secondaryText)
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
                ContentUnavailableView("No opportunities match", systemImage: "briefcase", description: Text("Try another search or add an opportunity."))
            } else if showsBoard {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal) {
                        HStack(alignment: .top, spacing: 14) {
                            ForEach(PipelineStage.allCases, id: \.self) { stage in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(stage.rawValue).font(.headline)
                                    ScrollView {
                                        ForEach(model.filteredOpportunities.filter { $0.stage == stage }, id: \.id) { opportunity in
                                            OpportunityCard(opportunity: opportunity) { anchorID = opportunity.id; open(opportunity) }
                                                .id(opportunity.id)
                                        }
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
                        proxy.scrollTo(anchorID, anchor: .center)
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
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 3) { Text(opportunity.title).font(.largeTitle.bold()); Text(opportunity.company).foregroundStyle(RekonTheme.secondaryText) }
                            Spacer()
                            Text(opportunity.stage.rawValue).padding(.horizontal, 10).padding(.vertical, 5).background(RekonTheme.elevatedSurface, in: Capsule())
                        }
                        GroupBox("Opportunity") {
                            Form {
                                TextField("Job title", text: $model.selectedTitle).accessibilityIdentifier("selected-opportunity-title")
                                TextField("Company", text: $model.selectedCompany)
                                TextField("Job URL (optional)", text: $model.selectedJobURL)
                                TextField("Job description (optional)", text: $model.selectedJobDescription, axis: .vertical)
                                TextField("Notes (optional)", text: $model.selectedNotes, axis: .vertical)
                                TextField("Compensation (optional)", text: $model.selectedCompensation)
                                TextField("Location (optional)", text: $model.selectedLocation)
                                Picker("Work arrangement", selection: $model.selectedWorkArrangement) { ForEach(WorkArrangement.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                                Picker("Stage", selection: $model.selectedStage) { ForEach(PipelineStage.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                                TextField("Next action (optional)", text: $model.selectedNextAction)
                                Toggle("Add a due date", isOn: $model.selectedHasDueDate)
                                if model.selectedHasDueDate { DatePicker("Due", selection: $model.selectedDueAt, displayedComponents: [.date, .hourAndMinute]) }
                                HStack { Button("Save changes locally") { _ = model.selectRouteOpportunity(id: opportunityID); model.saveSelectedOpportunity() }.accessibilityIdentifier("save-opportunity-changes"); Button("Reschedule action") { _ = model.selectRouteOpportunity(id: opportunityID); model.rescheduleSelectedTask() }.disabled(model.selectedNextAction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
                            }
                        }
                        HStack(spacing: 12) {
                            Button("Activity & history", systemImage: "clock.arrow.circlepath", action: showHistory)
                            Button("Reconcile posting", systemImage: "checkmark.shield", action: showReconcile)
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

private struct NeedsAttentionView: View {
    @ObservedObject var model: WorkspaceViewModel; let open: (TaskReminder) -> Void; let addOpportunity: () -> Void; let reschedule: (TaskReminder) -> Void
    var body: some View { ScrollView { VStack(alignment: .leading, spacing: 16) { Text("Needs Attention").font(.largeTitle.bold()).accessibilityIdentifier("needs-attention-home"); if model.needsAttention.isEmpty { ContentUnavailableView("No next actions", systemImage: "checkmark.circle", description: Text("Add an opportunity when you are ready.")); Button("Add an opportunity", action: addOpportunity).accessibilityIdentifier("show-add-opportunity") } else { ForEach(model.needsAttention, id: \.id) { task in HStack { VStack(alignment: .leading) { Text(task.title).font(.headline); Text(task.dueAt?.formatted(date: .abbreviated, time: .shortened) ?? "No due date").foregroundStyle(.secondary) }; Spacer(); Button("Open") { open(task) }; Button("Snooze 1 day") { model.snoozeOneDay(task) }; Button("Reschedule…") { reschedule(task) }; Button("Complete") { model.complete(task) } }.padding().background(RekonTheme.surface, in: RoundedRectangle(cornerRadius: 10)) } } }.padding(28).frame(maxWidth: .infinity, alignment: .leading) } }
}

private struct AddOpportunityView: View {
    @ObservedObject var model: WorkspaceViewModel
    var body: some View { ScrollView { VStack(alignment: .leading, spacing: 16) { Text("Add opportunity").font(.largeTitle.bold()); Form { TextField("Job title", text: $model.title).accessibilityIdentifier("opportunity-title"); TextField("Company", text: $model.company).accessibilityIdentifier("opportunity-company"); TextField("Job URL (optional)", text: $model.jobURL); TextField("Job description (optional)", text: $model.jobDescription, axis: .vertical); TextField("Notes (optional)", text: $model.notes, axis: .vertical); Section("Job details") { TextField("Compensation (optional)", text: $model.compensation); TextField("Location (optional)", text: $model.location); Picker("Work arrangement", selection: $model.workArrangement) { ForEach(WorkArrangement.allCases, id: \.self) { Text($0.rawValue).tag($0) } }; Toggle("Add applied date", isOn: $model.hasApplicationDate); if model.hasApplicationDate { DatePicker("Applied date", selection: $model.applicationDate, displayedComponents: .date) }; Picker("Current response", selection: $model.responseState) { ForEach(ResponseState.allCases, id: \.self) { Text($0.rawValue).tag($0) } } }; Picker("Stage", selection: $model.stage) { ForEach(PipelineStage.allCases, id: \.self) { Text($0.rawValue).tag($0) } }; TextField("Next action (optional)", text: $model.nextAction).accessibilityIdentifier("opportunity-next-action"); Toggle("Add a due date", isOn: $model.hasDueDate); if model.hasDueDate { DatePicker("Due", selection: $model.dueAt, displayedComponents: [.date, .hourAndMinute]) }; Button("Save opportunity locally") { model.createOpportunity() }.accessibilityIdentifier("save-opportunity").keyboardShortcut(.defaultAction).disabled(model.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.company.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) } }.padding(28).frame(maxWidth: 860, alignment: .leading) } }
}

private struct CSVImportView: View {
    @ObservedObject var model: WorkspaceViewModel; let chooseFile: () -> Void; let open: (Opportunity) -> Void
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Import CSV").font(.largeTitle.bold())
                GroupBox("Import opportunities") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Map a UTF-8 CSV, validate it, review duplicates, then import local data in one step.")
                            .foregroundStyle(.secondary)
                        Button("Choose CSV file…", action: chooseFile)
                            .accessibilityIdentifier("choose-csv-file")
                        if let preview = model.csvPreview {
                            Text("1. Map columns").font(.headline)
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
                            Button("2. Validate mapped rows") { model.validateCSVMapping() }
                                .disabled(!CSVOpportunityImporter.mappingIsValid(preview.mapping))
                            ForEach(model.csvImportPlan) { row in
                                VStack(alignment: .leading) {
                                    Text("Row \(row.id): \(row.row.opportunity?.title ?? "") · \(row.row.opportunity?.company ?? "")")
                                    if row.isDuplicate {
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
                            }
                            if !model.csvImportPlan.isEmpty {
                                Button("Import reviewed rows") { model.importCSVPreview() }
                                    .disabled(model.csvImportPlan.contains { $0.decision == nil || ($0.decision == .updateSelectedFields && $0.selectedFields.isEmpty) })
                                    .accessibilityIdentifier("import-reviewed-csv")
                            }
                        }
                        if let report = model.csvImportReport, model.csvPreview == nil {
                            Divider()
                            Text("Last import report").font(.headline)
                            Text("\(report.sourceBasename) · Created \(report.importedCount) · updated \(report.updatedCount) · kept separate \(report.duplicateKeptCount) · skipped \(report.skippedCount) · invalid \(report.invalidCount) · failed \(report.failedCount)")
                                .foregroundStyle(.secondary)
                            ForEach(model.csvImportReportRows) { row in
                                if let id = row.opportunityID {
                                    Button("Open \(row.outcome): \(row.sourceRow)") {
                                        if let opportunity = model.opportunities.first(where: { $0.id == id }) { open(opportunity) }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(28).frame(maxWidth: 960, alignment: .leading)
        }
    }
}

private struct ContactsView: View {
    @ObservedObject var model: WorkspaceViewModel; let open: (Opportunity) -> Void; let delete: (Contact) -> Void
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
                        TextField("Current employer (optional)", text: $model.contactEmployer)
                        TextField("Title (optional)", text: $model.contactTitle)
                        TextField("Email (optional)", text: $model.contactEmail)
                        TextField("Profile URL (optional)", text: $model.contactProfileURL)
                        TextField("Relationship context (optional)", text: $model.contactRelationshipContext)
                        TextField("Notes (optional)", text: $model.contactNotes, axis: .vertical)
                        HStack {
                            Button("New contact") { model.beginNewContact() }
                            Spacer()
                            Button(model.selectedContact == nil ? "Save contact locally" : "Save changes locally") {
                                if model.selectedContact == nil { model.createContact() } else { model.saveSelectedContact() }
                            }
                            .disabled(model.contactName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityIdentifier("save-contact")
                        }
                    }
                }
                if model.selectedContact != nil {
                    GroupBox("Linked opportunities") {
                        if model.selectedContactOpportunities.isEmpty {
                            Text("This contact is not linked to an active opportunity.").foregroundStyle(.secondary)
                        } else {
                            ForEach(model.selectedContactOpportunities, id: \.id) { opportunity in
                                Button("\(opportunity.title) · \(opportunity.company)") { open(opportunity) }
                            }
                        }
                    }
                }
            }
            .padding(28).frame(maxWidth: 920, alignment: .leading)
        }
    }
}

private struct GlobalActivityView: View { @ObservedObject var model: WorkspaceViewModel; var body: some View { ScrollView { VStack(alignment: .leading, spacing: 16) { Text("Activity & AI").font(.largeTitle.bold()); GroupBox("Local activity ledger") { TextField("Search activity", text: $model.activitySearch).accessibilityIdentifier("activity-search"); if model.filteredActivityEvents.isEmpty { Text(model.activityEvents.isEmpty ? "No local activity yet." : "No activity matches that search.").foregroundStyle(.secondary) } else { ForEach(model.filteredActivityEvents, id: \.id) { Text("\($0.kind.replacingOccurrences(of: "_", with: " ").capitalized) · \($0.occurredAt.formatted(date: .abbreviated, time: .shortened))") } } }; GroupBox("AI usage and cost") { Text("No AI requests have been made. Cloud AI, local-model execution, and cost tracking are intentionally unavailable in this MVP.").foregroundStyle(.secondary) } }.padding(28).frame(maxWidth: 920, alignment: .leading) } } }

private struct SettingsView: View { @ObservedObject var model: WorkspaceViewModel; let export: () -> Void; let backup: () -> Void; let restore: () -> Void; var body: some View { ScrollView { VStack(alignment: .leading, spacing: 16) { Text("Settings").font(.largeTitle.bold()); GroupBox("Workspace") { Toggle("Show closed opportunities in the pipeline", isOn: $model.showClosedOpportunities).accessibilityIdentifier("show-closed-opportunities") }; GroupBox("Data and recovery") { Text("CSV exports are unencrypted. Encrypted backups can be restored on this Mac after a clear replacement confirmation.").foregroundStyle(.secondary); HStack { Button("Export opportunities as CSV…", action: export).disabled(model.opportunities.isEmpty); Button("Create encrypted backup…", action: backup); Button("Restore encrypted backup…", action: restore) } }; GroupBox("AI and connections") { Text("Cloud AI, local-model execution, Gmail, and Google Calendar are disabled in this MVP. No network connections are configured.").foregroundStyle(.secondary) } }.padding(28).frame(maxWidth: 920, alignment: .leading) } } }
