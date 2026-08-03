import AppKit
import Foundation
import SwiftUI

/// Stable, testable values for the first Visual Design v2 foundation slice.
/// Screen-level layout work belongs to the later VD2 tasks; these values remain
/// the semantic seam those tasks consume.
nonisolated enum RekonVisualThemeContract {
    static let emblemAssetName = "RekonEmblem"
    static let brandLockupAccessibilityIdentifier = "sidebar-brand-lockup"
    static let collapseControlAccessibilityIdentifier = "sidebar-collapse"
    static let shellAccessibilityIdentifier = "app-shell"
    static let defaultSpacing: CGFloat = 16
    static let defaultCornerRadius: CGFloat = 16
    static let minimumWindowWidth: CGFloat = 860
    static let minimumWindowHeight: CGFloat = 600
    static let homeFocusAccessibilityIdentifier = "sidebar-home"
    static let brandEmblemTargetSize: CGFloat = 68
    static let brandLockupTextSize: CGFloat = 24
    static let railDestinationMinimumHeight: CGFloat = 56
    static let railIconSize: CGFloat = 24
    static let railSelectedIndicatorWidth: CGFloat = 3

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

/// The visible outline state for a rail destination. Pointer hover takes
/// precedence because the pointer is the immediate input affordance; keyboard
/// focus remains visibly distinct from hover and persistent route selection.
nonisolated enum RekonRailDestinationOutline: Equatable {
    case none
    case pointerHover
    case keyboardFocus
}

/// The input boundary for a navigation destination. Keeping this contract
/// explicit ensures pointer hover and activation are available across the
/// complete row, not just its icon and text.
nonisolated enum RekonRailDestinationInteractionRegion: Equatable {
    case fullRoundedRow
}

/// Rendering decisions for an individual rail destination. Selection is a
/// persistent route state; focus is transient input state. Keeping them
/// separate prevents a pointer click from looking like keyboard focus.
nonisolated enum RekonRailDestinationPresentation {
    static let interactionRegion: RekonRailDestinationInteractionRegion = .fullRoundedRow

    static func selectedIndicatorWidth(isSelected: Bool) -> CGFloat {
        isSelected ? RekonVisualThemeContract.railSelectedIndicatorWidth : 0
    }

    static func showsKeyboardFocus(
        isFocused: Bool,
        suppressingAfterPointerActivation: Bool
    ) -> Bool {
        isFocused && !suppressingAfterPointerActivation
    }

    static func outline(
        isPointerHovering: Bool,
        showsKeyboardFocus: Bool
    ) -> RekonRailDestinationOutline {
        if isPointerHovering {
            return .pointerHover
        }
        if showsKeyboardFocus {
            return .keyboardFocus
        }
        return .none
    }

    static func focusRingLineWidth(for outline: RekonRailDestinationOutline) -> CGFloat {
        outline == .none ? 0 : 2
    }
}

/// The window-level contract for the Visual Design v2 shell.  Keeping this
/// separate from individual screens prevents an intrinsic-width screen from
/// revealing the system canvas around the navigation split view.
nonisolated struct RekonWindowCanvasPolicy: Equatable {
    /// Keep AppKit's titled-window host intact so the native close, minimize,
    /// zoom, resize, and full-screen controls remain owned by the window.
    let preservesNativeWindowControls: Bool
    /// Hide the title text while leaving the native titlebar available.
    let hidesTitleText: Bool
    let fillsRootCanvas: Bool
    let fillsDetailCanvas: Bool
    let usesNavyWindowContainerBackground: Bool
    /// The scene declaration in `BootstrapApp` is the sole toolbar-style owner.
    /// This runtime configurator must never mutate the toolbar style.
    let usesUnifiedCompactWindowToolbar: Bool
    let showsNavyWindowToolbarMaterial: Bool
    let removesTitlebarSeparator: Bool
    /// `NSSplitViewController` permits its managed split view's divider
    /// properties to be configured, but not its child views to be mutated.
    let splitViewDividerStyle: NSSplitView.DividerStyle

    static let standard = Self(
        preservesNativeWindowControls: true,
        hidesTitleText: true,
        fillsRootCanvas: true,
        fillsDetailCanvas: true,
        usesNavyWindowContainerBackground: true,
        usesUnifiedCompactWindowToolbar: false,
        showsNavyWindowToolbarMaterial: true,
        removesTitlebarSeparator: true,
        splitViewDividerStyle: .thin
    )
}

/// Applies the window-owned chrome treatment. SwiftUI background modifiers do
/// not control the native titlebar, toolbar baseline, or `NSSplitView` divider,
/// so this AppKit bridge configures those chrome-owned surfaces while preserving
/// the native traffic lights and resizing behavior.
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
        private weak var observedWindow: NSWindow?
        private var pendingReapply: DispatchWorkItem?

        init(policy: RekonWindowCanvasPolicy) {
            self.policy = policy
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) {
            nil
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            observeWindowTransitions()
            apply(policy: policy)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.apply(policy: self.policy)
            }
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        func apply(policy: RekonWindowCanvasPolicy) {
            self.policy = policy
            guard let window else { return }

            window.standardWindowButton(.closeButton)?.setAccessibilityIdentifier("window-close")
            window.standardWindowButton(.miniaturizeButton)?.setAccessibilityIdentifier("window-miniaturize")
            window.standardWindowButton(.zoomButton)?.setAccessibilityIdentifier("window-zoom")

            if policy.preservesNativeWindowControls {
                window.styleMask.insert(.fullSizeContentView)
            }
            if policy.hidesTitleText {
                window.titleVisibility = .hidden
                window.titlebarAppearsTransparent = true
            }
            if policy.usesNavyWindowContainerBackground {
                window.backgroundColor = NSColor(RekonTheme.background)
                window.isOpaque = true
            }
            window.appearance = NSAppearance(named: .darkAqua)
            if policy.removesTitlebarSeparator {
                window.titlebarSeparatorStyle = .none
                window.toolbar?.showsBaselineSeparator = false
            }
            configureSplitViewDivider(in: window)
        }

        private func observeWindowTransitions() {
            guard let window, observedWindow !== window else { return }

            NotificationCenter.default.removeObserver(self)
            observedWindow = window

            let center = NotificationCenter.default
            [
                NSWindow.didResizeNotification,
                NSWindow.didEndLiveResizeNotification,
                NSWindow.didEnterFullScreenNotification,
                NSWindow.didExitFullScreenNotification,
                NSWindow.didBecomeMainNotification,
                NSWindow.didBecomeKeyNotification
            ].forEach { notification in
                center.addObserver(
                    self,
                    selector: #selector(reapplyWindowChrome(_:)),
                    name: notification,
                    object: window
                )
            }
        }

        @objc private func reapplyWindowChrome(_ notification: Notification) {
            // The notification arrives on AppKit's main thread. Restore the
            // owned chrome immediately so a resize/full-screen transition has
            // no observable system-color gap, then retain the coalesced pass
            // for any AppKit work completed after the notification returns.
            apply(policy: policy)
            pendingReapply?.cancel()
            let reapply = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.apply(policy: self.policy)
            }
            pendingReapply = reapply
            DispatchQueue.main.async(execute: reapply)
        }

        private func configureSplitViewDivider(in window: NSWindow) {
            guard let splitView = window.contentView?.firstDescendant(of: NSSplitView.self) else {
                return
            }
            // This is one of the properties AppKit explicitly allows callers
            // to configure on an NSSplitViewController-managed split view.
            // The policy uses AppKit's hairline divider while retaining its
            // documented clear divider color.
            splitView.dividerStyle = policy.splitViewDividerStyle
        }
    }
}

