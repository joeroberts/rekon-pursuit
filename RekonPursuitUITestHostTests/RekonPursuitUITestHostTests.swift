import Foundation
import XCTest

@testable import RekonPursuitUITestHost

final class RekonPursuitUITestHostTests: XCTestCase {

    @MainActor
    func testVisualFixtureWindowSizeParsesSupportedArguments() {
        XCTAssertEqual(
            VisualFixtureWindowSize(arguments: ["RekonPursuit", "-rekon-visual-window-size", "compact"]),
            .compact
        )
        XCTAssertEqual(
            VisualFixtureWindowSize(arguments: ["RekonPursuit", "-rekon-visual-window-size", "wide"]),
            .wide
        )
        XCTAssertEqual(
            VisualFixtureWindowSize(arguments: ["RekonPursuit"]),
            .wide
        )
        XCTAssertEqual(
            VisualFixtureWindowSize(arguments: ["RekonPursuit", "-rekon-visual-window-size", "unsupported"]),
            .wide
        )
        XCTAssertEqual(
            VisualFixtureWindowSize(arguments: ["RekonPursuit", "-rekon-visual-window-size"]),
            .wide
        )

        XCTAssertEqual(VisualFixtureWindowSize.compact.size, CGSize(width: 860, height: 600))
        XCTAssertEqual(VisualFixtureWindowSize.wide.size, CGSize(width: 1600, height: 1000))
    }

