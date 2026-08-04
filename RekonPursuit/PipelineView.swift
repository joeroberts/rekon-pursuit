import SwiftUI

/// A reversible presentation projection for the Board. It does not alter the
/// persisted stage on an opportunity.
nonisolated enum PipelineBoardLane: CaseIterable, Hashable {
    case saved
    case applied
    case screening
    case interviewing
    case offer
    case closed

    var stage: PipelineStage {
        switch self {
        case .saved: .saved
        case .applied: .applied
        case .screening: .screening
        case .interviewing: .interviewing
        case .offer: .offer
        case .closed: .closed
        }
    }

    var dropTarget: PipelineStage { stage }

    func includes(_ stage: PipelineStage) -> Bool {
        self.stage == stage
    }

    static func displayedLanes(includesClosed: Bool) -> [PipelineBoardLane] {
        includesClosed ? [.saved, .applied, .screening, .interviewing, .offer, .closed] : [.saved, .applied, .screening, .interviewing, .offer]
    }

    static func forStage(_ stage: PipelineStage) -> PipelineBoardLane {
        displayedLanes(includesClosed: true).first(where: { $0.includes(stage) }) ?? .saved
    }
}

nonisolated enum PipelineBoardHorizontalLaneResolver {
    static func resolve(
        restoredLane: PipelineBoardLane?,
        anchorStage: PipelineStage?
    ) -> PipelineBoardLane? {
        restoredLane ?? anchorStage.map(PipelineBoardLane.forStage)
    }
}

nonisolated struct PipelineBoardReturnContext: Equatable {
    let query: String
    let stageFilter: String
    let includesClosed: Bool
    let selectedOrAnchoredOpportunityID: String?
    let horizontalScrollLane: PipelineBoardLane?
}

nonisolated struct AddOpportunityCancelDestination: Equatable {
    let route: DailyRoute
    let showsBoard: Bool
    let boardContext: PipelineBoardReturnContext?
}

nonisolated enum AddOpportunityOrigin: Equatable {
    case home
    case pipelineTable
    case pipelineBoard(PipelineBoardReturnContext)

    var cancelDestination: AddOpportunityCancelDestination {
        switch self {
        case .home:
            AddOpportunityCancelDestination(route: .home, showsBoard: false, boardContext: nil)
        case .pipelineTable:
            AddOpportunityCancelDestination(route: .pipeline, showsBoard: false, boardContext: nil)
        case let .pipelineBoard(context):
            AddOpportunityCancelDestination(route: .pipeline, showsBoard: true, boardContext: context)
        }
    }

    static func replacing(_ previous: AddOpportunityOrigin?, with origin: AddOpportunityOrigin) -> AddOpportunityOrigin {
        origin
    }
}

/// Pipeline owns only ephemeral presentation state. ContentView retains the
/// workspace, canonical route, destructive dialog, and return-anchor owners.
struct PipelineView: View {
    @ObservedObject var model: WorkspaceViewModel
    @Binding var query: String
    @Binding var stage: String
    @Binding var includesClosed: Bool
    @Binding var showsBoard: Bool
    @Binding var anchorID: String?
    @Binding var horizontalLane: PipelineBoardLane?
    let open: (Opportunity) -> Void
    let delete: (Opportunity) -> Void
    let addOpportunity: () -> Void
    let importCSV: () -> Void
    @State private var selectedTableID: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var visibleOpportunities: [Opportunity] {
        model.filteredOpportunities(query: query, stage: stage, includesClosed: includesClosed)
    }

