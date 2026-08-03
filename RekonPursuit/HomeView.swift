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
            .filter { task in
                guard !task.isComplete, let dueAt = task.dueAt else { return false }
                return dueAt <= now
            }
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
                guard opportunity.stage != .closed,
                      !opportunity.nextAction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
                guard let dueAt = opportunity.dueAt else { return true }
                return dueAt >= now && dueAt <= calendar.date(byAdding: .day, value: 7, to: now)!
            }
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
        HStack {
            Spacer()
            addOpportunityButton
        }
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
                HomeEmptyAttentionCard()
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
                title: "Opportunities",
                subtitle: "Your opportunities at a glance",
                symbol: "chart.bar.xaxis",
                tint: RekonTheme.accent
            )
            ViewThatFits(in: .horizontal) {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: 14), count: 3),
                    spacing: 14
                ) {
                    metricCards
                }
                .frame(minWidth: 720)
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
        VStack(alignment: .leading, spacing: 18) {
            content
        }
        .padding(24)
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
        HStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: symbol == "clock" ? 30 : 26, weight: title == "Needs attention" ? .bold : .medium))
                .foregroundStyle(LinearGradient(colors: [tint, tint.opacity(0.58)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: symbol == "clock" ? 64 : 60, height: symbol == "clock" ? 64 : 60)
                .background(LinearGradient(colors: [tint.opacity(0.25), tint.opacity(0.07)], startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
                .overlay(Circle().stroke(tint.opacity(0.5), lineWidth: 1))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(RekonTheme.primaryText)
                Text(subtitle)
                    .font(.system(size: 16))
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
    @State private var isActionMenuPresented = false

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 18) {
                taskIcon
                identity
                Spacer(minLength: 0)
                actionMenu
                openButton(width: 180)
            }
            .frame(minWidth: 560, alignment: .leading)
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 10) {
                    taskIcon
                    identity
                }
                HStack(spacing: 8) {
                    actionMenu
                    Spacer(minLength: 0)
                    openButton(width: 124)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RekonTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(RekonTheme.border.opacity(0.82), lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home-attention-\(task.id)")
    }

    private var taskIcon: some View {
        Image(systemName: "briefcase")
            .font(.system(size: 26, weight: .bold))
            .foregroundStyle(LinearGradient(colors: [RekonTheme.violet, RekonTheme.violet.opacity(0.58)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 60, height: 60)
            .background(LinearGradient(colors: [RekonTheme.violet.opacity(0.25), RekonTheme.violet.opacity(0.07)], startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
            .overlay(Circle().stroke(RekonTheme.violet.opacity(0.45), lineWidth: 1))
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(opportunity?.title ?? task.title)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(RekonTheme.primaryText)
                .lineLimit(2)
            Text(opportunity?.company ?? task.title)
                .font(.system(size: 16))
                .foregroundStyle(RekonTheme.secondaryText)
                .lineLimit(2)
        }
        .layoutPriority(1)
    }

    private var actionMenu: some View {
        dueDate
            .overlay {
                Button {
                    isActionMenuPresented.toggle()
                } label: {
                    Color.clear
                        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .frame(width: 188, height: 64)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Actions for \(task.title)")
                .accessibilityIdentifier("home-actions-\(task.id)")
                .popover(isPresented: $isActionMenuPresented, arrowEdge: .bottom) {
                    attentionActionMenu
                }
            }
    }

    private var attentionActionMenu: some View {
        VStack(alignment: .leading, spacing: 4) {
            attentionMenuButton("Snooze 1 day", identifier: "home-snooze-\(task.id)", action: snooze)
            attentionMenuButton("Reschedule…", identifier: "home-reschedule-\(task.id)", action: reschedule)
            if !task.requiresClosureConfirmation {
                Divider()
                    .overlay(RekonTheme.border.opacity(0.8))
                attentionMenuButton("Complete", identifier: "home-complete-\(task.id)", action: complete)
            }
        }
        .padding(8)
        .frame(minWidth: 196, alignment: .leading)
        .rekonFloatingMenuSurface()
    }

    private func attentionMenuButton(_ title: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button {
            isActionMenuPresented = false
            action()
        } label: {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(RekonTheme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    private func openButton(width: CGFloat) -> some View {
        Button("Open", action: open)
            .buttonStyle(RekonAccentOutlineButtonStyle(labelFont: .system(size: 19, weight: .semibold)))
            .frame(width: width, height: 54)
            .accessibilityLabel("Open \(task.title)")
            .accessibilityIdentifier("home-open-\(task.id)")
    }

    private var dueDate: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(RekonTheme.violet)
                Text(actionTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(RekonTheme.primaryText)
                    .lineLimit(1)
            }
            Text(relativeDueLabel)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(dueColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .frame(width: 188, height: 64, alignment: .leading)
        .rekonActionSummarySurface()
        .accessibilityIdentifier("home-due-\(task.id)")
        .accessibilityValue(task.dueAt.map { String($0.timeIntervalSince1970) } ?? "none")
    }

    private var relativeDueLabel: String {
        guard let dueAt = task.dueAt else { return "No due date" }
        return "Due \(dueAt.formatted(.relative(presentation: .named)))"
    }

    private var actionTitle: String {
        if task.requiresClosureConfirmation {
            return "Review reconciliation"
        }
        switch opportunity?.actionType {
        case .apply:
            return "Apply"
        case .followUp:
            return "Follow up"
        case .interviewPrep:
            return "Interview prep"
        case .other:
            let customText = opportunity?.actionCustomText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return customText.isEmpty ? task.title : customText
        case .noAction, .none:
            let nextAction = opportunity?.nextAction.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return nextAction.isEmpty ? task.title : nextAction
        }
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
        HStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [tint, tint.opacity(0.58)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 58, height: 58)
                .background(
                    LinearGradient(
                        colors: [tint.opacity(0.24), tint.opacity(0.07)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: Circle()
                )
                .overlay(Circle().stroke(tint.opacity(0.18), lineWidth: 1))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(RekonTheme.secondaryText)
                Text(value, format: .number)
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
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
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [RekonTheme.violet, RekonTheme.accent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text("Nothing scheduled this week")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(RekonTheme.primaryText)
            Text("Upcoming meetings and next actions will appear here.")
                .font(.system(size: 16))
                .foregroundStyle(RekonTheme.secondaryText)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, minHeight: 150)
        .padding(.vertical, 12)
        .accessibilityIdentifier("home-empty-next-up")
    }
}

private struct HomeEmptyAttentionCard: View {
    var body: some View {
        VStack(spacing: 9) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [RekonTheme.success, RekonTheme.accent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text("You’re all caught up")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(RekonTheme.primaryText)
            Text("Nothing needs your attention right now.")
                .font(.system(size: 16))
                .foregroundStyle(RekonTheme.secondaryText)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, minHeight: 150)
        .padding(.vertical, 12)
        .accessibilityIdentifier("home-empty-attention")
    }
}
