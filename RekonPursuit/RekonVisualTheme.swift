import AppKit
import Foundation
import SwiftUI

/// Stable, testable values for the first Visual Design v2 foundation slice.
/// Screen-level layout work belongs to the later VD2 tasks; these values remain
/// the semantic seam those tasks consume.
nonisolated enum RekonVisualThemeContract {
    static let emblemAssetName = "RekonEmblem"
    static let shellAccessibilityIdentifier = "app-shell"
    static let defaultSpacing: CGFloat = 16
    static let defaultCornerRadius: CGFloat = 16
    static let minimumWindowWidth: CGFloat = 860
    static let minimumWindowHeight: CGFloat = 600
    static let homeFocusAccessibilityIdentifier = "sidebar-home"

    static func decorativeBackgroundOpacity(reduceMotion: Bool) -> Double {
        reduceMotion ? 0.45 : 1
    }

    static func controlOpacity(isEnabled: Bool) -> Double {
        isEnabled ? 1 : 0.42
    }

    static func controlBorderWidth(isFocused: Bool) -> CGFloat {
        isFocused ? 2 : 1
    }

    static func buttonFocusBorderWidth(isFocused: Bool) -> CGFloat {
        isFocused ? 2 : 1
    }

    static func buttonFocusGlowOpacity(isFocused: Bool) -> Double {
        isFocused ? 0.45 : 0
    }
}

/// The window-level contract for the Visual Design v2 shell.  Keeping this
/// separate from individual screens prevents an intrinsic-width screen from
/// revealing the system canvas around the navigation split view.
nonisolated struct RekonWindowCanvasPolicy: Equatable {
    let hidesSystemTitleBar: Bool
    let fillsRootCanvas: Bool
    let fillsDetailCanvas: Bool
    let usesNavyWindowContainerBackground: Bool
    let hidesWindowToolbarMaterial: Bool

    static let standard = Self(
        hidesSystemTitleBar: true,
        fillsRootCanvas: true,
        fillsDetailCanvas: true,
        usesNavyWindowContainerBackground: true,
        hidesWindowToolbarMaterial: true
    )
}

/// Sidebar destinations provide their own visible focus ring. Suppressing the
/// platform focus effect prevents a second, inset ring from appearing around
/// the image and label while preserving keyboard focus and VoiceOver behavior.
nonisolated struct RekonSidebarFocusPolicy: Equatable {
    let rendersCustomFocusRing: Bool
    let suppressesSystemFocusEffect: Bool

    static let standard = Self(
        rendersCustomFocusRing: true,
        suppressesSystemFocusEffect: true
    )
}

/// Applies the window-owned chrome treatment that SwiftUI's root background
/// cannot reach on macOS 14. The view has no visual content; it configures its
/// hosting window whenever SwiftUI attaches or updates it.
struct RekonWindowChromeConfigurator: NSViewRepresentable {
    let policy: RekonWindowCanvasPolicy

    func makeNSView(context: Context) -> WindowConfigurationView {
        WindowConfigurationView(policy: policy)
    }

    func updateNSView(_ view: WindowConfigurationView, context: Context) {
        view.apply(policy: policy)
    }

    final class WindowConfigurationView: NSView {
        private var policy: RekonWindowCanvasPolicy

        init(policy: RekonWindowCanvasPolicy) {
            self.policy = policy
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) {
            nil
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            apply(policy: policy)
        }

        func apply(policy: RekonWindowCanvasPolicy) {
            self.policy = policy
            guard let window else { return }

            if policy.hidesSystemTitleBar {
                window.titleVisibility = .hidden
                window.titlebarAppearsTransparent = true
            }
            if policy.usesNavyWindowContainerBackground {
                window.backgroundColor = NSColor(RekonTheme.background)
                window.isOpaque = true
            }
        }
    }
}

