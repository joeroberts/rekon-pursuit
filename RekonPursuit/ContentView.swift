import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum BootstrapCopy {
    nonisolated static let status = "Local-only foundation"
}

struct CSVExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }

    var text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        text = String(data: configuration.file.regularFileContents ?? Data(), encoding: .utf8) ?? ""
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

struct ContentView: View {
    @StateObject private var model = WorkspaceViewModel()
    @State private var pendingDeletion: Opportunity?
    @State private var pendingContactDeletion: Contact?
    @State private var taskToReschedule: TaskReminder?
    @State private var rescheduledDueAt = Date.now
    @State private var showsPipelineBoard = false
    @State private var showsDocumentReferenceImporter = false
    @State private var showsBackupImporter = false
    @State private var pendingRestoreURL: URL?
    @State private var showsUnencryptedExportWarning = false
    @State private var showsCSVExporter = false
    @State private var exportDocument: CSVExportDocument?
    @State private var page: AppDestination = .needsAttention

    var body: some View {
        AppShellView(selection: $page) {
            workspaceGate
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

            if page == .addOpportunity {
            Form {
                TextField("Job title", text: $model.title)
                    .accessibilityIdentifier("opportunity-title")
                TextField("Company", text: $model.company)
                    .accessibilityIdentifier("opportunity-company")
                TextField("Job URL (optional)", text: $model.jobURL)
                TextField("Job description (optional)", text: $model.jobDescription, axis: .vertical)
                TextField("Notes (optional)", text: $model.notes, axis: .vertical)
                Picker("Stage", selection: $model.stage) {
                    ForEach(PipelineStage.allCases, id: \.self) { stage in
                        Text(stage.rawValue).tag(stage)
                    }
                }
                TextField("Next action (optional)", text: $model.nextAction)
                    .accessibilityIdentifier("opportunity-next-action")
                Toggle("Add a due date", isOn: $model.hasDueDate)
                if model.hasDueDate {
                    DatePicker("Due", selection: $model.dueAt, displayedComponents: [.date, .hourAndMinute])
                }
                Button("Save opportunity locally") {
                    model.createOpportunity()
                }
                .accessibilityIdentifier("save-opportunity")
                .keyboardShortcut(.defaultAction)
                .disabled(!model.workspaceReady || model.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.company.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            }

            if page == .importCSV {
                GroupBox("Import opportunities") {
                    Text("Use a UTF-8 CSV with title and company columns. Imported rows stay on this Mac.")
                        .foregroundStyle(.secondary)
                    Button("Choose CSV file…") { chooseCSVFile() }
                        .disabled(!model.workspaceReady)
                        .accessibilityIdentifier("choose-csv-file")
                    if !model.workspaceReady {
                        Text("Create or recover the local workspace before choosing a CSV file.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let preview = model.csvPreview {
                        Text("\(preview.rows.count) valid row\(preview.rows.count == 1 ? "" : "s") · \(preview.invalidRowCount) invalid row\(preview.invalidRowCount == 1 ? "" : "s") skipped")
                            .font(.headline)
                        if preview.rows.isEmpty {
                            Text("No importable rows were found. Check the title and company values.")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(model.csvImportPlan) { row in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Row \(row.id): \(row.row.opportunity.title) · \(row.row.opportunity.company)")
                                if row.isDuplicate {
                                    Text("Possible duplicate — exact title and company match. Choose what to do.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Picker("Duplicate decision for row \(row.id)", selection: Binding(
                                        get: { row.decision },
                                        set: { decision in if let decision { model.setCSVDecision(decision, for: row.id) } }
                                    )) {
                                        Text("Choose a decision").tag(CSVDuplicateDecision?.none)
                                        Text("Skip this row").tag(CSVDuplicateDecision?.some(.skip))
                                        Text("Keep as separate opportunity").tag(CSVDuplicateDecision?.some(.keepSeparate))
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        Button("Import reviewed rows") { model.importCSVPreview() }
                            .disabled(!model.workspaceReady || model.csvImportPlan.isEmpty || model.csvImportPlan.contains { $0.isDuplicate && $0.decision == nil })
                            .accessibilityIdentifier("import-reviewed-csv")
                    }
                    if let report = model.csvImportReport, model.csvPreview == nil {
                        Divider()
                        Text("Last import report")
                            .font(.headline)
                        Text("Created \(report.importedCount) · skipped \(report.skippedCount) · kept separate \(report.duplicateKeptCount) · invalid \(report.invalidCount)")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if page == .pipeline {
            GroupBox("Opportunities") {
                if model.opportunities.isEmpty {
                    Text("No opportunities yet.").foregroundStyle(.secondary)
                } else {
                    HStack {
                        TextField("Search opportunities", text: $model.opportunitySearch)
                            .accessibilityIdentifier("opportunity-search")
                        Picker("Stage filter", selection: $model.stageFilter) {
                            Text("All stages").tag("All stages")
                            ForEach(PipelineStage.allCases, id: \.self) { stage in
                                Text(stage.rawValue).tag(stage.rawValue)
                            }
                        }
                        Picker("View", selection: $showsPipelineBoard) {
                            Text("Table").tag(false)
                            Text("Board").tag(true)
                        }
                        .pickerStyle(.segmented)
                    }
                    if model.filteredOpportunities.isEmpty {
                        Text("No opportunities match that filter.").foregroundStyle(.secondary)
                    }
                    if showsPipelineBoard {
                        ScrollView(.horizontal) {
                            HStack(alignment: .top, spacing: 12) {
                                ForEach(PipelineStage.allCases, id: \.self) { stage in
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(stage.rawValue).font(.headline)
                                        ForEach(model.filteredOpportunities.filter { $0.stage == stage }, id: \.id) { opportunity in
                                            Button { model.select(opportunity) } label: {
                                                VStack(alignment: .leading) {
                                                    Text(opportunity.title)
                                                    Text(opportunity.company).font(.caption).foregroundStyle(.secondary)
                                                }
                                                .frame(width: 132, alignment: .leading)
                                                .padding(8)
                                                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .frame(width: 148, alignment: .leading)
                                }
                            }
                        }
                    } else {
                        ForEach(model.filteredOpportunities, id: \.id) { opportunity in
                        HStack {
                            Button { model.select(opportunity) } label: {
                                VStack(alignment: .leading) {
                                    Text(opportunity.title)
                                    Text("\(opportunity.company) · \(opportunity.stage.rawValue)").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            Spacer()
                            Button("Delete", role: .destructive) {
                                pendingDeletion = opportunity
                            }
                        }
                        }
                    }
                }
            }

            if model.selectedOpportunity != nil {
                GroupBox("Opportunity record") {
                    Form {
                        TextField("Job title", text: $model.selectedTitle)
                            .accessibilityIdentifier("selected-opportunity-title")
                        TextField("Company", text: $model.selectedCompany)
                        TextField("Job URL (optional)", text: $model.selectedJobURL)
                        TextField("Job description (optional)", text: $model.selectedJobDescription, axis: .vertical)
                        TextField("Notes (optional)", text: $model.selectedNotes, axis: .vertical)
                        Picker("Stage", selection: $model.selectedStage) {
                            ForEach(PipelineStage.allCases, id: \.self) { stage in
                                Text(stage.rawValue).tag(stage)
                            }
                        }
                        TextField("Next action (optional)", text: $model.selectedNextAction)
                        Toggle("Add a due date", isOn: $model.selectedHasDueDate)
                        if model.selectedHasDueDate {
                            DatePicker("Due", selection: $model.selectedDueAt, displayedComponents: [.date, .hourAndMinute])
                        }
                        HStack {
                            Button("Save changes locally") { model.saveSelectedOpportunity() }
                                .accessibilityIdentifier("save-opportunity-changes")
                            Button("Reschedule action") { model.rescheduleSelectedTask() }
                                .disabled(model.selectedNextAction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    if let task = model.selectedTask {
                        LabeledContent("Task status", value: task.isComplete ? "Completed" : "Active")
                        Text("Tracked action: \(task.title)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No tracked next action.")
                            .foregroundStyle(.secondary)
                    }
                    if !model.selectedStageHistory.isEmpty {
                        Text("Stage history").font(.headline)
                        ForEach(model.selectedStageHistory, id: \.id) { entry in
                            Text("\(entry.fromStage?.rawValue ?? "Created") → \(entry.toStage.rawValue) · \(entry.occurredAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                        }
                    }
                    if model.selectedActivityEvents.isEmpty {
                        Text("No activity for this opportunity yet.").foregroundStyle(.secondary)
                    } else {
                        Text("Activity").font(.headline)
                        ForEach(model.selectedActivityEvents, id: \.id) { event in
                            Text("\(event.kind.replacingOccurrences(of: "_", with: " ").capitalized) · \(event.occurredAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                        }
                    }
                    GroupBox("Contacts") {
                        if model.selectedContacts.isEmpty {
                            Text("No contacts are linked to this opportunity.").foregroundStyle(.secondary)
                        } else {
                            ForEach(model.selectedContacts, id: \.id) { contact in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(contact.name)
                                        Text([contact.title, contact.employer].filter { !$0.isEmpty }.joined(separator: " · "))
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Button("Unlink") { model.unlink(contact) }
                                }
                            }
                        }
                        if !model.selectedSameEmployerContacts.isEmpty {
                            Text("At this employer").font(.headline)
                            ForEach(model.selectedSameEmployerContacts, id: \.id) { contact in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(contact.name)
                                        Text(contact.title.isEmpty ? contact.employer : "\(contact.title) · \(contact.employer)")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Button("Link") { model.link(contact) }
                                }
                            }
                        }
                    }
                    GroupBox("Relationship history") {
                        if model.selectedOpportunityInteractions.isEmpty {
                            Text("No contact interactions are recorded for this opportunity yet.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(model.selectedOpportunityInteractions, id: \.id) { interaction in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(interaction.contactName ?? "Prior note") · \(interaction.kind.rawValue) · \(interaction.occurredAt.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption.bold())
                                    Text(interaction.summary)
                                    if let nextTouchAt = interaction.nextTouchAt {
                                        Text("Next touch: \(nextTouchAt.formatted(date: .abbreviated, time: .shortened))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                    GroupBox("Reconcile opening") {
                        Text("Review the posting yourself, then save the outcome and evidence. This app does not check the web or change the opportunity stage automatically.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let url = URL(string: model.selectedJobURL), !model.selectedJobURL.isEmpty {
                            Link("Open job posting", destination: url)
                        } else {
                            Text("Add a job URL to review this opening.")
                                .foregroundStyle(.secondary)
                        }
                        Form {
                            Picker("Outcome", selection: $model.postingStatus) {
                                ForEach(PostingStatus.allCases, id: \.self) { status in
                                    Text(status.rawValue).tag(status)
                                }
                            }
                            TextField("Evidence or error reviewed", text: $model.postingEvidence, axis: .vertical)
                            Button("Save reconciliation locally") { model.recordPostingCheck() }
                                .disabled(!model.workspaceReady || model.selectedJobURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.postingEvidence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        if model.selectedPostingChecks.isEmpty {
                            Text("No reconciliation recorded yet.")
                                .foregroundStyle(.secondary)
                        } else {
                            Text("History").font(.headline)
                            ForEach(model.selectedPostingChecks, id: \.id) { check in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(check.status.rawValue) · \(check.checkedAt.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption.bold())
                                    Text(check.evidence)
                                        .font(.caption)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                    GroupBox("Résumé and cover-letter references") {
                        Text("Choose a local PDF or DOCX. Rekon Pursuit stores its filename, size, and SHA-256 hash only; it does not copy, edit, or upload the file.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            Picker("Reference type", selection: $model.documentReferenceKind) {
                                ForEach(DocumentReferenceKind.allCases, id: \.self) { kind in
                                    Text(kind.rawValue).tag(kind)
                                }
                            }
                            Button("Choose PDF or DOCX…") { showsDocumentReferenceImporter = true }
                                .disabled(!model.workspaceReady)
                                .accessibilityIdentifier("choose-document-reference")
                        }
                        if model.selectedDocumentReferences.isEmpty {
                            Text("No document references attached.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(model.selectedDocumentReferences, id: \.id) { reference in
                                HStack(alignment: .firstTextBaseline) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(reference.kind.rawValue) · \(reference.filename)")
                                        Text("SHA-256 \(reference.sourceHash.prefix(12))… · \(reference.byteCount.formatted()) bytes")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        if let finalSentAt = reference.finalSentAt {
                                            Text("Final sent: \(finalSentAt.formatted(date: .abbreviated, time: .shortened))")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    if reference.finalSentAt == nil {
                                        Button("Mark final sent") { model.markDocumentReferenceFinalSent(reference) }
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }
            }
            }

            if page == .needsAttention {
            Text("Needs Attention")
                .font(.title2.bold())
                .accessibilityIdentifier("needs-attention-home")
            GroupBox("Needs Attention") {
                if model.needsAttention.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No next actions yet.").foregroundStyle(.secondary)
                        Button("Add an opportunity") { page = .addOpportunity }
                            .accessibilityIdentifier("show-add-opportunity")
                    }
                } else {
                    ForEach(model.needsAttention, id: \.id) { task in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(task.title)
                                Text(task.dueAt.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "No due date")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Open") {
                                model.open(task)
                                page = .pipeline
                            }
                            Button("Snooze 1 day") { model.snoozeOneDay(task) }
                            Button("Reschedule…") {
                                taskToReschedule = task
                                rescheduledDueAt = task.dueAt ?? Date.now
                            }
                            Button("Complete") { model.complete(task) }
                        }
                    }
                }
            }
            }

            if page == .contacts {
                GroupBox("Contacts") {
                    if model.contacts.isEmpty {
                        Text("No contacts yet. Add a person you want to remember.").foregroundStyle(.secondary)
                    } else {
                        HStack {
                            TextField("Search contacts", text: $model.contactSearch)
                                .accessibilityIdentifier("contact-search")
                            Picker("Employer", selection: $model.contactEmployerFilter) {
                                Text("All employers").tag("All employers")
                                ForEach(model.contactEmployers, id: \.self) { employer in
                                    Text(employer).tag(employer)
                                }
                            }
                        }
                        if model.filteredContacts.isEmpty {
                            Text("No contacts match that filter.").foregroundStyle(.secondary)
                        }
                        ForEach(model.filteredContacts, id: \.id) { contact in
                            HStack {
                                Button { model.selectContact(contact) } label: {
                                    VStack(alignment: .leading) {
                                        Text(contact.name)
                                        Text([contact.title, contact.employer].filter { !$0.isEmpty }.joined(separator: " · "))
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                .buttonStyle(.plain)
                                Spacer()
                                Button("Delete", role: .destructive) { pendingContactDeletion = contact }
                            }
                        }
                    }
                }
                GroupBox(model.selectedContact == nil ? "New contact" : "Contact record") {
                    Form {
                        TextField("Name", text: $model.contactName)
                            .accessibilityIdentifier("contact-name")
                        TextField("Current employer (optional)", text: $model.contactEmployer)
                        TextField("Title (optional)", text: $model.contactTitle)
                        TextField("Email (optional)", text: $model.contactEmail)
                        TextField("Profile URL (optional)", text: $model.contactProfileURL)
                        TextField("Relationship context (optional)", text: $model.contactRelationshipContext)
                        TextField("Notes (optional)", text: $model.contactNotes, axis: .vertical)
                        HStack {
                            Button("New contact") { model.beginNewContact() }
                            Spacer()
                            if model.selectedContact == nil {
                                Button("Save contact locally") { model.createContact() }
                                    .disabled(!model.workspaceReady || model.contactName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                    .accessibilityIdentifier("save-contact")
                            } else {
                                Button("Save changes locally") { model.saveSelectedContact() }
                                    .disabled(!model.workspaceReady || model.contactName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }
                    }
                }
                if model.selectedContact != nil {
                    GroupBox("Linked opportunities") {
                        if model.selectedContactOpportunities.isEmpty {
                            Text("This contact is not linked to an active opportunity.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(model.selectedContactOpportunities, id: \.id) { opportunity in
                                Button {
                                    model.select(opportunity)
                                    page = .pipeline
                                } label: {
                                    VStack(alignment: .leading) {
                                        Text(opportunity.title)
                                        Text("\(opportunity.company) · \(opportunity.stage.rawValue)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    GroupBox("Interaction history") {
                        HStack {
                            LabeledContent("Last touch", value: model.selectedContactLastTouch?.formatted(date: .abbreviated, time: .shortened) ?? "None yet")
                            Spacer()
                            LabeledContent("Next touch", value: model.selectedContactNextTouch?.formatted(date: .abbreviated, time: .shortened) ?? "Not scheduled")
                        }
                        if model.selectedContactInteractions.isEmpty {
                            Text("No local interactions yet. Log a call, email, meeting, or note.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(model.selectedContactInteractions, id: \.id) { interaction in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(interaction.kind.rawValue) · \(interaction.occurredAt.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption.bold())
                                    Text(interaction.summary)
                                    if let nextTouchAt = interaction.nextTouchAt {
                                        Text("Next touch: \(nextTouchAt.formatted(date: .abbreviated, time: .shortened))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        Form {
                            Picker("Type", selection: $model.interactionKind) {
                                ForEach(InteractionKind.allCases, id: \.self) { kind in
                                    Text(kind.rawValue).tag(kind)
                                }
                            }
                            TextField("What happened?", text: $model.interactionSummary, axis: .vertical)
                                .accessibilityIdentifier("interaction-summary")
                            DatePicker("Occurred", selection: $model.interactionOccurredAt, displayedComponents: [.date, .hourAndMinute])
                            Picker("Linked opportunity", selection: $model.interactionOpportunityID) {
                                Text("None").tag("")
                                ForEach(model.selectedContactOpportunities, id: \.id) { opportunity in
                                    Text("\(opportunity.title) · \(opportunity.company)").tag(opportunity.id)
                                }
                            }
                            Toggle("Schedule next touch", isOn: $model.interactionHasNextTouch)
                            if model.interactionHasNextTouch {
                                DatePicker("Next touch", selection: $model.interactionNextTouchAt, displayedComponents: [.date, .hourAndMinute])
                            }
                            Button("Save interaction locally") { model.recordSelectedContactInteraction() }
                                .disabled(!model.workspaceReady || model.interactionSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                .accessibilityIdentifier("save-contact-interaction")
                        }
                    }
                }
            }

            if page == .activityAndAI {
                GroupBox("Local activity ledger") {
                    Text("A read-only record of actions completed in this workspace. Activity stays on this Mac.")
                        .foregroundStyle(.secondary)
                    TextField("Search activity", text: $model.activitySearch)
                        .accessibilityIdentifier("activity-search")
                    if model.filteredActivityEvents.isEmpty {
                        Text(model.activityEvents.isEmpty ? "No local activity yet." : "No activity matches that search.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(model.filteredActivityEvents, id: \.id) { event in
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(event.kind.replacingOccurrences(of: "_", with: " ").capitalized)
                                    Text(event.occurredAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if let opportunity = model.opportunities.first(where: { $0.id == event.opportunityID }) {
                                    Text("\(opportunity.title) · \(opportunity.company)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                GroupBox("AI usage and cost") {
                    Text("No AI requests have been made. Cloud AI, local-model execution, and cost tracking are intentionally unavailable in this MVP.")
                        .foregroundStyle(.secondary)
                }
            }

            if page == .settings {
                GroupBox("Workspace") {
                    Text("Your workspace is encrypted and stays on this Mac. Active records are retained until you delete them.")
                        .foregroundStyle(.secondary)
                    Toggle("Show closed opportunities in the pipeline", isOn: $model.showClosedOpportunities)
                        .accessibilityIdentifier("show-closed-opportunities")
                }

                GroupBox("Data and recovery") {
                    Text("CSV exports are unencrypted. Encrypted backups can be restored on this Mac after a clear replacement confirmation.")
                        .foregroundStyle(.secondary)
                    HStack {
                        Button("Export opportunities as CSV…") { showsUnencryptedExportWarning = true }
                            .disabled(!model.workspaceReady || model.opportunities.isEmpty)
                        Button("Create encrypted backup…") {
                            let panel = NSSavePanel()
                            panel.nameFieldStringValue = "rekon-pursuit-backup.rekonbackup"
                            panel.canCreateDirectories = true
                            if panel.runModal() == .OK, let url = panel.url {
                                model.createEncryptedBackup(at: url)
                            }
                        }
                        .disabled(!model.workspaceReady)
                        Button("Restore encrypted backup…") { showsBackupImporter = true }
                            .disabled(!model.workspaceReady)
                    }
                }

                GroupBox("AI and connections") {
                    Text("Cloud AI, local-model execution, Gmail, and Google Calendar are disabled in this MVP. No network connections are configured.")
                        .foregroundStyle(.secondary)
                }
            }

            if page == .needsAttention {
            GroupBox("Local activity") {
                if model.activityEvents.isEmpty {
                    Text("No local activity yet.").foregroundStyle(.secondary)
                } else {
                    ForEach(model.activityEvents, id: \.id) { event in
                        Text(event.kind.replacingOccurrences(of: "_", with: " ").capitalized)
                    }
                }
            }

            }

            Text("This MVP keeps data on this Mac. CSV exports are unencrypted; encrypted backup is same-Mac only and replaces the current workspace after confirmation.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("\(model.opportunityCount) opportunities · \(model.needsAttentionCount) needs attention · \(model.activityCount) activity events")
                .foregroundStyle(.secondary)
            Text(model.statusMessage)
                .accessibilityIdentifier("workspace-status")
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        }
        .onAppear { model.start() }
        .fileImporter(
            isPresented: $showsBackupImporter,
            allowedContentTypes: [.data],
            allowsMultipleSelection: false
        ) { result in
            if case let .success(urls) = result, let url = urls.first {
                pendingRestoreURL = model.stageEncryptedBackupForRestore(from: url)
            }
        }
        .fileImporter(
            isPresented: $showsDocumentReferenceImporter,
            allowedContentTypes: [.pdf, UTType(filenameExtension: "docx") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            if case let .success(urls) = result, let url = urls.first {
                model.attachDocumentReference(at: url)
            }
        }
        .fileExporter(
            isPresented: $showsCSVExporter,
            document: exportDocument,
            contentType: .commaSeparatedText,
            defaultFilename: "rekon-pursuit-opportunities"
        ) { result in
            if case .success = result {
                model.noteExportSaved()
            }
            exportDocument = nil
        }
        .alert("Export unencrypted CSV?", isPresented: $showsUnencryptedExportWarning) {
            Button("Export unencrypted CSV") {
                if let csv = model.exportOpportunitiesCSV() {
                    exportDocument = CSVExportDocument(text: csv)
                    showsCSVExporter = true
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This file will contain your job titles, companies, actions, dates, and job URLs in plain text. Save it only to storage you trust.")
        }
        .alert("Replace current workspace?", isPresented: Binding(
            get: { pendingRestoreURL != nil },
            set: { if !$0 { pendingRestoreURL = nil; model.discardStagedBackupRestore() } }
        )) {
            Button("Restore and replace", role: .destructive) {
                if let pendingRestoreURL { model.restoreEncryptedBackup(from: pendingRestoreURL) }
                pendingRestoreURL = nil
            }
            Button("Cancel", role: .cancel) { pendingRestoreURL = nil; model.discardStagedBackupRestore() }
        } message: {
            Text("This replaces the current local workspace with the selected same-Mac encrypted backup. Your current workspace is kept if the restore fails.")
        }
        .alert("Delete opportunity?", isPresented: Binding(
            get: { pendingDeletion != nil },
            set: { if !$0 { pendingDeletion = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let pendingDeletion { model.deleteOpportunity(pendingDeletion) }
                pendingDeletion = nil
            }
            Button("Cancel", role: .cancel) { pendingDeletion = nil }
        } message: {
            Text("This removes the opportunity and its pending actions from the active tracker. A redacted local deletion record is retained.")
        }
        .alert("Delete contact?", isPresented: Binding(
            get: { pendingContactDeletion != nil },
            set: { if !$0 { pendingContactDeletion = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let pendingContactDeletion { model.deleteContact(pendingContactDeletion) }
                pendingContactDeletion = nil
            }
            Button("Cancel", role: .cancel) { pendingContactDeletion = nil }
        } message: {
            Text("This removes the contact from active lists and links. A redacted local deletion record is retained.")
        }
        .sheet(isPresented: Binding(
            get: { taskToReschedule != nil },
            set: { if !$0 { taskToReschedule = nil } }
        )) {
            if let task = taskToReschedule {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Reschedule action")
                        .font(.title2.bold())
                    Text(task.title)
                        .foregroundStyle(.secondary)
                    DatePicker("New due date", selection: $rescheduledDueAt, displayedComponents: [.date, .hourAndMinute])
                    HStack {
                        Button("Cancel") { taskToReschedule = nil }
                            .keyboardShortcut(.cancelAction)
                        Spacer()
                        Button("Save locally") {
                            model.reschedule(task, to: rescheduledDueAt)
                            taskToReschedule = nil
                        }
                        .keyboardShortcut(.defaultAction)
                    }
                }
                .padding(24)
                .frame(width: 380)
            }
        }
    }

    @ViewBuilder
    private var workspaceGate: some View {
        GroupBox("Local workspace") {
            VStack(alignment: .leading, spacing: 10) {
                Text(model.statusMessage)
                if !model.workspaceReady {
                    if model.canCreateWorkspace {
                        Button("Create local workspace") {
                            model.createWorkspaceIfNeeded()
                        }
                        .accessibilityIdentifier("create-local-workspace")
                    } else if model.workspaceRequiresRecovery {
                        Text("Recovery is required before this workspace can be opened. Rekon Pursuit kept the existing local material unchanged and will not create over it.")
                            .foregroundStyle(.secondary)
                        Button("Recheck local workspace") {
                            model.retryWorkspaceOpen()
                        }
                        .accessibilityIdentifier("recheck-local-workspace")
                    } else {
                        Button("Retry opening workspace") {
                            model.retryWorkspaceOpen()
                        }
                        .accessibilityIdentifier("retry-local-workspace")
                    }
                    Text("CSV import becomes available after the local workspace is ready.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Workspace ready. All records remain local to this Mac.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityIdentifier("workspace-gate")
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

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            model.previewCSV(at: url)
        }
    }
}
