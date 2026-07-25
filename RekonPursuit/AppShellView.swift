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

struct AppShellView<WorkspaceGate: View, Detail: View>: View {
    @Binding private var selection: AppDestination
    private let workspaceGate: WorkspaceGate
    private let detail: Detail

    init(
        selection: Binding<AppDestination>,
        @ViewBuilder workspaceGate: () -> WorkspaceGate,
        @ViewBuilder detail: () -> Detail
    ) {
        _selection = selection
        self.workspaceGate = workspaceGate()
        self.detail = detail()
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section {
                    ForEach(AppDestination.allCases) { destination in
                        Label(destination.rawValue, systemImage: destination.icon)
                            .tag(destination)
                            .accessibilityIdentifier(destination.accessibilityID)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Rekon Pursuit")
        } detail: {
            VStack(spacing: 0) {
                workspaceGate
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                detail
            }
            .navigationTitle(selection.rawValue)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Rekon Pursuit")
                        .font(.headline)
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 760, minHeight: 520)
    }
}
