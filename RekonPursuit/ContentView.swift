import SwiftUI

enum BootstrapCopy {
    nonisolated static let status = "Local-only foundation"
}

struct ContentView: View {
    @StateObject private var model = WorkspaceViewModel()

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
                        VStack(alignment: .leading) {
                            Text(task.title)
                            Text(task.dueAt, style: .date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
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
    }
}