private extension NSView {
    func firstDescendant<T: NSView>(of type: T.Type) -> T? {
        if let matchingView = self as? T {
            return matchingView
        }
        for subview in subviews {
            if let matchingView = subview.firstDescendant(of: type) {
                return matchingView
            }
        }
        return nil
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

    // Shell colors are deliberately fixed rather than derived from the host
    // appearance. The product shell always renders as a dark surface.
    static let shellForeground = Color(red: 0.94, green: 0.97, blue: 1.0)
    static let shellMutedForeground = Color(red: 0.64, green: 0.71, blue: 0.85)
    static let shellIcon = Color(red: 0.75, green: 0.85, blue: 0.98)
    static let shellSelectedForeground = Color.white
    static let shellToolbarBackground = background
    static let shellRailBackground = backgroundRaised
    static let shellSelectedSurface = Color(red: 0.17, green: 0.18, blue: 0.42)
    static let shellSelectedLeadingAccent = accent
    /// Cyan is reserved for pointer hover on rail destinations, including the
    /// active route. Keyboard focus intentionally uses violet instead.
    static let shellPointerHoverRing = accent
    static let shellKeyboardFocusRing = violet
    static let shellRailDivider = borderSubtle

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

    enum Rail {
        static let minimumWidth: CGFloat = 268
        static let idealWidth: CGFloat = 310
        static let maximumWidth: CGFloat = 340
        static let horizontalInset: CGFloat = 22
        static let brandTopInset: CGFloat = 16
        static let brandSpacing: CGFloat = 12
        static let destinationRowGap: CGFloat = 12
        static let destinationLabelGap: CGFloat = 17
        static let selectedIndicatorWidth = RekonVisualThemeContract.railSelectedIndicatorWidth
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

/// A shared quiet-surface action with a persistent accent outline. Screens use
/// it where an action needs the same visual weight as the reference's "Open"
/// controls without looking like a filled primary button.
struct RekonAccentOutlineButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @FocusState private var isFocused: Bool
    private let labelFont: Font

    init(labelFont: Font = .body.weight(.medium)) {
        self.labelFont = labelFont
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(labelFont)
            .foregroundStyle(RekonTheme.accent)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(RekonTheme.surface.opacity(configuration.isPressed ? 0.62 : 0.9), in: RoundedRectangle(cornerRadius: RekonTheme.Radius.control))
            .overlay(
                RoundedRectangle(cornerRadius: RekonTheme.Radius.control)
                    .stroke(
                        RekonTheme.accent.opacity(configuration.isPressed ? 0.7 : 0.96),
                        lineWidth: RekonVisualThemeContract.buttonFocusBorderWidth(isFocused: isFocused)
                    )
            )
            .shadow(color: RekonTheme.accent.opacity(RekonVisualThemeContract.buttonFocusGlowOpacity(isFocused: isFocused)), radius: 6)
            .contentShape(RoundedRectangle(cornerRadius: RekonTheme.Radius.control))
            .focused($isFocused)
            .opacity(RekonVisualThemeContract.controlOpacity(isEnabled: isEnabled))
    }
}

private struct RekonActionSummarySurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(RekonTheme.backgroundRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(RekonTheme.border.opacity(0.85), lineWidth: 1))
    }
}

extension View {
    func rekonActionSummarySurface() -> some View {
        modifier(RekonActionSummarySurface())
    }

    func rekonFloatingMenuSurface() -> some View {
        background(RekonTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(RekonTheme.border.opacity(0.92), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.32), radius: 18, y: 8)
    }
}

/// Pipeline-local interaction states are deliberately semantic rather than
/// color-based so presentation contracts can be verified without inspecting
/// platform rendering. A selected state is persistent selection, never an
/// action treatment or a substitute for keyboard focus.
nonisolated enum PipelineNavySurfaceInteractionState: CaseIterable, Equatable {
    case idle
    case pointerHover
    case keyboardFocus
    case pressed
    case selected
    case disabled
}

/// Tokens resolved only through the Rekon navy visual system. Keeping the
/// mapping token-based prevents a Pipeline control from falling back to a
/// system-neutral fill while allowing AppKit and SwiftUI renderers to share it.
nonisolated enum PipelineNavySurfaceToken: Equatable {
    case surface
    case elevatedSurface
    case border
    case accent
    case violet
}

/// The complete semantic paint contract for one Pipeline interaction state.
/// It intentionally contains no platform colors so it is independently
/// testable and reusable by SwiftUI and the later AppKit control seam.
nonisolated struct PipelineNavySurfacePresentationValue: Equatable {
    let fill: PipelineNavySurfaceToken
    let outline: PipelineNavySurfaceToken
    let borderWidth: CGFloat
    let opacity: Double
}

nonisolated enum PipelineNavySurfacePresentation {
    static func presentation(
        for state: PipelineNavySurfaceInteractionState
    ) -> PipelineNavySurfacePresentationValue {
        switch state {
        case .idle:
            .init(fill: .surface, outline: .border, borderWidth: 1, opacity: 1)
        case .pointerHover:
            .init(fill: .elevatedSurface, outline: .accent, borderWidth: 1, opacity: 1)
        case .keyboardFocus:
            .init(fill: .elevatedSurface, outline: .violet, borderWidth: 2, opacity: 1)
        case .pressed:
            .init(fill: .elevatedSurface, outline: .accent, borderWidth: 1, opacity: 0.62)
        case .selected:
            .init(fill: .elevatedSurface, outline: .accent, borderWidth: 1, opacity: 1)
        case .disabled:
            .init(fill: .surface, outline: .border, borderWidth: 1, opacity: 0.42)
        }
    }

    /// Compatibility accessors delegate to the one complete presentation
    /// value so old consumers cannot recreate a split state mapping.
    static func fill(for state: PipelineNavySurfaceInteractionState) -> PipelineNavySurfaceToken {
        presentation(for: state).fill
    }

    static func outline(for state: PipelineNavySurfaceInteractionState) -> PipelineNavySurfaceToken {
        presentation(for: state).outline
    }

    static func borderWidth(for state: PipelineNavySurfaceInteractionState) -> CGFloat {
        presentation(for: state).borderWidth
    }

    static func opacity(for state: PipelineNavySurfaceInteractionState) -> Double {
        presentation(for: state).opacity
    }

    static func interactionState(
        isEnabled: Bool,
        isPointerHovering: Bool,
        isKeyboardFocused: Bool,
        isPressed: Bool
    ) -> PipelineNavySurfaceInteractionState {
        if !isEnabled {
            return .disabled
        }
        if isPressed {
            return .pressed
        }
        if isKeyboardFocused {
            return .keyboardFocus
        }
        if isPointerHovering {
            return .pointerHover
        }
        return .idle
    }
}

/// Resolves semantic Pipeline presentation tokens to the existing Rekon
/// palette. It is intentionally Pipeline-local: it neither mutates AppKit's
/// global appearance nor changes the rendering defaults of unrelated forms.
enum PipelineNavySurfaceColor {
    static func resolve(_ token: PipelineNavySurfaceToken) -> Color {
        switch token {
        case .surface:
            RekonTheme.surface
        case .elevatedSurface:
            RekonTheme.elevatedSurface
        case .border:
            RekonTheme.border
        case .accent:
            RekonTheme.accent
        case .violet:
            RekonTheme.violet
        }
    }
}

/// Painting-only primitive for Pipeline controls. It never creates an
/// accessibility element, focus target, or gesture; the containing native
/// control remains the sole owner of those responsibilities.
private struct PipelineNavySurface: ViewModifier {
    let state: PipelineNavySurfaceInteractionState
    let cornerRadius: CGFloat

    private var presentation: PipelineNavySurfacePresentationValue {
        PipelineNavySurfacePresentation.presentation(for: state)
    }

