import AppKit
import SwiftUI

@main
struct RekonPursuitApp: App {
    private let visualFixture: VisualFixtureLaunchConfiguration?

    init() {
        let launchMode = VisualFixtureProcessLaunch.currentProcess()
        switch launchMode {
        case let .application(visualFixture):
            self.visualFixture = visualFixture
        case let .cleanup(cleanupConfiguration):
            VisualFixtureWorkspace.teardown(configuration: cleanupConfiguration)
            // This launch is a test-owned cleanup subprocess, not an app
            // render. Exit before SwiftUI builds any scene or dependency.
            exit(EXIT_SUCCESS)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(visualFixture: visualFixture)
                .preferredColorScheme(.dark)
        }
        .defaultSize(width: 1100, height: 760)
        .windowResizability(.contentMinSize)
        .windowToolbarStyle(.unifiedCompact(showsTitle: false))
    }
}
