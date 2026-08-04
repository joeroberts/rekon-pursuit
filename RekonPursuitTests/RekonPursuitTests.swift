import AppKit
import XCTest

@testable import RekonPursuit

final class RekonPursuitTests: XCTestCase {

    func testPipelineInspectorPresentationUsesDesktopAtTheApproved1220PointGuardBand() {
        XCTAssertTrue(PipelineInspectorPresentationPolicy.usesCompactTable(forAvailableWidth: 1219))
        XCTAssertFalse(PipelineInspectorPresentationPolicy.usesCompactTable(forAvailableWidth: 1220))
    }

    @MainActor
    func testPipelineNativeTableSelectionOwnerRestoresOnlyTheTableItOwnsAcrossReplacement() {
        let initialTable = NSTableView()
        initialTable.selectionHighlightStyle = .regular
        let initialScrollView = NSScrollView()
        initialScrollView.documentView = initialTable
        let initialHost = NSView()
        initialTable.addSubview(initialHost)

        let replacementTable = NSTableView()
        replacementTable.selectionHighlightStyle = .regular
        let replacementScrollView = NSScrollView()
        replacementScrollView.documentView = replacementTable
        let replacementHost = NSView()
        replacementTable.addSubview(replacementHost)

        let owner = PipelineNativeTableSelectionOwner()
        owner.install(from: initialHost)
        XCTAssertEqual(initialTable.selectionHighlightStyle, .none)
        XCTAssertEqual(replacementTable.selectionHighlightStyle, .regular)

        owner.install(from: replacementHost)
        XCTAssertEqual(initialTable.selectionHighlightStyle, .regular)
        XCTAssertEqual(replacementTable.selectionHighlightStyle, .none)

        // A replacement table can be reconfigured by its new SwiftUI owner.
        // This bridge must not restore a stale style over that owner’s change.
        replacementTable.selectionHighlightStyle = .regular
        owner.restore()
        XCTAssertEqual(replacementTable.selectionHighlightStyle, .regular)
    }

    func testStageMovePayloadContainsOnlyOpportunityID() throws {
        let opportunityID = "00000000-0000-4000-8000-000000000205"

        let data = try XCTUnwrap(PipelineStageMovePayload.data(forOpportunityID: opportunityID))

        XCTAssertEqual(String(data: data, encoding: .utf8), opportunityID)
        XCTAssertEqual(data.count, opportunityID.utf8.count)
        XCTAssertFalse(data.contains(UInt8(ascii: "{")))
        XCTAssertFalse(data.contains(UInt8(ascii: ":")))
    }

    func testEmptyOversizedMalformedAndUnknownPayloadNeverInvokesCommand() {
        let knownID = "00000000-0000-4000-8000-000000000205"
        let inputs: [Data?] = [
            Data(),
            Data(repeating: UInt8(ascii: "a"), count: PipelineStageMovePayload.maximumByteCount + 1),
            Data([0xFF, 0xFE]),
            Data("malformed\nidentifier".utf8),
            Data("00000000-0000-4000-8000-000000000999".utf8)
        ]

        for input in inputs {
            XCTAssertNil(
                PipelineStageMovePayload.request(
                    from: input,
                    target: .screening,
                    knownOpportunityIDs: [knownID],
                    isCancelled: false,
                    isInsideTarget: true
                )
            )
        }
    }

    func testCancelledAndOutsideDropNeverInvokesCommand() {
        let opportunityID = "00000000-0000-4000-8000-000000000205"
        let data = Data(opportunityID.utf8)

        XCTAssertNil(
            PipelineStageMovePayload.request(
                from: data,
                target: .screening,
                knownOpportunityIDs: [opportunityID],
                isCancelled: true,
                isInsideTarget: true
            )
        )
        XCTAssertNil(
            PipelineStageMovePayload.request(
                from: data,
                target: .screening,
                knownOpportunityIDs: [opportunityID],
                isCancelled: false,
                isInsideTarget: false
            )
        )
        XCTAssertNil(
            PipelineStageMovePayload.request(
                from: data,
                target: nil,
                knownOpportunityIDs: [opportunityID],
                isCancelled: false,
                isInsideTarget: true
            )
        )
    }

    func testNonPersistedResultsKeepSourceLane() {
        let opportunityID = "00000000-0000-4000-8000-000000000205"
        let results: [StageMoveResult] = [
            .noOp(opportunityID: opportunityID, stage: .saved),
            .reconciliationBlocked(opportunityID: opportunityID, target: .closed),
            .unavailable(opportunityID: opportunityID),
            .failed(opportunityID: opportunityID)
        ]
        let presentations = results.map {
            PipelineStageMovePresentation.make(for: $0, sourceStage: .saved)
        }

        XCTAssertTrue(presentations.allSatisfy { !$0.relocatesCard })
        XCTAssertTrue(presentations.allSatisfy { $0.presentedStage == .saved })
        XCTAssertTrue(presentations.allSatisfy { $0.boardLane == .saved })
        XCTAssertEqual(Set(presentations.map(\.outcomeText)).count, results.count)
    }

    @MainActor
    func testPersistedResultUsesExactStageChipAndBoardLane() {
        let deliveryGate = PipelineStageMoveDeliveryGate()
        let nativeProvider = NSItemProvider()
        let distinctProvider = NSItemProvider()

        XCTAssertTrue(deliveryGate.accept(provider: nativeProvider, target: .screening))
        XCTAssertFalse(deliveryGate.accept(provider: nativeProvider, target: .screening))
        XCTAssertTrue(deliveryGate.accept(provider: distinctProvider, target: .screening))

        let presentation = PipelineStageMovePresentation.make(
            for: .persisted(
                opportunityID: "00000000-0000-4000-8000-000000000205",
                from: .saved,
                to: .screening
            ),
            sourceStage: .saved
        )

        XCTAssertTrue(presentation.relocatesCard)
        XCTAssertEqual(presentation.presentedStage, .screening)
        XCTAssertEqual(presentation.boardLane, .screening)
        XCTAssertEqual(presentation.outcomeText, "Moved to Screening.")
        XCTAssertTrue(presentation.isLiveOutcome)

        let independentNoOp = PipelineStageMovePresentation.make(
            for: .noOp(
                opportunityID: "00000000-0000-4000-8000-000000000205",
                stage: .screening
            ),
            sourceStage: .screening
        )
        XCTAssertEqual(independentNoOp.outcomeText, "Already in Screening.")
        XCTAssertFalse(independentNoOp.relocatesCard)
    }

