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

            Text("\(model.opportunityCount) opportunities · \(model.activityCount) activity events")
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
