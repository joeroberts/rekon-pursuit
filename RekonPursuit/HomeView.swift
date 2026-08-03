import Foundation
import SwiftUI

/// A read-only, live-data projection for the Home screen. It deliberately
/// derives every displayed count from the current workspace rather than
/// persisting another summary that could diverge from the source records.
struct HomeDashboardSnapshot: Equatable {
    let attentionTasks: [TaskReminder]
    let activeOpportunityCount: Int
    let appliedThisWeekCount: Int
    let interviewCount: Int
    let upcomingTasks: [TaskReminder]

    init(
        opportunities: [Opportunity],
        attentionTasks: [TaskReminder],
        now: Date,
        calendar: Calendar
    ) {
        let incompleteTasks = attentionTasks
            .filter { !$0.isComplete }
            .sorted { lhs, rhs in
                switch (lhs.dueAt, rhs.dueAt) {
                case let (left?, right?):
                    return left == right ? lhs.id < rhs.id : left < right
                case (.some, .none):
                    return true
                case (.none, .some):
                    return false
                case (.none, .none):
                    return lhs.id < rhs.id
                }
            }
        self.attentionTasks = incompleteTasks
        activeOpportunityCount = opportunities.filter { $0.stage != .closed }.count
        appliedThisWeekCount = opportunities.filter { opportunity in
            guard opportunity.stage == .applied,
                  let appliedAt = opportunity.applicationDate ?? opportunity.stageChangedAt else {
                return false
            }
            return calendar.isDate(appliedAt, equalTo: now, toGranularity: .weekOfYear)
                && calendar.isDate(appliedAt, equalTo: now, toGranularity: .yearForWeekOfYear)
        }.count
        interviewCount = opportunities.filter { $0.stage == .interviewing }.count
        upcomingTasks = incompleteTasks
    }
}

struct HomeView: View {
    @ObservedObject var model: WorkspaceViewModel
    let open: (TaskReminder) -> Void
    let addOpportunity: () -> Void
    let reschedule: (TaskReminder) -> Void
    let now: Date
    let calendar: Calendar

    init(
        model: WorkspaceViewModel,
        open: @escaping (TaskReminder) -> Void,
        addOpportunity: @escaping () -> Void,
        reschedule: @escaping (TaskReminder) -> Void,
        now: Date = .now,
        calendar: Calendar = .current
    ) {
        self.model = model
        self.open = open
        self.addOpportunity = addOpportunity
        self.reschedule = reschedule
        self.now = now
        self.calendar = calendar
    }

    private var snapshot: HomeDashboardSnapshot {
        HomeDashboardSnapshot(
            opportunities: model.opportunities,
            attentionTasks: model.needsAttention,
            now: now,
            calendar: calendar
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                attentionSection
                snapshotSection
                upcomingSection
            }
            .padding(28)
            .frame(maxWidth: 1_240, alignment: .leading)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("home-content")
        }
        .accessibilityIdentifier("home-content")
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Home")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(RekonTheme.primaryText)
                Text("Your job search, at a glance")
                    .font(.subheadline)
                    .foregroundStyle(RekonTheme.secondaryText)
            }
            Spacer()
            Button(action: addOpportunity) {
                Label("Add opportunity", systemImage: "plus")
            }
            .buttonStyle(RekonPrimaryButtonStyle())
            .accessibilityIdentifier("show-add-opportunity")
        }
    }

    @ViewBuilder
    private var attentionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Needs attention", subtitle: attentionSubtitle)
            if snapshot.attentionTasks.isEmpty {
                HomeEmptyAttentionCard(addOpportunity: addOpportunity)
            } else {
                ForEach(snapshot.attentionTasks.prefix(3), id: \.id) { task in
                    HomeAttentionCard(
                        task: task,
                        opportunity: opportunity(for: task),
                        open: { open(task) },
                        snooze: { model.snoozeOneDay(task) },
                        reschedule: { reschedule(task) },
                        complete: { model.complete(task) }
                    )
                }
            }
        }
    }

    private var snapshotSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Pipeline snapshot", subtitle: "Your opportunities at a glance")
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 14) { metricCards }
                VStack(spacing: 12) { metricCards }
            }
        }
    }

    @ViewBuilder
    private var metricCards: some View {
        HomeMetricCard(
            title: "Active opportunities",
            value: snapshot.activeOpportunityCount,
            symbol: "briefcase.fill",
            tint: RekonTheme.success,
            accessibilityIdentifier: "home-active-opportunities"
        )
        HomeMetricCard(
            title: "Applied this week",
            value: snapshot.appliedThisWeekCount,
            symbol: "paperplane.fill",
            tint: RekonTheme.accent,
            accessibilityIdentifier: "home-applied-this-week"
        )
        HomeMetricCard(
            title: "Interviews",
            value: snapshot.interviewCount,
            symbol: "person.2.fill",
            tint: RekonTheme.violet,
            accessibilityIdentifier: "home-interviews"
        )
    }

    @ViewBuilder
    private var upcomingSection: some View {
        let tasks = Array(snapshot.upcomingTasks.dropFirst(3).prefix(3))
        if !tasks.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(title: "Next up", subtitle: "Your upcoming actions")
                VStack(spacing: 10) {
                    ForEach(tasks, id: \.id) { task in
                        HomeUpcomingTaskRow(task: task, opportunity: opportunity(for: task), open: { open(task) })
                    }
                }
            }
        }
    }

    private var attentionSubtitle: String {
        switch snapshot.attentionTasks.count {
        case 0: "Nothing needs attention right now"
        case 1: "1 item requires your attention"
        default: "\(snapshot.attentionTasks.count) items require your attention"
        }
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.title2.weight(.bold))
                .foregroundStyle(RekonTheme.primaryText)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(RekonTheme.secondaryText)
        }
    }

    private func opportunity(for task: TaskReminder) -> Opportunity? {
        model.opportunities.first { $0.id == task.opportunityID }
    }
}