    func testReduceMotionDisablesSpatialMoveAnimationButKeepsFeedback() {
        let standard = PipelineStageMoveMotionPolicy.make(reduceMotion: false)
        let reduced = PipelineStageMoveMotionPolicy.make(reduceMotion: true)

        XCTAssertTrue(standard.allowsSpatialAnimation)
        XCTAssertFalse(reduced.allowsSpatialAnimation)
        XCTAssertTrue(reduced.keepsFocusVisible)
        XCTAssertTrue(reduced.keepsTextFeedback)
    }

    func testVD204PipelineBoardLaneMappingRetainsPreciseStages() {
        XCTAssertTrue(PipelineBoardLane.saved.includes(.saved))
        XCTAssertFalse(PipelineBoardLane.saved.includes(.applied))
        XCTAssertTrue(PipelineBoardLane.applied.includes(.applied))
        XCTAssertFalse(PipelineBoardLane.applied.includes(.screening))
        XCTAssertTrue(PipelineBoardLane.screening.includes(.screening))
        XCTAssertFalse(PipelineBoardLane.applied.includes(.interviewing))
        XCTAssertTrue(PipelineBoardLane.interviewing.includes(.interviewing))
        XCTAssertTrue(PipelineBoardLane.offer.includes(.offer))
        XCTAssertTrue(PipelineBoardLane.closed.includes(.closed))
        XCTAssertFalse(PipelineBoardLane.closed.includes(.offer))
        XCTAssertEqual(
            PipelineBoardLane.displayedLanes(includesClosed: false),
            [.saved, .applied, .screening, .interviewing, .offer]
        )
        XCTAssertEqual(
            PipelineBoardLane.displayedLanes(includesClosed: true),
            [.saved, .applied, .screening, .interviewing, .offer, .closed]
        )
    }

    func testVD205PipelineBoardLaneStageAndDropTargetsAreOneToOneAndCanonical() {
        XCTAssertEqual(PipelineBoardLane.allCases.map(\.stage), PipelineStage.allCases)
        XCTAssertEqual(PipelineBoardLane.displayedLanes(includesClosed: false).count, 5)
        XCTAssertEqual(PipelineBoardLane.displayedLanes(includesClosed: true).count, 6)
        XCTAssertEqual(PipelineBoardLane.displayedLanes(includesClosed: false), [.saved, .applied, .screening, .interviewing, .offer])
        XCTAssertEqual(PipelineBoardLane.displayedLanes(includesClosed: true), [.saved, .applied, .screening, .interviewing, .offer, .closed])

        for lane in PipelineBoardLane.allCases {
            XCTAssertEqual(lane.dropTarget, lane.stage)
            for stage in PipelineStage.allCases {
                XCTAssertEqual(lane.includes(stage), lane.stage == stage, "\(lane) must own only \(lane.stage).")
            }
        }
    }

    func testVD205PersistedAppliedAndScreeningPresentInTheirExactLanes() {
        let opportunityID = "00000000-0000-4000-8000-000000000205"
        let appliedPresentation = PipelineStageMovePresentation.make(
            for: .persisted(opportunityID: opportunityID, from: .saved, to: .applied),
            sourceStage: .saved
        )
        let screeningPresentation = PipelineStageMovePresentation.make(
            for: .persisted(opportunityID: opportunityID, from: .applied, to: .screening),
            sourceStage: .applied
        )
        let presentedLanes = [appliedPresentation.boardLane, screeningPresentation.boardLane]

        XCTAssertEqual(presentedLanes, [.applied, .screening])
        XCTAssertEqual(presentedLanes.map(\.dropTarget), [.applied, .screening])
    }

    func testVD205RestoredHorizontalLaneWinsOverAnchorDerivedLane() {
        XCTAssertEqual(
            PipelineBoardHorizontalLaneResolver.resolve(
                restoredLane: .offer,
                anchorStage: .screening
            ),
            .offer
        )
        XCTAssertEqual(
            PipelineBoardHorizontalLaneResolver.resolve(
                restoredLane: nil,
                anchorStage: .screening
            ),
            .screening
        )
        XCTAssertNil(
            PipelineBoardHorizontalLaneResolver.resolve(
                restoredLane: nil,
                anchorStage: nil
            )
        )
    }

    @MainActor
    func testVD205ProductionMenuBuilderConsumesCanonicalActionsConfiguration() throws {
        var editInvocationCount = 0
        var movedTargets: [PipelineStage] = []
        let menu = PipelineCardActionsMenuBuilder.makeMenu(
            configuration: .canonical,
            edit: { editInvocationCount += 1 },
            move: { movedTargets.append($0) }
        )

        XCTAssertEqual(menu.items.map(\.title), ["Edit opportunity", "Move to stage…"])
        let moveSubmenu = try XCTUnwrap(menu.items.last?.submenu)
        XCTAssertEqual(
            moveSubmenu.items.map(\.title),
            ["Saved", "Applied", "Screening", "Interviewing", "Offer", "Closed"]
        )
        XCTAssertEqual(moveSubmenu.items.count, 6)

        let editItem = try XCTUnwrap(menu.items.first)
        XCTAssertTrue(NSApp.sendAction(try XCTUnwrap(editItem.action), to: editItem.target, from: editItem))
        let screeningItem = moveSubmenu.items[2]
        XCTAssertTrue(NSApp.sendAction(try XCTUnwrap(screeningItem.action), to: screeningItem.target, from: screeningItem))
        XCTAssertEqual(editInvocationCount, 1)
        XCTAssertEqual(movedTargets, [.screening])
    }