    func testVD202FixtureHostPublishesAProofThatLiveStoresAreUnavailable() throws {
        let configuration = try XCTUnwrap(
            VisualFixtureLaunchConfiguration(
                arguments: ["RekonPursuit", "-rekon-visual-fixture", "populated"],
                environment: ["REKON_VISUAL_FIXTURE_SESSION": "vd2-02-isolation-proof"]
            )
        )

        XCTAssertTrue(
            FileManager.default.fileExists(atPath: configuration.root.appendingPathComponent(".live-store-access-disabled").path),
            "Fixture configuration must explicitly prove that personal workspace, keychain, and live support DB access are disabled."
        )
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

    @MainActor
    func testVD206ContactsFixtureInventoryAndRelaunch() throws {
        // This catches a fixture regression that replaces the Contacts source
        // inventory with generated values, loses an explicit relationship, or
        // seeds outside the UUID-qualified encrypted session root.
        let session = "vd2-06-contacts-inventory-\(UUID().uuidString)"
        let configuration = try XCTUnwrap(
            VisualFixtureLaunchConfiguration(
                arguments: ["RekonPursuit", VisualFixtureLaunchConfiguration.argument, "contacts"],
                environment: [VisualFixtureLaunchConfiguration.fixtureSessionEnvironmentKey: session]
            )
        )
        defer { VisualFixtureWorkspace.teardown(configuration: configuration) }

        let firstLaunch = VisualFixtureWorkspace.makeViewModel(configuration: configuration)
        firstLaunch.start()
        XCTAssertTrue(firstLaunch.workspaceReady)
        XCTAssertEqual(
            firstLaunch.contacts.map { "\($0.name) @ \($0.employer)" },
            [
                "Contacts Primary @ Fixture North",
                "Contacts Secondary @ Fixture South",
                "Contacts Unlinked @ Fixture North"
            ]
        )
        XCTAssertEqual(
            Set(firstLaunch.opportunities.map(\.title)),
            Set(["Contacts Linked Opportunity", "Contacts Unlinked Opportunity"])
        )
        let primary = try XCTUnwrap(firstLaunch.contacts.first { $0.name == "Contacts Primary" })
        let secondary = try XCTUnwrap(firstLaunch.contacts.first { $0.name == "Contacts Secondary" })
        let unlinked = try XCTUnwrap(firstLaunch.contacts.first { $0.name == "Contacts Unlinked" })
        firstLaunch.selectContact(primary)
        XCTAssertEqual(firstLaunch.selectedContactOpportunities.map(\.title), ["Contacts Linked Opportunity"])
        firstLaunch.selectContact(secondary)
        XCTAssertEqual(firstLaunch.selectedContactOpportunities, [])
        firstLaunch.selectContact(unlinked)
        XCTAssertEqual(firstLaunch.selectedContactOpportunities, [])
        XCTAssertTrue(
            firstLaunch.selectedContactUnlinkedEmployerOpportunities.contains { $0.title == "Contacts Unlinked Opportunity" }
        )
        XCTAssertEqual(configuration.root.deletingLastPathComponent(), configuration.sessionRoot)
        XCTAssertTrue(FileManager.default.fileExists(atPath: configuration.root.appendingPathComponent(".live-store-access-disabled").path))
        let encryptedHeader = try Data(contentsOf: configuration.root.appendingPathComponent("workspace.sqlite")).prefix(16)
        XCTAssertNotEqual(encryptedHeader, Data("SQLite format 3\u{0}".utf8))
        let firstInventory = firstLaunch.contacts.map { "\($0.name) @ \($0.employer)" }
        firstLaunch.teardown()

        let relaunched = VisualFixtureWorkspace.makeViewModel(configuration: configuration)
        relaunched.start()
        XCTAssertTrue(relaunched.workspaceReady)
        XCTAssertEqual(
            relaunched.contacts.map { "\($0.name) @ \($0.employer)" },
            firstInventory
        )
        XCTAssertEqual(
            Set(relaunched.opportunities.map(\.title)),
            Set(["Contacts Linked Opportunity", "Contacts Unlinked Opportunity"])
        )
        relaunched.teardown()
    }

    @MainActor
    func testVD206ContactsEmptyFixtureIsReady() throws {
        // This catches a fixture regression that treats the intentional empty
        // Contacts inventory as an unopened workspace instead of a ready one.
        let configuration = try XCTUnwrap(
            VisualFixtureLaunchConfiguration(
                arguments: ["RekonPursuit", VisualFixtureLaunchConfiguration.argument, "contacts-empty"],
                environment: [VisualFixtureLaunchConfiguration.fixtureSessionEnvironmentKey: "vd2-06-contacts-empty-\(UUID().uuidString)"]
            )
        )
        defer { VisualFixtureWorkspace.teardown(configuration: configuration) }

        let model = VisualFixtureWorkspace.makeViewModel(configuration: configuration)
        model.start()
        XCTAssertTrue(model.workspaceReady)
        XCTAssertFalse(model.canCreateWorkspace)
        XCTAssertEqual(model.contacts, [])
        model.teardown()
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

    func testVisualFixtureCurrentProcessIsAvailableOnlyInTheDedicatedTestHost() throws {
        let arguments = ["RekonPursuit", VisualFixtureLaunchConfiguration.argument, VisualFixtureID.populated.rawValue]
        let session = "current-process-gate"

        let configuration = try XCTUnwrap(
            VisualFixtureLaunchConfiguration.currentProcess(
                arguments: arguments,
                environment: [VisualFixtureLaunchConfiguration.fixtureSessionEnvironmentKey: session]
            )
        )
        XCTAssertEqual(configuration.fixture, .populated)
        XCTAssertTrue(configuration.root.path.contains(session))
    }

    func testVisualFixtureCleanupLaunchUsesTheSameParserWithoutRenderingAFixture() throws {
        let environment = [VisualFixtureLaunchConfiguration.fixtureSessionEnvironmentKey: "cleanup-session"]
        let cleanupConfiguration = try XCTUnwrap(
            VisualFixtureLaunchConfiguration.cleanupCurrentProcess(
                arguments: ["RekonPursuit", VisualFixtureLaunchConfiguration.cleanupArgument, VisualFixtureID.empty.rawValue],
                environment: environment
            )
        )

        XCTAssertEqual(cleanupConfiguration.sessionRoot.lastPathComponent, "cleanup-session")
        XCTAssertNil(VisualFixtureLaunchConfiguration.currentProcess(
            arguments: ["RekonPursuit", VisualFixtureLaunchConfiguration.cleanupArgument, VisualFixtureID.empty.rawValue],
            environment: environment
        ))
        XCTAssertFalse(VisualFixtureProcessLaunch.currentProcess(
            arguments: ["RekonPursuit", VisualFixtureLaunchConfiguration.cleanupArgument, VisualFixtureID.empty.rawValue],
            environment: environment
        ).requiresApplicationDependencies)
    }

    func testVisualFixtureProcessWithoutAnExplicitFixtureCannotCreateApplicationDependencies() {
        let launch = VisualFixtureProcessLaunch.currentProcess(
            arguments: ["RekonPursuitUITestHost"],
            environment: [:]
        )

        XCTAssertFalse(
            launch.requiresApplicationDependencies,
            "The fixture host must never fall through to a live workspace when its fixture arguments are absent."
        )
    }

    @MainActor
    func testVisualFixtureCleanupRemovesEveryPopulatedFixtureRootForTheSession() throws {
        let session = "cleanup-all-\(UUID().uuidString)"
        let environment = [VisualFixtureLaunchConfiguration.fixtureSessionEnvironmentKey: session]
        let configurations = try VisualFixtureID.allCases.map { fixture in
            try XCTUnwrap(VisualFixtureLaunchConfiguration(
                arguments: ["RekonPursuit", VisualFixtureLaunchConfiguration.argument, fixture.rawValue],
                environment: environment
            ))
        }
        for configuration in configurations {
            try FileManager.default.createDirectory(at: configuration.root, withIntermediateDirectories: true)
            try Data("fixture".utf8).write(to: configuration.root.appendingPathComponent("seed.txt"))
        }

        let cleanupConfiguration = try XCTUnwrap(VisualFixtureLaunchConfiguration.cleanupCurrentProcess(
            arguments: ["RekonPursuit", VisualFixtureLaunchConfiguration.cleanupArgument, VisualFixtureID.empty.rawValue],
            environment: environment
        ))
        VisualFixtureWorkspace.teardown(configuration: cleanupConfiguration)

        for configuration in configurations {
            XCTAssertFalse(FileManager.default.fileExists(atPath: configuration.root.path),
                           "Cleanup must remove the populated \(configuration.fixture.rawValue) fixture root.")
        }
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: cleanupConfiguration.sessionRoot.path),
            "Cleanup must remove the complete exact-session root, including its fixture-only key material."
        )
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
    func testVisualFixtureWorkspaceRefusesASymlinkedSessionBeforeWritingFixtureData() throws {
        let testRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("rekon-pursuit-fixture-launch-symlink-test-\(UUID().uuidString)", isDirectory: true)
        let fixtureBase = testRoot.appendingPathComponent("owned-fixtures", isDirectory: true)
        let externalRoot = testRoot.appendingPathComponent("external-session", isDirectory: true)
        let sessionRoot = fixtureBase.appendingPathComponent("session", isDirectory: true)
        let sentinel = externalRoot.appendingPathComponent("preserve.txt")
        try FileManager.default.createDirectory(at: fixtureBase, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: externalRoot, withIntermediateDirectories: true)
        try Data("preserve".utf8).write(to: sentinel)
        try FileManager.default.createSymbolicLink(at: sessionRoot, withDestinationURL: externalRoot)
        defer { try? FileManager.default.removeItem(at: testRoot) }

        let configuration = VisualFixtureLaunchConfiguration(
            fixture: .populated,
            session: "session",
            fixtureBaseRoot: fixtureBase
        )
        let model = VisualFixtureWorkspace.makeViewModel(configuration: configuration)
        model.start()

        XCTAssertFalse(model.workspaceReady)
        XCTAssertEqual(try Data(contentsOf: sentinel), Data("preserve".utf8))
        XCTAssertEqual(
            try FileManager.default.contentsOfDirectory(atPath: externalRoot.path).sorted(),
            ["preserve.txt"],
            "A symlinked fixture session must be rejected before proof, key, or database writes reach its external target."
        )
    }

    @MainActor
    func testVisualFixtureWorkspaceRefusesASymlinkedRootBeforeWritingFixtureData() throws {
        let testRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("rekon-pursuit-fixture-root-symlink-test-\(UUID().uuidString)", isDirectory: true)
        let fixtureBase = testRoot.appendingPathComponent("owned-fixtures", isDirectory: true)
        let sessionRoot = fixtureBase.appendingPathComponent("session", isDirectory: true)
        let externalRoot = testRoot.appendingPathComponent("external-root", isDirectory: true)
        let fixtureRoot = sessionRoot.appendingPathComponent(VisualFixtureID.populated.rawValue, isDirectory: true)
        let sentinel = externalRoot.appendingPathComponent("preserve.txt")
        try FileManager.default.createDirectory(at: sessionRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: externalRoot, withIntermediateDirectories: true)
        try Data("preserve".utf8).write(to: sentinel)
        try FileManager.default.createSymbolicLink(at: fixtureRoot, withDestinationURL: externalRoot)
        defer { try? FileManager.default.removeItem(at: testRoot) }

        let configuration = VisualFixtureLaunchConfiguration(
            fixture: .populated,
            session: "session",
            fixtureBaseRoot: fixtureBase
        )
        let model = VisualFixtureWorkspace.makeViewModel(configuration: configuration)
        model.start()

        XCTAssertFalse(model.workspaceReady)
        XCTAssertEqual(try Data(contentsOf: sentinel), Data("preserve".utf8))
        XCTAssertEqual(
            try FileManager.default.contentsOfDirectory(atPath: externalRoot.path).sorted(),
            ["preserve.txt"],
            "A symlinked fixture root must be rejected before proof, key, or database writes reach its external target."
        )
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

        XCTAssertFalse(VisualFixtureWorkspace.removeTemporaryFixtureRoot(sessionRoot, fixtureBaseRoot: fixtureBase))
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

        XCTAssertFalse(VisualFixtureWorkspace.removeTemporaryFixtureRoot(sessionRoot, fixtureBaseRoot: fixtureBase))
        XCTAssertTrue(FileManager.default.fileExists(atPath: sentinel.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: externalSession.path))
    }

    @MainActor
    func testVisualFixtureUsesFixedTimeAndReducedMotionContracts() throws {
        let configuration = try XCTUnwrap(VisualFixtureLaunchConfiguration(
            arguments: ["RekonPursuit", VisualFixtureLaunchConfiguration.argument, VisualFixtureID.empty.rawValue],
            environment: [VisualFixtureLaunchConfiguration.fixtureSessionEnvironmentKey: "fixed-time"]
        ))

        XCTAssertEqual(configuration.now, VisualFixtureLaunchConfiguration.fixedNow)
        let formatter = ISO8601DateFormatter()
        XCTAssertEqual(
            formatter.string(from: VisualFixtureLaunchConfiguration.fixedNow),
            "2025-05-06T12:00:00Z"
        )
        XCTAssertEqual(configuration.timeZone.identifier, "GMT")
        XCTAssertEqual(RekonVisualThemeContract.decorativeBackgroundOpacity(reduceMotion: false), 1)
        XCTAssertEqual(RekonVisualThemeContract.decorativeBackgroundOpacity(reduceMotion: true), 0.45)
        XCTAssertEqual(RekonVisualThemeContract.homeFocusAccessibilityIdentifier, AppDestination.home.accessibilityID)
    }

    @MainActor
    func testAllVisualFixtureStatesReachTheirExpectedWorkspaceState() throws {
        for fixture in VisualFixtureID.allCases {
            let configuration = try XCTUnwrap(VisualFixtureLaunchConfiguration(
                arguments: ["RekonPursuit", VisualFixtureLaunchConfiguration.argument, fixture.rawValue],
                environment: [VisualFixtureLaunchConfiguration.fixtureSessionEnvironmentKey: "state-\(fixture.rawValue)"]
            ))
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
            case .populated, .contacts, .contactsEmpty, .pipeline, .archive, .documentRelink, .reconciliation:
                XCTAssertTrue(model.workspaceReady)
                XCTAssertFalse(model.canCreateWorkspace)
            }
            model.teardown()
        }
    }