    func body(content: Content) -> some View {
        content
            .background(
                PipelineNavySurfaceColor
                    .resolve(presentation.fill)
                    .opacity(presentation.opacity),
                in: RoundedRectangle(cornerRadius: cornerRadius)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        PipelineNavySurfaceColor.resolve(presentation.outline),
                        lineWidth: presentation.borderWidth
                    )
            )
            .shadow(
                color: PipelineNavySurfaceColor
                    .resolve(presentation.outline)
                    .opacity(state == .keyboardFocus ? 0.45 : 0),
                radius: 6
            )
    }
}

extension View {
    func pipelineNavySurface(
        _ state: PipelineNavySurfaceInteractionState,
        cornerRadius: CGFloat = RekonTheme.Radius.control
    ) -> some View {
        modifier(PipelineNavySurface(state: state, cornerRadius: cornerRadius))
    }
}

/// Pipeline-only secondary action treatment. It is deliberately separate from
/// the shared secondary style so later Pipeline wiring cannot change other
/// product surfaces that use `RekonSecondaryButtonStyle`.
struct PipelineSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        PipelineSecondaryButtonBody(
            label: configuration.label,
            isEnabled: isEnabled,
            isPressed: configuration.isPressed
        )
    }
}

// MARK: - Pipeline-local AppKit controls

/// These controls intentionally own both their AppKit interaction semantics and
/// their visual rendering. A SwiftUI surface behind a standard AppKit control
/// cannot remove the control's opaque gray bezel, which is why these are not
/// general-purpose styles and are only used by Pipeline.
private enum PipelineNativeControlDrawing {
    static let cornerRadius: CGFloat = RekonTheme.Radius.control

    static func paint(
        in rect: NSRect,
        state: PipelineNavySurfaceInteractionState,
        cornerRadius: CGFloat = cornerRadius
    ) {
        let presentation = PipelineNavySurfacePresentation.presentation(for: state)
        let path = NSBezierPath(roundedRect: rect.insetBy(dx: presentation.borderWidth / 2, dy: presentation.borderWidth / 2), xRadius: cornerRadius, yRadius: cornerRadius)
        NSColor(PipelineNavySurfaceColor.resolve(presentation.fill).opacity(presentation.opacity)).setFill()
        path.fill()
        NSColor(PipelineNavySurfaceColor.resolve(presentation.outline)).setStroke()
        path.lineWidth = presentation.borderWidth
        path.stroke()
    }

    static func textColor(isEnabled: Bool) -> NSColor {
        NSColor(isEnabled ? RekonTheme.primaryText : RekonTheme.secondaryText)
    }

    static func secondaryTextColor(isEnabled: Bool) -> NSColor {
        NSColor(isEnabled ? RekonTheme.secondaryText : RekonTheme.secondaryText.opacity(0.64))
    }
}

private class PipelineNativeControl: NSControl {
    var isPointerHovering = false { didSet { needsDisplay = true } }
    var isPressed = false { didSet { needsDisplay = true } }

    override var isEnabled: Bool { didSet { needsDisplay = true } }

    private var trackingArea: NSTrackingArea?

    var interactionState: PipelineNavySurfaceInteractionState {
        PipelineNavySurfacePresentation.interactionState(
            isEnabled: isEnabled,
            isPointerHovering: isPointerHovering,
            isKeyboardFocused: window?.firstResponder === self,
            isPressed: isPressed
        )
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        self.trackingArea = trackingArea
    }

    override func mouseEntered(with event: NSEvent) { isPointerHovering = true }
    override func mouseExited(with event: NSEvent) { isPointerHovering = false }
    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted { needsDisplay = true }
        return accepted
    }
    override func resignFirstResponder() -> Bool {
        let accepted = super.resignFirstResponder()
        if accepted { needsDisplay = true }
        return accepted
    }
    override func mouseDown(with event: NSEvent) {
        isPressed = true
        super.mouseDown(with: event)
        isPressed = false
    }
}

final class PipelineNavySearchField: NSTextField {
    var isPointerHovering = false { didSet { refreshChrome() } }
    private var trackingArea: NSTrackingArea?

    override var isEnabled: Bool { didSet { refreshChrome() } }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isBezeled = false
        isBordered = false
        drawsBackground = false
        focusRingType = .none
        wantsLayer = true
        font = .systemFont(ofSize: 15)
        textColor = PipelineNativeControlDrawing.textColor(isEnabled: true)
        placeholderAttributedString = NSAttributedString(
            string: "Search opportunities",
            attributes: [.foregroundColor: PipelineNativeControlDrawing.secondaryTextColor(isEnabled: true)]
        )
        lineBreakMode = .byTruncatingTail
    }

    required init?(coder: NSCoder) { nil }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let trackingArea = NSTrackingArea(rect: bounds, options: [.activeInKeyWindow, .mouseEnteredAndExited, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
        self.trackingArea = trackingArea
    }

    override func mouseEntered(with event: NSEvent) { isPointerHovering = true }
    override func mouseExited(with event: NSEvent) { isPointerHovering = false }
    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted { refreshChrome() }
        return accepted
    }
    override func resignFirstResponder() -> Bool {
        let accepted = super.resignFirstResponder()
        if accepted { refreshChrome() }
        return accepted
    }

    func refreshChrome() {
        let state = PipelineNavySurfacePresentation.interactionState(
            isEnabled: isEnabled,
            isPointerHovering: isPointerHovering,
            isKeyboardFocused: window?.firstResponder === self,
            isPressed: false
        )
        let presentation = PipelineNavySurfacePresentation.presentation(for: state)
        layer?.backgroundColor = NSColor(PipelineNavySurfaceColor.resolve(presentation.fill).opacity(presentation.opacity)).cgColor
        layer?.borderColor = NSColor(PipelineNavySurfaceColor.resolve(presentation.outline)).cgColor
        layer?.borderWidth = presentation.borderWidth
        layer?.cornerRadius = PipelineNativeControlDrawing.cornerRadius
        layer?.shadowColor = state == .keyboardFocus ? NSColor(RekonTheme.violet).cgColor : nil
        layer?.shadowOpacity = state == .keyboardFocus ? 0.45 : 0
        layer?.shadowRadius = state == .keyboardFocus ? 6 : 0
        textColor = PipelineNativeControlDrawing.textColor(isEnabled: isEnabled)
        placeholderAttributedString = NSAttributedString(
            string: "Search opportunities",
            attributes: [.foregroundColor: PipelineNativeControlDrawing.secondaryTextColor(isEnabled: isEnabled)]
        )
    }
}

final class PipelineNavyPopupButton: NSPopUpButton {
    var isPointerHovering = false { didSet { needsDisplay = true } }
    var isPressed = false { didSet { needsDisplay = true } }
    private var trackingArea: NSTrackingArea?

    override init(frame buttonFrame: NSRect, pullsDown flag: Bool) {
        super.init(frame: buttonFrame, pullsDown: flag)
        isBordered = false
        focusRingType = .none
        font = .systemFont(ofSize: 15, weight: .medium)
    }

    required init?(coder: NSCoder) { nil }

