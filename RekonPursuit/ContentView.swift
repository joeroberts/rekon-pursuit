import SwiftUI

enum BootstrapCopy {
    nonisolated static let status = "Local-only foundation"
}

private enum TrackerPage: String, CaseIterable {
    case home = "Needs Attention"
    case pipeline = "Pipeline"
    case add = "Add opportunity"
}

struct ContentView: View {
    @StateObject private var model = WorkspaceViewModel()
    @State private var pendingDeletion: Opportunity?
    @State private var showsPipelineBoard = false
    @State private var page: TrackerPage = .home

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Rekon Pursuit")
                .font(.largeTitle.bold())
            Text("Local job tracker")
                .foregroundStyle(.secondary)

            Picker("Workspace", selection: $page) {
                ForEach(TrackerPage.allCases, id: \.self) { page in
                    Text(page.rawValue).tag(page)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("workspace-navigation")

            if page == .add {
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
            }

            if page == .add && model.canCreateWorkspace {
                Button("Create new local workspace") {
                    model.createWorkspaceIfNeeded()
                }
                .accessibilityIdentifier("create-local-workspace")
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
                    if model.selectedActivityEvents.isEmpty {
                        Text("No activity for this opportunity yet.").foregroundStyle(.secondary)
                    } else {
                        Text("History").font(.headline)
                        ForEach(model.selectedActivityEvents, id: \.id) { event in
                            Text("\(event.kind.replacingOccurrences(of: "_", with: " ").capitalized) · \(event.occurredAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                        }
                    }
                }
            }
            }

            if page == .home {
            Text("Needs Attention")
                .font(.title2.bold())
                .accessibilityIdentifier("needs-attention-home")
            GroupBox("Needs Attention") {
                if model.needsAttention.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No next actions yet.").foregroundStyle(.secondary)
                        Button("Add an opportunity") { page = .add }
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
                            Button("Complete") { model.complete(task) }
                        }
                    }
                }
            }
            .accessibilityIdentifier("needs-attention-home")
            }

            if page == .home {
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
        .frame(minWidth: 760, minHeight: 520, alignment: .topLeading)
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
