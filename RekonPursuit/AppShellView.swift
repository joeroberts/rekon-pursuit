import SwiftUI

enum AppDestination: String, CaseIterable, Identifiable {
    case home = "Home"
    case pipeline = "Pipeline"
    case addOpportunity = "Add opportunity"
    case importCSV = "Import CSV"
    case contacts = "Contacts"
    case activityAndAI = "Activity & AI"
    case settings = "Settings"

    var id: Self { self }

    var icon: String {
        switch self {
        case .home: "house"
        case .pipeline: "rectangle.3.group"
        case .addOpportunity: "plus.circle"
        case .importCSV: "square.and.arrow.down"
        case .contacts: "person.2"
        case .activityAndAI: "clock.arrow.circlepath"
        case .settings: "gearshape"
        }
    }

    var accessibilityID: String {
        "sidebar-" + rawValue.lowercased().replacingOccurrences(of: " ", with: "-").replacingOccurrences(of: "&", with: "and")
    }

    static let sidebarDestinations: [AppDestination] = [.home, .pipeline, .contacts, .activityAndAI, .settings]

    init(_ route: DailyRoute) {
        switch route {
        case .home: self = .home
        case .pipeline: self = .pipeline
        case .addOpportunity: self = .addOpportunity
        case .importCSV: self = .importCSV
        case .contacts: self = .contacts
        case .activityAI: self = .activityAndAI
        case .settings: self = .settings
        }
    }
}

nonisolated enum DailyRoute: Equatable {
    case home
    case pipeline
    case addOpportunity
    case importCSV
    case contacts
    case activityAI
    case settings

    var accessibilityIdentifier: String {
        switch self {
        case .home: "daily-route-home"
        case .pipeline: "daily-route-pipeline"
        case .addOpportunity: "daily-route-add-opportunity"
        case .importCSV: "daily-route-import-csv"
        case .contacts: "daily-route-contacts"
        case .activityAI: "daily-route-activity-ai"
        case .settings: "daily-route-settings"
        }
    }

    init(_ destination: AppDestination) {
        switch destination {
        case .home: self = .home
        case .pipeline: self = .pipeline
        case .addOpportunity: self = .addOpportunity
        case .importCSV: self = .importCSV
        case .contacts: self = .contacts
        case .activityAndAI: self = .activityAI
        case .settings: self = .settings
        }
    }
}

nonisolated enum DailyNavigationIntent: Equatable {
    case homeEmptyStateAdd
    case pipelineAdd
    case pipelineImport

    var route: DailyRoute {
        switch self {
        case .homeEmptyStateAdd, .pipelineAdd: .addOpportunity
        case .pipelineImport: .importCSV
        }
    }
}

nonisolated struct DailyNavigationState: Equatable {
    private(set) var route: DailyRoute = .home

    mutating func select(_ route: DailyRoute) {
        self.route = route
    }

    mutating func handle(_ intent: DailyNavigationIntent) {
        select(intent.route)
    }
}

nonisolated enum OpportunityRoute: Equatable {
    case overview(String)
    case history(String)
    case reconcile(String)

    var opportunityID: String {
        switch self {
        case let .overview(id), let .history(id), let .reconcile(id): id
        }
    }

    /// Returns to the overview only while the routed record still exists.
    /// Callers use `nil` to return safely to Pipeline instead of leaving an
    /// unavailable-record sub-route on screen.
    func parentRoute(recordIsAvailable: Bool) -> OpportunityRoute? {
        guard recordIsAvailable else { return nil }
        return .overview(opportunityID)
    }
}

struct AppShellView<Detail: View>: View {
    @Binding private var selection: DailyRoute
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    private let windowCanvasPolicy = RekonWindowCanvasPolicy.standard
    private let detailTitle: String
    private let selectDestination: (DailyRoute) -> Void
    private let detail: Detail