    private var interactionState: PipelineNavySurfaceInteractionState {
        PipelineNavySurfacePresentation.interactionState(isEnabled: isEnabled, isPointerHovering: isPointerHovering, isKeyboardFocused: window?.firstResponder === self, isPressed: isPressed)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let trackingArea = NSTrackingArea(rect: bounds, options: [.activeInKeyWindow, .mouseEnteredAndExited, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
        self.trackingArea = trackingArea
    }

    override func mouseEntered(with event: NSEvent) { isPointerHovering = true }
    override func mouseExited(with event: NSEvent) { isPointerHovering = false }
    override func becomeFirstResponder() -> Bool { let accepted = super.becomeFirstResponder(); if accepted { needsDisplay = true }; return accepted }
    override func resignFirstResponder() -> Bool { let accepted = super.resignFirstResponder(); if accepted { needsDisplay = true }; return accepted }
    override func mouseDown(with event: NSEvent) { isPressed = true; super.mouseDown(with: event); isPressed = false }

    override func draw(_ dirtyRect: NSRect) {
        PipelineNativeControlDrawing.paint(in: bounds, state: interactionState)
        let textRect = bounds.insetBy(dx: 12, dy: 0).insetBy(dx: 0, dy: 1)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .medium),
            .foregroundColor: PipelineNativeControlDrawing.textColor(isEnabled: isEnabled)
        ]
        let titleSize = title.size(withAttributes: attributes)
        title.draw(at: NSPoint(x: textRect.minX, y: textRect.midY - titleSize.height / 2), withAttributes: attributes)
        let arrow = NSBezierPath()
        let arrowCenterX = bounds.maxX - 18
        let arrowCenterY = bounds.midY
        arrow.move(to: NSPoint(x: arrowCenterX - 5, y: arrowCenterY + 2))
        arrow.line(to: NSPoint(x: arrowCenterX, y: arrowCenterY - 3))
        arrow.line(to: NSPoint(x: arrowCenterX + 5, y: arrowCenterY + 2))
        arrow.lineWidth = 1.6
        PipelineNativeControlDrawing.secondaryTextColor(isEnabled: isEnabled).setStroke()
        arrow.stroke()
    }
}

final class PipelineNavyCheckbox: NSButton {
    var isPointerHovering = false { didSet { needsDisplay = true } }
    var isPressed = false { didSet { needsDisplay = true } }
    private var trackingArea: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setButtonType(.switch)
        isBordered = false
        focusRingType = .none
        font = .systemFont(ofSize: 15, weight: .medium)
    }

    required init?(coder: NSCoder) { nil }

    private var interactionState: PipelineNavySurfaceInteractionState {
        PipelineNavySurfacePresentation.interactionState(isEnabled: isEnabled, isPointerHovering: isPointerHovering, isKeyboardFocused: window?.firstResponder === self, isPressed: isPressed)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let trackingArea = NSTrackingArea(rect: bounds, options: [.activeInKeyWindow, .mouseEnteredAndExited, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
        self.trackingArea = trackingArea
    }

    override func mouseEntered(with event: NSEvent) { isPointerHovering = true }
    override func mouseExited(with event: NSEvent) { isPointerHovering = false }
    override func becomeFirstResponder() -> Bool { let accepted = super.becomeFirstResponder(); if accepted { needsDisplay = true }; return accepted }
    override func resignFirstResponder() -> Bool { let accepted = super.resignFirstResponder(); if accepted { needsDisplay = true }; return accepted }
    override func mouseDown(with event: NSEvent) { isPressed = true; super.mouseDown(with: event); isPressed = false }

    override func draw(_ dirtyRect: NSRect) {
        PipelineNativeControlDrawing.paint(in: bounds, state: interactionState)
        let box = NSRect(x: 10, y: bounds.midY - 9, width: 18, height: 18)
        let boxPath = NSBezierPath(roundedRect: box, xRadius: 5, yRadius: 5)
        NSColor(RekonTheme.background).setFill()
        boxPath.fill()
        NSColor(state == .on ? RekonTheme.accent : RekonTheme.border).setStroke()
        boxPath.lineWidth = 1
        boxPath.stroke()
        if state == .on {
            let check = NSBezierPath()
            check.move(to: NSPoint(x: box.minX + 4, y: box.midY))
            check.line(to: NSPoint(x: box.minX + 7.5, y: box.minY + 4.5))
            check.line(to: NSPoint(x: box.maxX - 3.5, y: box.maxY - 4))
            check.lineWidth = 2
            NSColor.white.setStroke()
            check.stroke()
        }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .medium),
            .foregroundColor: PipelineNativeControlDrawing.textColor(isEnabled: isEnabled)
        ]
        let titleSize = title.size(withAttributes: attributes)
        title.draw(at: NSPoint(x: box.maxX + 8, y: bounds.midY - titleSize.height / 2), withAttributes: attributes)
    }
}

final class PipelineNavySegmentedControl: NSSegmentedControl {
    var isPointerHovering = false { didSet { needsDisplay = true } }
    var isPressed = false { didSet { needsDisplay = true } }
    private var trackingArea: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        trackingMode = .selectOne
        focusRingType = .none
    }

    required init?(coder: NSCoder) { nil }

    private var interactionState: PipelineNavySurfaceInteractionState {
        PipelineNavySurfacePresentation.interactionState(isEnabled: isEnabled, isPointerHovering: isPointerHovering, isKeyboardFocused: window?.firstResponder === self, isPressed: isPressed)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let trackingArea = NSTrackingArea(rect: bounds, options: [.activeInKeyWindow, .mouseEnteredAndExited, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
        self.trackingArea = trackingArea
    }

    override func mouseEntered(with event: NSEvent) { isPointerHovering = true }
    override func mouseExited(with event: NSEvent) { isPointerHovering = false }
    override func becomeFirstResponder() -> Bool { let accepted = super.becomeFirstResponder(); if accepted { needsDisplay = true }; return accepted }
    override func resignFirstResponder() -> Bool { let accepted = super.resignFirstResponder(); if accepted { needsDisplay = true }; return accepted }
    override func mouseDown(with event: NSEvent) { isPressed = true; super.mouseDown(with: event); isPressed = false }

    override func draw(_ dirtyRect: NSRect) {
        PipelineNativeControlDrawing.paint(in: bounds, state: interactionState)
        guard segmentCount > 0 else { return }
        let segmentWidth = bounds.width / CGFloat(segmentCount)
        for index in 0..<segmentCount {
            let rect = NSRect(x: CGFloat(index) * segmentWidth, y: 0, width: segmentWidth, height: bounds.height).insetBy(dx: 3, dy: 3)
            let selected = selectedSegment == index
            if selected {
                PipelineNativeControlDrawing.paint(in: rect, state: window?.firstResponder === self ? .keyboardFocus : .selected, cornerRadius: 7)
            }
            let title = label(forSegment: index) ?? ""
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 15, weight: selected ? .semibold : .medium),
                .foregroundColor: PipelineNativeControlDrawing.textColor(isEnabled: isEnabled)
            ]
            let titleSize = title.size(withAttributes: attributes)
            title.draw(at: NSPoint(x: rect.midX - titleSize.width / 2, y: rect.midY - titleSize.height / 2), withAttributes: attributes)
        }
    }
}

struct PipelineNavySearchControl: NSViewRepresentable {
    @Binding var text: String
    let accessibilityIdentifier: String
    let accessibilityLabel: String

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    func makeNSView(context: Context) -> PipelineNavySearchField {
        let field = PipelineNavySearchField(frame: .zero)
        field.delegate = context.coordinator
        field.stringValue = text
        field.setAccessibilityIdentifier(accessibilityIdentifier)
        field.setAccessibilityLabel(accessibilityLabel)
        field.refreshChrome()
        return field
    }

    func updateNSView(_ field: PipelineNavySearchField, context: Context) {
        if field.stringValue != text { field.stringValue = text }
        field.setAccessibilityIdentifier(accessibilityIdentifier)
        field.setAccessibilityLabel(accessibilityLabel)
        field.refreshChrome()
    }

    static func dismantleNSView(_ field: PipelineNavySearchField, coordinator: Coordinator) { field.delegate = nil }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        @Binding var text: String
        init(text: Binding<String>) { _text = text }
        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            text = field.stringValue
        }
    }
}

struct PipelineNavyStageControl: NSViewRepresentable {
    @Binding var selection: String
    let options: [String]
    let accessibilityIdentifier: String
    let accessibilityLabel: String

    func makeCoordinator() -> Coordinator { Coordinator(selection: $selection) }

    func makeNSView(context: Context) -> PipelineNavyPopupButton {
        let popup = PipelineNavyPopupButton(frame: .zero, pullsDown: false)
        popup.addItems(withTitles: options)
        popup.selectItem(withTitle: selection)
        popup.target = context.coordinator
        popup.action = #selector(Coordinator.selectStage(_:))
        popup.setAccessibilityIdentifier(accessibilityIdentifier)
        popup.setAccessibilityLabel(accessibilityLabel)
        return popup
    }