    func testVD205AddOpportunityOriginResolvesHomeTableAndExactBoardContext() {
        let boardContext = PipelineBoardReturnContext(
            query: "Product",
            stageFilter: "Screening",
            includesClosed: true,
            selectedOrAnchoredOpportunityID: "fixture-screening-id",
            horizontalScrollLane: .offer
        )

        XCTAssertEqual(
            boardContext,
            PipelineBoardReturnContext(
                query: "Product",
                stageFilter: "Screening",
                includesClosed: true,
                selectedOrAnchoredOpportunityID: "fixture-screening-id",
                horizontalScrollLane: .offer
            )
        )
        XCTAssertEqual(
            AddOpportunityOrigin.home.cancelDestination,
            AddOpportunityCancelDestination(route: .home, showsBoard: false, boardContext: nil)
        )
        XCTAssertEqual(
            AddOpportunityOrigin.pipelineTable.cancelDestination,
            AddOpportunityCancelDestination(route: .pipeline, showsBoard: false, boardContext: nil)
        )
        XCTAssertEqual(
            AddOpportunityOrigin.pipelineBoard(boardContext).cancelDestination,
            AddOpportunityCancelDestination(route: .pipeline, showsBoard: true, boardContext: boardContext)
        )

        var origin: AddOpportunityOrigin? = .home
        origin = AddOpportunityOrigin.replacing(origin, with: .pipelineTable)
        XCTAssertEqual(origin, .pipelineTable)
        origin = AddOpportunityOrigin.replacing(origin, with: .pipelineBoard(boardContext))
        XCTAssertEqual(origin, .pipelineBoard(boardContext))
    }

    @MainActor
    func testVD205DiscardNewOpportunityDraftIsExhaustivePureAndWriteFree() throws {
        let store = try makeVD205Store()
        let subject = try store.create(CreateOpportunity(
            title: "Persisted subject",
            company: "Rekon Labs",
            stage: .screening,
            nextAction: "Follow up",
            dueAt: Date(timeIntervalSince1970: 1_746_576_000)
        ))
        let model = WorkspaceViewModel(
            openWorkspace: { .ready(store) },
            createWorkspace: { store },
            separateLocalWorkspace: SeparateLocalWorkspaceDependencies(
                selectedIdentity: { nil },
                allocateAndPersistIdentity: { throw WorkspaceStoreError.injectedFailure },
                open: { _ in .unavailable },
                create: { _ in throw WorkspaceStoreError.injectedFailure },
                clearSelection: {}
            )
        )
        defer { model.teardown() }
        model.start()
        model.select(subject)

        let storeOpportunities = try store.opportunities()
        let storeActivityEvents = try store.activityEvents()
        let storeStageHistory = try store.stageHistory(forOpportunityID: subject.id)
        let storeNeedsAttention = try store.needsAttention()
        let publishedProjection = VD205PublishedProjectionSnapshot(model: model)
        let workspaceReady = model.workspaceReady
        let canCreateWorkspace = model.canCreateWorkspace
        let workspaceRequiresRecovery = model.workspaceRequiresRecovery

        model.title = "Draft title"
        model.company = "Draft company"
        model.jobURL = "jobs.example.com/malformed"
        model.jobDescription = "Draft description"
        model.notes = "Draft notes"
        model.compensation = "$210,000"
        model.compensationMinimum = "200000"
        model.compensationMaximum = "250000"
        model.compensationPayPeriod = .month
        model.location = "New York"
        model.workArrangement = .hybrid
        model.stage = .offer
        model.nextAction = "Prepare offer review"
        model.dueAt = Date(timeIntervalSince1970: 1_751_846_400)
        model.hasDueDate = true
        model.applicationDate = Date(timeIntervalSince1970: 1_704_067_200)
        model.hasApplicationDate = true
        model.responseEffectiveDate = Date(timeIntervalSince1970: 1_721_174_400)
        model.stageChangedAt = Date(timeIntervalSince1970: 1_735_776_000)
        model.responseState = .awaitingResponse
        model.actionType = .other
        model.actionCustomText = "Custom draft action"
        model.createOpportunity()

        XCTAssertEqual(model.addOpportunitySaveError, "Enter an absolute http or https job URL with a host.")
        XCTAssertEqual(try store.opportunities(), storeOpportunities)
        XCTAssertEqual(try store.activityEvents(), storeActivityEvents)
        XCTAssertEqual(try store.stageHistory(forOpportunityID: subject.id), storeStageHistory)
        XCTAssertEqual(try store.needsAttention(), storeNeedsAttention)
        assertVD205PublishedProjection(VD205PublishedProjectionSnapshot(model: model), equals: publishedProjection)
        XCTAssertEqual(model.workspaceReady, workspaceReady)
        XCTAssertEqual(model.canCreateWorkspace, canCreateWorkspace)
        XCTAssertEqual(model.workspaceRequiresRecovery, workspaceRequiresRecovery)

        let validationStatusMessage = model.statusMessage
        let beforeDiscard = Date.now
        model.discardNewOpportunityDraft()
        let afterDiscard = Date.now

        XCTAssertEqual(model.title, "")
        XCTAssertEqual(model.company, "")
        XCTAssertEqual(model.jobURL, "")
        XCTAssertEqual(model.jobDescription, "")
        XCTAssertEqual(model.notes, "")
        XCTAssertEqual(model.compensation, "")
        XCTAssertEqual(model.compensationMinimum, "")
        XCTAssertEqual(model.compensationMaximum, "")
        XCTAssertEqual(model.location, "")
        XCTAssertEqual(model.nextAction, "")
        XCTAssertEqual(model.actionCustomText, "")
        XCTAssertEqual(model.stage, .saved)
        XCTAssertEqual(model.compensationPayPeriod, .year)
        XCTAssertEqual(model.workArrangement, .notSpecified)
        XCTAssertEqual(model.responseState, .noResponseRecorded)
        XCTAssertEqual(model.actionType, .noAction)
        XCTAssertFalse(model.hasApplicationDate)
        XCTAssertFalse(model.hasDueDate)
        XCTAssertNil(model.addOpportunitySaveError)
        XCTAssertGreaterThanOrEqual(model.applicationDate, beforeDiscard)
        XCTAssertLessThanOrEqual(model.applicationDate, afterDiscard)
        XCTAssertGreaterThanOrEqual(model.responseEffectiveDate, beforeDiscard)
        XCTAssertLessThanOrEqual(model.responseEffectiveDate, afterDiscard)
        XCTAssertGreaterThanOrEqual(model.stageChangedAt, beforeDiscard)
        XCTAssertLessThanOrEqual(model.stageChangedAt, afterDiscard)
        XCTAssertGreaterThanOrEqual(model.dueAt, beforeDiscard)
        XCTAssertLessThanOrEqual(model.dueAt, afterDiscard)

        XCTAssertEqual(try store.opportunities(), storeOpportunities)
        XCTAssertEqual(try store.activityEvents(), storeActivityEvents)
        XCTAssertEqual(try store.stageHistory(forOpportunityID: subject.id), storeStageHistory)
        XCTAssertEqual(try store.needsAttention(), storeNeedsAttention)
        assertVD205PublishedProjection(VD205PublishedProjectionSnapshot(model: model), equals: publishedProjection)
        XCTAssertEqual(model.workspaceReady, workspaceReady)
        XCTAssertEqual(model.canCreateWorkspace, canCreateWorkspace)
        XCTAssertEqual(model.workspaceRequiresRecovery, workspaceRequiresRecovery)
        XCTAssertEqual(model.statusMessage, validationStatusMessage)
    }