    private var selectedOpportunity: Opportunity? {
        guard let selectedTableID else { return nil }
        return visibleOpportunities.first { $0.id == selectedTableID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Opportunities").font(.largeTitle.bold())
                Spacer()
                Button(action: importCSV) {
                    Label("Import CSV", systemImage: "arrow.down.to.line")
                }
                    .buttonStyle(PipelineSecondaryButtonStyle())
                    .accessibilityIdentifier("pipeline-import-csv")
                Button("Add opportunity", action: addOpportunity)
                    .buttonStyle(RekonPrimaryButtonStyle())
                    .accessibilityIdentifier("pipeline-add-opportunity")
            }
            pipelineToolbar
            if visibleOpportunities.isEmpty {
                FlexibleCenteredContent {
                    if model.opportunities.isEmpty {
                        ContentUnavailableView("No opportunities", systemImage: "briefcase", description: Text("Add an opportunity to begin tracking your opportunities."))
                        Button("Add opportunity", action: addOpportunity)
                            .buttonStyle(RekonPrimaryButtonStyle())
                    } else {
                        ContentUnavailableView("No opportunities match", systemImage: "line.3.horizontal.decrease.circle", description: Text("Try another search or clear the current filters."))
                        Button("Clear filters") { query = ""; stage = "All stages"; includesClosed = false }
                            .accessibilityIdentifier("pipeline-clear-filters")
                    }
                }
            } else if showsBoard {
                PipelineBoardView(
                    model: model,
                    opportunities: visibleOpportunities,
                    includesClosed: includesClosed,
                    anchorID: $anchorID,
                    horizontalLane: $horizontalLane,
                    open: open,
                    addOpportunity: addOpportunity
                )
            } else {
                responsiveTable
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RekonTheme.background)
        .onChange(of: visibleOpportunities.map(\.id)) { _, ids in
            if let selectedTableID, !ids.contains(selectedTableID) {
                self.selectedTableID = nil
            }
        }
    }

