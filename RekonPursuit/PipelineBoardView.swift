import AppKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

nonisolated struct PipelineStageMoveRequest: Equatable {
    let opportunityID: String
    let target: PipelineStage
}

nonisolated struct PipelineCardActionsConfiguration: Equatable {
    let editTitle: String
    let moveTitle: String
    let moveTargets: [PipelineStage]

    static let canonical = Self(
        editTitle: "Edit opportunity",
        moveTitle: "Move to stage…",
        moveTargets: PipelineStage.allCases
    )
}

@MainActor
enum PipelineCardActionsMenuBuilder {
    static func makeMenu(
        configuration: PipelineCardActionsConfiguration,
        edit: @escaping () -> Void,
        move: @escaping (PipelineStage) -> Void
    ) -> NSMenu {
        let menu = NSMenu(title: "Opportunity actions")
        menu.addItem(makeActionItem(title: configuration.editTitle, handler: edit))

        let moveItem = NSMenuItem(title: configuration.moveTitle, action: nil, keyEquivalent: "")
        let moveSubmenu = NSMenu(title: configuration.moveTitle)
        configuration.moveTargets.forEach { stage in
            moveSubmenu.addItem(
                makeActionItem(title: stage.rawValue) {
                    move(stage)
                }
            )
        }
        moveItem.submenu = moveSubmenu
        menu.addItem(moveItem)
        return menu
    }

    private static func makeActionItem(title: String, handler: @escaping () -> Void) -> NSMenuItem {
        let actionTarget = PipelineCardActionTarget(handler: handler)
        let item = NSMenuItem(
            title: title,
            action: #selector(PipelineCardActionTarget.performAction(_:)),
            keyEquivalent: ""
        )
        item.target = actionTarget
        item.representedObject = actionTarget
        return item
    }
}

@MainActor
private final class PipelineCardActionTarget: NSObject {
    private let handler: () -> Void

    init(handler: @escaping () -> Void) {
        self.handler = handler
        super.init()
    }

    @objc func performAction(_ sender: NSMenuItem) {
        handler()
    }
}

/// The native drag boundary intentionally carries one UTF-8 identifier and
/// nothing else. Every drop resolves that identifier against the current
/// committed projection before a command can be dispatched.
nonisolated enum PipelineStageMovePayload {
    static let maximumByteCount = 128

    static func data(forOpportunityID opportunityID: String) -> Data? {
        guard isWellFormed(opportunityID) else { return nil }
        return Data(opportunityID.utf8)
    }

    static func request(
        from data: Data?,
        target: PipelineStage?,
        knownOpportunityIDs: Set<String>,
        isCancelled: Bool,
        isInsideTarget: Bool
    ) -> PipelineStageMoveRequest? {
        guard !isCancelled,
              isInsideTarget,
              let target,
              let data,
              !data.isEmpty,
              data.count <= maximumByteCount,
              let opportunityID = String(data: data, encoding: .utf8),
              isWellFormed(opportunityID),
              knownOpportunityIDs.contains(opportunityID) else {
            return nil
        }
        return PipelineStageMoveRequest(opportunityID: opportunityID, target: target)
    }

    private static func isWellFormed(_ opportunityID: String) -> Bool {
        guard !opportunityID.isEmpty,
              opportunityID.utf8.count <= maximumByteCount else {
            return false
        }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        return opportunityID.unicodeScalars.allSatisfy(allowed.contains)
    }
}

