import AppKit
import XCTest
@testable import RekonPursuit

final class RekonPursuitTests: XCTestCase {

    func testVisualFoundationUsesSemanticTokensAndTheExistingRekonEmblem() {
        XCTAssertEqual(RekonVisualThemeContract.emblemAssetName, "RekonEmblem")
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

    func testVisualFoundationUsesAUnifiedNavyWindowCanvasPolicy() {
        let policy = RekonWindowCanvasPolicy.standard

        XCTAssertTrue(policy.hidesSystemTitleBar)
        XCTAssertTrue(policy.fillsRootCanvas)
        XCTAssertTrue(policy.fillsDetailCanvas)
    }

    func testVisualFoundationKeepsWindowChromeNavyWithSupportedSplitViewConfiguration() {
        let windowPolicy = RekonWindowCanvasPolicy.standard

        XCTAssertTrue(windowPolicy.usesNavyWindowContainerBackground)
        XCTAssertTrue(windowPolicy.hidesWindowToolbarMaterial)
        XCTAssertTrue(windowPolicy.hidesWindowToolbar)
        XCTAssertTrue(windowPolicy.removesTitlebarSeparator)
        XCTAssertEqual(windowPolicy.splitViewDividerStyle, .thick)
    }

    @MainActor
    func testWindowChromeConfiguratorAppliesNavyChromeWithoutAddingManagedSplitViewSubviews() throws {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
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
        XCTAssertEqual(splitView.dividerStyle, .thick)
        XCTAssertEqual(splitView.subviews.count, 2)
        XCTAssertTrue(splitView.subviews.contains(sidebar))
        XCTAssertTrue(splitView.subviews.contains(detail))
    }

    func testVisualFixtureLaunchConfigurationIsExplicitAndIsolated() throws {
        let configuration = try XCTUnwrap(
            VisualFixtureLaunchConfiguration(
                arguments: ["RekonPursuit", "-rekon-visual-fixture", "populated"],
                environment: [:]
            )
        )

        XCTAssertEqual(configuration.fixture, .populated)
        XCTAssertEqual(configuration.timeZone.identifier, "GMT")
        XCTAssertTrue(configuration.keychainNamespace.hasPrefix("com.rekonlabs.RekonPursuit.visual-fixture.direct-initializer.populated"))
        XCTAssertTrue(configuration.root.path.contains("rekon-pursuit-visual-fixtures"))
        XCTAssertFalse(configuration.root.path.contains("Application Support"))
    }

    func testVisualFixtureConfigurationsUsePerRunTemporaryRoots() throws {
        let first = try XCTUnwrap(
            VisualFixtureLaunchConfiguration(
                arguments: ["RekonPursuit", "-rekon-visual-fixture", "populated"],
                environment: ["REKON_VISUAL_FIXTURE_SESSION": "fixture-run-a"]
            )
        )
        let second = try XCTUnwrap(
            VisualFixtureLaunchConfiguration(
                arguments: ["RekonPursuit", "-rekon-visual-fixture", "populated"],
                environment: ["REKON_VISUAL_FIXTURE_SESSION": "fixture-run-b"]
            )
        )

        XCTAssertNotEqual(first.root, second.root)
        XCTAssertNotEqual(first.keychainNamespace, second.keychainNamespace)
        XCTAssertTrue(first.root.path.contains("fixture-run-a"))
        XCTAssertTrue(second.root.path.contains("fixture-run-b"))
    }

    func testVisualFixtureCurrentProcessRequiresTheXCTestEnvironment() throws {
        let arguments = ["RekonPursuit", VisualFixtureLaunchConfiguration.argument, VisualFixtureID.populated.rawValue]
        let session = "current-process-gate"

        XCTAssertNil(
            VisualFixtureLaunchConfiguration.currentProcess(
                arguments: arguments,
                environment: [VisualFixtureLaunchConfiguration.fixtureSessionEnvironmentKey: session]
            )
        )

        let configuration = try XCTUnwrap(
            VisualFixtureLaunchConfiguration.currentProcess(
                arguments: arguments,
                environment: [
                    VisualFixtureLaunchConfiguration.fixtureSessionEnvironmentKey: session,
                    VisualFixtureLaunchConfiguration.xctestConfigurationFilePathEnvironmentKey: "/tmp/RekonPursuit.xctestconfiguration"
                ]
            )
        )
        XCTAssertEqual(configuration.fixture, .populated)
        XCTAssertTrue(configuration.root.path.contains(session))
    }

    func testVisualFixtureCleanupLaunchUsesTheSameParserWithoutRenderingAFixture() throws {
        let environment = [
            VisualFixtureLaunchConfiguration.xctestConfigurationFilePathEnvironmentKey: "/tmp/test.xctestconfiguration",
            VisualFixtureLaunchConfiguration.fixtureSessionEnvironmentKey: "cleanup-session"
        ]

        let cleanupConfiguration = try XCTUnwrap(
            VisualFixtureLaunchConfiguration.cleanupCurrentProcess(
                arguments: ["RekonPursuit", VisualFixtureLaunchConfiguration.cleanupArgument, VisualFixtureID.empty.rawValue],
                environment: environment
            )
        )

        XCTAssertEqual(cleanupConfiguration.sessionRoot.lastPathComponent, "cleanup-session")
        XCTAssertNil(
            VisualFixtureLaunchConfiguration.currentProcess(
                arguments: ["RekonPursuit", VisualFixtureLaunchConfiguration.cleanupArgument, VisualFixtureID.empty.rawValue],
                environment: environment
            )
        )
        XCTAssertFalse(
            VisualFixtureProcessLaunch.currentProcess(
                arguments: ["RekonPursuit", VisualFixtureLaunchConfiguration.cleanupArgument, VisualFixtureID.empty.rawValue],
                environment: environment
            ).requiresApplicationDependencies
        )
    }

    @MainActor
    func testVisualFixtureCleanupRemovesEveryPopulatedFixtureRootForTheSession() throws {
        let session = "cleanup-all-\(UUID().uuidString)"
        let environment = [
            VisualFixtureLaunchConfiguration.xctestConfigurationFilePathEnvironmentKey: "/tmp/test.xctestconfiguration",
            VisualFixtureLaunchConfiguration.fixtureSessionEnvironmentKey: session
        ]
        let configurations = try VisualFixtureID.allCases.map { fixture in
            try XCTUnwrap(
                VisualFixtureLaunchConfiguration(
                    arguments: ["RekonPursuit", VisualFixtureLaunchConfiguration.argument, fixture.rawValue],
                    environment: environment
                )
            )
        }
        for configuration in configurations {
            try FileManager.default.createDirectory(at: configuration.root, withIntermediateDirectories: true)
            try Data("fixture".utf8).write(to: configuration.root.appendingPathComponent("seed.txt"))
        }

        let cleanupConfiguration = try XCTUnwrap(
            VisualFixtureLaunchConfiguration.cleanupCurrentProcess(
                arguments: ["RekonPursuit", VisualFixtureLaunchConfiguration.cleanupArgument, VisualFixtureID.empty.rawValue],
                environment: environment
            )
        )
        VisualFixtureWorkspace.teardown(configuration: cleanupConfiguration)

        for configuration in configurations {
            XCTAssertFalse(
                FileManager.default.fileExists(atPath: configuration.root.path),
                "Cleanup must remove the populated \(configuration.fixture.rawValue) fixture root."
            )
        }
    }

    @MainActor
    func testVisualFixturePathGuardRefusesToDeleteOutsideTheFixtureBase() throws {
        let outsideRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("rekon-pursuit-outside-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: outsideRoot, withIntermediateDirectories: true)
        try Data("preserve".utf8).write(to: outsideRoot.appendingPathComponent("preserve.txt"))
        defer { try? FileManager.default.removeItem(at: outsideRoot) }

        XCTAssertFalse(VisualFixtureWorkspace.removeTemporaryFixtureRoot(outsideRoot))
        XCTAssertTrue(FileManager.default.fileExists(atPath: outsideRoot.path))
    }

    @MainActor
    func testVisualFixtureCleanupRefusesAnIntermediateSessionSymlinkAndPreservesItsTarget() throws {
        let testRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("rekon-pursuit-fixture-symlink-test-\(UUID().uuidString)", isDirectory: true)
        let fixtureBase = testRoot.appendingPathComponent("owned-fixtures", isDirectory: true)
        let externalRoot = testRoot.appendingPathComponent("external-session", isDirectory: true)
        let sessionRoot = fixtureBase.appendingPathComponent("session", isDirectory: true)
        let sentinel = externalRoot.appendingPathComponent("preserve.txt")
        try FileManager.default.createDirectory(at: fixtureBase, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: externalRoot, withIntermediateDirectories: true)
        try Data("preserve".utf8).write(to: sentinel)
        try FileManager.default.createSymbolicLink(at: sessionRoot, withDestinationURL: externalRoot)
        defer { try? FileManager.default.removeItem(at: testRoot) }

        XCTAssertFalse(
            VisualFixtureWorkspace.removeTemporaryFixtureRoot(sessionRoot, fixtureBaseRoot: fixtureBase)
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: sentinel.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: sessionRoot.path))
    }

    @MainActor
    func testVisualFixtureCleanupRefusesASymlinkedFixtureBaseAndPreservesItsTarget() throws {
        let testRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("rekon-pursuit-fixture-base-symlink-test-\(UUID().uuidString)", isDirectory: true)
        let fixtureBase = testRoot.appendingPathComponent("owned-fixtures", isDirectory: true)
        let externalBase = testRoot.appendingPathComponent("external-fixtures", isDirectory: true)
        let sessionRoot = fixtureBase.appendingPathComponent("session", isDirectory: true)
        let externalSession = externalBase.appendingPathComponent("session", isDirectory: true)
        let sentinel = externalSession.appendingPathComponent("preserve.txt")
        try FileManager.default.createDirectory(at: externalSession, withIntermediateDirectories: true)
        try Data("preserve".utf8).write(to: sentinel)
        try FileManager.default.createSymbolicLink(at: fixtureBase, withDestinationURL: externalBase)
        defer { try? FileManager.default.removeItem(at: testRoot) }

        XCTAssertFalse(
            VisualFixtureWorkspace.removeTemporaryFixtureRoot(sessionRoot, fixtureBaseRoot: fixtureBase)
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: sentinel.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: externalSession.path))
    }