    @MainActor
    func testVisualFoundationUsesSemanticTokensAndTheExistingRekonEmblem() {
        XCTAssertEqual(RekonVisualThemeContract.emblemAssetName, "RekonEmblem")
        XCTAssertEqual(RekonVisualThemeContract.brandLockupAccessibilityIdentifier, "sidebar-brand-lockup")
        XCTAssertEqual(RekonVisualThemeContract.collapseControlAccessibilityIdentifier, "sidebar-collapse")
        XCTAssertEqual(RekonVisualThemeContract.brandEmblemTargetSize, 68)
        XCTAssertEqual(RekonVisualThemeContract.brandLockupTextSize, 24)
        XCTAssertEqual(RekonVisualThemeContract.railDestinationMinimumHeight, 56)
        XCTAssertEqual(RekonVisualThemeContract.railIconSize, 24)
        XCTAssertEqual(RekonTheme.Rail.minimumWidth, 268)
        XCTAssertEqual(RekonTheme.Rail.idealWidth, 310)
        XCTAssertEqual(RekonTheme.Rail.maximumWidth, 340)
        XCTAssertEqual(RekonTheme.Rail.horizontalInset, 22)
        XCTAssertEqual(RekonTheme.Rail.destinationRowGap, 12)
        XCTAssertGreaterThanOrEqual(RekonTheme.Rail.destinationLabelGap, 12)
        XCTAssertEqual(RekonTheme.Rail.destinationLabelGap, 17)
        XCTAssertEqual(RekonVisualThemeContract.defaultSpacing, 16)
        XCTAssertEqual(RekonVisualThemeContract.defaultCornerRadius, 16)
        XCTAssertEqual(RekonVisualThemeContract.minimumWindowWidth, 860)
        XCTAssertEqual(RekonVisualThemeContract.minimumWindowHeight, 600)
        XCTAssertEqual(RekonVisualThemeContract.shellAccessibilityIdentifier, "app-shell")
        XCTAssertEqual(RekonVisualThemeContract.controlOpacity(isEnabled: true), 1)
        XCTAssertEqual(RekonVisualThemeContract.controlOpacity(isEnabled: false), 0.42)
        XCTAssertEqual(RekonVisualThemeContract.controlBorderWidth(isFocused: false), 1)
        XCTAssertEqual(RekonVisualThemeContract.controlBorderWidth(isFocused: true), 2)
        XCTAssertEqual(RekonVisualThemeContract.buttonFocusBorderWidth(isFocused: false), 1)
        XCTAssertEqual(RekonVisualThemeContract.buttonFocusBorderWidth(isFocused: true), 2)
        XCTAssertEqual(RekonVisualThemeContract.buttonFocusGlowOpacity(isFocused: false), 0)
        XCTAssertGreaterThan(RekonVisualThemeContract.buttonFocusGlowOpacity(isFocused: true), 0)
    }

    func testRailDestinationKeepsSelectionDistinctFromPointerAndKeyboardFocus() {
        XCTAssertEqual(
            RekonRailDestinationPresentation.interactionRegion,
            .fullRoundedRow,
            "Hover and activation must share the whole rounded navigation row, not only the icon and label."
        )
        XCTAssertEqual(
            RekonRailDestinationPresentation.selectedIndicatorWidth(isSelected: true),
            RekonVisualThemeContract.railSelectedIndicatorWidth
        )
        XCTAssertEqual(
            RekonRailDestinationPresentation.outline(
                isPointerHovering: false,
                showsKeyboardFocus: false
            ),
            .none
        )
        XCTAssertEqual(
            RekonRailDestinationPresentation.outline(
                isPointerHovering: true,
                showsKeyboardFocus: false
            ),
            .pointerHover
        )
        XCTAssertEqual(
            RekonRailDestinationPresentation.outline(
                isPointerHovering: true,
                showsKeyboardFocus: true
            ),
            .pointerHover,
            "Pointer hover uses cyan for both selected and unselected destinations."
        )
        XCTAssertEqual(
            RekonRailDestinationPresentation.outline(
                isPointerHovering: false,
                showsKeyboardFocus: true
            ),
            .keyboardFocus,
            "Keyboard focus must remain visible without reusing the cyan hover outline."
        )
        XCTAssertEqual(
            RekonRailDestinationPresentation.focusRingLineWidth(for: .none),
            0
        )
        XCTAssertEqual(
            RekonRailDestinationPresentation.focusRingLineWidth(for: .pointerHover),
            2
        )
        XCTAssertEqual(
            RekonRailDestinationPresentation.focusRingLineWidth(for: .keyboardFocus),
            2
        )
        XCTAssertEqual(
            RekonRailDestinationPresentation.outline(
                isPointerHovering: false,
                showsKeyboardFocus: RekonRailDestinationPresentation.showsKeyboardFocus(
                    isFocused: true,
                    suppressingAfterPointerActivation: true
                )
            ),
            .none
        )
        XCTAssertTrue(
            RekonRailDestinationPresentation.showsKeyboardFocus(
                isFocused: true,
                suppressingAfterPointerActivation: false
            )
        )
    }