enum RekonTheme {
    // Background and surface hierarchy
    static let background = Color(red: 0.012, green: 0.024, blue: 0.063)
    static let backgroundRaised = Color(red: 0.021, green: 0.043, blue: 0.102)
    static let surface = Color(red: 0.035, green: 0.062, blue: 0.135)
    static let elevatedSurface = Color(red: 0.055, green: 0.094, blue: 0.185)
    static let border = Color(red: 0.155, green: 0.235, blue: 0.39)
    static let borderSubtle = Color.white.opacity(0.11)

    // Content and semantic accents. Statuses pair color with an SF Symbol in
    // the caller so information remains understandable without color alone.
    static let primaryText = Color.white.opacity(0.94)
    static let secondaryText = Color(red: 0.64, green: 0.71, blue: 0.85)
    static let accent = Color(red: 0.06, green: 0.69, blue: 0.98)
    static let violet = Color(red: 0.55, green: 0.25, blue: 0.98)
    static let success = Color(red: 0.16, green: 0.82, blue: 0.55)
    static let warning = Color(red: 0.98, green: 0.66, blue: 0.20)
    static let danger = Color(red: 1.0, green: 0.36, blue: 0.43)

    static let actionGradient = LinearGradient(
        colors: [accent, violet],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let surfaceGradient = LinearGradient(
        colors: [backgroundRaised, surface],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let emblemAssetName = RekonVisualThemeContract.emblemAssetName

    enum Spacing {
        static let micro: CGFloat = 4
        static let tight: CGFloat = 8
        static let compact: CGFloat = 12
        static let standard = RekonVisualThemeContract.defaultSpacing
        static let section: CGFloat = 24
        static let screen: CGFloat = 32
    }

    enum Radius {
        static let control: CGFloat = 10
        static let card = RekonVisualThemeContract.defaultCornerRadius
        static let large: CGFloat = 22
    }

    enum Status {
        case success, warning, danger, information

        var color: Color {
            switch self {
            case .success: RekonTheme.success
            case .warning: RekonTheme.warning
            case .danger: RekonTheme.danger
            case .information: RekonTheme.accent
            }
        }

        var symbolName: String {
            switch self {
            case .success: "checkmark.circle.fill"
            case .warning: "exclamationmark.triangle.fill"
            case .danger: "xmark.octagon.fill"
            case .information: "info.circle.fill"
            }
        }
    }
}

struct RekonPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @FocusState private var isFocused: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, RekonTheme.Spacing.standard)
            .padding(.vertical, RekonTheme.Spacing.tight)
            .background(RekonTheme.actionGradient.opacity(configuration.isPressed ? 0.78 : 1), in: RoundedRectangle(cornerRadius: RekonTheme.Radius.control))
            .overlay(
                RoundedRectangle(cornerRadius: RekonTheme.Radius.control)
                    .stroke(
                        RekonTheme.accent.opacity(isFocused ? 1 : 0.8),
                        lineWidth: RekonVisualThemeContract.buttonFocusBorderWidth(isFocused: isFocused)
                    )
            )
            .shadow(color: RekonTheme.accent.opacity(configuration.isPressed ? 0 : 0.24), radius: 10, y: 4)
            .shadow(color: RekonTheme.accent.opacity(RekonVisualThemeContract.buttonFocusGlowOpacity(isFocused: isFocused)), radius: 6)
            .contentShape(RoundedRectangle(cornerRadius: RekonTheme.Radius.control))
            .focused($isFocused)
            .opacity(RekonVisualThemeContract.controlOpacity(isEnabled: isEnabled))
    }
}