    func updateNSView(_ popup: PipelineNavyPopupButton, context: Context) {
        if popup.itemTitles != options {
            popup.removeAllItems()
            popup.addItems(withTitles: options)
        }
        if popup.titleOfSelectedItem != selection { popup.selectItem(withTitle: selection) }
        popup.setAccessibilityIdentifier(accessibilityIdentifier)
        popup.setAccessibilityLabel(accessibilityLabel)
        popup.needsDisplay = true
    }

    final class Coordinator: NSObject {
        @Binding var selection: String
        init(selection: Binding<String>) { _selection = selection }
        @objc func selectStage(_ sender: NSPopUpButton) { selection = sender.titleOfSelectedItem ?? selection }
    }
}

struct PipelineNavyCheckboxControl: NSViewRepresentable {
    @Binding var isOn: Bool
    let title: String
    let accessibilityIdentifier: String
    let accessibilityLabel: String
    let accessibilityValue: String

    func makeCoordinator() -> Coordinator { Coordinator(isOn: $isOn) }

    func makeNSView(context: Context) -> PipelineNavyCheckbox {
        let checkbox = PipelineNavyCheckbox(frame: .zero)
        checkbox.title = title
        checkbox.state = isOn ? .on : .off
        checkbox.target = context.coordinator
        checkbox.action = #selector(Coordinator.toggle(_:))
        checkbox.setAccessibilityIdentifier(accessibilityIdentifier)
        checkbox.setAccessibilityLabel(accessibilityLabel)
        return checkbox
    }

    func updateNSView(_ checkbox: PipelineNavyCheckbox, context: Context) {
        checkbox.title = title
        checkbox.state = isOn ? .on : .off
        checkbox.setAccessibilityIdentifier(accessibilityIdentifier)
        checkbox.setAccessibilityLabel(accessibilityLabel)
        checkbox.needsDisplay = true
    }

    final class Coordinator: NSObject {
        @Binding var isOn: Bool
        init(isOn: Binding<Bool>) { _isOn = isOn }
        @objc func toggle(_ sender: NSButton) { isOn = sender.state == .on }
    }
}

struct PipelineNavyViewModeControl: NSViewRepresentable {
    @Binding var showsBoard: Bool
    let accessibilityIdentifier: String
    let accessibilityLabel: String

    func makeCoordinator() -> Coordinator { Coordinator(showsBoard: $showsBoard) }

    func makeNSView(context: Context) -> PipelineNavySegmentedControl {
        let segmented = PipelineNavySegmentedControl(frame: .zero)
        segmented.segmentCount = 2
        segmented.setLabel("Table", forSegment: 0)
        segmented.setLabel("Board", forSegment: 1)
        segmented.selectedSegment = showsBoard ? 1 : 0
        segmented.target = context.coordinator
        segmented.action = #selector(Coordinator.selectMode(_:))
        segmented.setAccessibilityIdentifier(accessibilityIdentifier)
        // Match the pre-existing SwiftUI segmented Picker projection while
        // preserving the native radio descendants' individual Table/Board
        // labels. Existing assistive-tech automation uses this composite
        // group label as its stable contract.
        segmented.setAccessibilityLabel("\(accessibilityLabel), \(accessibilityLabel)")
        return segmented
    }

    func updateNSView(_ segmented: PipelineNavySegmentedControl, context: Context) {
        let selection = showsBoard ? 1 : 0
        if segmented.selectedSegment != selection { segmented.selectedSegment = selection }
        segmented.setAccessibilityIdentifier(accessibilityIdentifier)
        segmented.setAccessibilityLabel("\(accessibilityLabel), \(accessibilityLabel)")
        segmented.needsDisplay = true
    }

    final class Coordinator: NSObject {
        @Binding var showsBoard: Bool
        init(showsBoard: Binding<Bool>) { _showsBoard = showsBoard }
        @objc func selectMode(_ sender: NSSegmentedControl) { showsBoard = sender.selectedSegment == 1 }
    }
}

private struct PipelineSecondaryButtonBody<Label: View>: View {
    let label: Label
    let isEnabled: Bool
    let isPressed: Bool
    @State private var isPointerHovering = false
    @FocusState private var isFocused: Bool

    private var interactionState: PipelineNavySurfaceInteractionState {
        PipelineNavySurfacePresentation.interactionState(
            isEnabled: isEnabled,
            isPointerHovering: isPointerHovering,
            isKeyboardFocused: isFocused,
            isPressed: isPressed
        )
    }

    var body: some View {
        label
            .font(.body.weight(.medium))
            .foregroundStyle(RekonTheme.primaryText)
            .padding(.horizontal, RekonTheme.Spacing.standard)
            .padding(.vertical, RekonTheme.Spacing.tight)
            .pipelineNavySurface(interactionState)
            .contentShape(RoundedRectangle(cornerRadius: RekonTheme.Radius.control))
            .focused($isFocused)
            .onHover { isPointerHovering = $0 }
    }
}

/// A compact, application-owned field treatment for forms that use explicit
/// labels.  The native text field is the sole visual and input surface: this
/// style removes AppKit's default bezel before painting one quiet navy surface
/// and one border.  It deliberately does not add an enclosing wrapper.
struct RekonQuietTextFieldStyle: TextFieldStyle {
    @FocusState private var isFocused: Bool

    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .textFieldStyle(.plain)
            .padding(.horizontal, 10)
            .frame(minHeight: 34)
            .background(RekonTheme.backgroundRaised, in: RoundedRectangle(cornerRadius: 7))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(
                        isFocused ? RekonTheme.accent : RekonTheme.border.opacity(0.72),
                        lineWidth: isFocused ? 1.5 : 1
                    )
                    .allowsHitTesting(false)
            )
            .focused($isFocused)
    }
}

/// Paint-only counterpart for a native `TextEditor`.  The caller supplies its
/// real focus state; no overlay is interactive and no extra focus target is
/// introduced.
private struct RekonQuietTextEditorSurface: ViewModifier {
    let isFocused: Bool

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(RekonTheme.backgroundRaised, in: RoundedRectangle(cornerRadius: 7))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(
                        isFocused ? RekonTheme.accent : RekonTheme.border.opacity(0.72),
                        lineWidth: isFocused ? 1.5 : 1
                    )
                    .allowsHitTesting(false)
            )
    }
}

