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
        .onChange(of: model.protectedExportSuccess) { _, success in
            guard success != nil else { return }
            isPresentingProtectedExport = false
            protectedExportReentry = ""
        }
        .onChange(of: model.protectedExportReview) { _, review in
            if review != nil { protectedExportReentry = "" }
        }
        .overlay {
            if isPresentingProtectedExport {
                ZStack {
                    Color.black.opacity(0.52)
                        .ignoresSafeArea()
                    SettingsProtectedExportDialog(
                        mode: model.protectedExportReview.map {
                            .confirmation(displayFilename: $0.displayFilename)
                        } ?? .entry,
                        recoveryKey: $protectedExportReentry,
                        errorMessage: settingsRootModalPresentation.protectedExportErrorMessage,
                        isBusy: model.isCreatingProtectedExport,
                        cancel: {
                            model.cancelProtectedExport()
                            isPresentingProtectedExport = false
                            protectedExportReentry = ""
                        },
                        primaryAction: {
                            if model.protectedExportReview != nil {
                                model.confirmProtectedExport(reentry: protectedExportReentry)
                                protectedExportReentry = ""
                            } else {
                                model.reviewProtectedExport(reentry: protectedExportReentry)
                            }
                        }
                    )
                }
            } else if settingsRootModalPresentation.isProtectedExportSuccessPresented,
               let displayFilename = settingsRootModalPresentation.protectedExportSuccessDisplayFilename {
                ZStack {
                    Color.black.opacity(0.52)
                        .ignoresSafeArea()
                    SettingsProtectedExportSuccessDialog(
                        displayFilename: displayFilename,
                        dismiss: dismissProtectedExportSuccess
                    )
                }
            }
        }
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
                    TextField("Re-enter the complete recovery key", text: $reentry).textFieldStyle(RekonQuietTextFieldStyle())
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
                TextField("Re-enter the complete recovery key", text: $archiveRecoveryReentry).textFieldStyle(RekonQuietTextFieldStyle())
                HStack {
                    Button("Cancel", role: .cancel) { isPresentingArchiveCreation = false; archiveRecoveryReentry = "" }
                    Spacer()
                    Button("Create recovery archive") { model.createPortableArchive(reentry: archiveRecoveryReentry); isPresentingArchiveCreation = false; archiveRecoveryReentry = "" }
                        .disabled(model.isCreatingPortableArchive)
                        .keyboardShortcut(.defaultAction)
                }
            }.padding(24).frame(width: 520)
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
                    .textFieldStyle(RekonQuietTextFieldStyle())
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
        .sheet(isPresented: portableArchiveRestoreSheetBinding) {
            VStack(alignment: .leading, spacing: 16) {
                switch model.portableArchiveRestoreState {
                case .awaitingRecoveryKey:
                    Text("Restore portable archive").font(.title2.bold())
                    Text("Enter the recovery key to verify the archive. The key is used only for this restore attempt.")
                        .foregroundStyle(.secondary)
                    TextField("Recovery key", text: $portableArchiveRestoreKey)
                        .textFieldStyle(RekonQuietTextFieldStyle())
                    HStack {
                        Button("Cancel", role: .cancel) {
                            SettingsRootModalBindings.dismissPortableArchiveRestore(
                                clearRestoreEntry: { portableArchiveRestoreKey = "" },
                                cancelPortableArchiveRestore: { model.cancelPortableArchiveRestore() }
                            )
                        }
                        Spacer()
                        Button("Verify archive") {
                            model.verifyPortableArchiveForRestore(portableArchiveRestoreKey)
                            portableArchiveRestoreKey = ""
                        }
                        .keyboardShortcut(.defaultAction)
                    }
                case .verifying:
                    ProgressView("Verifying portable archive…")
                    Button("Cancel", role: .cancel) {
                        SettingsRootModalBindings.dismissPortableArchiveRestore(
                            clearRestoreEntry: { portableArchiveRestoreKey = "" },
                            cancelPortableArchiveRestore: { model.cancelPortableArchiveRestore() }
                        )
                    }
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
                        Button("Cancel", role: .cancel) {
                            SettingsRootModalBindings.dismissPortableArchiveRestore(
                                clearRestoreEntry: { portableArchiveRestoreKey = "" },
                                cancelPortableArchiveRestore: { model.cancelPortableArchiveRestore() }
                            )
                        }
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
        .alert("Portable archive restore", isPresented: portableArchiveRestoreFailureAlertBinding) {
            Button("Choose another archive") {
                model.dismissPortableArchiveRestoreFailure()
                model.choosePortableArchiveForRestore()
            }
            Button("Dismiss", role: .cancel) {
                SettingsRootModalBindings.dismissPortableArchiveRestoreFailure(
                    dismissPortableArchiveRestoreFailure: { model.dismissPortableArchiveRestoreFailure() }
                )
            }
        } message: {
            if let message = settingsRootModalPresentation.portableArchiveRestoreFailureMessage {
                Text(message)
            }
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
            case .settings:
                SettingsView(
                    usingSeparateLocalWorkspace: model.usingSeparateLocalWorkspace,
                    recovery: settingsRecoveryPresentation,
                    documentReferenceSummary: model.documentReferenceSummary,
                    returnToPreservedWorkspaceRecovery: { model.returnToPreservedWorkspaceRecovery() },
                    beginRecoveryKeyEnrollment: {
                        generatedRecoveryKey = try? RecoveryKey.generate()
                        recoveryKeyCopied = false
                    },
                    presentArchiveCreation: { isPresentingArchiveCreation = true },
                    presentProtectedExport: { isPresentingProtectedExport = true },
                    presentRetainedDataPurge: { isPresentingRetainedDataPurge = true },
                    cancelRetainedDataPurge: { model.cancelRetainedDataPurge() },
                    choosePortableArchiveForRestore: { model.choosePortableArchiveForRestore() }
                )
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

    private var settingsRecoveryPresentation: SettingsRecoveryPresentation {
        let restoreProgressText: String?
        switch model.portableArchiveRestoreState {
        case .verifying:
            restoreProgressText = "Verifying portable archive…"
        case .restoring:
            restoreProgressText = "Restore in progress…"
        case .idle, .awaitingRecoveryKey, .awaitingConfirmation, .ready, .failed:
            restoreProgressText = nil
        }

        let restoreReady: Bool
        if case .ready = model.portableArchiveRestoreState {
            restoreReady = true
        } else {
            restoreReady = false
        }

        return SettingsRecoveryPresentation(
            recoveryEnrollmentEnabled: model.recoveryEnrollmentEnabled,
            archiveSummaries: model.portableArchiveCatalogue.map(SettingsArchiveSummary.init(archive:)),
            isCreatingPortableArchive: model.isCreatingPortableArchive,
            isCreatingProtectedExport: model.isCreatingProtectedExport,
            isPurgingRetainedArchiveData: model.isPurgingRetainedArchiveData,
            isRestoringPortableArchive: model.isRestoringPortableArchive,
            restoreProgressText: restoreProgressText,
            retainedDataPurgeStatusText: model.retainedDataPurgeStatus.map(retainedDataPurgeStatusText),
            restoreReady: restoreReady
        )
    }

    private var settingsRootModalPresentation: SettingsRootModalPresentation {
        SettingsRootModalPresentation(
            portableArchiveRestoreState: model.portableArchiveRestoreState,
            protectedExportErrorMessage: model.protectedExportErrorMessage,
            protectedExportSuccess: model.protectedExportSuccess
        )
    }

    private func dismissProtectedExportSuccess() {
        SettingsRootModalBindings.dismissProtectedExportSuccess(
            dismissProtectedExportSuccess: { model.dismissProtectedExportSuccess() }
        )
    }

    private var portableArchiveRestoreSheetBinding: Binding<Bool> {
        Binding(
            get: { settingsRootModalPresentation.isPortableArchiveRestoreSheetPresented },
            set: { isPresented in
                if !isPresented {
                    SettingsRootModalBindings.dismissPortableArchiveRestore(
                        clearRestoreEntry: { portableArchiveRestoreKey = "" },
                        cancelPortableArchiveRestore: { model.cancelPortableArchiveRestore() }
                    )
                }
            }
        )
    }

    private var portableArchiveRestoreFailureAlertBinding: Binding<Bool> {
        Binding(
            get: { settingsRootModalPresentation.isPortableArchiveRestoreFailureAlertPresented },
            set: { isPresented in
                if !isPresented {
                    SettingsRootModalBindings.dismissPortableArchiveRestoreFailure(
                        dismissPortableArchiveRestoreFailure: { model.dismissPortableArchiveRestoreFailure() }
                    )
                }
            }
        )
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
    @FocusState private var focusedEditor: OverviewEditor?

    private enum OverviewEditor: Hashable {
        case description
        case notes
    }

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
                            VStack(alignment: .leading, spacing: RekonTheme.Spacing.standard) {
                                overviewTextField("Job title", text: $model.selectedTitle, accessibilityIdentifier: "selected-opportunity-title")
                                overviewTextField("Company", text: $model.selectedCompany)
                                overviewTextField("Job URL (optional)", text: $model.selectedJobURL)
                                if let warning = model.selectedJobURLWarning { Text(warning).font(.caption).foregroundStyle(.orange) }
                                overviewEditor("Job description", text: $model.selectedJobDescription, focus: .description, minHeight: 110)
                                overviewEditor("Notes", text: $model.selectedNotes, focus: .notes, minHeight: 90)
                                overviewSection("Compensation") {
                                    if !model.selectedCompensation.isEmpty { Text("Imported: \(model.selectedCompensation)").font(.caption).foregroundStyle(.secondary) }
                                    ResponsiveFormRow {
                                        overviewTextField("Minimum (USD)", text: $model.selectedCompensationMinimum)
                                        overviewTextField("Maximum (USD)", text: $model.selectedCompensationMaximum)
                                    }
                                    overviewPicker("Pay period") {
                                        Picker("Pay period", selection: $model.selectedCompensationPayPeriod) { ForEach(CompensationPayPeriod.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                                    }
                                    if let formatted = model.formattedCompensation(for: opportunity) { Text(formatted).font(.caption).foregroundStyle(.secondary) }
                                }
                                overviewSection("Location & logistics") {
                                    overviewTextField("Location (optional)", text: $model.selectedLocation)
                                    ResponsiveFormRow {
                                        overviewPicker("Work arrangement") { Picker("Work arrangement", selection: $model.selectedWorkArrangement) { ForEach(WorkArrangement.allCases, id: \.self) { Text($0.rawValue).tag($0) } } }
                                        overviewPicker("Stage") { Picker("Stage", selection: $model.selectedStage) { ForEach(PipelineStage.allCases, id: \.self) { Text($0.rawValue).tag($0) } } }
                                        overviewPicker("Next action") { Picker("Next action", selection: $model.selectedActionType) { ForEach(OpportunityActionType.allCases, id: \.self) { Text($0.rawValue).tag($0) } } }
                                    }
                                    if model.selectedActionType == .other { overviewTextField("Other action", text: $model.selectedActionCustomText) }
                                }
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

    @ViewBuilder private func overviewTextField(_ title: String, text: Binding<String>, accessibilityIdentifier: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: RekonTheme.Spacing.micro) {
            Text(title).font(.caption).foregroundStyle(RekonTheme.secondaryText)
            if let accessibilityIdentifier {
                TextField(title, text: text)
                    .textFieldStyle(RekonQuietTextFieldStyle())
                    .accessibilityIdentifier(accessibilityIdentifier)
            } else {
                TextField(title, text: text)
                    .textFieldStyle(RekonQuietTextFieldStyle())
            }
        }
    }

    private func overviewEditor(_ title: String, text: Binding<String>, focus: OverviewEditor, minHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: RekonTheme.Spacing.micro) {
            Text(title).font(.caption).foregroundStyle(RekonTheme.secondaryText)
            TextEditor(text: text)
                .focused($focusedEditor, equals: focus)
                .frame(minHeight: minHeight)
                .rekonQuietTextEditorSurface(isFocused: focusedEditor == focus)
        }
    }

    private func overviewSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: RekonTheme.Spacing.tight) {
            HStack(spacing: RekonTheme.Spacing.tight) {
                Text(title).font(.headline)
                Rectangle().fill(RekonTheme.borderSubtle).frame(height: 1)
            }
            content()
        }
    }

    private func overviewPicker<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: RekonTheme.Spacing.micro) {
            Text(title).font(.caption).foregroundStyle(RekonTheme.secondaryText)
            content().pickerStyle(.menu)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                            VStack(alignment: .leading, spacing: RekonTheme.Spacing.standard) {
                                reconcilePicker("Local outcome") { Picker("Local outcome", selection: $model.reconciliationOutcome) { ForEach(ReconciliationOutcome.allCases, id: \.self) { Text($0.rawValue).tag($0) } } }
                                reconcilePicker("Classification") { Picker("Classification", selection: $model.reconciliationClassification) { ForEach(ReconciliationClassification.allCases, id: \.self) { Text($0.rawValue).tag($0) } } }
                                reconcilePicker("Reason") { Picker("Reason", selection: $model.reconciliationReason) { ForEach(ReconciliationReason.allCases, id: \.self) { Text($0.rawValue).tag($0) } } }
                                reconcilePicker("Confidence") { Picker("Confidence", selection: $model.reconciliationConfidence) { ForEach(ReconciliationConfidence.allCases, id: \.self) { Text($0.rawValue).tag($0) } } }
                                VStack(alignment: .leading, spacing: RekonTheme.Spacing.micro) {
                                    Text("Evidence or error reviewed").font(.caption).foregroundStyle(RekonTheme.secondaryText)
                                    TextField("Evidence or error reviewed", text: $model.reconciliationEvidence, axis: .vertical)
                                        .textFieldStyle(RekonQuietTextFieldStyle())
                                }
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

    private func reconcilePicker<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: RekonTheme.Spacing.micro) {
            Text(title).font(.caption).foregroundStyle(RekonTheme.secondaryText)
            content().pickerStyle(.menu)
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

private struct ResponsiveFormRow<Content: View>: View {
    private let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: RekonTheme.Spacing.standard) {
                content()
            }
            VStack(alignment: .leading, spacing: RekonTheme.Spacing.standard) {
                content()
            }
        }
    }
}

private struct AddOpportunityView: View {
    @ObservedObject var model: WorkspaceViewModel
    let cancel: () -> Void
    @FocusState private var focusedEditor: AddOpportunityEditor?

    private enum AddOpportunityEditor: Hashable {
        case description
        case notes
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Add opportunity").font(.largeTitle.bold())
                VStack(alignment: .leading, spacing: RekonTheme.Spacing.standard) {
                    addTextField("Job title", text: $model.title, accessibilityIdentifier: "opportunity-title")
                    addTextField("Company", text: $model.company, accessibilityIdentifier: "opportunity-company")
                    addTextField("Job URL (optional)", text: $model.jobURL)
                    if let warning = model.jobURLWarning { Text(warning).font(.caption).foregroundStyle(.orange).accessibilityIdentifier("add-opportunity-url-warning") }
                    addEditor("Job description", text: $model.jobDescription, focus: .description, minHeight: 110)
                    addEditor("Notes", text: $model.notes, focus: .notes, minHeight: 90)
                    addSection("Compensation") {
                        ResponsiveFormRow {
                            addTextField("Minimum (USD)", text: $model.compensationMinimum)
                            addTextField("Maximum (USD)", text: $model.compensationMaximum)
                        }
                        addPicker("Pay period") { Picker("Pay period", selection: $model.compensationPayPeriod) { ForEach(CompensationPayPeriod.allCases, id: \.self) { Text($0.rawValue).tag($0) } } }
                    }
                    addSection("Location & logistics") {
                        addTextField("Location (optional)", text: $model.location)
                        addPicker("Work arrangement") { Picker("Work arrangement", selection: $model.workArrangement) { ForEach(WorkArrangement.allCases, id: \.self) { Text($0.rawValue).tag($0) } } }
                        Toggle("Add applied date", isOn: $model.hasApplicationDate)
                        if model.hasApplicationDate { DatePicker("Applied date", selection: $model.applicationDate, displayedComponents: .date) }
                        addPicker("Current response") { Picker("Current response", selection: $model.responseState) { ForEach(ResponseState.allCases, id: \.self) { Text($0.rawValue).tag($0) } } }
                    }
                    ResponsiveFormRow {
                        addPicker("Stage") { Picker("Stage", selection: $model.stage) { ForEach(PipelineStage.allCases, id: \.self) { Text($0.rawValue).tag($0) } } }
                        addPicker("Next action") { Picker("Next action", selection: $model.actionType) { ForEach(OpportunityActionType.allCases, id: \.self) { Text($0.rawValue).tag($0) } } }
                    }
                    if model.actionType == .other { addTextField("Other action", text: $model.actionCustomText, accessibilityIdentifier: "opportunity-next-action") }
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

    @ViewBuilder private func addTextField(_ title: String, text: Binding<String>, accessibilityIdentifier: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: RekonTheme.Spacing.micro) {
            Text(title).font(.caption).foregroundStyle(RekonTheme.secondaryText)
            if let accessibilityIdentifier {
                TextField(title, text: text)
                    .textFieldStyle(RekonQuietTextFieldStyle())
                    .accessibilityIdentifier(accessibilityIdentifier)
            } else {
                TextField(title, text: text)
                    .textFieldStyle(RekonQuietTextFieldStyle())
            }
        }
    }

    private func addEditor(_ title: String, text: Binding<String>, focus: AddOpportunityEditor, minHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: RekonTheme.Spacing.micro) {
            Text(title).font(.caption).foregroundStyle(RekonTheme.secondaryText)
            TextEditor(text: text)
                .focused($focusedEditor, equals: focus)
                .frame(minHeight: minHeight)
                .rekonQuietTextEditorSurface(isFocused: focusedEditor == focus)
        }
    }

    private func addSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: RekonTheme.Spacing.tight) {
            HStack(spacing: RekonTheme.Spacing.tight) {
                Text(title).font(.headline)
                Rectangle().fill(RekonTheme.borderSubtle).frame(height: 1)
            }
            content()
        }
    }

    private func addPicker<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: RekonTheme.Spacing.micro) {
            Text(title).font(.caption).foregroundStyle(RekonTheme.secondaryText)
            content().pickerStyle(.menu)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

private struct GlobalActivityView: View {
    @ObservedObject var model: WorkspaceViewModel
    @State private var selectedSection: Section = .ledger

    private enum Section: Hashable {
        case ledger
        case assistant
    }

    private var visibleEvents: [ActivityEvent] { model.filteredActivityEvents }

    var body: some View {
        VStack(alignment: .leading, spacing: RekonTheme.Spacing.section) {
            Text("Activity & AI")
                .font(.system(size: 34, weight: .bold))

            activitySectionNavigation

            if selectedSection == .ledger {
                activityLedger
            } else {
                assistantPlaceholder
            }
        }
        .padding(.horizontal, 36)
        .padding(.vertical, 30)
        .frame(maxWidth: 1_240, maxHeight: .infinity, alignment: .topLeading)
    }

    private var activitySectionNavigation: some View {
        HStack(spacing: 38) {
            sectionButton("Activity ledger", symbol: "document.text", section: .ledger)
            sectionButton("AI assistant", symbol: "sparkles", section: .assistant)
            Spacer(minLength: 0)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(RekonTheme.borderSubtle)
                .frame(height: 1)
        }
    }

    private func sectionButton(_ title: String, symbol: String, section: Section) -> some View {
        let isSelected = selectedSection == section
        return Button {
            selectedSection = section
        } label: {
            Label(title, systemImage: symbol)
                .font(.body.weight(.medium))
                .foregroundStyle(isSelected ? RekonTheme.accent : RekonTheme.secondaryText)
                .padding(.horizontal, 10)
                .padding(.bottom, 14)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(isSelected ? RekonTheme.accent : .clear)
                        .frame(height: 3)
                }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(section == .ledger ? "activity-ledger-tab" : "ai-assistant-tab")
    }

    private var activityLedger: some View {
        RekonCard {
            VStack(alignment: .leading, spacing: RekonTheme.Spacing.compact) {
                Text("Local activity ledger")
                    .font(.headline)

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(RekonTheme.secondaryText)
                    TextField("Search activity", text: $model.activitySearch)
                        .textFieldStyle(.plain)
                        .accessibilityIdentifier("activity-search")
                }
                .padding(.horizontal, 12)
                .frame(height: 52)
                .background(RekonTheme.backgroundRaised, in: RoundedRectangle(cornerRadius: RekonTheme.Radius.control))
                .overlay(
                    RoundedRectangle(cornerRadius: RekonTheme.Radius.control)
                        .stroke(RekonTheme.border.opacity(0.82), lineWidth: 1)
                )

                if visibleEvents.isEmpty {
                    Text(model.activityEvents.isEmpty ? "No local activity yet." : "No activity matches that search.")
                        .foregroundStyle(RekonTheme.secondaryText)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(visibleEvents, id: \.id) { event in
                                ActivityLedgerRow(event: event)
                                if event.id != visibleEvents.last?.id {
                                    Divider().overlay(RekonTheme.borderSubtle)
                                }
                            }
                        }
                    }
                    .frame(minHeight: 260, maxHeight: 650)
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var assistantPlaceholder: some View {
        RekonCard {
            VStack(spacing: 22) {
                Image(systemName: "sparkles")
                    .font(.system(size: 54, weight: .light))
                    .foregroundStyle(RekonTheme.violet)

                VStack(spacing: 12) {
                    Text("AI assistant coming soon")
                        .font(.title.bold())
                    Text("AI-powered workspace assistance will be available here in a future update.")
                        .foregroundStyle(RekonTheme.secondaryText)
                        .multilineTextAlignment(.center)
                    Label("Your workspace remains local and private.", systemImage: "shield")
                        .foregroundStyle(RekonTheme.secondaryText)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, 70)
            .accessibilityIdentifier("ai-ledger-empty-state")
        }
        .frame(maxHeight: .infinity)
    }

}

private struct ActivityLedgerRow: View {
    let event: ActivityEvent

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbolName)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(iconColor)
                .frame(width: 34, height: 34)
                .overlay(Circle().stroke(iconColor.opacity(0.72), lineWidth: 1))

            Text(displayName)
                .font(.body.weight(.medium))
                .foregroundStyle(RekonTheme.primaryText)

            Spacer(minLength: 16)

            Text(event.occurredAt.formatted(date: .abbreviated, time: .shortened))
                .font(.body)
                .foregroundStyle(RekonTheme.secondaryText)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
    }

    private var displayName: String {
        event.kind
            .split(separator: "_")
            .map { $0.capitalized }
            .joined(separator: " ")
    }

    private var symbolName: String {
        switch event.kind {
        case "opportunity_created": "plus"
        case "opportunity_updated", "opportunity_stage_changed": "arrow.triangle.2.circlepath"
        case "opportunity_deleted": "trash"
        case "task_opened": "checkmark.square"
        case "task_completed": "checkmark"
        case "task_rescheduled", "task_snoozed": "clock.arrow.circlepath"
        case "csv_import_row_created", "csv_import_row_updated": "doc.text"
        case "contact_linked", "contact_unlinked": "person.2"
        case "document_reference_linked", "document_reference_relinked": "doc.badge.plus"
        default: "circle"
        }
    }

    private var iconColor: Color {
        switch event.kind {
        case "opportunity_created", "task_completed": RekonTheme.success
        case "task_opened", "csv_import_row_created", "csv_import_row_updated": RekonTheme.violet
        case "opportunity_updated", "opportunity_stage_changed", "task_rescheduled", "task_snoozed": RekonTheme.accent
        default: RekonTheme.secondaryText
        }
    }
}