struct RekonSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @FocusState private var isFocused: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .foregroundStyle(RekonTheme.primaryText)
            .padding(.horizontal, RekonTheme.Spacing.standard)
            .padding(.vertical, RekonTheme.Spacing.tight)
            .background(RekonTheme.surface.opacity(configuration.isPressed ? 0.62 : 0.92), in: RoundedRectangle(cornerRadius: RekonTheme.Radius.control))
            .overlay(
                RoundedRectangle(cornerRadius: RekonTheme.Radius.control)
                    .stroke(
                        isFocused ? RekonTheme.accent : RekonTheme.border,
                        lineWidth: RekonVisualThemeContract.buttonFocusBorderWidth(isFocused: isFocused)
                    )
            )
            .shadow(color: RekonTheme.accent.opacity(RekonVisualThemeContract.buttonFocusGlowOpacity(isFocused: isFocused)), radius: 6)
            .contentShape(RoundedRectangle(cornerRadius: RekonTheme.Radius.control))
            .focused($isFocused)
            .opacity(RekonVisualThemeContract.controlOpacity(isEnabled: isEnabled))
    }
}

struct RekonTextFieldStyle: TextFieldStyle {
    @FocusState private var isFocused: Bool

    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .focused($isFocused)
            .padding(.horizontal, RekonTheme.Spacing.compact)
            .padding(.vertical, RekonTheme.Spacing.tight)
            .background(RekonTheme.surface, in: RoundedRectangle(cornerRadius: RekonTheme.Radius.control))
            .overlay(
                RoundedRectangle(cornerRadius: RekonTheme.Radius.control)
                    .stroke(
                        isFocused ? RekonTheme.accent : RekonTheme.border,
                        lineWidth: RekonVisualThemeContract.controlBorderWidth(isFocused: isFocused)
                    )
            )
    }
}

struct RekonCard<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(RekonTheme.Spacing.standard)
            .background(RekonTheme.surfaceGradient, in: RoundedRectangle(cornerRadius: RekonTheme.Radius.card))
            .overlay(RoundedRectangle(cornerRadius: RekonTheme.Radius.card).stroke(RekonTheme.borderSubtle, lineWidth: 1))
    }
}

/// Decorative-only native geometry. It never conveys app state, never captures
/// input, and honors reduced motion by avoiding the ambient animation.
struct RekonDecorativeBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: [RekonTheme.background, RekonTheme.backgroundRaised.opacity(0.75)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Path { path in
                    let width = proxy.size.width
                    let height = proxy.size.height
                    path.move(to: CGPoint(x: -20, y: height - 24))
                    path.addCurve(
                        to: CGPoint(x: width * 0.50, y: height * 0.60),
                        control1: CGPoint(x: width * 0.16, y: height * 0.95),
                        control2: CGPoint(x: width * 0.24, y: height * 0.56)
                    )
                }
                .stroke(RekonTheme.accent.opacity(0.34), style: StrokeStyle(lineWidth: 1.25, lineCap: .round))

                Path { path in
                    let width = proxy.size.width
                    let height = proxy.size.height
                    path.move(to: CGPoint(x: -16, y: height - 2))
                    path.addCurve(
                        to: CGPoint(x: width * 0.72, y: height * 0.52),
                        control1: CGPoint(x: width * 0.20, y: height * 0.86),
                        control2: CGPoint(x: width * 0.43, y: height * 0.56)
                    )
                }
                .stroke(RekonTheme.violet.opacity(0.28), style: StrokeStyle(lineWidth: 1, lineCap: .round))
            }
            .opacity(RekonVisualThemeContract.decorativeBackgroundOpacity(reduceMotion: reduceMotion))
            .animation(reduceMotion ? nil : .easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: reduceMotion)
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

nonisolated enum VisualFixtureID: String, CaseIterable, Equatable {
    case empty
    case populated
    case recovery
    case error
    case archive
    case documentRelink = "document-relink"
}