    @MainActor
    func testVisualFixtureUsesFixedTimeAndReducedMotionContracts() throws {
        let configuration = try XCTUnwrap(
            VisualFixtureLaunchConfiguration(
                arguments: ["RekonPursuit", VisualFixtureLaunchConfiguration.argument, VisualFixtureID.empty.rawValue],
                environment: [VisualFixtureLaunchConfiguration.fixtureSessionEnvironmentKey: "fixed-time"]
            )
        )

        XCTAssertEqual(configuration.now, VisualFixtureLaunchConfiguration.fixedNow)
        XCTAssertEqual(configuration.timeZone.identifier, "GMT")
        XCTAssertEqual(RekonVisualThemeContract.decorativeBackgroundOpacity(reduceMotion: false), 1)
        XCTAssertEqual(RekonVisualThemeContract.decorativeBackgroundOpacity(reduceMotion: true), 0.45)
        XCTAssertEqual(RekonVisualThemeContract.homeFocusAccessibilityIdentifier, AppDestination.home.accessibilityID)
    }

    @MainActor
    func testAllVisualFixtureStatesReachTheirExpectedWorkspaceState() throws {
        for fixture in VisualFixtureID.allCases {
            let configuration = try XCTUnwrap(
                VisualFixtureLaunchConfiguration(
                    arguments: ["RekonPursuit", VisualFixtureLaunchConfiguration.argument, fixture.rawValue],
                    environment: [VisualFixtureLaunchConfiguration.fixtureSessionEnvironmentKey: "state-\(fixture.rawValue)"]
                )
            )
            defer { VisualFixtureWorkspace.teardown(configuration: configuration) }

            let model = VisualFixtureWorkspace.makeViewModel(configuration: configuration)
            model.start()

            switch fixture {
            case .empty:
                XCTAssertTrue(model.canCreateWorkspace)
                XCTAssertFalse(model.workspaceReady)
            case .recovery:
                XCTAssertTrue(model.workspaceRequiresRecovery)
                XCTAssertFalse(model.workspaceReady)
            case .error:
                XCTAssertFalse(model.workspaceReady)
                XCTAssertFalse(model.canCreateWorkspace)
                XCTAssertFalse(model.workspaceRequiresRecovery)
            case .populated, .archive, .documentRelink:
                XCTAssertTrue(model.workspaceReady)
                XCTAssertFalse(model.canCreateWorkspace)
            }

            model.teardown()
        }
    }

