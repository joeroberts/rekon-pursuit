import SwiftUI

@main
struct RekonPursuitApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(model: WorkspaceViewModel())
                .preferredColorScheme(.dark)
        }
        .defaultSize(width: 1100, height: 760)
        .windowResizability(.contentMinSize)
        .windowToolbarStyle(.unifiedCompact(showsTitle: false))
    }
}
