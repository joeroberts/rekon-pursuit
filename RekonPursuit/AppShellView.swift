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
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 9) {
                    Image("RekonEmblem")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                    Text("Rekon Pursuit")
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)
                }
                .padding(.horizontal, 12)
                .padding(.top, 14)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(AppDestination.sidebarDestinations) { destination in
                            SidebarDestinationButton(
                                destination: destination,
                                isSelected: selection == DailyRoute(destination),
                                select: { selectDestination(DailyRoute(destination)) }
                            )
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }
            .background {
                ZStack {
                    RekonTheme.background
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
                .background(RekonTheme.background)
                .navigationTitle(detailTitle)
        }
        .tint(RekonTheme.accent)
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
        .background(RekonTheme.background.ignoresSafeArea())
        .background(RekonWindowChromeConfigurator(policy: windowCanvasPolicy))
        .toolbarBackground(
            windowCanvasPolicy.hidesWindowToolbarMaterial ? .hidden : .automatic,
            for: .windowToolbar
        )
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
            HStack(spacing: 10) {
                Image(systemName: destination.icon)
                    .frame(width: 18)
                Text(destination.rawValue)
                Spacer(minLength: 0)
            }
            .font(.body.weight(isSelected ? .semibold : .regular))
            .foregroundStyle(isSelected ? Color.white : RekonTheme.secondaryText)
            .padding(.horizontal, RekonTheme.Spacing.compact)
            .padding(.vertical, RekonTheme.Spacing.tight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? RekonTheme.elevatedSurface : Color.clear, in: RoundedRectangle(cornerRadius: RekonTheme.Radius.control))
            .overlay(
                RoundedRectangle(cornerRadius: RekonTheme.Radius.control)
                    .stroke(
                        isFocused ? RekonTheme.accent : (isSelected ? RekonTheme.accent.opacity(0.55) : Color.clear),
                        lineWidth: RekonVisualThemeContract.controlBorderWidth(isFocused: isFocused)
                    )
            )
            .shadow(color: isFocused ? RekonTheme.accent.opacity(0.32) : .clear, radius: 7)
        }
        .buttonStyle(.plain)
        .focusable()
        .focused($isFocused)
        // The custom cyan outline above is the single visible keyboard focus
        // treatment; suppress the system halo to avoid rendering two rings.
        .focusEffectDisabled(true)
        .accessibilityIdentifier(destination.accessibilityID)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