    @MainActor
    func testPopulatedVisualFixtureContainsDeterministicOpportunityContent() throws {
        let configuration = try XCTUnwrap(
            VisualFixtureLaunchConfiguration(
                arguments: ["RekonPursuit", VisualFixtureLaunchConfiguration.argument, VisualFixtureID.populated.rawValue],
                environment: [VisualFixtureLaunchConfiguration.fixtureSessionEnvironmentKey: "populated-content"]
            )
        )
        defer { VisualFixtureWorkspace.teardown(configuration: configuration) }

        let model = VisualFixtureWorkspace.makeViewModel(configuration: configuration)
        model.start()

        XCTAssertEqual(model.opportunities.count, 1)
        XCTAssertEqual(model.opportunities.first?.title, "Fixture opportunity")
        XCTAssertEqual(model.opportunities.first?.company, "Fixture employer")
        XCTAssertEqual(model.opportunities.first?.jobURL, "https://jobs.example.test/fixture")
        XCTAssertEqual(model.opportunities.first?.location, "Fixture location")
        XCTAssertEqual(model.opportunities.first?.dueAt, configuration.now)
        model.teardown()
    }

    @MainActor
    func testDocumentRelinkVisualFixtureContainsASelectedRelinkRequiredReference() throws {
        let configuration = try XCTUnwrap(
            VisualFixtureLaunchConfiguration(
                arguments: ["RekonPursuit", VisualFixtureLaunchConfiguration.argument, VisualFixtureID.documentRelink.rawValue],
                environment: [VisualFixtureLaunchConfiguration.fixtureSessionEnvironmentKey: "document-relink-content"]
            )
        )
        defer { VisualFixtureWorkspace.teardown(configuration: configuration) }

        let model = VisualFixtureWorkspace.makeViewModel(configuration: configuration)
        model.start()

        XCTAssertEqual(model.selectedDocumentReferences.count, 1)
        XCTAssertEqual(model.selectedDocumentReferences.first?.filename, "fixture-resume.pdf")
        XCTAssertEqual(model.selectedDocumentReferences.first?.availability, .relinkRequired)
        XCTAssertNil(model.selectedDocumentReferences.first?.bookmarkData)
        XCTAssertEqual(model.documentReferenceSummary, DocumentReferenceSummary(availableCount: 0, relinkRequiredCount: 1))
        model.teardown()
    }