nonisolated struct PipelineStageMovePresentation: Equatable {
    let outcomeText: String
    let presentedStage: PipelineStage
    let boardLane: PipelineBoardLane
    let relocatesCard: Bool
    let isLiveOutcome: Bool

    static func make(
        for result: StageMoveResult,
        sourceStage: PipelineStage
    ) -> PipelineStageMovePresentation {
        switch result {
        case let .persisted(_, _, target):
            return Self(
                outcomeText: "Moved to \(target.rawValue).",
                presentedStage: target,
                boardLane: lane(for: target),
                relocatesCard: true,
                isLiveOutcome: true
            )
        case let .noOp(_, stage):
            return Self(
                outcomeText: "Already in \(stage.rawValue).",
                presentedStage: sourceStage,
                boardLane: lane(for: sourceStage),
                relocatesCard: false,
                isLiveOutcome: true
            )
        case let .reconciliationBlocked(_, target):
            return Self(
                outcomeText: "Confirm reconciliation before moving to \(target.rawValue).",
                presentedStage: sourceStage,
                boardLane: lane(for: sourceStage),
                relocatesCard: false,
                isLiveOutcome: true
            )
        case .unavailable:
            return Self(
                outcomeText: "Opportunity is no longer available locally.",
                presentedStage: sourceStage,
                boardLane: lane(for: sourceStage),
                relocatesCard: false,
                isLiveOutcome: true
            )
        case .failed:
            return Self(
                outcomeText: "The local stage was not changed.",
                presentedStage: sourceStage,
                boardLane: lane(for: sourceStage),
                relocatesCard: false,
                isLiveOutcome: true
            )
        }
    }

    private static func lane(for stage: PipelineStage) -> PipelineBoardLane {
        PipelineBoardLane.forStage(stage)
    }
}

nonisolated struct PipelineStageMoveMotionPolicy: Equatable {
    let allowsSpatialAnimation: Bool
    let keepsFocusVisible: Bool
    let keepsTextFeedback: Bool

    static func make(reduceMotion: Bool) -> Self {
        Self(
            allowsSpatialAnimation: !reduceMotion,
            keepsFocusVisible: true,
            keepsTextFeedback: true
        )
    }
}

/// Accepts one callback for a native provider/target pair while that provider
/// is alive. The weak entry keeps the guard bounded to the native delivery;
/// a later drag creates a distinct provider and is never deduplicated by
/// opportunity identifier or stage.
@MainActor
final class PipelineStageMoveDeliveryGate {
    private final class Entry {
        weak var provider: NSItemProvider?
        let identity: ObjectIdentifier
        let target: PipelineStage

        init(provider: NSItemProvider, target: PipelineStage) {
            self.provider = provider
            identity = ObjectIdentifier(provider)
            self.target = target
        }
    }

    private var entries: [Entry] = []

    func accept(provider: NSItemProvider, target: PipelineStage) -> Bool {
        entries.removeAll { $0.provider == nil }
        let identity = ObjectIdentifier(provider)
        guard !entries.contains(where: {
            $0.identity == identity && $0.provider === provider && $0.target == target
        }) else {
            return false
        }
        entries.append(Entry(provider: provider, target: target))
        return true
    }
}

/// The Board is a projection of the view model's committed opportunities.
/// Drag and menu interactions submit only an opportunity identifier and target
/// stage through `changeStage`; this view never relocates a card optimistically.
struct PipelineBoardView: View {
    let model: WorkspaceViewModel
    let opportunities: [Opportunity]
    let includesClosed: Bool
    @Binding var anchorID: String?
    @Binding var horizontalLane: PipelineBoardLane?
    let open: (Opportunity) -> Void
    let addOpportunity: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var focusedMoveOpportunityID: String?
    @State private var hoveredLane: PipelineBoardLane?
    @State private var outcomeText: String?
    @State private var deliveryGate = PipelineStageMoveDeliveryGate()