/// An opt-in UI-test-only launch seam. No path, keychain account, fixture ID,
/// or clock is configurable through production workspace preferences.
nonisolated struct VisualFixtureLaunchConfiguration: Equatable {
    static let argument = "-rekon-visual-fixture"
    static let cleanupArgument = "-rekon-visual-fixture-cleanup"
    static let xctestConfigurationFilePathEnvironmentKey = "XCTestConfigurationFilePath"
    static let fixtureSessionEnvironmentKey = "REKON_VISUAL_FIXTURE_SESSION"
    static let fixedNow = Date(timeIntervalSince1970: 1_746_057_600) // 2025-05-06T12:00:00Z

    let fixture: VisualFixtureID
    let sessionRoot: URL
    let root: URL
    let keychainNamespace: String
    let now: Date
    let timeZone: TimeZone

    init(
        fixture: VisualFixtureID,
        session: String,
        now: Date = Self.fixedNow,
        timeZone: TimeZone = TimeZone(secondsFromGMT: 0)!
    ) {
        let sanitizedSession = Self.sanitizedSession(session)
        self.fixture = fixture
        sessionRoot = Self.fixtureBaseRoot
            .appendingPathComponent(sanitizedSession, isDirectory: true)
        root = sessionRoot.appendingPathComponent(fixture.rawValue, isDirectory: true)
        keychainNamespace = "com.rekonlabs.RekonPursuit.visual-fixture.\(sanitizedSession).\(fixture.rawValue)"
        self.now = now
        self.timeZone = timeZone
    }

    init?(arguments: [String], environment: [String: String]) {
        guard let argumentIndex = arguments.firstIndex(of: Self.argument),
              arguments.indices.contains(argumentIndex + 1),
              let fixture = VisualFixtureID(rawValue: arguments[argumentIndex + 1]) else {
            return nil
        }

        self.init(
            fixture: fixture,
            session: environment[Self.fixtureSessionEnvironmentKey] ?? "direct-initializer"
        )
    }

    var fixtureCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = timeZone
        return calendar
    }

    static func currentProcess(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Self? {
        guard environment[xctestConfigurationFilePathEnvironmentKey]?.isEmpty == false else { return nil }
        return Self(arguments: arguments, environment: environment)
    }

    /// App-owned cleanup entry point for UI-test teardown. Cleanup is scoped
    /// to the complete test session, never to one named fixture.
    static func cleanupCurrentProcess(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> VisualFixtureCleanupConfiguration? {
        VisualFixtureCleanupConfiguration(arguments: arguments, environment: environment)
    }

    static var fixtureBaseRoot: URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("rekon-pursuit-visual-fixtures", isDirectory: true)
    }

    static func sanitizedSession(_ value: String?) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
        let sanitized = value?.unicodeScalars.filter { allowed.contains($0) }.map(String.init).joined() ?? ""
        return sanitized.isEmpty ? "direct-initializer" : sanitized
    }
}

nonisolated struct VisualFixtureCleanupConfiguration: Equatable {
    let sessionRoot: URL

    init?(arguments: [String], environment: [String: String]) {
        guard environment[VisualFixtureLaunchConfiguration.xctestConfigurationFilePathEnvironmentKey]?.isEmpty == false,
              arguments.contains(VisualFixtureLaunchConfiguration.cleanupArgument) else {
            return nil
        }

        let session = VisualFixtureLaunchConfiguration.sanitizedSession(
            environment[VisualFixtureLaunchConfiguration.fixtureSessionEnvironmentKey]
        )
        sessionRoot = VisualFixtureLaunchConfiguration.fixtureBaseRoot
            .appendingPathComponent(session, isDirectory: true)
    }
}