    func testVD204PipelineNavySurfacePresentationContract() {
        let expected: [(PipelineNavySurfaceInteractionState, PipelineNavySurfaceToken, PipelineNavySurfaceToken, CGFloat, Double)] = [
            (.idle, .surface, .border, 1, 1),
            (.pointerHover, .elevatedSurface, .accent, 1, 1),
            (.keyboardFocus, .elevatedSurface, .violet, 2, 1),
            (.pressed, .elevatedSurface, .accent, 1, 0.62),
            (.selected, .elevatedSurface, .accent, 1, 1),
            (.disabled, .surface, .border, 1, 0.42)
        ]

        for (state, fill, outline, borderWidth, opacity) in expected {
            let presentation = PipelineNavySurfacePresentation.presentation(for: state)

            XCTAssertEqual(presentation.fill, fill, "Unexpected fill for \(state)")
            XCTAssertEqual(presentation.outline, outline, "Unexpected outline for \(state)")
            XCTAssertEqual(presentation.borderWidth, borderWidth, "Unexpected border width for \(state)")
            XCTAssertEqual(presentation.opacity, opacity, "Unexpected opacity for \(state)")
        }
    }

    func testVisualFoundationUsesAUnifiedNavyWindowCanvasPolicy() {
        let policy = RekonWindowCanvasPolicy.standard

        XCTAssertTrue(policy.preservesNativeWindowControls)
        XCTAssertTrue(policy.hidesTitleText)
        XCTAssertTrue(policy.fillsRootCanvas)
        XCTAssertTrue(policy.fillsDetailCanvas)
    }

    func testVisualFoundationKeepsWindowChromeNavyWithSupportedSplitViewConfiguration() {
        let windowPolicy = RekonWindowCanvasPolicy.standard

        XCTAssertTrue(windowPolicy.usesNavyWindowContainerBackground)
        XCTAssertFalse(windowPolicy.usesUnifiedCompactWindowToolbar)
        XCTAssertTrue(windowPolicy.showsNavyWindowToolbarMaterial)
        XCTAssertTrue(windowPolicy.removesTitlebarSeparator)
        XCTAssertEqual(windowPolicy.splitViewDividerStyle, .thin)
    }

    @MainActor
    func testWindowChromeConfiguratorAppliesNavyChromeWithoutAddingManagedSplitViewSubviews() throws {
        let window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: RekonVisualThemeContract.minimumWindowWidth,
                height: RekonVisualThemeContract.minimumWindowHeight
            ),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        let contentView = NSView(frame: window.contentView?.bounds ?? .zero)
        let splitView = NSSplitView(frame: contentView.bounds)
        splitView.isVertical = true
        let sidebar = NSView(frame: NSRect(x: 0, y: 0, width: 260, height: 600))
        let detail = NSView(frame: NSRect(x: 261, y: 0, width: 639, height: 600))
        splitView.addSubview(sidebar)
        splitView.addSubview(detail)
        contentView.addSubview(splitView)
        window.contentView = contentView

        let configurationView = RekonWindowChromeConfigurator.WindowConfigurationView(
            policy: .standard
        )
        contentView.addSubview(configurationView)
        configurationView.apply(policy: .standard)