    var body: some View {
        VStack(alignment: .leading, spacing: RekonTheme.Spacing.tight) {
            if let outcomeText {
                Text(outcomeText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(RekonTheme.primaryText)
                    .accessibilityIdentifier("pipeline-stage-move-outcome")
                    .accessibilityAddTraits(.updatesFrequently)
            }

            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(PipelineBoardLane.displayedLanes(includesClosed: includesClosed), id: \.self) { lane in
                        boardLane(lane)
                            .id(lane)
                            .frame(width: 280, alignment: .leading)
                    }
                }
                .padding(.bottom, 4)
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $horizontalLane, anchor: .center)
            .accessibilityIdentifier("pipeline-board-region")
            .accessibilityValue("Horizontal lane: \(accessibleHorizontalLane.title)")
            .onAppear {
                resolveHorizontalLaneFromAnchorIfNeeded()
            }
            .onChange(of: anchorID) { _, _ in
                resolveHorizontalLaneFromAnchorIfNeeded()
            }
        }
        .background {
            PipelineBoardMoveShortcut {
                focusedMoveOpportunityID = opportunities.first?.id
            }
            .frame(width: 0, height: 0)
        }
        .overlay(alignment: .bottomTrailing) {
            #if REKON_UI_TEST_HOST
            PipelineStageMoveHostOverlay()
            #else
            EmptyView()
            #endif
        }
    }

    private var anchorStage: PipelineStage? {
        guard let anchorID else { return nil }
        return model.opportunity(id: anchorID)?.stage
    }

    private var accessibleHorizontalLane: PipelineBoardLane {
        PipelineBoardHorizontalLaneResolver.resolve(
            restoredLane: horizontalLane,
            anchorStage: anchorStage
        ) ?? PipelineBoardLane.displayedLanes(includesClosed: includesClosed).first ?? .saved
    }

    private func resolveHorizontalLaneFromAnchorIfNeeded() {
        horizontalLane = PipelineBoardHorizontalLaneResolver.resolve(
            restoredLane: horizontalLane,
            anchorStage: anchorStage
        )
    }

    private func boardLane(_ lane: PipelineBoardLane) -> some View {
        let laneOpportunities = opportunities.filter { lane.includes($0.stage) }
        return ScrollViewReader { laneProxy in
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: lane.symbolName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(lane.accent)
                    Text(lane.title).font(.headline)
                    Text("\(laneOpportunities.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RekonTheme.secondaryText)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(RekonTheme.surface, in: Capsule())
                        .accessibilityIdentifier("pipeline-board-lane-count-\(lane.accessibilityName)")
                    Spacer(minLength: 0)
                    Image(systemName: "ellipsis")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(RekonTheme.secondaryText)
                        .accessibilityHidden(true)
                }

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        if laneOpportunities.isEmpty {
                            PipelineBoardEmptyLane(lane: lane)
                        } else {
                            ForEach(laneOpportunities, id: \.id) { opportunity in
                                PipelineOpportunityMoveCard(
                                    opportunity: opportunity,
                                    isAnchored: anchorID == opportunity.id,
                                    focusedMoveOpportunityID: $focusedMoveOpportunityID,
                                    open: {
                                        anchorID = opportunity.id
                                        open(opportunity)
                                    },
                                    move: submit
                                )
                                .id(opportunity.id)
                                .onDrag {
                                    dragProvider(for: opportunity)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button(action: addOpportunity) {
                    Label("Add opportunity", systemImage: "plus")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .foregroundStyle(RekonTheme.accent)
                .accessibilityIdentifier("pipeline-board-lane-add-\(lane.accessibilityName)")
            }
            .padding(14)
            .background(
                hoveredLane == lane ? lane.accent.opacity(0.12) : RekonTheme.backgroundRaised,
                in: RoundedRectangle(cornerRadius: RekonTheme.Radius.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RekonTheme.Radius.card)
                    .stroke(hoveredLane == lane ? lane.accent : RekonTheme.borderSubtle, lineWidth: hoveredLane == lane ? 2 : 1)
            )
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("pipeline-board-lane-\(lane.accessibilityName)")
            .accessibilityLabel("\(lane.title) lane")
            .accessibilityValue("\(laneOpportunities.count) opportunities")
            .onDrop(
                of: [UTType.utf8PlainText.identifier],
                delegate: PipelineStageDropDelegate(
                    target: lane.dropTarget,
                    knownOpportunityIDs: Set(model.opportunities.map(\.id)),
                    hoveredLane: $hoveredLane,
                    lane: lane,
                    deliveryGate: deliveryGate,
                    submit: submit
                )
            )
            .onAppear {
                guard let anchorID,
                      let opportunity = model.opportunity(id: anchorID),
                      lane.includes(opportunity.stage) else { return }
                laneProxy.scrollTo(anchorID, anchor: .center)
            }
            .onChange(of: anchorID) { _, id in
                guard let id,
                      let opportunity = model.opportunity(id: id),
                      lane.includes(opportunity.stage) else { return }
                laneProxy.scrollTo(id, anchor: .center)
            }
        }
    }

    private func dragProvider(for opportunity: Opportunity) -> NSItemProvider {
        guard let data = PipelineStageMovePayload.data(forOpportunityID: opportunity.id) else {
            return NSItemProvider()
        }
        return NSItemProvider(item: data as NSData, typeIdentifier: UTType.utf8PlainText.identifier)
    }

    private func submit(_ request: PipelineStageMoveRequest) {
        guard let opportunity = model.opportunity(id: request.opportunityID) else { return }
        let sourceStage = opportunity.stage
        let opportunityID = request.opportunityID

        // Clear the old control's request before the committed projection can
        // replace it. Its responder teardown must not cancel the new control's
        // deferred focus restoration after a cross-lane move.
        focusedMoveOpportunityID = nil

        #if REKON_UI_TEST_HOST
        VisualFixtureStageMoveHooks.runBeforeDispatch(for: model)
        #endif

        let spatialAnimation: Animation? = PipelineStageMoveMotionPolicy
            .make(reduceMotion: reduceMotion)
            .allowsSpatialAnimation
            ? .easeInOut(duration: 0.2)
            : nil
        let result = withAnimation(spatialAnimation) {
            model.changeStage(opportunity, to: request.target)
        }
        let presentation = PipelineStageMovePresentation.make(for: result, sourceStage: sourceStage)
        #if REKON_UI_TEST_HOST
        if presentation.relocatesCard {
            VisualFixtureStageMoveObservations.shared.recordMotion(
                executed: spatialAnimation != nil
            )
        }
        #endif
        outcomeText = presentation.outcomeText
        DispatchQueue.main.async {
            focusedMoveOpportunityID = opportunityID
        }
    }
}

private struct PipelineStageDropDelegate: DropDelegate {
    private nonisolated struct NativeProvider: @unchecked Sendable {
        let value: NSItemProvider
    }

    let target: PipelineStage
    let knownOpportunityIDs: Set<String>
    @Binding var hoveredLane: PipelineBoardLane?
    let lane: PipelineBoardLane
    let deliveryGate: PipelineStageMoveDeliveryGate
    let submit: (PipelineStageMoveRequest) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [UTType.utf8PlainText.identifier])
    }

    func dropEntered(info: DropInfo) {
        hoveredLane = lane
    }

    func dropExited(info: DropInfo) {
        if hoveredLane == lane {
            hoveredLane = nil
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        hoveredLane = nil
        guard let provider = info.itemProviders(for: [UTType.utf8PlainText.identifier]).first else {
            return false
        }
        let nativeProvider = NativeProvider(value: provider)
        provider.loadDataRepresentation(forTypeIdentifier: UTType.utf8PlainText.identifier) { data, _ in
            DispatchQueue.main.async {
                #if REKON_UI_TEST_HOST
                VisualFixtureStageMoveObservations.shared.recordProviderDelivery()
                #endif
                guard let request = PipelineStageMovePayload.request(
                    from: data,
                    target: target,
                    knownOpportunityIDs: knownOpportunityIDs,
                    isCancelled: false,
                    isInsideTarget: true
                ) else {
                    #if REKON_UI_TEST_HOST
                    VisualFixtureStageMoveObservations.shared.recordValidationRejection()
                    #endif
                    return
                }
                guard deliveryGate.accept(provider: nativeProvider.value, target: target) else { return }
                #if REKON_UI_TEST_HOST
                VisualFixtureStageMoveObservations.shared.recordCommandDispatch()
                #endif
                submit(request)
            }
        }
        return true
    }
}

#if REKON_UI_TEST_HOST
private struct PipelineStageMoveHostOverlay: View {
    @ObservedObject private var observations = VisualFixtureStageMoveObservations.shared

    var body: some View {
        if VisualFixtureStageMoveObservations.exposesInvalidDragSources {
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    ForEach(VisualFixtureInvalidDragSource.allCases, id: \.self) { source in
                        Text(source.shortLabel)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(RekonTheme.primaryText)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(RekonTheme.surface, in: RoundedRectangle(cornerRadius: 5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(RekonTheme.borderSubtle)
                            )
                            .onDrag { source.provider() }
                            .accessibilityIdentifier(source.accessibilityIdentifier)
                    }
                }
                Text("Invalid drag observation")
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(observations.invalidDropValue)
                    .accessibilityIdentifier("pipeline-invalid-drag-observation")
                Text("Stage move motion observation")
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(observations.motionValue)
                    .accessibilityIdentifier("pipeline-stage-move-motion-observation")
            }
            .padding(5)
            .background(RekonTheme.backgroundRaised.opacity(0.96), in: RoundedRectangle(cornerRadius: 7))
            .allowsHitTesting(true)
        }
    }
}
#endif

