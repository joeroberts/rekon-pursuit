import SwiftUI

enum BootstrapCopy {
    nonisolated static let status = "Local-only foundation"
}

struct ContentView: View {
    @StateObject private var model = WorkspaceViewModel()
    @State private var pendingDeletion: Opportunity?

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
                .disabled(!model.workspaceReady || model.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.company.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if model.canCreateWorkspace {
                Button("Create new local workspace") {
                    model.createWorkspaceIfNeeded()
                }
                .accessibilityIdentifier("create-local-workspace")
            }

            GroupBox("Opportunities") {
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
                            Button("Delete", role: .destructive) {
                                pendingDeletion = opportunity
                            }
                        }
                    }
                }
            }

            GroupBox("Local activity") {
                if model.activityEvents.isEmpty {
                    Text("No local activity yet.").foregroundStyle(.secondary)
                } else {
                    ForEach(model.activityEvents, id: \.id) { event in
                        Text(event.kind.replacingOccurrences(of: "_", with: " ").capitalized)
                    }
                }
            }

            Text("This MVP keeps data on this Mac. Backup, restore, and export are not available yet.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("\(model.opportunityCount) opportunities · \(model.activityCount) activity events")
                .foregroundStyle(.secondary)
            Text(model.statusMessage)
                .accessibilityIdentifier("workspace-status")
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(minWidth: 560, minHeight: 420, alignment: .topLeading)
        .onAppear { model.start() }
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
    }
}