        XCTAssertEqual(window.backgroundColor, NSColor(RekonTheme.background))
        XCTAssertTrue(window.isOpaque)
        XCTAssertEqual(window.titleVisibility, .hidden)
        XCTAssertTrue(window.titlebarAppearsTransparent)
        XCTAssertEqual(window.titlebarSeparatorStyle, .none)
        XCTAssertEqual(window.appearance?.name, .darkAqua)
        XCTAssertEqual(window.toolbarStyle, .automatic)
        XCTAssertTrue(window.styleMask.contains(.fullSizeContentView))
        XCTAssertEqual(window.frame.size.width, RekonVisualThemeContract.minimumWindowWidth)
        XCTAssertEqual(window.frame.size.height, RekonVisualThemeContract.minimumWindowHeight)
        let closeButton = try XCTUnwrap(window.standardWindowButton(.closeButton))
        let minimizeButton = try XCTUnwrap(window.standardWindowButton(.miniaturizeButton))
        let zoomButton = try XCTUnwrap(window.standardWindowButton(.zoomButton))
        [closeButton, minimizeButton, zoomButton].forEach {
            XCTAssertFalse($0.isHidden)
            XCTAssertTrue($0.window === window)
        }
        window.setFrame(NSRect(x: 0, y: 0, width: 1440, height: 900), display: false)
        window.layoutIfNeeded()
        XCTAssertEqual(window.frame.size.width, 1440)
        XCTAssertEqual(window.frame.size.height, 900)
        [closeButton, minimizeButton, zoomButton].forEach {
            XCTAssertFalse($0.isHidden)
            XCTAssertTrue($0.window === window)
        }
        XCTAssertEqual(splitView.dividerStyle, .thin)
        XCTAssertEqual(splitView.subviews.count, 2)
        XCTAssertTrue(splitView.subviews.contains(sidebar))
        XCTAssertTrue(splitView.subviews.contains(detail))
    }

    @MainActor
    func testWindowChromeConfiguratorReappliesNavyPolicyAfterResizeFullscreenAndActivationNotifications() throws {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        let contentView = NSView(frame: window.contentView?.bounds ?? .zero)
        window.contentView = contentView

        let configurationView = RekonWindowChromeConfigurator.WindowConfigurationView(
            policy: .standard
        )
        contentView.addSubview(configurationView)
        configurationView.apply(policy: .standard)

        let closeButton = try XCTUnwrap(window.standardWindowButton(.closeButton))
        let minimizeButton = try XCTUnwrap(window.standardWindowButton(.miniaturizeButton))
        let zoomButton = try XCTUnwrap(window.standardWindowButton(.zoomButton))

        [
            NSWindow.didResizeNotification,
            NSWindow.didEndLiveResizeNotification,
            NSWindow.didEnterFullScreenNotification,
            NSWindow.didExitFullScreenNotification,
            NSWindow.didBecomeMainNotification,
            NSWindow.didBecomeKeyNotification
        ].forEach { notification in
            window.backgroundColor = .systemRed
            window.titlebarSeparatorStyle = .automatic
            NotificationCenter.default.post(name: notification, object: window)
            XCTAssertEqual(
                window.backgroundColor,
                NSColor(RekonTheme.background),
                "\(notification) must synchronously restore navy chrome before deferred AppKit work."
            )
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))

            XCTAssertEqual(window.backgroundColor, NSColor(RekonTheme.background), "\(notification) must restore navy chrome.")
            XCTAssertEqual(window.appearance?.name, .darkAqua)
            XCTAssertEqual(window.titlebarSeparatorStyle, .none)
            [closeButton, minimizeButton, zoomButton].forEach {
                XCTAssertFalse($0.isHidden, "\(notification) must retain visible stoplights.")
                XCTAssertTrue($0.window === window)
            }
        }
    }

    @MainActor
    func testShellSemanticForegroundsMeetTextContrastAgainstTheirSurfaces() {
        XCTAssertGreaterThanOrEqual(
            contrastRatio(foreground: NSColor(RekonTheme.shellForeground), background: NSColor(RekonTheme.shellRailBackground)),
            4.5
        )
        XCTAssertGreaterThanOrEqual(
            contrastRatio(foreground: NSColor(RekonTheme.shellMutedForeground), background: NSColor(RekonTheme.shellRailBackground)),
            4.5
        )
        XCTAssertGreaterThanOrEqual(
            contrastRatio(foreground: NSColor(RekonTheme.shellSelectedForeground), background: NSColor(RekonTheme.shellSelectedSurface)),
            4.5
        )
        XCTAssertGreaterThanOrEqual(
            contrastRatio(foreground: NSColor(RekonTheme.shellIcon), background: NSColor(RekonTheme.shellRailBackground)),
            3
        )
        XCTAssertGreaterThanOrEqual(
            contrastRatio(foreground: NSColor(RekonTheme.shellPointerHoverRing), background: NSColor(RekonTheme.shellRailBackground)),
            3
        )
        XCTAssertGreaterThanOrEqual(
            contrastRatio(foreground: NSColor(RekonTheme.shellKeyboardFocusRing), background: NSColor(RekonTheme.shellRailBackground)),
            3
        )
    }

    @MainActor
    private func contrastRatio(foreground: NSColor, background: NSColor) -> CGFloat {
        func luminance(_ color: NSColor) -> CGFloat {
            let converted = color.usingColorSpace(.sRGB) ?? color
            let channels = [converted.redComponent, converted.greenComponent, converted.blueComponent].map { channel in
                channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]
        }

        let first = luminance(foreground)
        let second = luminance(background)
        return (max(first, second) + 0.05) / (min(first, second) + 0.05)
    }


    @MainActor
    func testAIUsageLedgerFilterStartsWithUnboundedDefaults() {
        let filter = AIUsageLedgerFilter()

        XCTAssertEqual(filter.time, .allTime)
        XCTAssertEqual(filter.featureQuery, "")
        XCTAssertNil(filter.opportunityID)
        XCTAssertEqual(filter.route, .any)
        XCTAssertEqual(filter.modelQuery, "")
        XCTAssertEqual(filter.completion, .any)
        XCTAssertEqual(filter.minimumCostUSD, "")
        XCTAssertEqual(filter.maximumCostUSD, "")
        XCTAssertTrue(filter.isDefault)
        XCTAssertNil(filter.costRangeValidationMessage)
    }

    @MainActor
    func testAIUsageLedgerFilterResetRestoresDefaults() {
        var filter = AIUsageLedgerFilter()
        filter.time = .last7Days
        filter.featureQuery = "interview prep"
        filter.opportunityID = "opportunity-1"
        filter.route = .sanitizedCloud
        filter.modelQuery = "local-model"
        filter.completion = .failed
        filter.minimumCostUSD = "1.25"
        filter.maximumCostUSD = "4.50"

        filter.reset()

        XCTAssertTrue(filter.isDefault)
        XCTAssertNil(filter.costRangeValidationMessage)
    }

    @MainActor
    func testAIUsageLedgerFilterValidatesCostRangeWithoutCoercion() {
        var filter = AIUsageLedgerFilter()
        filter.minimumCostUSD = "1.50"
        filter.maximumCostUSD = "1.25"

        XCTAssertEqual(filter.costRangeValidationMessage, "Minimum cost cannot exceed maximum cost.")
        XCTAssertEqual(filter.minimumCostUSD, "1.50")
        XCTAssertEqual(filter.maximumCostUSD, "1.25")

        filter.minimumCostUSD = "-1"
        filter.maximumCostUSD = ""
        XCTAssertEqual(filter.costRangeValidationMessage, "Cost values must be non-negative USD amounts.")

        filter.minimumCostUSD = "not-a-number"
        XCTAssertEqual(filter.costRangeValidationMessage, "Enter a valid USD amount.")

        filter.minimumCostUSD = "nan"
        XCTAssertEqual(filter.costRangeValidationMessage, "Enter a valid USD amount.")

        filter.minimumCostUSD = "inf"
        XCTAssertEqual(filter.costRangeValidationMessage, "Enter a valid USD amount.")

        filter.minimumCostUSD = "0"
        filter.maximumCostUSD = "4.50"
        XCTAssertNil(filter.costRangeValidationMessage)
    }

    func testDailyNavigationStateStartsAtHome() {
        XCTAssertEqual(DailyNavigationState().route, .home)
    }

    func testDailyNavigationStateRoutesHomeEmptyStateAddIntentWithoutStoreEffects() {
        var state = DailyNavigationState()

        state.handle(.homeEmptyStateAdd)
        XCTAssertEqual(state.route, .addOpportunity)
    }

    func testDailyNavigationStateRoutesPipelineAddIntentWithoutStoreEffects() {
        var state = DailyNavigationState()

        state.handle(.pipelineAdd)
        XCTAssertEqual(state.route, .addOpportunity)
    }

    func testDailyNavigationStateRoutesPipelineImportIntentWithoutStoreEffects() {
        var state = DailyNavigationState()

        state.handle(.pipelineImport)
        XCTAssertEqual(state.route, .importCSV)
    }

    func testOpportunitySubrouteFallsBackToPipelineWhenItsRecordIsUnavailable() {
        XCTAssertNil(OpportunityRoute.history("missing").parentRoute(recordIsAvailable: false))
        XCTAssertNil(OpportunityRoute.reconcile("missing").parentRoute(recordIsAvailable: false))
    }

    func testBootstrapCopyDescribesLocalOnlyFoundation() {
        XCTAssertEqual(BootstrapCopy.status, "Local-only foundation")
    }

    func testFixtureManifestContainsEveryM1RequiredFixture() throws {
        let manifest = try FixtureManifest.load(from: Bundle(for: Self.self))

        XCTAssertEqual(manifest.schemaVersion, 1)
        XCTAssertEqual(Set(manifest.fixtures.map(\.id)), FixtureManifest.requiredM1FixtureIDs)
        XCTAssertTrue(manifest.fixtures.allSatisfy { fixture in
            fixture.provenance == "synthetic" &&
                !fixture.fixedClock.isEmpty &&
                !fixture.fixedIDSeed.isEmpty &&
                !fixture.fixedRandomSeed.isEmpty &&
                !fixture.expectedResult.isEmpty &&
                fixture.path.hasPrefix("fixtures/")
        })
    }

    func testFixtureManifestRejectsDuplicateIDs() {
        let fixture = FixtureManifest.Fixture(
            id: "WS-EMPTY-001", schemaVersion: 1, provenance: "synthetic",
            fixedClock: "2024-01-01T00:00:00Z", fixedIDSeed: "seed",
            fixedRandomSeed: "seed", path: "fixtures/WS-EMPTY-001", expectedResult: "ok"
        )
        let manifest = FixtureManifest(schemaVersion: 1, fixtures: Array(repeating: fixture, count: 22))

        XCTAssertThrowsError(try FixtureManifest.validate(manifest))
    }

    func testFixtureManifestRejectsTraversalPath() {
        let fixtures = FixtureManifest.requiredM1FixtureIDs.sorted().map { id in
            FixtureManifest.Fixture(
                id: id, schemaVersion: 1, provenance: "synthetic",
                fixedClock: "2024-01-01T00:00:00Z", fixedIDSeed: id,
                fixedRandomSeed: id,
                path: id == "WS-EMPTY-001" ? "fixtures/../../outside" : "fixtures/\(id)",
                expectedResult: "ok"
            )
        }

        XCTAssertThrowsError(try FixtureManifest.validate(FixtureManifest(schemaVersion: 1, fixtures: fixtures)))
    }

    func testHarnessDefaultsToOfflineAndNoXPCLaunch() throws {
        let harness = try TestHarness.make()

        XCTAssertEqual(harness.http.attemptedRequests, [])
        XCTAssertEqual(harness.xpc.launches, 0)
        try harness.tearDown()
    }

    func testDefaultDenyHTTPRecordsRejectedRequest() {
        let http = DefaultDenyHTTP()
        let request = "https://jobs.fixture.rekon.test/open"

        XCTAssertThrowsError(try http.send(request))
        XCTAssertEqual(http.attemptedRequests, [request])
    }

    func testHarnessConfinementTeardownAndDeterministicValues() throws {
        let first = try TestHarness.make(seed: "fixture-seed")
        let second = try TestHarness.make(seed: "fixture-seed")
        defer {
            try? first.tearDown()
            try? second.tearDown()
        }

        XCTAssertEqual(first.clock.now, second.clock.now)
        XCTAssertEqual(first.ids.next(), second.ids.next())
        XCTAssertEqual(first.random.nextBytes(count: 4), second.random.nextBytes(count: 4))
        XCTAssertTrue(first.fileStore.isConfined(first.root.appendingPathComponent("state.json")))
        XCTAssertFalse(first.fileStore.isConfined(URL(fileURLWithPath: "/tmp/outside-state.json")))

        try first.tearDown()
        XCTAssertFalse(FileManager.default.fileExists(atPath: first.root.path))
    }

    func testHarnessInjectsFilesystemFaultsAndIsolatesKeychain() throws {
        let harness = try TestHarness.make()
        defer { try? harness.tearDown() }
        let faultingStore = TestFileStore(root: harness.root, faultMode: .diskFull)

        XCTAssertThrowsError(try faultingStore.write(Data("x".utf8), relativePath: "fixture.bin"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: harness.root.appendingPathComponent("fixture.bin").path))
        try harness.keychain.write(Data("value".utf8), for: "fixture")
        XCTAssertEqual(try harness.keychain.read("fixture"), Data("value".utf8))
        harness.keychain.state = .locked
        XCTAssertThrowsError(try harness.keychain.read("fixture"))
    }

    func testHarnessUsesFixedLocaleAndUTC() throws {
        let harness = try TestHarness.make()
        defer { try? harness.tearDown() }

        XCTAssertEqual(harness.localeTimeZone.locale.identifier, "en_US_POSIX")
        XCTAssertEqual(harness.localeTimeZone.timeZone.secondsFromGMT(), 0)
    }

    @MainActor
    private func makeVD205Store() throws -> WorkspaceStore {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("rekon-vd205-discard-draft-\(UUID().uuidString).sqlite")
        let database = try EncryptedDatabase.open(url: databaseURL, key: Data(repeating: 5, count: 32))
        return try WorkspaceStore(database: database, actorID: "test", correlationID: "vd205")
    }

    @MainActor
    private func assertVD205PublishedProjection(
        _ actual: VD205PublishedProjectionSnapshot,
        equals expected: VD205PublishedProjectionSnapshot,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(actual.opportunities, expected.opportunities, file: file, line: line)
        XCTAssertEqual(actual.activityEvents, expected.activityEvents, file: file, line: line)
        XCTAssertEqual(actual.needsAttention, expected.needsAttention, file: file, line: line)
        XCTAssertEqual(actual.opportunityCount, expected.opportunityCount, file: file, line: line)
        XCTAssertEqual(actual.activityCount, expected.activityCount, file: file, line: line)
        XCTAssertEqual(actual.needsAttentionCount, expected.needsAttentionCount, file: file, line: line)
        XCTAssertEqual(actual.selectedOpportunityID, expected.selectedOpportunityID, file: file, line: line)
        XCTAssertEqual(actual.selectedContactID, expected.selectedContactID, file: file, line: line)
        XCTAssertEqual(actual.selectedOpportunity, expected.selectedOpportunity, file: file, line: line)
        XCTAssertEqual(actual.selectedStageHistory, expected.selectedStageHistory, file: file, line: line)
        XCTAssertEqual(actual.selectedResponseHistory, expected.selectedResponseHistory, file: file, line: line)
        XCTAssertEqual(actual.selectedTask, expected.selectedTask, file: file, line: line)
        XCTAssertEqual(actual.contacts, expected.contacts, file: file, line: line)
        XCTAssertEqual(actual.selectedContacts, expected.selectedContacts, file: file, line: line)
        XCTAssertEqual(actual.selectedSameEmployerContacts, expected.selectedSameEmployerContacts, file: file, line: line)
        XCTAssertEqual(actual.selectedOpportunityInteractions, expected.selectedOpportunityInteractions, file: file, line: line)
        XCTAssertEqual(actual.selectedContactInteractions, expected.selectedContactInteractions, file: file, line: line)
        XCTAssertEqual(actual.selectedContactOpportunities, expected.selectedContactOpportunities, file: file, line: line)
        XCTAssertEqual(actual.selectedContactEmployerOpportunities, expected.selectedContactEmployerOpportunities, file: file, line: line)
        XCTAssertEqual(actual.selectedReconciliationResults, expected.selectedReconciliationResults, file: file, line: line)
        XCTAssertEqual(actual.selectedReconciliationTask, expected.selectedReconciliationTask, file: file, line: line)
        XCTAssertEqual(actual.selectedDocumentReferences, expected.selectedDocumentReferences, file: file, line: line)
        XCTAssertEqual(actual.csvImportPlan, expected.csvImportPlan, file: file, line: line)
        XCTAssertEqual(actual.csvImportReportRows, expected.csvImportReportRows, file: file, line: line)
        XCTAssertEqual(actual.portableArchiveCatalogue, expected.portableArchiveCatalogue, file: file, line: line)
    }
}