private struct PipelineOpportunityMoveCard: View {
    let opportunity: Opportunity
    let isAnchored: Bool
    @Binding var focusedMoveOpportunityID: String?
    let open: () -> Void
    let move: (PipelineStageMoveRequest) -> Void

    private var hasKeyboardFocus: Bool {
        focusedMoveOpportunityID == opportunity.id
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: open) {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(opportunity.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(RekonTheme.primaryText)
                            .lineLimit(2)
                            .padding(.trailing, 42)
                        HStack(spacing: 6) {
                            PipelineEmployerMark(company: opportunity.company)
                            Text(opportunity.company)
                                .font(.caption)
                                .foregroundStyle(RekonTheme.secondaryText)
                                .lineLimit(1)
                                .accessibilityIdentifier("pipeline-board-card-company-\(opportunity.id)")
                        }
                    }

                    if let locality = opportunity.locationSummary {
                        Label(locality, systemImage: "mappin.circle.fill")
                            .font(.caption)
                            .foregroundStyle(RekonTheme.secondaryText)
                            .lineLimit(1)
                            .accessibilityIdentifier("pipeline-board-card-locality-\(opportunity.id)")
                    }

                    Divider().overlay(RekonTheme.borderSubtle)

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Next action")
                            .font(.caption2)
                            .foregroundStyle(RekonTheme.secondaryText)
                        Text(opportunity.nextAction.isEmpty ? "No next action" : opportunity.nextAction)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(RekonTheme.primaryText)
                            .lineLimit(2)
                            .accessibilityIdentifier("pipeline-board-card-next-action-\(opportunity.id)")
                    }