private struct HomeAttentionCard: View {
    let task: TaskReminder
    let opportunity: Opportunity?
    let open: () -> Void
    let snooze: () -> Void
    let reschedule: () -> Void
    let complete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: "briefcase.fill")
                .font(.title3)
                .foregroundStyle(RekonTheme.violet)
                .frame(width: 42, height: 42)
                .background(RekonTheme.violet.opacity(0.16), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(opportunity?.title ?? task.title)
                    .font(.headline)
                    .foregroundStyle(RekonTheme.primaryText)
                Text(opportunity.map { "\($0.company) · \(task.title)" } ?? task.title)
                    .font(.subheadline)
                    .foregroundStyle(RekonTheme.secondaryText)
            }
            Spacer(minLength: 10)
            dueDate
            Menu {
                Button("Snooze 1 day", action: snooze)
                    .accessibilityIdentifier("home-snooze-\(task.id)")
                Button("Reschedule…", action: reschedule)
                    .accessibilityIdentifier("home-reschedule-\(task.id)")
                if !task.requiresClosureConfirmation {
                    Divider()
                    Button("Complete", action: complete)
                        .accessibilityIdentifier("home-complete-\(task.id)")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 28, height: 28)
            }
            .accessibilityLabel("Actions for \(task.title)")
            .accessibilityIdentifier("home-actions-\(task.id)")
            Button("Open", action: open)
                .buttonStyle(RekonSecondaryButtonStyle())
                .accessibilityLabel("Open \(task.title)")
                .accessibilityIdentifier("home-open-\(task.id)")
        }
        .padding(16)
        .background(RekonTheme.surfaceGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(RekonTheme.border.opacity(0.9), lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home-attention-\(task.id)")
    }

    private var dueDate: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(task.dueAt == nil ? "No due date" : task.dueAt!.formatted(date: .abbreviated, time: .shortened))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(task.dueAt == nil ? RekonTheme.secondaryText : RekonTheme.warning)
            if task.dueAt != nil {
                Label("Due", systemImage: "calendar")
                    .font(.caption)
                .foregroundStyle(RekonTheme.secondaryText)
            }
        }
        .accessibilityIdentifier("home-due-\(task.id)")
        .accessibilityValue(task.dueAt.map { String($0.timeIntervalSince1970) } ?? "none")
    }
}

private struct HomeMetricCard: View {
    let title: String
    let value: Int
    let symbol: String
    let tint: Color
    let accessibilityIdentifier: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(tint)
                .frame(width: 46, height: 46)
                .background(tint.opacity(0.15), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(RekonTheme.secondaryText)
                Text(value, format: .number)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .background(RekonTheme.surfaceGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(tint.opacity(0.56), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private struct HomeUpcomingTaskRow: View {
    let task: TaskReminder
    let opportunity: Opportunity?
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: 14) {
                Image(systemName: "clock.fill")
                    .foregroundStyle(RekonTheme.accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title)
                        .foregroundStyle(RekonTheme.primaryText)
                    if let opportunity {
                        Text("\(opportunity.title) · \(opportunity.company)")
                            .font(.subheadline)
                            .foregroundStyle(RekonTheme.secondaryText)
                    }
                }
                Spacer()
                Text(task.dueAt?.formatted(date: .abbreviated, time: .shortened) ?? "No due date")
                    .font(.subheadline)
                    .foregroundStyle(RekonTheme.secondaryText)
                Image(systemName: "chevron.right")
                    .foregroundStyle(RekonTheme.secondaryText)
            }
            .padding(16)
            .background(RekonTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(RekonTheme.border.opacity(0.75), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private struct HomeEmptyAttentionCard: View {
    let addOpportunity: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 30))
                .foregroundStyle(RekonTheme.success)
            VStack(alignment: .leading, spacing: 4) {
                Text("You’re all caught up")
                    .font(.headline)
                    .foregroundStyle(RekonTheme.primaryText)
                Text("Add an opportunity when you’re ready to track one.")
                    .font(.subheadline)
                    .foregroundStyle(RekonTheme.secondaryText)
            }
            Spacer()
            Button("Add opportunity", action: addOpportunity)
                .buttonStyle(RekonSecondaryButtonStyle())
        }
        .padding(18)
        .background(RekonTheme.surfaceGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(RekonTheme.border.opacity(0.9), lineWidth: 1))
    }
}
