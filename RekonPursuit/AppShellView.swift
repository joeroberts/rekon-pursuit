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
    @State private var isSidebarVisible = true
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
        HSplitView {
            if isSidebarVisible {
                sidebarRail
            }
            detailContent
        }
        .tint(RekonTheme.shellSelectedLeadingAccent)
        .textFieldStyle(RekonTextFieldStyle())
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    isSidebarVisible.toggle()
                } label: {
                    Image(systemName: isSidebarVisible ? "sidebar.left" : "sidebar.leading")
                        .symbolRenderingMode(.hierarchical)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(RekonTheme.shellIcon)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(RekonVisualThemeContract.collapseControlAccessibilityIdentifier)
                .accessibilityLabel(isSidebarVisible ? "Collapse sidebar" : "Show sidebar")
                .help(isSidebarVisible ? "Collapse sidebar" : "Show sidebar")
            }
        }
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
        .toolbarColorScheme(.dark, for: .windowToolbar)
        .toolbarBackground(RekonTheme.shellToolbarBackground, for: .windowToolbar)
        .toolbarBackground(
            windowCanvasPolicy.showsNavyWindowToolbarMaterial ? .visible : .automatic,
            for: .windowToolbar
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(RekonVisualThemeContract.shellAccessibilityIdentifier)
    }

    private var sidebarRail: some View {
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
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, RekonTheme.Rail.horizontalInset)
            }
        }
        .frame(
            minWidth: RekonTheme.Rail.minimumWidth,
            idealWidth: RekonTheme.Rail.idealWidth,
            maxWidth: RekonTheme.Rail.maximumWidth,
            maxHeight: .infinity,
            alignment: .topLeading
        )
        .fixedSize(horizontal: true, vertical: false)
        .background {
            ZStack {
                RekonTheme.shellRailBackground
                RekonDecorativeBackground()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sidebar-rail")
    }

    private var detailContent: some View {
        detail
            .frame(
                maxWidth: windowCanvasPolicy.fillsDetailCanvas ? .infinity : nil,
                maxHeight: windowCanvasPolicy.fillsDetailCanvas ? .infinity : nil,
                alignment: .topLeading
            )
            .background(RekonTheme.shellToolbarBackground)
            .navigationTitle(detailTitle)
    }
}

private struct SidebarDestinationButton: View {
    let destination: AppDestination
    let isSelected: Bool
    let select: () -> Void
    @FocusState private var isFocused: Bool
    @State private var isPointerHovering = false
    @State private var suppressingKeyboardFocusAfterPointerActivation = false

    private var showsKeyboardFocus: Bool {
        RekonRailDestinationPresentation.showsKeyboardFocus(
            isFocused: isFocused,
            suppressingAfterPointerActivation: suppressingKeyboardFocusAfterPointerActivation
        )
    }

    private var outlinePresentation: RekonRailDestinationOutline {
        RekonRailDestinationPresentation.outline(
            isPointerHovering: isPointerHovering,
            showsKeyboardFocus: showsKeyboardFocus
        )
    }

    private var outlineColor: Color {
        switch outlinePresentation {
        case .pointerHover:
            RekonTheme.shellPointerHoverRing
        case .keyboardFocus:
            RekonTheme.shellKeyboardFocusRing
        case .none:
            .clear
        }
    }

    private var outlineGlow: Color {
        switch outlinePresentation {
        case .pointerHover:
            RekonTheme.shellPointerHoverRing.opacity(0.32)
        case .keyboardFocus:
            RekonTheme.shellKeyboardFocusRing.opacity(0.28)
        case .none:
            .clear
        }
    }

    private var rowShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: RekonTheme.Radius.control)
    }

    var body: some View {
        Button {
            // A mouse click can focus a native Button. Preserve the focus for
            // keyboard traversal, but do not present it as a keyboard halo.
            suppressingKeyboardFocusAfterPointerActivation = true
            select()
        } label: {
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
            .contentShape(rowShape)
            .onHover { isHovering in
                isPointerHovering = isHovering
            }
            .background(
                isSelected ? RekonTheme.shellSelectedSurface : Color.clear,
                in: rowShape
            )
            .overlay(
                rowShape
                    .stroke(
                        outlineColor,
                        lineWidth: RekonRailDestinationPresentation.focusRingLineWidth(for: outlinePresentation)
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
                color: outlineGlow,
                radius: 7
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(rowShape)
        .focusable()
        .focused($isFocused)
        .onChange(of: isFocused) { _, focused in
            if !focused {
                suppressingKeyboardFocusAfterPointerActivation = false
            }
        }
        .onKeyPress(.space) {
            suppressingKeyboardFocusAfterPointerActivation = false
            select()
            return .handled
        }
        // The custom hover/focus treatments above are the only visible rings;
        // suppress the system halo to avoid rendering a second outline.
        .focusEffectDisabled(true)
        .accessibilityLabel(destination.rawValue)
        // Exposes the same state as the visible focus ring to accessibility
        // automation without adding a user-facing label or changing selection.
        .accessibilityValue(showsKeyboardFocus ? "Keyboard focus" : "")
        .accessibilityIdentifier(destination.accessibilityID)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
