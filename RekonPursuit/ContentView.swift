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
                            Picker("Stage for \(opportunity.title)", selection: Binding(
                                get: { opportunity.stage },
                                set: { model.changeStage(opportunity, to: $0) }
                            )) {
                                ForEach(PipelineStage.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                            }
                            .labelsHidden()
                            Button("Delete", role: .destructive) {
                                pendingDeletion = opportunity
                            }
                        }
                    }
                }
            }

            GroupBox("Needs Attention") {
                if model.needsAttention.isEmpty {
                    Text("No next actions yet.").foregroundStyle(.secondary)
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
                            Button("Snooze 1 day") { model.snoozeOneDay(task) }
                            Button("Complete") { model.complete(task) }
                        }
                    }
                }
            }

            GroupBox("Contacts & interactions") {
                TextField("Contact name", text: $model.contactName)
                TextField("Employer", text: $model.contactEmployer)
                Button("Save contact locally") { model.createContact() }
                    .disabled(!model.workspaceReady || model.contactName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.contactEmployer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if !model.opportunities.isEmpty {
                    Picker("Opportunity", selection: $model.selectedOpportunityID) {
                        ForEach(model.opportunities, id: \.id) { opportunity in
                            Text("\(opportunity.title) · \(opportunity.company)").tag(opportunity.id)
                        }
                    }
                    TextField("Interaction note", text: $model.interactionSummary)
                    Button("Save interaction locally") { model.recordInteraction() }
                        .disabled(!model.workspaceReady || model.selectedOpportunityID.isEmpty || model.interactionSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                ForEach(model.contacts, id: \.id) { contact in
                    HStack {
                        Text("\(contact.name) · \(contact.employer)")
                        Spacer()
                        Button("Link") { model.link(contact) }
                            .disabled(!model.workspaceReady || model.selectedOpportunityID.isEmpty)
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

            Text("\(model.opportunityCount) opportunities · \(model.needsAttentionCount) needs attention · \(model.activityCount) activity events")
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