extension View {
    func rekonQuietTextEditorSurface(isFocused: Bool) -> some View {
        modifier(RekonQuietTextEditorSurface(isFocused: isFocused))
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

#if REKON_UI_TEST_HOST
nonisolated enum VisualFixtureID: String, CaseIterable, Equatable {
    case empty
    case populated
    case contacts
    case contactsEmpty = "contacts-empty"
    case pipeline
    case recovery
    case error
    case archive
    case documentRelink = "document-relink"
    case reconciliation
}

nonisolated enum VisualFixtureStageMoveScenario: String, CaseIterable, Equatable {
    case blockedClose = "stage-move-blocked-close"
    case unavailable = "stage-move-unavailable"
    case writeFailure = "stage-move-write-failure"
    case projectionFailure = "stage-move-projection-failure"
}

nonisolated enum VisualFixtureInvalidDragSource: CaseIterable {
    case empty
    case oversized
    case malformed
    case unknown

    var accessibilityIdentifier: String {
        switch self {
        case .empty: "pipeline-invalid-drag-empty"
        case .oversized: "pipeline-invalid-drag-oversized"
        case .malformed: "pipeline-invalid-drag-malformed"
        case .unknown: "pipeline-invalid-drag-unknown"
        }
    }

    var shortLabel: String {
        switch self {
        case .empty: "Empty"
        case .oversized: "129B"
        case .malformed: "UTF-8"
        case .unknown: "Unknown"
        }
    }

    private var data: Data {
        switch self {
        case .empty:
            Data()
        case .oversized:
            Data(repeating: UInt8(ascii: "a"), count: 129)
        case .malformed:
            Data([0xFF, 0xFE])
        case .unknown:
            Data("00000000-0000-4000-8000-000000000999".utf8)
        }
    }

    @MainActor
    func provider() -> NSItemProvider {
        NSItemProvider(
            item: data as NSData,
            typeIdentifier: "public.utf8-plain-text"
        )
    }
}

@MainActor
final class VisualFixtureStageMoveObservations: ObservableObject {
    static let shared = VisualFixtureStageMoveObservations()

    @Published private(set) var providerDeliveries = 0
    @Published private(set) var validationRejections = 0
    @Published private(set) var commandDispatches = 0
    @Published private(set) var motionExecutions = 0
    @Published private(set) var motionSuppressions = 0

    static var exposesInvalidDragSources: Bool {
        guard let configuration = VisualFixtureLaunchConfiguration.currentProcess() else {
            return false
        }
        return configuration.fixture == .pipeline
            && configuration.stageMoveScenario == nil
    }

    var invalidDropValue: String {
        "deliveries=\(providerDeliveries); rejections=\(validationRejections); commands=\(commandDispatches)"
    }

    var motionValue: String {
        "executed=\(motionExecutions); suppressed=\(motionSuppressions)"
    }

    func recordProviderDelivery() {
        providerDeliveries += 1
    }

    func recordValidationRejection() {
        validationRejections += 1
    }

    func recordCommandDispatch() {
        commandDispatches += 1
    }

    func recordMotion(executed: Bool) {
        if executed {
            motionExecutions += 1
        } else {
            motionSuppressions += 1
        }
    }
}

/// An opt-in UI-test-only launch seam. No path, keychain account, fixture ID,
/// or clock is configurable through production workspace preferences.
nonisolated struct VisualFixtureLaunchConfiguration: Equatable {
    static let argument = "-rekon-visual-fixture"
    static let cleanupArgument = "-rekon-visual-fixture-cleanup"
    static let fixtureSessionEnvironmentKey = "REKON_VISUAL_FIXTURE_SESSION"
    static let fixedNow = Date(timeIntervalSince1970: 1_746_532_800) // 2025-05-06T12:00:00Z

    let fixture: VisualFixtureID
    let stageMoveScenario: VisualFixtureStageMoveScenario?
    let fixtureBaseRoot: URL
    let sessionRoot: URL
    let root: URL
    let keychainNamespace: String
    let now: Date
    let timeZone: TimeZone

    init(
        fixture: VisualFixtureID,
        session: String,
        now: Date = Self.fixedNow,
        timeZone: TimeZone = TimeZone(secondsFromGMT: 0)!,
        fixtureBaseRoot: URL = Self.fixtureBaseRoot
    ) {
        self.init(
            fixture: fixture,
            stageMoveScenario: nil,
            session: session,
            now: now,
            timeZone: timeZone,
            fixtureBaseRoot: fixtureBaseRoot
        )
    }

    private init(
        fixture: VisualFixtureID,
        stageMoveScenario: VisualFixtureStageMoveScenario?,
        session: String,
        now: Date,
        timeZone: TimeZone,
        fixtureBaseRoot: URL
    ) {
        let sanitizedSession = Self.sanitizedSession(session)
        let standardizedBaseRoot = fixtureBaseRoot.standardizedFileURL
        let fixtureIdentifier = stageMoveScenario?.rawValue ?? fixture.rawValue
        self.fixture = fixture
        self.stageMoveScenario = stageMoveScenario
        self.fixtureBaseRoot = standardizedBaseRoot
        sessionRoot = standardizedBaseRoot
            .appendingPathComponent(sanitizedSession, isDirectory: true)
        root = sessionRoot.appendingPathComponent(fixtureIdentifier, isDirectory: true)
        keychainNamespace = "com.rekonlabs.RekonPursuit.visual-fixture.\(sanitizedSession).\(fixtureIdentifier)"
        self.now = now
        self.timeZone = timeZone

        // Preserve the fixture host's explicit isolation-proof contract, but
        // never publish it until every fixture path component is verified.
        try? prepareFixtureRoot()
    }

    init?(arguments: [String], environment: [String: String]) {
        guard let argumentIndex = arguments.firstIndex(of: Self.argument),
              arguments.indices.contains(argumentIndex + 1) else {
            return nil
        }
        let rawIdentifier = arguments[argumentIndex + 1]
        let session = environment[Self.fixtureSessionEnvironmentKey] ?? "direct-initializer"
        if let fixture = VisualFixtureID(rawValue: rawIdentifier) {
            self.init(fixture: fixture, session: session)
        } else if let scenario = VisualFixtureStageMoveScenario(rawValue: rawIdentifier) {
            self.init(
                fixture: .pipeline,
                stageMoveScenario: scenario,
                session: session,
                now: Self.fixedNow,
                timeZone: TimeZone(secondsFromGMT: 0)!,
                fixtureBaseRoot: Self.fixtureBaseRoot
            )
        } else {
            return nil
        }
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

    /// Creates the exact fixture path only after confirming every owned path
    /// component is a real directory beneath the fixture base. This must run
    /// before the proof, fixture keys, or encrypted database are touched.
    func prepareFixtureRoot() throws {
        let base = fixtureBaseRoot.standardizedFileURL
        let session = sessionRoot.standardizedFileURL
        let fixtureRoot = root.standardizedFileURL
        guard session.pathComponents.starts(with: base.pathComponents),
              fixtureRoot.pathComponents.starts(with: session.pathComponents),
              session != base,
              fixtureRoot != session else {
            throw VisualFixturePathError.notOwned
        }

        try Self.createOwnedDirectory(at: base)
        try Self.createOwnedDirectory(at: session)
        try Self.createOwnedDirectory(at: fixtureRoot)
        try verifyPreparedFixtureRoot()
        try Self.publishIsolationProof(at: fixtureRoot)
    }

    func verifyPreparedFixtureRoot() throws {
        let base = fixtureBaseRoot.standardizedFileURL
        let session = sessionRoot.standardizedFileURL
        let fixtureRoot = root.standardizedFileURL
        guard !Self.isSymbolicLink(at: base),
              !Self.isSymbolicLink(at: session),
              !Self.isSymbolicLink(at: fixtureRoot),
              FileManager.default.fileExists(atPath: base.path),
              FileManager.default.fileExists(atPath: session.path),
              FileManager.default.fileExists(atPath: fixtureRoot.path),
              fixtureRoot.resolvingSymlinksInPath().standardizedFileURL.path.hasPrefix(
                base.resolvingSymlinksInPath().standardizedFileURL.path + "/"
              ) else {
            throw VisualFixturePathError.notOwned
        }
    }

    private static func createOwnedDirectory(at url: URL) throws {
        guard !isSymbolicLink(at: url) else { throw VisualFixturePathError.notOwned }
        if FileManager.default.fileExists(atPath: url.path) {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                throw VisualFixturePathError.notOwned
            }
        } else {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        }
        guard !isSymbolicLink(at: url) else { throw VisualFixturePathError.notOwned }
    }

    private static func publishIsolationProof(at root: URL) throws {
        let proof = root.appendingPathComponent(".live-store-access-disabled")
        guard !isSymbolicLink(at: proof) else { throw VisualFixturePathError.notOwned }
        let contents = "Visual fixture only. Personal workspace, keychain, and live support DB access are disabled.\n"
        try Data(contents.utf8).write(to: proof, options: .atomic)
    }

    private static func isSymbolicLink(at url: URL) -> Bool {
        (try? FileManager.default.destinationOfSymbolicLink(atPath: url.path)) != nil
    }

    static func sanitizedSession(_ value: String?) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
        let sanitized = value?.unicodeScalars.filter { allowed.contains($0) }.map(String.init).joined() ?? ""
        return sanitized.isEmpty ? "direct-initializer" : sanitized
    }
}

private enum VisualFixturePathError: Error {
    case notOwned
}

nonisolated struct VisualFixtureCleanupConfiguration: Equatable {
    let sessionRoot: URL

    init?(arguments: [String], environment: [String: String]) {
        guard arguments.contains(VisualFixtureLaunchConfiguration.cleanupArgument) else {
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
        if case let .application(configuration) = self {
            return configuration != nil
        }
        return false
    }
}

nonisolated final class VisualFixtureWorkspaceKeyStore: WorkspaceKeyStore {
    private let lock = NSLock()
    let namespace: String
    private let root: URL
    private let verifyRoot: () throws -> Void
    private let primaryURL: URL
    private let pendingURL: URL

    init(namespace: String, root: URL, verifyRoot: @escaping () throws -> Void) {
        self.namespace = namespace
        self.root = root
        self.verifyRoot = verifyRoot
        primaryURL = root.appendingPathComponent("fixture-primary-workspace-key", isDirectory: false)
        pendingURL = root.appendingPathComponent("fixture-pending-workspace-key", isDirectory: false)
    }

    func readWorkspaceKey() throws -> Data? {
        try lock.withLock { try readKey(at: primaryURL) }
    }

    func writeWorkspaceKey(_ key: Data) throws {
        try lock.withLock { try writeKey(key, to: primaryURL) }
    }

    func deleteWorkspaceKey() throws {
        try lock.withLock { try deleteKey(at: primaryURL) }
    }

    func readPendingWorkspaceKey() throws -> Data? {
        try lock.withLock { try readKey(at: pendingURL) }
    }

    func writePendingWorkspaceKey(_ key: Data) throws {
        try lock.withLock { try writeKey(key, to: pendingURL) }
    }

    func promotePendingWorkspaceKey() throws {
        try lock.withLock {
            guard let pending = try readKey(at: pendingURL) else {
                return
            }
            try writeKey(pending, to: primaryURL)
            try deleteKey(at: pendingURL)
        }
    }

    func deletePendingWorkspaceKey() throws {
        try lock.withLock { try deleteKey(at: pendingURL) }
    }

    private func readKey(at url: URL) throws -> Data? {
        try verifyRoot()
        guard !isSymbolicLink(at: url) else { throw VisualFixturePathError.notOwned }
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try Data(contentsOf: url)
    }

    private func writeKey(_ key: Data, to url: URL) throws {
        try verifyRoot()
        guard !isSymbolicLink(at: url) else { throw VisualFixturePathError.notOwned }
        try key.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private func deleteKey(at url: URL) throws {
        try verifyRoot()
        guard !isSymbolicLink(at: url) else { throw VisualFixturePathError.notOwned }
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    private func isSymbolicLink(at url: URL) -> Bool {
        (try? FileManager.default.destinationOfSymbolicLink(atPath: url.path)) != nil
    }
}

@MainActor
enum VisualFixtureWorkspace {
    static func makeViewModel(
        configuration: VisualFixtureLaunchConfiguration
    ) -> WorkspaceViewModel {
        guard (try? configuration.prepareFixtureRoot()) != nil else {
            return unavailableFixtureViewModel()
        }

        let keyStore = VisualFixtureWorkspaceKeyStore(
            namespace: configuration.keychainNamespace,
            root: configuration.root,
            verifyRoot: configuration.verifyPreparedFixtureRoot
        )
        let session = WorkspaceSession(
            root: configuration.root,
            keyStore: keyStore,
            newKey: { Data(repeating: 0xA5, count: 32) },
            now: configuration.now,
            archiveSigningKeyStore: InMemoryArchiveSigningKeyStore()
        )

        if case .ready? = try? session.open() {
            // Keep a test's isolated fixture intact across an explicit process
            // relaunch so UI tests exercise the same persistent workspace.
        } else {
            guard removeTemporaryFixtureRoot(configuration.root),
                  (try? configuration.prepareFixtureRoot()) != nil else {
                return unavailableFixtureViewModel()
            }
            seedFixtureIfNeeded(
                configuration.fixture,
                stageMoveScenario: configuration.stageMoveScenario,
                session: session,
                now: configuration.now,
                calendar: configuration.fixtureCalendar
            )
        }

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

        var openedStore: WorkspaceStore?
        let stageMoveFailurePoint: StageMoveFailurePoint?
        switch configuration.stageMoveScenario {
        case .writeFailure:
            stageMoveFailurePoint = .beforeWrite
        case .projectionFailure:
            stageMoveFailurePoint = .beforeProjectionRead
        default:
            stageMoveFailurePoint = nil
        }
        let openFixtureWorkspace: () throws -> WorkspaceOpenState = {
            let state: WorkspaceOpenState
            if let stageMoveFailurePoint {
                state = try openStageMoveFailureFixture(
                    configuration: configuration,
                    keyStore: keyStore,
                    failurePoint: stageMoveFailurePoint
                )
            } else {
                state = try session.open()
            }
            if case let .ready(store) = state {
                openedStore = store
            }
            return state
        }

        if let stageMoveScenario = configuration.stageMoveScenario {
            let model = WorkspaceViewModel(
                openWorkspace: openFixtureWorkspace,
                createWorkspace: session.create,
                workspaceLocationBookmarks: isolatedBookmarks,
                publicURLChecker: VisualFixturePublicURLChecker(),
                separateLocalWorkspace: disabledSeparateWorkspace
            )
            if stageMoveScenario == .unavailable {
                VisualFixtureStageMoveHooks.registerBeforeDispatch(for: model) {
                    guard let store = openedStore,
                          let opportunityID = try store.opportunities().first?.id else {
                        return
                    }
                    try store.deleteOpportunity(id: opportunityID)
                }
            }
            return model
        }

        switch configuration.fixture {
        case .recovery:
            return WorkspaceViewModel(
                openWorkspace: { .recoveryRequired },
                createWorkspace: { try session.create() },
                workspaceLocationBookmarks: isolatedBookmarks,
                publicURLChecker: VisualFixturePublicURLChecker(),
                separateLocalWorkspace: disabledSeparateWorkspace
            )
        case .error:
            return WorkspaceViewModel(
                openWorkspace: { .unavailable },
                createWorkspace: { throw WorkspaceStoreError.injectedFailure },
                workspaceLocationBookmarks: isolatedBookmarks,
                publicURLChecker: VisualFixturePublicURLChecker(),
                separateLocalWorkspace: disabledSeparateWorkspace
            )
        case .empty, .populated, .contacts, .contactsEmpty, .pipeline, .archive, .documentRelink, .reconciliation:
            return WorkspaceViewModel(
                openWorkspace: openFixtureWorkspace,
                createWorkspace: session.create,
                workspaceLocationBookmarks: isolatedBookmarks,
                publicURLChecker: VisualFixturePublicURLChecker(),
                separateLocalWorkspace: disabledSeparateWorkspace
            )
        }
    }

    private static func openStageMoveFailureFixture(
        configuration: VisualFixtureLaunchConfiguration,
        keyStore: VisualFixtureWorkspaceKeyStore,
        failurePoint: StageMoveFailurePoint
    ) throws -> WorkspaceOpenState {
        guard let key = try keyStore.readWorkspaceKey() else {
            return .recoveryRequired
        }
        let database = try EncryptedDatabase.open(
            url: configuration.root.appendingPathComponent("workspace.sqlite"),
            key: key,
            createIfMissing: false
        )
        return .ready(
            try WorkspaceStore(
                database: database,
                now: configuration.now,
                actorID: "local-user",
                correlationID: "visual-stage-move",
                stageMoveFailurePoint: failurePoint,
                archiveSigningKeyStore: InMemoryArchiveSigningKeyStore()
            )
        )
    }

    private static func unavailableFixtureViewModel() -> WorkspaceViewModel {
        WorkspaceViewModel(
            openWorkspace: { .unavailable },
            createWorkspace: { throw WorkspaceStoreError.injectedFailure },
            separateLocalWorkspace: SeparateLocalWorkspaceDependencies(
                selectedIdentity: { nil },
                allocateAndPersistIdentity: { throw WorkspaceStoreError.injectedFailure },
                open: { _ in .unavailable },
                create: { _ in throw WorkspaceStoreError.injectedFailure },
                clearSelection: {}
            )
        )
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
        stageMoveScenario: VisualFixtureStageMoveScenario?,
        session: WorkspaceSession,
        now: Date,
        calendar: Calendar
    ) {
        guard stageMoveScenario != nil
                || [.populated, .contacts, .contactsEmpty, .pipeline, .archive, .documentRelink, .reconciliation].contains(fixture),
              let store = try? session.create() else {
            return
        }

        defer { try? store.close() }
        do {
            if fixture == .contacts {
                let linkedOpportunity = try store.create(
                    CreateOpportunity(
                        title: "Contacts Linked Opportunity",
                        company: "Fixture North",
                        stage: .applied,
                        nextAction: "Review fixture",
                        dueAt: now,
                        jobURL: "https://jobs.example.test/contacts-linked",
                        location: "Fixture North",
                        applicationDate: now
                    )
                )
                _ = try store.create(
                    CreateOpportunity(
                        title: "Contacts Unlinked Opportunity",
                        company: "Fixture North",
                        stage: .saved,
                        nextAction: "Review fixture",
                        dueAt: now,
                        jobURL: "https://jobs.example.test/contacts-unlinked",
                        location: "Fixture North",
                        applicationDate: now
                    )
                )
                let primary = try store.createContact(CreateContact(
                    name: "Contacts Primary", employer: "Fixture North",
                    workEmail: "primary.work@example.test", personalEmail: "primary.personal@example.test",
                    mobilePhone: "+1 212 555 0101", officePhone: "+1 212 555 0102",
                    linkedInURL: "https://linkedin.example.test/in/primary",
                    instagramURL: "https://instagram.example.test/primary",
                    facebookURL: "https://facebook.example.test/primary"
                ))
                _ = try store.createContact(
                    CreateContact(name: "Contacts Secondary", employer: "Fixture South")
                )
                _ = try store.createContact(
                    CreateContact(name: "Contacts Unlinked", employer: "Fixture North")
                )
                try store.linkContact(contactID: primary.id, toOpportunityID: linkedOpportunity.id)
                return
            }

            if fixture == .contactsEmpty {
                return
            }

            if fixture == .pipeline, stageMoveScenario == nil {
                _ = try store.create(CreateOpportunity(
                    title: "Senior iOS Engineer",
                    company: "Nebula Labs",
                    stage: .saved,
                    nextAction: "Research company",
                    dueAt: now.addingTimeInterval(259_200),
                    location: "Boston, MA",
                    workArrangement: .hybrid,
                    applicationDate: now
                ))
                _ = try store.create(CreateOpportunity(
                    title: "Senior Product Manager",
                    company: "Northstar Labs",
                    stage: .applied,
                    nextAction: "Prepare portfolio",
                    dueAt: now,
                    location: "New York, NY",
                    workArrangement: .hybrid,
                    applicationDate: now
                ))
                _ = try store.create(CreateOpportunity(
                    title: "Product Designer",
                    company: "Northstar Labs",
                    stage: .screening,
                    nextAction: "Schedule recruiter call",
                    dueAt: now.addingTimeInterval(86_400),
                    location: "Austin, TX",
                    workArrangement: .remote,
                    applicationDate: now
                ))
                _ = try store.create(CreateOpportunity(
                    title: "Research Lead",
                    company: "Other employer",
                    stage: .interviewing,
                    nextAction: "Complete panel interview",
                    dueAt: now.addingTimeInterval(172_800),
                    location: "Remote",
                    workArrangement: .remote,
                    applicationDate: now
                ))
                _ = try store.create(CreateOpportunity(
                    title: "Platform Engineer",
                    company: "Apex Cloud",
                    stage: .offer,
                    nextAction: "Review offer",
                    dueAt: now.addingTimeInterval(345_600),
                    location: "San Francisco, CA",
                    workArrangement: .remote,
                    applicationDate: now
                ))
                _ = try store.create(CreateOpportunity(
                    title: "Closed opportunity",
                    company: "Northstar Labs",
                    stage: .closed,
                    nextAction: "Archive correspondence",
                    dueAt: now.addingTimeInterval(432_000),
                    location: "Chicago, IL",
                    workArrangement: .onSite,
                    applicationDate: now
                ))
                return
            }

            if let stageMoveScenario {
                let opportunity = try store.create(
                    CreateOpportunity(
                        title: "Stage move subject",
                        company: "Fixture employer",
                        stage: .saved,
                        nextAction: "Review fixture",
                        dueAt: now,
                        jobURL: "https://jobs.example.test/stage-move",
                        location: "Fixture location",
                        applicationDate: now
                    )
                )
                if stageMoveScenario == .blockedClose {
                    _ = try store.recordReconciliationResult(
                        RecordReconciliationResult(
                            opportunityID: opportunity.id,
                            url: opportunity.jobURL,
                            outcome: .needsManualReview,
                            classification: .offlineUnchecked,
                            reason: .offlineUnchecked,
                            evidence: "Offline — check not run"
                        )
                    )
                }
                return
            }

            let opportunity = try store.create(
                CreateOpportunity(
                    title: "Fixture opportunity",
                    company: "Fixture employer",
                    stage: .applied,
                    nextAction: "Review fixture",
                    dueAt: now,
                    jobURL: "https://jobs.example.test/fixture",
                    location: "Fixture location",
                    applicationDate: now
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

            if fixture == .reconciliation {
                _ = try store.recordReconciliationResult(
                    RecordReconciliationResult(
                        opportunityID: opportunity.id,
                        url: opportunity.jobURL,
                        outcome: .needsManualReview,
                        classification: .offlineUnchecked,
                        reason: .offlineUnchecked,
                        evidence: "Offline — check not run"
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

@MainActor
enum VisualFixtureStageMoveHooks {
    private static var beforeDispatch: [ObjectIdentifier: () throws -> Void] = [:]

    static func registerBeforeDispatch(
        for model: WorkspaceViewModel,
        action: @escaping () throws -> Void
    ) {
        beforeDispatch[ObjectIdentifier(model)] = action
    }

    static func runBeforeDispatch(for model: WorkspaceViewModel) {
        guard let action = beforeDispatch.removeValue(forKey: ObjectIdentifier(model)) else {
            return
        }
        try? action()
    }
}

@MainActor
private final class VisualFixturePublicURLChecker: PublicURLChecking {
    func prepare(_ savedURL: String) -> PublicURLPreparation {
        guard let components = URLComponents(string: savedURL),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let hostname = components.host,
              !hostname.isEmpty else {
            return .malformed
        }

        let path = components.percentEncodedPath.isEmpty ? "/" : components.percentEncodedPath
        let query = components.percentEncodedQuery.map { "?\($0)" } ?? ""
        return .eligible(
            PublicURLRequest(
                originalURL: savedURL,
                hostname: hostname,
                requestTarget: path + query
            )
        )
    }

    func check(_ request: PublicURLRequest, opportunityTitle: String) async -> PublicURLCheckCompletion {
        while !Task.isCancelled {
            await Task.yield()
        }
        return PublicURLCheckCompletion(
            terminalState: .cancelled,
            outcome: .needsManualReview,
            classification: .offlineUnchecked,
            reason: .offlineUnchecked,
            evidence: "Visual fixture check cancelled before any network request."
        )
    }
}
#endif
