import SwiftUI
import UniformTypeIdentifiers

enum BootstrapCopy {
    nonisolated static let status = "Local-only foundation"
}

struct ContentView: View {
    @StateObject private var model = WorkspaceViewModel()
    @State private var isChoosingCSV = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Rekon Pursuit")
                .font(.largeTitle.bold())
            Text("Local job tracker")
                .foregroundStyle(.secondary)

            Form {
                TextField("Job title", text: $model.title)
                    .accessibilityIdentifier("opportunity-title")
                TextField("Company", text: $model.company)
                    .accessibilityIdentifier("opportunity-company")
                Picker("Stage", selection: $model.stage) {
                    ForEach(PipelineStage.allCases, id: \.self) { stage in
                        Text(stage.rawValue).tag(stage)
                    }
                }
                TextField("Next action (optional)", text: $model.nextAction)
                    .accessibilityIdentifier("opportunity-next-action")
                DatePicker("Due", selection: $model.dueAt, displayedComponents: [.date, .hourAndMinute])
                Button("Save opportunity locally") {
                    model.createOpportunity()
                }
                .accessibilityIdentifier("save-opportunity")
                .keyboardShortcut(.defaultAction)
                .disabled(model.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.company.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if model.canCreateWorkspace {
                Button("Create new local workspace") {
                    model.createWorkspaceIfNeeded()
                }
                .accessibilityIdentifier("create-local-workspace")
            }

            GroupBox("Needs Attention") {
                if model.needsAttention.isEmpty {
                    Text("No upcoming actions.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.needsAttention, id: \.id) { task in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(task.title)
                                Text(task.dueAt, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Snooze 1 day") { model.snoozeOneDay(task) }
                            Button("Complete") { model.complete(task) }
                        }
                    }
                }
            }

            GroupBox("Pipeline") {
                if model.opportunities.isEmpty {
                    Text("No opportunities yet.").foregroundStyle(.secondary)
                } else {
                    ForEach(model.opportunities, id: \.id) { opportunity in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(opportunity.title)
                                Text(opportunity.company).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Picker("Stage for \(opportunity.title)", selection: Binding(
                                get: { opportunity.stage },
                                set: { model.changeStage(opportunity, to: $0) }
                            )) {
                                ForEach(PipelineStage.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                            }
                            .labelsHidden()
                        }
                    }
                }
            }

            GroupBox("Contacts") {
                TextField("Name", text: $model.contactName)
                TextField("Employer", text: $model.contactEmployer)
                Button("Save contact locally") { model.createContact() }
                    .disabled(model.contactName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.contactEmployer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                ForEach(model.contacts, id: \.id) { contact in
                    Text("\(contact.name) · \(contact.employer)")
                }
            }

            GroupBox("CSV import") {
                Button("Choose CSV file") { isChoosingCSV = true }
                if let preview = model.csvPreview {
                    Text("\(preview.validRows.count) valid rows · \(preview.invalidRowCount) invalid rows")
                    Button("Import previewed rows") { model.importCSVPreview() }
                }
            }

            Text("\(model.opportunityCount) opportunities · \(model.needsAttentionCount) needs attention · \(model.activityCount) activity events")
                .foregroundStyle(.secondary)
            Text(model.statusMessage)
                .accessibilityIdentifier("workspace-status")
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(minWidth: 560, minHeight: 420, alignment: .topLeading)
        .onAppear { model.start() }
        .fileImporter(isPresented: $isChoosingCSV, allowedContentTypes: [.commaSeparatedText]) { result in
            if case let .success(url) = result { model.previewCSV(at: url) }
        }
    }
}