                    HStack(spacing: 5) {
                        Image(systemName: "calendar")
                        Text(opportunity.dueAt.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "No due date")
                            .lineLimit(1)
                    }
                    .font(.caption)
                    .foregroundStyle(RekonTheme.secondaryText)
                    .accessibilityIdentifier("pipeline-board-card-due-date-\(opportunity.id)")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("pipeline-opportunity-\(opportunity.id)")
            .accessibilityLabel(opportunity.title)
            // The card body is the native AXButton that owns the direct detail
            // route. Project the existing anchorID-derived state here rather
            // than onto the containing AXGroup, whose custom value is not
            // reliably surfaced by macOS accessibility.
            .accessibilityValue(isAnchored ? "Anchored" : "")

            PipelineCardActionsMenuControl(
                opportunity: opportunity,
                focusedOpportunityID: $focusedMoveOpportunityID,
                open: open,
                move: move
            )
            .frame(width: 36, height: 36)
        }
        .padding(12)
        .background(RekonTheme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(hasKeyboardFocus ? RekonTheme.accent : RekonTheme.borderSubtle, lineWidth: hasKeyboardFocus ? 2 : 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pipeline-stage-move-card-\(opportunity.id)")
    }
}

private struct PipelineBoardMoveShortcut: NSViewRepresentable {
    let focusFirstMoveControl: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(focusFirstMoveControl: focusFirstMoveControl)
    }

    func makeNSView(context: Context) -> NSView {
        context.coordinator.installMonitorIfNeeded()
        return NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.focusFirstMoveControl = focusFirstMoveControl
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.removeMonitor()
    }

    final class Coordinator {
        var focusFirstMoveControl: () -> Void
        private var eventMonitor: Any?

        init(focusFirstMoveControl: @escaping () -> Void) {
            self.focusFirstMoveControl = focusFirstMoveControl
        }

        func installMonitorIfNeeded() {
            guard eventMonitor == nil else { return }
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                guard flags.contains(.command),
                      flags.contains(.shift),
                      !flags.contains(.control),
                      !flags.contains(.option),
                      event.charactersIgnoringModifiers?.lowercased() == "m" else {
                    return event
                }
                self?.focusFirstMoveControl()
                return nil
            }
        }

        func removeMonitor() {
            guard let eventMonitor else { return }
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }

    }
}