    init(
        selection: Binding<DailyRoute>,
        detailTitle: String,
        selectDestination: @escaping (DailyRoute) -> Void,
        @ViewBuilder detail: () -> Detail
    ) {
        _selection = selection
        self.detailTitle = detailTitle
        self.selectDestination = selectDestination
        self.detail = detail()
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            VStack(alignment: .leading, spacing: RekonTheme.Spacing.standard) {
                HStack(spacing: RekonTheme.Rail.brandSpacing) {
                    Image(RekonVisualThemeContract.emblemAssetName)
                        .resizable()
                        .scaledToFit()
                        .frame(
                            width: RekonVisualThemeContract.brandEmblemTargetSize,
                            height: RekonVisualThemeContract.brandEmblemTargetSize
                        )
                    Text("Rekon Pursuit")
                        .font(.system(size: RekonVisualThemeContract.brandLockupTextSize, weight: .semibold))
                        .foregroundStyle(RekonTheme.shellForeground)
                        .lineLimit(1)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Rekon Pursuit")
                .accessibilityIdentifier(RekonVisualThemeContract.brandLockupAccessibilityIdentifier)
                .padding(.horizontal, RekonTheme.Rail.horizontalInset)
                .padding(.top, RekonTheme.Rail.brandTopInset)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: RekonTheme.Rail.destinationRowGap) {
                        ForEach(AppDestination.sidebarDestinations) { destination in
                            SidebarDestinationButton(
                                destination: destination,
                                isSelected: selection == DailyRoute(destination),
                                select: { selectDestination(DailyRoute(destination)) }
                            )
                        }
                    }
                    .padding(.horizontal, RekonTheme.Rail.horizontalInset)
                }
            }
            .navigationSplitViewColumnWidth(
                min: RekonTheme.Rail.minimumWidth,
                ideal: RekonTheme.Rail.idealWidth,
                max: RekonTheme.Rail.maximumWidth
            )
            .background {
                ZStack {
                    RekonTheme.shellRailBackground
                    RekonDecorativeBackground()
                }
            }
        } detail: {
            detail
                .frame(
                    maxWidth: windowCanvasPolicy.fillsDetailCanvas ? .infinity : nil,
                    maxHeight: windowCanvasPolicy.fillsDetailCanvas ? .infinity : nil,
                    alignment: .topLeading
                )
                .background(RekonTheme.shellToolbarBackground)
                .navigationTitle(detailTitle)
        }
        .tint(RekonTheme.shellSelectedLeadingAccent)
        .textFieldStyle(RekonTextFieldStyle())
        .navigationSplitViewStyle(.balanced)
        .frame(
            minWidth: RekonVisualThemeContract.minimumWindowWidth,
            minHeight: RekonVisualThemeContract.minimumWindowHeight
        )
        .frame(
            maxWidth: windowCanvasPolicy.fillsRootCanvas ? .infinity : nil,
            maxHeight: windowCanvasPolicy.fillsRootCanvas ? .infinity : nil
        )
        .background(RekonTheme.shellToolbarBackground.ignoresSafeArea())
        .background(RekonWindowChromeConfigurator(policy: windowCanvasPolicy))
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
                } label: {
                    Image(systemName: columnVisibility == .detailOnly ? "sidebar.leading" : "sidebar.left")
                        .symbolRenderingMode(.hierarchical)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(RekonTheme.shellIcon)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(RekonVisualThemeContract.collapseControlAccessibilityIdentifier)
                .accessibilityLabel(columnVisibility == .detailOnly ? "Show sidebar" : "Collapse sidebar")
                .help(columnVisibility == .detailOnly ? "Show sidebar" : "Collapse sidebar")
            }
        }
        .toolbarColorScheme(.dark, for: .windowToolbar)
        .toolbarBackground(RekonTheme.shellToolbarBackground, for: .windowToolbar)
        .toolbarBackground(
            windowCanvasPolicy.showsNavyWindowToolbarMaterial ? .visible : .automatic,
            for: .windowToolbar
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(RekonVisualThemeContract.shellAccessibilityIdentifier)
    }
}

private struct SidebarDestinationButton: View {
    let destination: AppDestination
    let isSelected: Bool
    let select: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: select) {
            HStack(spacing: RekonTheme.Rail.destinationLabelGap) {
                Image(systemName: destination.icon)
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: RekonVisualThemeContract.railIconSize, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? RekonTheme.shellSelectedForeground : RekonTheme.shellIcon)
                    .frame(width: RekonVisualThemeContract.railIconSize)
                Text(destination.rawValue)
                    .foregroundStyle(isSelected ? RekonTheme.shellSelectedForeground : RekonTheme.shellMutedForeground)
                Spacer(minLength: 0)
            }
            .font(.body.weight(isSelected ? .semibold : .regular))
            .padding(.horizontal, RekonTheme.Spacing.compact)
            .padding(.vertical, RekonTheme.Spacing.tight)
            .frame(minHeight: RekonVisualThemeContract.railDestinationMinimumHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected ? RekonTheme.shellSelectedSurface : Color.clear,
                in: RoundedRectangle(cornerRadius: RekonTheme.Radius.control)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RekonTheme.Radius.control)
                    .stroke(
                        isFocused
                            ? (isSelected ? RekonTheme.shellSelectedFocusRing : RekonTheme.shellFocusRing)
                            : Color.clear,
                        lineWidth: RekonRailDestinationPresentation.focusRingLineWidth(
                            isSelected: isSelected,
                            isFocused: isFocused
                        )
                    )
            )
            .overlay(alignment: .leading) {
                if isSelected {
                    Capsule()
                        .fill(RekonTheme.shellSelectedLeadingAccent)
                        .frame(
                            width: RekonRailDestinationPresentation.selectedIndicatorWidth(
                                isSelected: isSelected
                            )
                        )
                        .padding(.vertical, RekonTheme.Spacing.tight)
                }
            }
            .shadow(
                color: isFocused
                    ? (isSelected ? RekonTheme.shellSelectedFocusRing.opacity(0.24) : RekonTheme.shellFocusRing.opacity(0.32))
                    : .clear,
                radius: 7
            )
        }
        .buttonStyle(.plain)
        .focusable()
        .focused($isFocused)
        // The custom cyan outline above is the single visible keyboard focus
        // treatment; suppress the system halo to avoid rendering two rings.
        .focusEffectDisabled(true)
        .accessibilityLabel(destination.rawValue)
        // Exposes the same state as the visible focus ring to accessibility
        // automation without adding a user-facing label or changing selection.
        .accessibilityValue(isFocused ? "Keyboard focus" : "")
        .accessibilityIdentifier(destination.accessibilityID)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
