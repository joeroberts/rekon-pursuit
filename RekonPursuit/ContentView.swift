import SwiftUI

enum BootstrapCopy {
    nonisolated static let status = "Local-only foundation"
}

struct ContentView: View {
    var body: some View {
        Text(BootstrapCopy.status)
            .accessibilityIdentifier("bootstrap-status")
            .frame(minWidth: 480, minHeight: 320)
    }
}
