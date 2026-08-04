import AppKit
import SwiftUI

enum VisualFixtureWindowSize: String {
    case compact
    case wide
    case breakpoint1219 = "breakpoint-1219"
    case breakpoint1220 = "breakpoint-1220"

    static let argument = "-rekon-visual-window-size"

    init(arguments: [String]) {
        guard let argumentIndex = arguments.firstIndex(of: Self.argument) else {
            self = .wide
            return
        }

        let valueIndex = argumentIndex + 1
        guard arguments.indices.contains(valueIndex), let size = Self(rawValue: arguments[valueIndex]) else {
            self = .wide
            return
        }

        self = size
    }

    var size: CGSize {
        switch self {
        case .compact:
            CGSize(width: 860, height: 600)
        case .wide:
            // The wide visual fixture represents the supplied desktop mock,
            // where a real five-track Table and persistent inspector fit
            // together without clipping either surface.
            CGSize(width: 1600, height: 1000)
        case .breakpoint1219:
            // 310pt fixed rail + 1pt split divider + 56pt Pipeline padding
            // leaves exactly 1,219pt for Pipeline's responsive container.
            CGSize(width: 1586, height: 1000)
        case .breakpoint1220:
            // One additional point selects the desktop five-column Table.
            CGSize(width: 1587, height: 1000)
        }
    }
}

@main
struct RekonPursuitUITestHostApp: App {
    private let visualFixture: VisualFixtureLaunchConfiguration?
    private let windowSize: VisualFixtureWindowSize

    init() {
        self.windowSize = VisualFixtureWindowSize(arguments: ProcessInfo.processInfo.arguments)
        let launchMode = VisualFixtureProcessLaunch.currentProcess()
        switch launchMode {
        case let .application(visualFixture):
            self.visualFixture = visualFixture
        case let .cleanup(cleanupConfiguration):
            VisualFixtureWorkspace.teardown(configuration: cleanupConfiguration)
            exit(EXIT_SUCCESS)
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let visualFixture {
                    ContentView(
                        model: VisualFixtureWorkspace.makeViewModel(configuration: visualFixture),
                        homeDashboardNow: visualFixture.now,
                        homeDashboardCalendar: visualFixture.fixtureCalendar
                    )
                } else {
                    VisualFixtureConfigurationRequiredView()
                }
            }
            .preferredColorScheme(.dark)
        }
        .defaultSize(width: windowSize.size.width, height: windowSize.size.height)
        .windowResizability(.contentMinSize)
        .windowToolbarStyle(.unifiedCompact(showsTitle: false))
    }
}

private struct VisualFixtureConfigurationRequiredView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28, weight: .semibold))
            Text("Visual fixture configuration required")
                .font(.headline)
            Text("This test host does not open a local workspace without an explicit fixture.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .accessibilityIdentifier("visual-fixture-required")
    }
}