    private var pipelineToolbar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: RekonTheme.Spacing.standard) {
                searchControl
                filterControls
                Spacer(minLength: RekonTheme.Spacing.standard)
                viewModeControl
            }

            VStack(alignment: .leading, spacing: RekonTheme.Spacing.tight) {
                HStack(spacing: RekonTheme.Spacing.standard) {
                    searchControl
                    viewModeControl
                }
                filterControls
            }
        }
    }

    private var searchControl: some View {
        PipelineNavySearchControl(
            text: $query,
            accessibilityIdentifier: "opportunity-search",
            accessibilityLabel: "Search opportunities"
        )
        .frame(minWidth: 220, maxWidth: 320)
        .frame(height: 48)
    }

    private var filterControls: some View {
        HStack(spacing: RekonTheme.Spacing.standard) {
            PipelineNavyStageControl(
                selection: $stage,
                options: ["All stages"] + PipelineStage.allCases.map(\.rawValue),
                accessibilityIdentifier: "pipeline-stage-filter",
                accessibilityLabel: "Stage"
            )
            .frame(width: 164, height: 48)

            PipelineNavyCheckboxControl(
                isOn: $includesClosed,
                title: "Include closed",
                accessibilityIdentifier: "pipeline-include-closed",
                accessibilityLabel: "Include closed",
                accessibilityValue: includesClosed ? "Included" : "Excluded"
            )
            .fixedSize(horizontal: true, vertical: false)
            .frame(minWidth: 164, minHeight: 48, maxHeight: 48)
        }
    }

    private var viewModeControl: some View {
        HStack(spacing: RekonTheme.Spacing.tight) {
            PipelineNavyViewModeControl(
                showsBoard: $showsBoard,
                accessibilityIdentifier: "pipeline-view-mode",
                accessibilityLabel: "View"
            )
            .frame(width: 188, height: 48)
        }
    }

    private var responsiveTable: some View {
        GeometryReader { geometry in
            if geometry.size.width < PipelineTableLayout.desktopInspectorMinimumWidth {
                ZStack(alignment: .trailing) {
                    table(isCompact: true)
                    if let selectedOpportunity {
                        PipelineInspector(opportunity: selectedOpportunity, close: { selectedTableID = nil }) {
                            anchorID = selectedOpportunity.id
                            open(selectedOpportunity)
                        }
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("pipeline-inspector-drawer")
                        .frame(width: min(380, max(300, geometry.size.width * 0.48)))
                        .transition(reduceMotion ? .identity : .move(edge: .trailing).combined(with: .opacity))
                        .transaction { transaction in
                            if reduceMotion {
                                transaction.animation = nil
                                transaction.disablesAnimations = true
                            }
                        }
                    }
                }
                .animation(reduceMotion ? nil : .default, value: selectedTableID)
            } else {
                HStack(alignment: .top, spacing: 16) {
                    table(isCompact: false)
                    inspector
                        .frame(width: PipelineTableLayout.inspectorWidth)
                }
            }
        }
    }

    private func table(isCompact: Bool) -> some View {
        GeometryReader { _ in
            VStack(spacing: 0) {
                PipelineTableHeader(isCompact: isCompact)
                Divider().overlay(RekonTheme.borderSubtle)
                List(selection: $selectedTableID) {
                    ForEach(visibleOpportunities, id: \.id) { opportunity in
                        PipelineTableRow(
                            opportunity: opportunity,
                            isSelected: selectedTableID == opportunity.id,
                            isCompact: isCompact
                        )
                        .tag(opportunity.id)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("pipeline-table-row-\(opportunity.id)")
                        .accessibilityLabel("\(opportunity.title), \(opportunity.company), \(opportunity.stage.rawValue)")
                        .accessibilityValue(selectedTableID == opportunity.id ? "Selected" : "Not selected")
                        .contextMenu {
                            Button("Delete", role: .destructive) { delete(opportunity) }
                                .accessibilityIdentifier("pipeline-delete-\(opportunity.id)")
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                Divider().overlay(RekonTheme.borderSubtle)
                Text("1–\(visibleOpportunities.count) of \(visibleOpportunities.count) opportunities")
                    .font(.caption)
                    .foregroundStyle(RekonTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .accessibilityIdentifier("pipeline-table-result-count")
            }
            .background(RekonTheme.backgroundRaised, in: RoundedRectangle(cornerRadius: RekonTheme.Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: RekonTheme.Radius.card)
                    .stroke(RekonTheme.borderSubtle, lineWidth: 1)
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pipeline-table-region")
        .frame(minWidth: isCompact ? 360 : 400, maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder private var inspector: some View {
        if let selectedOpportunity {
            PipelineInspector(opportunity: selectedOpportunity, close: nil) {
                anchorID = selectedOpportunity.id
                open(selectedOpportunity)
            }
        } else {
            PipelineInspectorEmptyState()
                .accessibilityIdentifier("pipeline-inspector-empty")
        }
    }

}

private struct PipelineTableRow: View {
    let opportunity: Opportunity
    let isSelected: Bool
    let isCompact: Bool

    var body: some View {
        HStack(alignment: .center, spacing: isCompact ? 12 : PipelineTableLayout.columnSpacing) {
            VStack(alignment: .leading, spacing: 4) {
                Text(opportunity.title)
                    .font(.body.weight(.semibold))
                    .lineLimit(isCompact ? 1 : 2)
                if let locality = opportunity.locationSummary {
                    Label(locality, systemImage: "mappin.circle.fill")
                        .font(.caption)
                        .foregroundStyle(RekonTheme.secondaryText)
                        .lineLimit(1)
                        .accessibilityIdentifier("pipeline-table-locality-\(opportunity.id)")
                }
            }
            .frame(minWidth: isCompact ? 105 : PipelineTableLayout.roleWidth, maxWidth: .infinity, alignment: .leading)

            if !isCompact {
                HStack(spacing: 4) {
                    PipelineEmployerMark(company: opportunity.company)
                    Text(opportunity.company)
                        .font(.caption2)
                        .foregroundStyle(RekonTheme.primaryText)
                        .lineLimit(2)
                }
                .frame(width: PipelineTableLayout.employerWidth, alignment: .leading)
            }

            PipelineStagePill(stage: opportunity.stage)
                .frame(width: isCompact ? 78 : PipelineTableLayout.stageWidth, alignment: .leading)

            if !isCompact {
                Text(opportunity.nextAction.isEmpty ? "—" : opportunity.nextAction)
                    .font(.subheadline)
                    .foregroundStyle(opportunity.nextAction.isEmpty ? RekonTheme.secondaryText : RekonTheme.primaryText)
                    .lineLimit(2)
                    .frame(minWidth: PipelineTableLayout.nextActionWidth, maxWidth: .infinity, alignment: .leading)
                Text(opportunity.dueAt.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "—")
                    .font(.caption)
                    .foregroundStyle(RekonTheme.secondaryText)
                    .lineLimit(1)
                    .frame(width: PipelineTableLayout.dueDateWidth, alignment: .leading)
            }
        }
        .padding(.vertical, isCompact ? 10 : 14)
        .padding(.horizontal, isCompact ? 14 : PipelineTableLayout.horizontalPadding)
        .background(
            isSelected ? RekonTheme.elevatedSurface : Color.clear,
            in: RoundedRectangle(cornerRadius: RekonTheme.Radius.control)
        )
        .overlay(
            RoundedRectangle(cornerRadius: RekonTheme.Radius.control)
                .stroke(isSelected ? RekonTheme.accent : Color.clear, lineWidth: isSelected ? 1.5 : 0)
        )
        .overlay(alignment: .leading) {
            if isSelected {
                Capsule().fill(RekonTheme.violet).frame(width: 3).padding(.vertical, 7)
            }
        }
    }
}

private struct PipelineTableHeader: View {
    let isCompact: Bool

    var body: some View {
        HStack(spacing: isCompact ? 12 : PipelineTableLayout.columnSpacing) {
            Text("Role")
                .frame(minWidth: isCompact ? 105 : PipelineTableLayout.roleWidth, maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("pipeline-table-header-role")
            if !isCompact {
                Text("Employer")
                    .frame(width: PipelineTableLayout.employerWidth, alignment: .leading)
                    .accessibilityIdentifier("pipeline-table-header-employer")
            }
            Text("Stage")
                .frame(width: isCompact ? 78 : PipelineTableLayout.stageWidth, alignment: .leading)
                .accessibilityIdentifier("pipeline-table-header-stage")
            if !isCompact {
                Text("Next action")
                    .frame(minWidth: PipelineTableLayout.nextActionWidth, maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("pipeline-table-header-next-action")
                Text("Due date")
                    .frame(width: PipelineTableLayout.dueDateWidth, alignment: .leading)
                    .accessibilityIdentifier("pipeline-table-header-due-date")
            }
        }
                .font(.subheadline.weight(.medium))
        .foregroundStyle(RekonTheme.secondaryText)
        .padding(.horizontal, isCompact ? 14 : PipelineTableLayout.horizontalPadding)
        .padding(.vertical, 14)
    }
}

struct PipelineEmployerMark: View {
    let company: String

    var body: some View {
        Text(String(company.prefix(1)).uppercased())
            .font(.caption.weight(.bold))
            .foregroundStyle(RekonTheme.shellForeground)
            .frame(width: 16, height: 16)
            .background(RekonTheme.violet.opacity(0.62), in: RoundedRectangle(cornerRadius: 6))
    }
}

/// The desktop tracks deliberately match the information density of the
/// approved mock. We never squeeze this five-column layout beside an
/// inspector: below the documented available width, Pipeline switches to its
/// compact dense Table and existing in-place drawer instead.
private enum PipelineTableLayout {
    static let desktopInspectorMinimumWidth: CGFloat = 1220
    static let inspectorWidth: CGFloat = 330
    static let roleWidth: CGFloat = 180
    static let employerWidth: CGFloat = 140
    static let stageWidth: CGFloat = 108
    static let nextActionWidth: CGFloat = 150
    static let dueDateWidth: CGFloat = 104
    static let columnSpacing: CGFloat = 12
    static let horizontalPadding: CGFloat = 16
}

struct PipelineStagePill: View {
    let stage: PipelineStage

    private var color: Color {
        switch stage {
        case .saved: RekonTheme.violet
        case .applied: RekonTheme.success
        case .screening, .interviewing: RekonTheme.accent
        case .offer: RekonTheme.warning
        case .closed: RekonTheme.secondaryText
        }
    }

    var body: some View {
        Text(stage.rawValue)
            .font(.caption2.weight(.medium))
            .foregroundStyle(color)
            .lineLimit(1)
            .padding(.horizontal, 4)
            .padding(.vertical, 5)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(color.opacity(0.35), lineWidth: 1))
    }
}

private struct PipelineInspector: View {
    let opportunity: Opportunity
    let close: (() -> Void)?
    let openDetails: () -> Void

    private var locationSummary: String? {
        let parts = [opportunity.location, opportunity.workArrangement == .notSpecified ? nil : opportunity.workArrangement.rawValue]
            .compactMap { $0?.isEmpty == false ? $0 : nil }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Selection summary")
                    .font(.headline)
                    .accessibilityIdentifier("pipeline-inspector-\(opportunity.id)")
                Spacer()
                if let close {
                    Button(action: close) {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("pipeline-inspector-close")
                    .accessibilityLabel("Close selection details")
                }
            }

            HStack(alignment: .top, spacing: 12) {
                PipelineEmployerMark(company: opportunity.company)
                    .frame(width: 44, height: 44)
                    .background(RekonTheme.surface, in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityIdentifier("pipeline-inspector-employer-mark-\(opportunity.id)")
                VStack(alignment: .leading, spacing: 4) {
                    Text(opportunity.title).font(.title3.bold()).textSelection(.enabled)
                    Text(opportunity.company)
                        .foregroundStyle(RekonTheme.secondaryText)
                        .accessibilityIdentifier("pipeline-inspector-company-\(opportunity.id)")
                    if let locationSummary {
                        Text(locationSummary)
                            .font(.subheadline)
                            .foregroundStyle(RekonTheme.secondaryText)
                    }
                }
            }
            Divider().overlay(RekonTheme.borderSubtle)

            HStack {
                Text("Stage").foregroundStyle(RekonTheme.secondaryText)
                Spacer()
                PipelineStagePill(stage: opportunity.stage)
                    .accessibilityIdentifier("pipeline-inspector-stage-\(opportunity.id)")
            }
            PipelineInspectorFact(
                title: "Applied",
                value: opportunity.applicationDate.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "Not recorded"
            )
            PipelineInspectorFact(
                title: "Next action",
                value: opportunity.nextAction.isEmpty ? "No next action is recorded." : opportunity.nextAction,
                accessibilityIdentifier: "pipeline-inspector-fact-next-action-\(opportunity.id)"
            )
            PipelineInspectorFact(
                title: "Due date",
                value: opportunity.dueAt.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "No due date"
            )
            Spacer(minLength: 0)
            Button("Open details", action: openDetails)
                .buttonStyle(PipelineSecondaryButtonStyle())
                .accessibilityIdentifier("pipeline-open-details-\(opportunity.id)")
                .frame(maxWidth: .infinity)
        }
        .padding(18)
        .background(RekonTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(RekonTheme.border, lineWidth: 1))
    }
}

private struct PipelineInspectorFact: View {
    let title: String
    let value: String
    var accessibilityIdentifier: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .foregroundStyle(RekonTheme.secondaryText)
            Spacer(minLength: 12)
            Text(value)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
        .font(.subheadline)
        .accessibilityIdentifier(accessibilityIdentifier ?? "")
    }
}

extension Opportunity {
    var locationSummary: String? {
        let parts = [location, workArrangement == .notSpecified ? nil : workArrangement.rawValue]
            .compactMap { $0?.isEmpty == false ? $0 : nil }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

private struct PipelineInspectorEmptyState: View {
    var body: some View {
        VStack(spacing: RekonTheme.Spacing.compact) {
            Image(systemName: "rectangle.rightthird.inset.filled")
                .font(.title2)
                .foregroundStyle(RekonTheme.secondaryText)
            Text("Select an opportunity")
                .font(.title3.weight(.semibold))
            Text("Choose a row to inspect its details.")
                .font(.subheadline)
                .foregroundStyle(RekonTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(RekonTheme.Spacing.section)
        .background(RekonTheme.backgroundRaised, in: RoundedRectangle(cornerRadius: RekonTheme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: RekonTheme.Radius.card)
                .stroke(RekonTheme.borderSubtle, lineWidth: 1)
        )
    }
}
