import SwiftUI

enum AppDestination: String, CaseIterable, Identifiable {
    case needsAttention = "Needs Attention"
    case pipeline = "Pipeline"
    case addOpportunity = "Add opportunity"
    case importCSV = "Import CSV"
    case contacts = "Contacts"
    case activityAndAI = "Activity & AI"
    case settings = "Settings"

    var id: Self { self }

    var icon: String {
        switch self {
        case .needsAttention: "checklist"
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
}

enum OpportunityRoute: Equatable {
    case overview(String)
    case history(String)
    case reconcile(String)

    var opportunityID: String {
        switch self {
        case let .overview(id), let .history(id), let .reconcile(id): id
        }
    }
}

enum RekonTheme {
    static let background = Color(red: 0.018, green: 0.035, blue: 0.075)
    static let surface = Color(red: 0.045, green: 0.075, blue: 0.13)
    static let elevatedSurface = Color(red: 0.065, green: 0.105, blue: 0.18)
    static let border = Color(red: 0.16, green: 0.23, blue: 0.35)
    static let secondaryText = Color(red: 0.62, green: 0.69, blue: 0.80)
    static let accent = Color(red: 0.10, green: 0.70, blue: 0.96)
    static let violet = Color(red: 0.53, green: 0.30, blue: 0.96)
}

struct AppShellView<Detail: View>: View {
    @Binding private var selection: AppDestination
    private let detailTitle: String
    private let selectDestination: (AppDestination) -> Void
    private let detail: Detail

    init(
        selection: Binding<AppDestination>,
        detailTitle: String,
        selectDestination: @escaping (AppDestination) -> Void,
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
                List(selection: Binding(
                    get: { selection },
                    set: { selectDestination($0) }
                )) {
                    ForEach(AppDestination.allCases) { destination in
                        Label(destination.rawValue, systemImage: destination.icon)
                            .tag(destination)
                            .accessibilityIdentifier(destination.accessibilityID)
                    }
                }
                .listStyle(.sidebar)
            }
            .background(RekonTheme.background)
        } detail: {
            detail
                .background(RekonTheme.background)
                .navigationTitle(detailTitle)
        }
        .tint(RekonTheme.accent)
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 860, minHeight: 600)
    }
}