@MainActor
private struct VD205PublishedProjectionSnapshot {
    let opportunities: [Opportunity]
    let activityEvents: [ActivityEvent]
    let needsAttention: [TaskReminder]
    let opportunityCount: Int
    let activityCount: Int
    let needsAttentionCount: Int
    let selectedOpportunityID: String
    let selectedContactID: String
    let selectedOpportunity: Opportunity?
    let selectedStageHistory: [StageHistoryEntry]
    let selectedResponseHistory: [ResponseHistoryEntry]
    let selectedTask: TaskReminder?
    let contacts: [Contact]
    let selectedContacts: [Contact]
    let selectedSameEmployerContacts: [Contact]
    let selectedOpportunityInteractions: [OpportunityInteraction]
    let selectedContactInteractions: [ContactInteraction]
    let selectedContactOpportunities: [Opportunity]
    let selectedContactEmployerOpportunities: [Opportunity]
    let selectedReconciliationResults: [ReconciliationResult]
    let selectedReconciliationTask: TaskReminder?
    let selectedDocumentReferences: [DocumentReference]
    let csvImportPlan: [CSVImportPlanRow]
    let csvImportReportRows: [CSVImportReportRow]
    let portableArchiveCatalogue: [PortableArchiveCatalogueRow]

    init(model: WorkspaceViewModel) {
        opportunities = model.opportunities
        activityEvents = model.activityEvents
        needsAttention = model.needsAttention
        opportunityCount = model.opportunityCount
        activityCount = model.activityCount
        needsAttentionCount = model.needsAttentionCount
        selectedOpportunityID = model.selectedOpportunityID
        selectedContactID = model.selectedContactID
        selectedOpportunity = model.selectedOpportunity
        selectedStageHistory = model.selectedStageHistory
        selectedResponseHistory = model.selectedResponseHistory
        selectedTask = model.selectedTask
        contacts = model.contacts
        selectedContacts = model.selectedContacts
        selectedSameEmployerContacts = model.selectedSameEmployerContacts
        selectedOpportunityInteractions = model.selectedOpportunityInteractions
        selectedContactInteractions = model.selectedContactInteractions
        selectedContactOpportunities = model.selectedContactOpportunities
        selectedContactEmployerOpportunities = model.selectedContactEmployerOpportunities
        selectedReconciliationResults = model.selectedReconciliationResults
        selectedReconciliationTask = model.selectedReconciliationTask
        selectedDocumentReferences = model.selectedDocumentReferences
        csvImportPlan = model.csvImportPlan
        csvImportReportRows = model.csvImportReportRows
        portableArchiveCatalogue = model.portableArchiveCatalogue
    }
}