    @MainActor
    func testPopulatedFixtureReopensItsCompletedTaskWithoutReseeding() throws {
        let configuration = try XCTUnwrap(VisualFixtureLaunchConfiguration(
            arguments: ["RekonPursuit", VisualFixtureLaunchConfiguration.argument, VisualFixtureID.populated.rawValue],
            environment: [VisualFixtureLaunchConfiguration.fixtureSessionEnvironmentKey: "reopen-completed-task-\(UUID().uuidString)"]
        ))
        defer { VisualFixtureWorkspace.teardown(configuration: configuration) }

        let firstLaunch = VisualFixtureWorkspace.makeViewModel(configuration: configuration)
        firstLaunch.start()
        let task = try XCTUnwrap(firstLaunch.needsAttention.first)
        firstLaunch.complete(task)
        XCTAssertTrue(firstLaunch.needsAttention.isEmpty)
        firstLaunch.teardown()

        let relaunchedModel = VisualFixtureWorkspace.makeViewModel(configuration: configuration)
        relaunchedModel.start()
        XCTAssertTrue(
            relaunchedModel.needsAttention.isEmpty,
            "A completed fixture task must survive a fresh fixture-host process without reseeding the workspace."
        )
        relaunchedModel.teardown()
    }

    @MainActor
    func testPopulatedVisualFixtureContainsDeterministicOpportunityContent() throws {
        let configuration = try XCTUnwrap(VisualFixtureLaunchConfiguration(
            arguments: ["RekonPursuit", VisualFixtureLaunchConfiguration.argument, VisualFixtureID.populated.rawValue],
            environment: [VisualFixtureLaunchConfiguration.fixtureSessionEnvironmentKey: "populated-content"]
        ))
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
    func testVD204PipelineFixtureSeedsTruthfulCrossFieldAndEditSafeRecords() throws {
        // This catches a fixture regression that would make Pipeline tests
        // prove a decorative or incomplete dataset instead of persisted
        // table/inspector data: omit a stage, invent optional metadata, or
        // remove the record used by the canonical edit/relaunch flow.
        let configuration = try XCTUnwrap(VisualFixtureLaunchConfiguration(
            arguments: ["RekonPursuit", VisualFixtureLaunchConfiguration.argument, VisualFixtureID.pipeline.rawValue],
            environment: [VisualFixtureLaunchConfiguration.fixtureSessionEnvironmentKey: "vd2-04-pipeline-contract-\(UUID().uuidString)"]
        ))
        defer { VisualFixtureWorkspace.teardown(configuration: configuration) }

        let model = VisualFixtureWorkspace.makeViewModel(configuration: configuration)
        model.start()
        defer { model.teardown() }

        XCTAssertEqual(model.opportunities.count, 6)

        let senior = try XCTUnwrap(model.opportunities.first { $0.title == "Senior Product Manager" })
        XCTAssertEqual(senior.company, "Northstar Labs")
        XCTAssertEqual(senior.stage, .applied)
        XCTAssertEqual(senior.location, "New York, NY")
        XCTAssertEqual(senior.workArrangement, .hybrid)
        XCTAssertEqual(senior.nextAction, "Prepare portfolio")
        XCTAssertEqual(senior.dueAt, configuration.now)

        let designer = try XCTUnwrap(model.opportunities.first { $0.title == "Product Designer" })
        XCTAssertEqual(designer.company, "Northstar Labs")
        XCTAssertEqual(designer.stage, .screening)

        let interviewing = try XCTUnwrap(model.opportunities.first { $0.title == "Research Lead" })
        XCTAssertEqual(interviewing.company, "Other employer")
        XCTAssertEqual(interviewing.stage, .interviewing)
        XCTAssertEqual(interviewing.location, "Remote")
        XCTAssertEqual(interviewing.workArrangement, .remote)
        XCTAssertEqual(interviewing.nextAction, "Complete panel interview")
        XCTAssertEqual(interviewing.dueAt, configuration.now.addingTimeInterval(172_800))

        let saved = try XCTUnwrap(model.opportunities.first { $0.title == "Senior iOS Engineer" })
        XCTAssertEqual(saved.company, "Nebula Labs")
        XCTAssertEqual(saved.stage, .saved)
        XCTAssertEqual(saved.location, "Boston, MA")
        XCTAssertEqual(saved.workArrangement, .hybrid)
        XCTAssertEqual(saved.nextAction, "Research company")
        XCTAssertEqual(saved.dueAt, configuration.now.addingTimeInterval(259_200))

        let offer = try XCTUnwrap(model.opportunities.first { $0.title == "Platform Engineer" })
        XCTAssertEqual(offer.company, "Apex Cloud")
        XCTAssertEqual(offer.stage, .offer)
        XCTAssertEqual(offer.location, "San Francisco, CA")
        XCTAssertEqual(offer.workArrangement, .remote)
        XCTAssertEqual(offer.nextAction, "Review offer")
        XCTAssertEqual(offer.dueAt, configuration.now.addingTimeInterval(345_600))

        let closed = try XCTUnwrap(model.opportunities.first { $0.title == "Closed opportunity" })
        XCTAssertEqual(closed.company, "Northstar Labs")
        XCTAssertEqual(closed.stage, .closed)
        XCTAssertEqual(closed.location, "Chicago, IL")
        XCTAssertEqual(closed.workArrangement, .onSite)
        XCTAssertEqual(closed.nextAction, "Archive correspondence")
        XCTAssertEqual(closed.dueAt, configuration.now.addingTimeInterval(432_000))

        XCTAssertEqual(
            model.filteredOpportunities(query: "northstar senior", stage: "All stages", includesClosed: false).map(\.id),
            [senior.id],
            "The fixture must include a real title/company pair for cross-field multi-token Pipeline search."
        )
        XCTAssertEqual(
            model.filteredOpportunities(query: "northstar missing", stage: "All stages", includesClosed: true),
            [],
            "The fixture must retain a deliberately nonmatching term so no-results behavior is exercised against stored data."
        )

        // The senior record is the canonical route's stable edit-safe record:
        // it has required values plus a next action and application date, so
        // saving an edited title exercises the real update/audit path.
        model.select(senior)
        XCTAssertEqual(model.selectedOpportunityID, senior.id)
        XCTAssertEqual(model.selectedTitle, "Senior Product Manager")
        XCTAssertEqual(model.selectedCompany, "Northstar Labs")
    }

    @MainActor
    func testVD204PipelineFixtureCoversEveryFidelityStageWithCardMetadata() throws {
        let configuration = try XCTUnwrap(VisualFixtureLaunchConfiguration(
            arguments: ["RekonPursuit", VisualFixtureLaunchConfiguration.argument, VisualFixtureID.pipeline.rawValue],
            environment: [VisualFixtureLaunchConfiguration.fixtureSessionEnvironmentKey: "vd2-04-fidelity-inventory-\(UUID().uuidString)"]
        ))
        defer { VisualFixtureWorkspace.teardown(configuration: configuration) }

        let model = VisualFixtureWorkspace.makeViewModel(configuration: configuration)
        model.start()
        defer { model.teardown() }

        let requiredStages: Set<PipelineStage> = [.saved, .applied, .screening, .interviewing, .offer, .closed]
        XCTAssertEqual(model.opportunities.count, requiredStages.count)
        XCTAssertEqual(Set(model.opportunities.map(\.stage)), requiredStages)
        for stage in requiredStages {
            XCTAssertEqual(model.opportunities.filter { $0.stage == stage }.count, 1)
        }
        for opportunity in model.opportunities {
            XCTAssertFalse(opportunity.title.isEmpty)
            XCTAssertFalse(opportunity.company.isEmpty)
            XCTAssertFalse((opportunity.location ?? "").isEmpty)
            XCTAssertNotEqual(opportunity.workArrangement, .notSpecified)
            XCTAssertFalse(opportunity.nextAction.isEmpty)
            XCTAssertNotNil(opportunity.dueAt)
        }
        XCTAssertEqual(model.filteredOpportunities(query: "", stage: "All stages", includesClosed: false).count, 5)
    }

    @MainActor
    func testReconciliationVisualFixtureSeedsAClosureProtectedAttentionTask() throws {
        let configuration = try XCTUnwrap(VisualFixtureLaunchConfiguration(
            arguments: ["RekonPursuit", VisualFixtureLaunchConfiguration.argument, "reconciliation"],
            environment: [VisualFixtureLaunchConfiguration.fixtureSessionEnvironmentKey: "reconciliation-content"]
        ))
        defer { VisualFixtureWorkspace.teardown(configuration: configuration) }

        let model = VisualFixtureWorkspace.makeViewModel(configuration: configuration)
        model.start()

        let task = try XCTUnwrap(model.needsAttention.first { $0.requiresClosureConfirmation })
        XCTAssertTrue(task.requiresClosureConfirmation)
        XCTAssertEqual(task.opportunityID, model.opportunities.first?.id)
        model.teardown()
    }

    @MainActor
    func testDocumentRelinkVisualFixtureContainsASelectedRelinkRequiredReference() throws {
        let configuration = try XCTUnwrap(VisualFixtureLaunchConfiguration(
            arguments: ["RekonPursuit", VisualFixtureLaunchConfiguration.argument, VisualFixtureID.documentRelink.rawValue],
            environment: [VisualFixtureLaunchConfiguration.fixtureSessionEnvironmentKey: "document-relink-content"]
        ))
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
        let configuration = try XCTUnwrap(VisualFixtureLaunchConfiguration(
            arguments: ["RekonPursuit", VisualFixtureLaunchConfiguration.argument, VisualFixtureID.archive.rawValue],
            environment: [VisualFixtureLaunchConfiguration.fixtureSessionEnvironmentKey: "archive-construction"]
        ))
        defer { VisualFixtureWorkspace.teardown(configuration: configuration) }

        let model = VisualFixtureWorkspace.makeViewModel(configuration: configuration)
        model.start()
        XCTAssertTrue(
            model.workspaceReady,
            "The normal archive fixture must open its isolated workspace before exposing its verified archive catalogue."
        )
        XCTAssertEqual(model.portableArchiveCatalogue.count, 1)
        model.teardown()
    }

    @MainActor
    func testArchiveVisualFixtureSeedsVerifiedArchiveCatalogue() throws {
        let configuration = try XCTUnwrap(VisualFixtureLaunchConfiguration(
            arguments: ["RekonPursuit", "-rekon-visual-fixture", "archive"],
            environment: ["REKON_VISUAL_FIXTURE_SESSION": "archive-catalogue"]
        ))
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
        let createdAt = try XCTUnwrap(utcCalendar.date(from: DateComponents(year: 2025, month: 9, day: 1, hour: 12)))
        let configuration = VisualFixtureLaunchConfiguration(
            fixture: .archive,
            session: "archive-time-zone",
            now: createdAt,
            timeZone: timeZone
        )
        defer { VisualFixtureWorkspace.teardown(configuration: configuration) }

        let model = VisualFixtureWorkspace.makeViewModel(configuration: configuration)
        model.start()
        let expectedExpiry = try XCTUnwrap(configuration.fixtureCalendar.date(byAdding: .day, value: 30, to: createdAt))
        XCTAssertEqual(model.portableArchiveCatalogue.first?.expiresAt, expectedExpiry)
        XCTAssertEqual(configuration.fixtureCalendar.timeZone.identifier, timeZone.identifier)
        model.teardown()
    }

    @MainActor
    func testVD207SettingsRecoveryPresentationPreservesBusyDisabledAndInactiveCandidateContracts() {
        let archive = PortableArchiveCatalogueRow(
            archiveID: UUID(),
            displayFilename: "Archive.rekonarchive",
            formatVersion: 1,
            createdAt: VisualFixtureLaunchConfiguration.fixedNow,
            expiresAt: VisualFixtureLaunchConfiguration.fixedNow.addingTimeInterval(30 * 24 * 60 * 60),
            verificationState: "Verified",
            ciphertextChecksum: Data(repeating: 0, count: 32),
            signingKeyFingerprint: Data(repeating: 0, count: 32)
        )
        let summary = SettingsArchiveSummary(archive: archive)
        func makePresentation(
            enrolled: Bool = true,
            summaries: [SettingsArchiveSummary] = [summary],
            creatingArchive: Bool = false,
            creatingExport: Bool = false,
            purging: Bool = false,
            restoring: Bool = false,
            restoreProgress: String? = nil,
            purgeStatus: String? = nil,
            restoreReady: Bool = false
        ) -> SettingsRecoveryPresentation {
            SettingsRecoveryPresentation(
                recoveryEnrollmentEnabled: enrolled,
                archiveSummaries: summaries,
                isCreatingPortableArchive: creatingArchive,
                isCreatingProtectedExport: creatingExport,
                isPurgingRetainedArchiveData: purging,
                isRestoringPortableArchive: restoring,
                restoreProgressText: restoreProgress,
                retainedDataPurgeStatusText: purgeStatus,
                restoreReady: restoreReady
            )
        }

        let notEnrolled = makePresentation(enrolled: false, summaries: [])
        XCTAssertEqual(notEnrolled.recoveryEnrollmentStatusText, "Recovery key not set up")
        XCTAssertEqual(notEnrolled.recoveryArchiveStatusText, "Set up a recovery key to protect this workspace.")

        let noArchive = makePresentation(summaries: [])
        XCTAssertEqual(noArchive.recoveryEnrollmentStatusText, "Recovery key enrolled")
        XCTAssertEqual(noArchive.recoveryArchiveStatusText, "No verified archive available")
        XCTAssertFalse(noArchive.createPortableArchiveIsDisabled)
        XCTAssertFalse(noArchive.protectedExportIsDisabled)
        XCTAssertTrue(noArchive.retainedDataPurgeIsDisabled)
        XCTAssertFalse(noArchive.portableArchiveRestoreIsDisabled)

        let verifiedArchive = makePresentation()
        XCTAssertEqual(verifiedArchive.recoveryEnrollmentStatusText, "Recovery key enrolled")
        XCTAssertEqual(verifiedArchive.recoveryArchiveStatusText, "Verified archive available")

        let creatingArchive = makePresentation(creatingArchive: true)
        XCTAssertTrue(creatingArchive.createPortableArchiveIsDisabled)
        XCTAssertTrue(creatingArchive.protectedExportIsDisabled)
        XCTAssertTrue(creatingArchive.retainedDataPurgeIsDisabled)
        XCTAssertTrue(creatingArchive.portableArchiveRestoreIsDisabled)
        XCTAssertEqual(creatingArchive.archiveProgressText, "Creating and verifying archive…")

        let creatingExport = makePresentation(creatingExport: true)
        XCTAssertFalse(creatingExport.createPortableArchiveIsDisabled)
        XCTAssertTrue(creatingExport.protectedExportIsDisabled)
        XCTAssertFalse(creatingExport.retainedDataPurgeIsDisabled)
        XCTAssertFalse(creatingExport.portableArchiveRestoreIsDisabled)
        XCTAssertEqual(creatingExport.protectedExportProgressText, "Preparing protected export…")

        let purging = makePresentation(purging: true, purgeStatus: "The last retained-data purge was incomplete. Review retained archives before retrying.")
        XCTAssertFalse(purging.createPortableArchiveIsDisabled)
        XCTAssertFalse(purging.protectedExportIsDisabled)
        XCTAssertTrue(purging.retainedDataPurgeIsDisabled)
        XCTAssertFalse(purging.portableArchiveRestoreIsDisabled)
        XCTAssertEqual(purging.retainedDataPurgeProgressText, "Purging retained archive data…")
        XCTAssertEqual(purging.retainedDataPurgeStatusText, "The last retained-data purge was incomplete. Review retained archives before retrying.")

        let verifying = makePresentation(restoring: true, restoreProgress: "Verifying portable archive…")
        XCTAssertTrue(verifying.createPortableArchiveIsDisabled)
        XCTAssertTrue(verifying.protectedExportIsDisabled)
        XCTAssertTrue(verifying.retainedDataPurgeIsDisabled)
        XCTAssertTrue(verifying.portableArchiveRestoreIsDisabled)
        XCTAssertEqual(verifying.restoreProgressText, "Verifying portable archive…")

        let restoring = makePresentation(restoring: true, restoreProgress: "Restore in progress…")
        XCTAssertEqual(restoring.restoreProgressText, "Restore in progress…")
        XCTAssertNil(restoring.inactiveRestoreCandidateText)

        let ready = makePresentation(restoreReady: true)
        XCTAssertEqual(
            ready.inactiveRestoreCandidateText,
            "Restored workspace ready. It remains inactive; a future workspace-open action is required."
        )
    }
}