nonisolated enum VisualFixtureProcessLaunch: Equatable {
    case application(VisualFixtureLaunchConfiguration?)
    case cleanup(VisualFixtureCleanupConfiguration)

    static func currentProcess(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Self {
        if let cleanup = VisualFixtureLaunchConfiguration.cleanupCurrentProcess(
            arguments: arguments,
            environment: environment
        ) {
            return .cleanup(cleanup)
        }
        return .application(
            VisualFixtureLaunchConfiguration.currentProcess(
                arguments: arguments,
                environment: environment
            )
        )
    }

    var requiresApplicationDependencies: Bool {
        if case .application = self { return true }
        return false
    }
}

nonisolated final class VisualFixtureWorkspaceKeyStore: WorkspaceKeyStore {
    private let lock = NSLock()
    private var primary: Data?
    private var pending: Data?
    let namespace: String

    init(namespace: String) {
        self.namespace = namespace
    }

    func readWorkspaceKey() throws -> Data? {
        lock.withLock { primary }
    }

    func writeWorkspaceKey(_ key: Data) throws {
        lock.withLock { primary = key }
    }

    func deleteWorkspaceKey() throws {
        lock.withLock { primary = nil }
    }

    func readPendingWorkspaceKey() throws -> Data? {
        lock.withLock { pending }
    }

    func writePendingWorkspaceKey(_ key: Data) throws {
        lock.withLock { pending = key }
    }

    func promotePendingWorkspaceKey() throws {
        lock.withLock {
            primary = pending
            pending = nil
        }
    }

    func deletePendingWorkspaceKey() throws {
        lock.withLock { pending = nil }
    }
}

@MainActor
enum VisualFixtureWorkspace {
    static func makeViewModel(configuration: VisualFixtureLaunchConfiguration) -> WorkspaceViewModel {
        _ = removeTemporaryFixtureRoot(configuration.root)
        let keyStore = VisualFixtureWorkspaceKeyStore(namespace: configuration.keychainNamespace)
        let session = WorkspaceSession(
            root: configuration.root,
            keyStore: keyStore,
            newKey: { Data(repeating: 0xA5, count: 32) },
            now: configuration.now,
            archiveSigningKeyStore: InMemoryArchiveSigningKeyStore()
        )

        seedFixtureIfNeeded(
            configuration.fixture,
            session: session,
            now: configuration.now,
            calendar: configuration.fixtureCalendar
        )

        let disabledSeparateWorkspace = SeparateLocalWorkspaceDependencies(
            selectedIdentity: { nil },
            allocateAndPersistIdentity: { throw WorkspaceStoreError.injectedFailure },
            open: { _ in .unavailable },
            create: { _ in throw WorkspaceStoreError.injectedFailure },
            clearSelection: {}
        )
        let isolatedBookmarks = WorkspaceLocationBookmarkStore(
            dependencies: WorkspaceLocationBookmarkDependencies(
                loadBookmark: { nil },
                saveBookmark: { _ in },
                createBookmark: { _ in Data() },
                resolveBookmark: { _ in throw WorkspaceStoreError.injectedFailure },
                startAccessing: { _ in false },
                stopAccessing: { _ in },
                validateWorkspace: { _ in .missingWorkspaceDatabase }
            )
        )

        switch configuration.fixture {
        case .recovery:
            return WorkspaceViewModel(
                openWorkspace: { .recoveryRequired },
                createWorkspace: { try session.create() },
                workspaceLocationBookmarks: isolatedBookmarks,
                separateLocalWorkspace: disabledSeparateWorkspace
            )
        case .error:
            return WorkspaceViewModel(
                openWorkspace: { .unavailable },
                createWorkspace: { throw WorkspaceStoreError.injectedFailure },
                workspaceLocationBookmarks: isolatedBookmarks,
                separateLocalWorkspace: disabledSeparateWorkspace
            )
        case .empty, .populated, .archive, .documentRelink:
            return WorkspaceViewModel(
                openWorkspace: session.open,
                createWorkspace: session.create,
                workspaceLocationBookmarks: isolatedBookmarks,
                separateLocalWorkspace: disabledSeparateWorkspace
            )
        }
    }

    @discardableResult
    static func removeTemporaryFixtureRoot(
        _ root: URL,
        fixtureBaseRoot: URL = VisualFixtureLaunchConfiguration.fixtureBaseRoot
    ) -> Bool {
        let fixtureRoot = fixtureBaseRoot.standardizedFileURL
        let candidate = root.standardizedFileURL
        guard ownsTemporaryFixtureRoot(candidate, under: fixtureRoot) else { return false }

        do {
            if FileManager.default.fileExists(atPath: candidate.path) {
                try FileManager.default.removeItem(at: candidate)
            }
            return !FileManager.default.fileExists(atPath: candidate.path)
        } catch {
            return false
        }
    }

    /// A fixture root is owned only when its lexical path is below the fixture
    /// base and neither the base nor any intervening component is a symbolic
    /// link. This ensures cleanup cannot recursively remove external data by
    /// traversing a symlink supplied in a fixture path.
    private static func ownsTemporaryFixtureRoot(_ candidate: URL, under fixtureRoot: URL) -> Bool {
        let baseComponents = fixtureRoot.pathComponents
        let candidateComponents = candidate.pathComponents
        guard candidate != fixtureRoot,
              candidateComponents.starts(with: baseComponents),
              !isSymbolicLink(at: fixtureRoot) else {
            return false
        }

        var componentURL = fixtureRoot
        for component in candidateComponents.dropFirst(baseComponents.count) {
            componentURL.appendPathComponent(component, isDirectory: true)
            guard !isSymbolicLink(at: componentURL) else { return false }
        }

        let resolvedFixtureRoot = fixtureRoot.resolvingSymlinksInPath().standardizedFileURL
        let resolvedCandidate = candidate.resolvingSymlinksInPath().standardizedFileURL
        let resolvedPrefix = resolvedFixtureRoot.path.hasSuffix("/")
            ? resolvedFixtureRoot.path
            : resolvedFixtureRoot.path + "/"
        return resolvedCandidate.path.hasPrefix(resolvedPrefix)
    }

    private static func isSymbolicLink(at url: URL) -> Bool {
        (try? FileManager.default.destinationOfSymbolicLink(atPath: url.path)) != nil
    }

    static func teardown(configuration: VisualFixtureLaunchConfiguration) {
        _ = removeTemporaryFixtureRoot(configuration.root)
    }

    static func teardown(configuration: VisualFixtureCleanupConfiguration) {
        _ = removeTemporaryFixtureRoot(configuration.sessionRoot)
    }

    /// The fixture launcher never reads a user workspace. Named non-empty
    /// fixtures instead receive small, deterministic records in their own
    /// temporary encrypted store so visual tests can exercise real UI paths.
    private static func seedFixtureIfNeeded(
        _ fixture: VisualFixtureID,
        session: WorkspaceSession,
        now: Date,
        calendar: Calendar
    ) {
        guard [.populated, .archive, .documentRelink].contains(fixture),
              let store = try? session.create() else {
            return
        }

        defer { try? store.close() }
        do {
            let opportunity = try store.create(
                CreateOpportunity(
                    title: "Fixture opportunity",
                    company: "Fixture employer",
                    nextAction: "Review fixture",
                    dueAt: now,
                    jobURL: "https://jobs.example.test/fixture",
                    location: "Fixture location"
                )
            )

            if fixture == .documentRelink {
                _ = try store.recordDocumentReference(
                    RecordDocumentReference(
                        opportunityID: opportunity.id,
                        kind: .resume,
                        filename: "fixture-resume.pdf",
                        contentType: "application/pdf",
                        sourceHash: "fixture-document-hash",
                        byteCount: 1
                    )
                )
            }

            if fixture == .archive {
                let recoveryKey = try RecoveryKey.generate()
                try store.enroll(recoveryKey: recoveryKey)
                try store.seedVerifiedPortableArchiveCatalogueForVisualFixture(
                    createdAt: now,
                    calendar: calendar
                )
            }
        } catch {
            preconditionFailure("Unable to seed the \(fixture.rawValue) visual fixture: \(error)")
        }
    }
}