    @MainActor
    func testArchiveVisualFixtureConstructionCompletesOnTheMainActor() throws {
        let configuration = try XCTUnwrap(
            VisualFixtureLaunchConfiguration(
                arguments: ["RekonPursuit", VisualFixtureLaunchConfiguration.argument, VisualFixtureID.archive.rawValue],
                environment: [VisualFixtureLaunchConfiguration.fixtureSessionEnvironmentKey: "archive-construction"]
            )
        )
        defer { VisualFixtureWorkspace.teardown(configuration: configuration) }

        let model = VisualFixtureWorkspace.makeViewModel(configuration: configuration)
        model.start()

        XCTAssertTrue(model.workspaceReady)
        XCTAssertEqual(model.portableArchiveCatalogue.count, 1)
        model.teardown()
    }

    @MainActor
    func testArchiveVisualFixtureSeedsVerifiedArchiveCatalogue() throws {
        let configuration = try XCTUnwrap(
            VisualFixtureLaunchConfiguration(
                arguments: ["RekonPursuit", "-rekon-visual-fixture", "archive"],
                environment: ["REKON_VISUAL_FIXTURE_SESSION": "archive-catalogue"]
            )
        )
        defer { VisualFixtureWorkspace.teardown(configuration: configuration) }

        let model = VisualFixtureWorkspace.makeViewModel(configuration: configuration)
        model.start()

        XCTAssertTrue(model.workspaceReady)
        XCTAssertTrue(model.recoveryEnrollmentEnabled)
        XCTAssertEqual(model.portableArchiveCatalogue.count, 1)
        XCTAssertEqual(model.portableArchiveCatalogue.first?.createdAt, configuration.now)
        XCTAssertEqual(model.portableArchiveCatalogue.first?.displayFilename, "Fixture Archive.rekonarchive")
        XCTAssertEqual(model.portableArchiveCatalogue.first?.verificationState, "Verified")
        XCTAssertEqual(model.portableArchiveCatalogue.first?.lifecycleState, .verified)
        model.teardown()
    }

    @MainActor
    func testArchiveVisualFixtureUsesItsDeclaredTimeZoneAtTheCalendarBoundary() throws {
        let timeZone = try XCTUnwrap(TimeZone(identifier: "Pacific/Auckland"))
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let createdAt = try XCTUnwrap(
            utcCalendar.date(from: DateComponents(year: 2025, month: 9, day: 1, hour: 12))
        )
        let configuration = VisualFixtureLaunchConfiguration(
            fixture: .archive,
            session: "archive-time-zone",
            now: createdAt,
            timeZone: timeZone
        )
        defer { VisualFixtureWorkspace.teardown(configuration: configuration) }

        let model = VisualFixtureWorkspace.makeViewModel(configuration: configuration)
        model.start()

        let expectedExpiry = try XCTUnwrap(
            configuration.fixtureCalendar.date(byAdding: .day, value: 30, to: createdAt)
        )
        XCTAssertEqual(model.portableArchiveCatalogue.first?.expiresAt, expectedExpiry)
        XCTAssertEqual(configuration.fixtureCalendar.timeZone.identifier, timeZone.identifier)
        model.teardown()
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
}
