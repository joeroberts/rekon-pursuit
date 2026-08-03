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
    let upcomingOpportunities: [Opportunity]

    init(
        opportunities: [Opportunity],
        attentionTasks: [TaskReminder],
        now: Date,
        calendar: Calendar
    ) {
        let incompleteTasks = attentionTasks
            .filter { !$0.isComplete && ($0.dueAt.map { $0 <= now } ?? true) }
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
        upcomingOpportunities = opportunities
            .filter { opportunity in
                guard let dueAt = opportunity.dueAt,
                      opportunity.stage != .closed,
                      dueAt >= now,
                      dueAt <= calendar.date(byAdding: .day, value: 7, to: now)! else { return false }
                return !opportunity.nextAction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            .sorted { ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture) }
    }
}

struct HomeView: View {
    @ObservedObject var model: WorkspaceViewModel
    let open: (TaskReminder) -> Void
    let openUpcoming: (Opportunity) -> Void
    let addOpportunity: () -> Void
    let reschedule: (TaskReminder) -> Void
    let now: Date
    let calendar: Calendar

    init(
        model: WorkspaceViewModel,
        open: @escaping (TaskReminder) -> Void,
        openUpcoming: @escaping (Opportunity) -> Void,
        addOpportunity: @escaping () -> Void,
        reschedule: @escaping (TaskReminder) -> Void,
        now: Date = .now,
        calendar: Calendar = .current
    ) {
        self.model = model
        self.open = open
        self.openUpcoming = openUpcoming
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
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    attentionSection
                    snapshotSection
                    upcomingSection
                }
                .padding(proxy.size.width < 640 ? 16 : 32)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("home-content")
            }
        }
        .accessibilityIdentifier("home-content")
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center) {
                title
                Spacer()
                addOpportunityButton
            }
            VStack(alignment: .leading, spacing: 12) {
                title
                HStack {
                    Spacer()
                    addOpportunityButton
                }
            }
        }
    }

    private var title: some View {
        Text("Home")
            .font(.system(size: 42, weight: .bold, design: .rounded))
            .foregroundStyle(RekonTheme.primaryText)
    }

    private var addOpportunityButton: some View {
        Button(action: addOpportunity) {
            Text("Add opportunity")
                .frame(minHeight: 28)
        }
        .buttonStyle(RekonPrimaryButtonStyle())
        .accessibilityIdentifier("show-add-opportunity")
    }

    @ViewBuilder
    private var attentionSection: some View {
        HomeSectionPanel {
            HomeSectionHeader(
                title: "Needs attention",
                subtitle: attentionSubtitle,
                symbol: "bell",
                tint: RekonTheme.violet
            )
            if snapshot.attentionTasks.isEmpty {
                HomeEmptyAttentionCard(addOpportunity: addOpportunity)
            } else {
                VStack(spacing: 8) {
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
    }

    private var snapshotSection: some View {
        HomeSectionPanel {
            HomeSectionHeader(
                title: "Pipeline snapshot",
                subtitle: "Your opportunities at a glance",
                symbol: "chart.bar.xaxis",
                tint: RekonTheme.accent
            )
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
            symbol: "briefcase",
            tint: RekonTheme.success,
            accessibilityIdentifier: "home-active-opportunities"
        )
        HomeMetricCard(
            title: "Applied this week",
            value: snapshot.appliedThisWeekCount,
            symbol: "paperplane",
            tint: RekonTheme.accent,
            accessibilityIdentifier: "home-applied-this-week"
        )
        HomeMetricCard(
            title: "Interviews",
            value: snapshot.interviewCount,
            symbol: "person.2",
            tint: RekonTheme.violet,
            accessibilityIdentifier: "home-interviews"
        )
    }

    @ViewBuilder
    private var upcomingSection: some View {
        let opportunities = Array(snapshot.upcomingOpportunities.prefix(3))
        HomeSectionPanel {
            HomeSectionHeader(
                title: "Next up",
                subtitle: "Your upcoming actions",
                symbol: "clock",
                tint: RekonTheme.accent
            )
            if opportunities.isEmpty {
                HomeEmptyUpcomingCard()
            } else {
                VStack(spacing: 10) {
                    ForEach(opportunities, id: \.id) { opportunity in
                        HomeUpcomingTaskRow(opportunity: opportunity, open: { openUpcoming(opportunity) })
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

    private func opportunity(for task: TaskReminder) -> Opportunity? {
        model.opportunities.first { $0.id == task.opportunityID }
    }
}

private struct HomeSectionPanel<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
        }
        .padding(20)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RekonTheme.surfaceGradient, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(RekonTheme.border.opacity(0.82), lineWidth: 1)
        )
    }
}

private struct HomeSectionHeader: View {
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 23, weight: .medium))
                .foregroundStyle(LinearGradient(colors: [tint, tint.opacity(0.58)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 54, height: 54)
                .background(LinearGradient(colors: [tint.opacity(0.25), tint.opacity(0.07)], startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
                .overlay(Circle().stroke(tint.opacity(0.5), lineWidth: 1))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(RekonTheme.primaryText)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(RekonTheme.secondaryText)
            }
        }
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
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 10) {
                taskIcon
                identity
                Spacer(minLength: 0)
                dueDate
                actionMenu
                openButton(minimumWidth: 150)
            }
            .frame(minWidth: 700, alignment: .leading)
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 10) {
                    taskIcon
                    identity
                }
                HStack(spacing: 8) {
                    dueDate
                    actionMenu
                    Spacer(minLength: 0)
                    openButton(minimumWidth: 108)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RekonTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(RekonTheme.border.opacity(0.82), lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home-attention-\(task.id)")
    }

    private var taskIcon: some View {
        Image(systemName: "briefcase")
            .font(.title2)
            .foregroundStyle(LinearGradient(colors: [RekonTheme.violet, RekonTheme.violet.opacity(0.58)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 54, height: 54)
            .background(LinearGradient(colors: [RekonTheme.violet.opacity(0.25), RekonTheme.violet.opacity(0.07)], startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
            .overlay(Circle().stroke(RekonTheme.violet.opacity(0.45), lineWidth: 1))
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(opportunity?.title ?? task.title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(RekonTheme.primaryText)
                .lineLimit(2)
            Text(opportunity.map { "\($0.company) · \(task.title)" } ?? task.title)
                .font(.subheadline)
                .foregroundStyle(RekonTheme.secondaryText)
                .lineLimit(2)
        }
        .layoutPriority(1)
    }

    private var actionMenu: some View {
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
    }

    private func openButton(minimumWidth: CGFloat) -> some View {
        Button("Open", action: open)
            .buttonStyle(RekonSecondaryButtonStyle())
            .frame(minWidth: minimumWidth)
            .accessibilityLabel("Open \(task.title)")
            .accessibilityIdentifier("home-open-\(task.id)")
    }

    private var dueDate: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(task.title, systemImage: "calendar")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(RekonTheme.primaryText)
                .lineLimit(1)
            Text(relativeDueLabel)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(dueColor)
        }
        .frame(minWidth: 0, idealWidth: 128, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 9)
        .background(RekonTheme.backgroundRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityIdentifier("home-due-\(task.id)")
        .accessibilityValue(task.dueAt.map { String($0.timeIntervalSince1970) } ?? "none")
    }

    private var relativeDueLabel: String {
        guard let dueAt = task.dueAt else { return "No due date" }
        return "Due \(dueAt.formatted(.relative(presentation: .named)))"
    }

    private var dueColor: Color {
        guard let dueAt = task.dueAt else { return RekonTheme.secondaryText }
        return dueAt < .now ? RekonTheme.danger : RekonTheme.warning
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
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [tint, tint.opacity(0.58)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 50, height: 50)
                .background(
                    LinearGradient(
                        colors: [tint.opacity(0.24), tint.opacity(0.07)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: Circle()
                )
                .overlay(Circle().stroke(tint.opacity(0.18), lineWidth: 1))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(RekonTheme.secondaryText)
                Text(value, format: .number)
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.headline.weight(.semibold))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
        .background(RekonTheme.backgroundRaised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(tint.opacity(0.65), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private struct HomeUpcomingTaskRow: View {
    let opportunity: Opportunity
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 14) {
                    taskIcon
                    schedule
                    identity
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(RekonTheme.secondaryText)
                }
                .frame(minWidth: 640, alignment: .leading)
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        taskIcon
                        identity
                    }
                    HStack {
                        schedule
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(RekonTheme.secondaryText)
                    }
                }
            }
            .padding(14)
            .background(RekonTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(RekonTheme.border.opacity(0.75), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var schedule: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(opportunity.dueAt?.formatted(.dateTime.weekday(.wide)) ?? "Upcoming")
                .font(.caption.weight(.semibold))
                .foregroundStyle(RekonTheme.secondaryText)
            Text(opportunity.dueAt?.formatted(date: .omitted, time: .shortened) ?? "No time set")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(RekonTheme.secondaryText)
        }
        .frame(width: 94, alignment: .leading)
    }

    private var taskIcon: some View {
        Image(systemName: "briefcase")
            .foregroundStyle(LinearGradient(colors: [RekonTheme.violet, RekonTheme.violet.opacity(0.58)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 40, height: 40)
            .background(LinearGradient(colors: [RekonTheme.violet.opacity(0.25), RekonTheme.violet.opacity(0.07)], startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(opportunity.nextAction) — \(opportunity.title)")
                .foregroundStyle(RekonTheme.primaryText)
                .lineLimit(2)
            Text(opportunity.company)
                .font(.subheadline)
                .foregroundStyle(RekonTheme.secondaryText)
                .lineLimit(1)
        }
        .layoutPriority(1)
    }
}

private struct HomeEmptyUpcomingCard: View {
    var body: some View {
        VStack(spacing: 9) {
            Image(systemName: "sparkles")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [RekonTheme.violet, RekonTheme.accent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text("Nothing scheduled this week")
                .font(.headline.weight(.semibold))
                .foregroundStyle(RekonTheme.primaryText)
            Text("Upcoming meetings and next actions will appear here.")
                .font(.subheadline)
                .foregroundStyle(RekonTheme.secondaryText)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, minHeight: 150)
        .padding(.vertical, 12)
        .accessibilityIdentifier("home-empty-next-up")
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