private struct PipelineCardActionsMenuControl: NSViewRepresentable {
    let opportunity: Opportunity
    @Binding var focusedOpportunityID: String?
    let open: () -> Void
    let move: (PipelineStageMoveRequest) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> PipelineCardActionsMenuButton {
        let button = PipelineCardActionsMenuButton(frame: .zero)
        button.target = context.coordinator
        button.action = #selector(Coordinator.presentMenu(_:))
        button.focusChanged = context.coordinator.focusChanged
        context.coordinator.configureMenu(for: button)
        return button
    }

    func updateNSView(_ button: PipelineCardActionsMenuButton, context: Context) {
        context.coordinator.parent = self
        button.focusChanged = context.coordinator.focusChanged
        let accessibilityText = "Actions for \(opportunity.title)"
        button.setAccessibilityIdentifier("pipeline-card-actions-\(opportunity.id)")
        button.setAccessibilityLabel(accessibilityText)
        button.setAccessibilityHelp(accessibilityText)
        button.baseAccessibilityValue = "Current stage: \(opportunity.stage.rawValue)"
        button.toolTip = accessibilityText
        context.coordinator.markCurrentStage(in: button.menu, stage: opportunity.stage)

        if focusedOpportunityID == opportunity.id,
           button.window?.firstResponder !== button {
            DispatchQueue.main.async { [weak button] in
                guard let button else { return }
                button.window?.makeFirstResponder(button)
            }
        }
    }

    final class Coordinator: NSObject {
        var parent: PipelineCardActionsMenuControl

        init(parent: PipelineCardActionsMenuControl) {
            self.parent = parent
        }

        func configureMenu(for button: PipelineCardActionsMenuButton) {
            button.menu = PipelineCardActionsMenuBuilder.makeMenu(
                configuration: .canonical,
                edit: { [weak self] in
                    self?.parent.open()
                },
                move: { [weak self] stage in
                    self?.submitMove(to: stage)
                }
            )
        }

        func markCurrentStage(in menu: NSMenu?, stage: PipelineStage) {
            guard let moveItems = menu?.items.last?.submenu?.items else { return }
            for (index, item) in moveItems.enumerated() {
                guard PipelineCardActionsConfiguration.canonical.moveTargets.indices.contains(index) else {
                    item.state = .off
                    continue
                }
                item.state = PipelineCardActionsConfiguration.canonical.moveTargets[index] == stage ? .on : .off
            }
        }

        @objc func presentMenu(_ button: PipelineCardActionsMenuButton) {
            button.window?.makeFirstResponder(button)
            button.presentMenu()
        }

        private func submitMove(to stage: PipelineStage) {
            parent.move(
                PipelineStageMoveRequest(
                    opportunityID: parent.opportunity.id,
                    target: stage
                )
            )
        }

        func focusChanged(_ isFocused: Bool) {
            if isFocused {
                parent.focusedOpportunityID = parent.opportunity.id
            } else if parent.focusedOpportunityID == parent.opportunity.id {
                parent.focusedOpportunityID = nil
            }
        }
    }
}

private final class PipelineCardActionsMenuButton: NSButton {
    var focusChanged: ((Bool) -> Void)?
    var baseAccessibilityValue = "" {
        didSet {
            updateAccessibilityValue(isFocused: window?.firstResponder === self)
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        title = ""
        image = NSImage(systemSymbolName: "ellipsis", accessibilityDescription: nil)
        imagePosition = .imageOnly
        bezelStyle = .texturedRounded
        setButtonType(.momentaryPushIn)
        setAccessibilityRole(.menuButton)
        wantsLayer = true
        layer?.cornerRadius = 8
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        let becameFirstResponder = super.becomeFirstResponder()
        if becameFirstResponder {
            updateFocusAppearance(isFocused: true)
            focusChanged?(true)
        }
        return becameFirstResponder
    }

    override func resignFirstResponder() -> Bool {
        let resignedFirstResponder = super.resignFirstResponder()
        if resignedFirstResponder {
            updateFocusAppearance(isFocused: false)
            focusChanged?(false)
        }
        return resignedFirstResponder
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 || event.keyCode == 49 || event.keyCode == 125 {
            presentMenu()
        } else {
            super.keyDown(with: event)
        }
    }

    func presentMenu() {
        guard let menu else { return }
        menu.popUp(
            positioning: nil,
            at: NSPoint(x: bounds.minX, y: bounds.minY),
            in: self
        )
        window?.makeFirstResponder(self)
    }

    private func updateFocusAppearance(isFocused: Bool) {
        layer?.borderColor = isFocused ? NSColor(RekonTheme.accent).cgColor : nil
        layer?.borderWidth = isFocused ? 2 : 0
        layer?.shadowColor = isFocused ? NSColor(RekonTheme.accent).cgColor : nil
        layer?.shadowOpacity = isFocused ? 0.28 : 0
        layer?.shadowRadius = isFocused ? 5 : 0
        updateAccessibilityValue(isFocused: isFocused)
        needsDisplay = true
    }

    private func updateAccessibilityValue(isFocused: Bool) {
        setAccessibilityValue(
            isFocused ? "\(baseAccessibilityValue); Keyboard focus" : baseAccessibilityValue
        )
        NSAccessibility.post(element: self, notification: .valueChanged)
    }
}

private struct PipelineBoardEmptyLane: View {
    let lane: PipelineBoardLane

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.title3)
                .foregroundStyle(lane.accent.opacity(0.8))
            Text("No \(lane.title.lowercased()) opportunities")
                .font(.caption.weight(.medium))
                .foregroundStyle(RekonTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 112)
        .padding(12)
        .background(RekonTheme.surface.opacity(0.55), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(RekonTheme.borderSubtle, style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
        )
        .accessibilityIdentifier("pipeline-board-empty-\(lane.accessibilityName)")
    }
}

private extension PipelineBoardLane {
    var title: String {
        switch self {
        case .saved: "Saved"
        case .applied: "Applied"
        case .screening: "Screening"
        case .interviewing: "Interviewing"
        case .offer: "Offer"
        case .closed: "Closed"
        }
    }

    var accessibilityName: String { title.lowercased() }

    var symbolName: String {
        switch self {
        case .saved: "bookmark"
        case .applied: "paperplane"
        case .screening: "checklist"
        case .interviewing: "person.2"
        case .offer: "star"
        case .closed: "checkmark.circle"
        }
    }

    var accent: Color {
        switch self {
        case .saved: RekonTheme.violet
        case .applied: RekonTheme.success
        case .screening: RekonTheme.accent
        case .interviewing: RekonTheme.accent
        case .offer: RekonTheme.warning
        case .closed: RekonTheme.secondaryText
        }
    }

}
