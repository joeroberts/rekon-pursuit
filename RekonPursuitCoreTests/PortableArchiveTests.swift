import CryptoKit
import Foundation
import XCTest
@testable import RekonPursuit

@MainActor
final class PortableArchiveTests: XCTestCase {
    func testPortableArchiveCatalogueMigrationDefaultsExistingRowsToVerified() throws {
        let fixture = try makeStoreAtVersion26(withArchiveCatalogueRow: true)
        defer {
            try? fixture.store.close()
            removeDatabase(at: fixture.databaseURL)
        }

        let catalogue = try fixture.store.portableArchiveCatalogue()

        XCTAssertEqual(catalogue.count, 1)
        XCTAssertEqual(catalogue.first?.lifecycleState, .verified)
        XCTAssertEqual(catalogue.first?.lastExpiryOutcome, PortableArchiveExpiryOutcome.none)
    }

    func testPortableArchiveCatalogueRejectsUnknownLifecycleState() throws {
        let fixture = try makeStoreAtVersion26(withArchiveCatalogueRow: true)
        defer {
            try? fixture.store.close()
            removeDatabase(at: fixture.databaseURL)
        }
        try fixture.database.execute(
            "UPDATE portable_archive_catalogue SET lifecycle_state = 'unrecognized_state'"
        )

        XCTAssertThrowsError(try fixture.store.portableArchiveCatalogue()) { error in
            XCTAssertEqual(error as? WorkspaceStoreError, .unexpectedDatabaseValue)
        }
    }

    func testRestoreOutcomeDoesNotExposeCandidateFilesystemRoot() {
        let outcome = RestoredWorkspaceCandidate(candidateID: UUID(), archiveID: UUID())

        let labels = Mirror(reflecting: outcome).children.compactMap(\.label)

        XCTAssertFalse(labels.contains("root"), "The worker result must not expose a candidate filesystem path.")
    }

    func testRestoreWorkerVerifiesArchiveWithoutCreatingCandidateMaterial() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("restore-worker-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let key = try RecoveryKey.generate()
        let archiveURL = root.appendingPathComponent("archive.rekonarchive")
        let verified = try PortableArchiveService.writeAndVerify(
            snapshot: emptyCanonicalSnapshot(), recoveryKey: key, signingKey: .init(), archiveID: UUID(), createdAt: Date(timeIntervalSince1970: 1_704_067_200), to: archiveURL
        )

        let worker = PortableArchiveRestoreWorker()
        let identity = try await worker.verifyArchive(at: archiveURL, recoveryKey: key)

        XCTAssertEqual(identity.archiveID, verified.archiveID)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("RestoredWorkspaces").path))
    }

    func testRestoreWorkerDoesNotExecuteRestoreOnMainActorCaller() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("restore-worker-executor-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let recoveryKey = try RecoveryKey.generate()
        let archiveURL = root.appendingPathComponent("archive.rekonarchive")
        let verified = try PortableArchiveService.writeAndVerify(snapshot: emptyCanonicalSnapshot(), recoveryKey: recoveryKey, signingKey: .init(), archiveID: UUID(), createdAt: Date(timeIntervalSince1970: 1_704_067_200), to: archiveURL)
        let observation = RestoreWorkerThreadObservation()
        let worker = PortableArchiveRestoreWorker(
            restoreService: PortableArchiveRestoreService(candidatesRoot: root.appendingPathComponent("candidates"), candidateKeyStore: InMemoryRestoreCandidateKeyStore(), workspaceKeyStoreForCandidate: InMemoryRestoreWorkspaceKeys().store, signingIdentityStore: InMemoryRestoreCandidateSigningIdentityStore()),
            executionObserver: { observation.record(isMainThread: $0) }
        )
        let request = PortableArchiveRestoreRequest(archiveURL: archiveURL, recoveryKey: recoveryKey, confirmation: .init(archiveID: verified.archiveID, createdAt: verified.createdAt, signingKeyFingerprint: verified.signingKeyFingerprint))
        _ = try await Task.detached { try await worker.restore(request) }.value
        XCTAssertEqual(observation.mainThreadValue, false)
    }

    func testWrongRecoveryKeyCreatesNoRestoreCandidateMaterial() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("restore-wrong-key-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let correctKey = try RecoveryKey.generate()
        let archiveURL = root.appendingPathComponent("archive.rekonarchive")
        _ = try PortableArchiveService.writeAndVerify(snapshot: emptyCanonicalSnapshot(), recoveryKey: correctKey, signingKey: .init(), archiveID: UUID(), createdAt: Date(timeIntervalSince1970: 1_704_067_200), to: archiveURL)
        let candidates = root.appendingPathComponent("candidates", isDirectory: true)
        let restorer = PortableArchiveRestoreWorker(restoreService: PortableArchiveRestoreService(candidatesRoot: candidates, candidateKeyStore: InMemoryRestoreCandidateKeyStore(), workspaceKeyStoreForCandidate: { _ in InMemoryRestoreWorkspaceKeys().store(for: UUID()) }, signingIdentityStore: InMemoryRestoreCandidateSigningIdentityStore()))

        do {
            _ = try await restorer.restore(.init(archiveURL: archiveURL, recoveryKey: try RecoveryKey.generate(), confirmation: nil))
            XCTFail("A wrong recovery key must fail before candidate material is created.")
        } catch {
            // Expected.
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: candidates.path))
    }

    func testMissingConfirmationAndCatalogueMismatchCreateNoCandidateMaterial() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("restore-no-confirmation-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let recoveryKey = try RecoveryKey.generate()
        let archiveID = UUID()
        let archiveURL = root.appendingPathComponent("archive.rekonarchive")
        let verified = try PortableArchiveService.writeAndVerify(
            snapshot: emptyCanonicalSnapshot(), recoveryKey: recoveryKey, signingKey: .init(), archiveID: archiveID,
            createdAt: Date(timeIntervalSince1970: 1_704_067_200), to: archiveURL
        )
        let candidates = root.appendingPathComponent("candidates", isDirectory: true)
        let workspaceKeys = InMemoryRestoreWorkspaceKeys()
        let worker = PortableArchiveRestoreWorker(restoreService: PortableArchiveRestoreService(
            candidatesRoot: candidates,
            candidateKeyStore: InMemoryRestoreCandidateKeyStore(),
            workspaceKeyStoreForCandidate: workspaceKeys.store,
            signingIdentityStore: InMemoryRestoreCandidateSigningIdentityStore()
        ))

        do {
            _ = try await worker.restore(.init(archiveURL: archiveURL, recoveryKey: recoveryKey, confirmation: nil))
            XCTFail("A clean-Mac archive requires explicit identity confirmation.")
        } catch let error as PortableArchiveRestoreError {
            guard case .confirmationRequired = error else { return XCTFail("Unexpected error: \(error)") }
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: candidates.path))

        let mismatchedCatalogue = PortableArchiveCatalogueRow(
            archiveID: archiveID,
            displayFilename: "archive.rekonarchive",
            formatVersion: 1,
            createdAt: verified.createdAt,
            expiresAt: verified.createdAt.addingTimeInterval(1),
            verificationState: "verified",
            ciphertextChecksum: Data(),
            signingKeyFingerprint: Data(repeating: 0, count: verified.signingKeyFingerprint.count)
        )
        let confirmation = PortableArchiveRestoreConfirmation(
            archiveID: verified.archiveID,
            createdAt: verified.createdAt,
            signingKeyFingerprint: verified.signingKeyFingerprint
        )
        do {
            _ = try await worker.restore(.init(archiveURL: archiveURL, recoveryKey: recoveryKey, localCatalogue: [mismatchedCatalogue], confirmation: confirmation))
            XCTFail("A same-Mac catalogue fingerprint mismatch must fail before reservation.")
        } catch let error as PortableArchiveRestoreError {
            guard case .catalogueMismatch = error else { return XCTFail("Unexpected error: \(error)") }
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: candidates.path))
    }

    func testMatchingLocalCatalogueStillRequiresExactConfirmationBeforeReservation() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("restore-same-mac-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let recoveryKey = try RecoveryKey.generate()
        let archiveURL = root.appendingPathComponent("archive.rekonarchive")
        let verified = try PortableArchiveService.writeAndVerify(
            snapshot: emptyCanonicalSnapshot(), recoveryKey: recoveryKey, signingKey: .init(), archiveID: UUID(),
            createdAt: Date(timeIntervalSince1970: 1_704_067_200), to: archiveURL
        )
        let catalogue = PortableArchiveCatalogueRow(
            archiveID: verified.archiveID,
            displayFilename: "archive.rekonarchive",
            formatVersion: 1,
            createdAt: verified.createdAt,
            expiresAt: verified.expiresAt,
            verificationState: "verified",
            ciphertextChecksum: verified.ciphertextChecksum,
            signingKeyFingerprint: verified.signingKeyFingerprint
        )
        let keys = InMemoryRestoreWorkspaceKeys()
        let worker = PortableArchiveRestoreWorker(restoreService: PortableArchiveRestoreService(
            candidatesRoot: root.appendingPathComponent("candidates"),
            candidateKeyStore: InMemoryRestoreCandidateKeyStore(),
            workspaceKeyStoreForCandidate: keys.store,
            signingIdentityStore: InMemoryRestoreCandidateSigningIdentityStore()
        ))

        do {
            _ = try await worker.restore(.init(archiveURL: archiveURL, recoveryKey: recoveryKey, localCatalogue: [catalogue], confirmation: nil))
            XCTFail("A matching catalogue must not bypass explicit confirmation.")
        } catch let error as PortableArchiveRestoreError {
            guard case .confirmationRequired = error else { return XCTFail("Unexpected error: \(error)") }
        }

        _ = try await worker.restore(.init(
            archiveURL: archiveURL,
            recoveryKey: recoveryKey,
            localCatalogue: [catalogue],
            confirmation: .init(
                archiveID: verified.archiveID,
                createdAt: verified.createdAt,
                signingKeyFingerprint: verified.signingKeyFingerprint
            )
        ))
    }

    func testUnrelatedCatalogueRowUsesCleanMacConfirmationFlow() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("restore-catalogue-exact-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let recoveryKey = try RecoveryKey.generate()
        let archiveURL = root.appendingPathComponent("archive.rekonarchive")
        let verified = try PortableArchiveService.writeAndVerify(snapshot: emptyCanonicalSnapshot(), recoveryKey: recoveryKey, signingKey: .init(), archiveID: UUID(), createdAt: Date(timeIntervalSince1970: 1_704_067_200), to: archiveURL)
        let wrongID = PortableArchiveCatalogueRow(archiveID: UUID(), displayFilename: "other", formatVersion: 1, createdAt: verified.createdAt, expiresAt: verified.expiresAt, verificationState: "verified", ciphertextChecksum: verified.ciphertextChecksum, signingKeyFingerprint: verified.signingKeyFingerprint)
        let worker = PortableArchiveRestoreWorker(restoreService: PortableArchiveRestoreService(candidatesRoot: root.appendingPathComponent("candidates"), candidateKeyStore: InMemoryRestoreCandidateKeyStore(), workspaceKeyStoreForCandidate: InMemoryRestoreWorkspaceKeys().store, signingIdentityStore: InMemoryRestoreCandidateSigningIdentityStore()))

        do {
            _ = try await worker.restore(.init(archiveURL: archiveURL, recoveryKey: recoveryKey, localCatalogue: [wrongID], confirmation: nil))
            XCTFail("An unrelated catalogue row must require clean-Mac confirmation.")
        } catch let error as PortableArchiveRestoreError {
            guard case .confirmationRequired = error else { return XCTFail("Unexpected error: \(error)") }
        }

        _ = try await worker.restore(.init(
            archiveURL: archiveURL,
            recoveryKey: recoveryKey,
            localCatalogue: [wrongID],
            confirmation: .init(archiveID: verified.archiveID, createdAt: verified.createdAt, signingKeyFingerprint: verified.signingKeyFingerprint)
        ))
    }

    func testEveryRestoreLifecycleFailureCleansCandidateMaterialAndAllowsARetry() async throws {
        let recoveryKey = try RecoveryKey.generate()
        for point in [
            PortableArchiveRestoreFaultPoint.afterReservation,
            .afterKeyCreation, .afterRootCreation, .afterImport, .afterCheckpoint,
            .afterReopen, .afterPromotion, .beforeReady
        ] {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("restore-fault-\(point)-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: root) }
            let archiveURL = root.appendingPathComponent("archive.rekonarchive")
            let verified = try PortableArchiveService.writeAndVerify(snapshot: emptyCanonicalSnapshot(), recoveryKey: recoveryKey, signingKey: .init(), archiveID: UUID(), createdAt: Date(timeIntervalSince1970: 1_704_067_200), to: archiveURL)
            let request = PortableArchiveRestoreRequest(archiveURL: archiveURL, recoveryKey: recoveryKey, confirmation: .init(archiveID: verified.archiveID, createdAt: verified.createdAt, signingKeyFingerprint: verified.signingKeyFingerprint))
            let candidates = root.appendingPathComponent("candidates")
            let registryKey = InMemoryRestoreCandidateKeyStore()
            let keys = InMemoryRestoreWorkspaceKeys()
            let signing = InMemoryRestoreCandidateSigningIdentityStore()
            let failing = PortableArchiveRestoreWorker(restoreService: PortableArchiveRestoreService(candidatesRoot: candidates, candidateKeyStore: registryKey, workspaceKeyStoreForCandidate: keys.store, signingIdentityStore: signing, injectedFault: point))

            await assertRestoreFails { _ = try await failing.restore(request) }
            XCTAssertTrue(candidateDirectoryNames(in: candidates).isEmpty, "\(point) must remove any candidate material.")

            let retry = PortableArchiveRestoreWorker(restoreService: PortableArchiveRestoreService(candidatesRoot: candidates, candidateKeyStore: registryKey, workspaceKeyStoreForCandidate: keys.store, signingIdentityStore: signing))
            let restored = try await retry.restore(request)
            XCTAssertTrue(FileManager.default.fileExists(atPath: candidates.appendingPathComponent(restored.candidateID.uuidString.lowercased()).path))
        }
    }

    func testPostConfirmationReservationFailureUsesTypedSafePreparingStage() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("restore-typed-reservation-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let recoveryKey = try RecoveryKey.generate()
        let archiveURL = root.appendingPathComponent("archive.rekonarchive")
        let verified = try PortableArchiveService.writeAndVerify(
            snapshot: emptyCanonicalSnapshot(), recoveryKey: recoveryKey, signingKey: .init(), archiveID: UUID(),
            createdAt: Date(timeIntervalSince1970: 1_704_067_200), to: archiveURL
        )
        let worker = PortableArchiveRestoreWorker(restoreService: PortableArchiveRestoreService(
            candidatesRoot: root.appendingPathComponent("candidates"),
            candidateKeyStore: FailingRestoreRegistryKeyStore(),
            workspaceKeyStoreForCandidate: InMemoryRestoreWorkspaceKeys().store,
            signingIdentityStore: InMemoryRestoreCandidateSigningIdentityStore()
        ))

        do {
            _ = try await worker.restore(.init(
                archiveURL: archiveURL,
                recoveryKey: recoveryKey,
                confirmation: .init(archiveID: verified.archiveID, createdAt: verified.createdAt, signingKeyFingerprint: verified.signingKeyFingerprint)
            ))
            XCTFail("A post-confirmation reservation failure must not escape as an untyped error.")
        } catch let error as PortableArchiveRestoreError {
            guard case .postConfirmationFailure(.preparing) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertFalse((error.errorDescription ?? "").contains("injected"))
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("candidates").path))
    }

    func testCleanupDoesNotMarkCandidateUnavailableUntilSigningIdentityReadbackIsAbsent() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("restore-signing-readback-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let recoveryKey = try RecoveryKey.generate()
        let archiveURL = root.appendingPathComponent("archive.rekonarchive")
        let verified = try PortableArchiveService.writeAndVerify(snapshot: emptyCanonicalSnapshot(), recoveryKey: recoveryKey, signingKey: .init(), archiveID: UUID(), createdAt: Date(timeIntervalSince1970: 1_704_067_200), to: archiveURL)
        let request = PortableArchiveRestoreRequest(archiveURL: archiveURL, recoveryKey: recoveryKey, confirmation: .init(archiveID: verified.archiveID, createdAt: verified.createdAt, signingKeyFingerprint: verified.signingKeyFingerprint))
        let candidates = root.appendingPathComponent("candidates")
        let registryKey = InMemoryRestoreCandidateKeyStore()
        let worker = PortableArchiveRestoreWorker(restoreService: PortableArchiveRestoreService(
            candidatesRoot: candidates,
            candidateKeyStore: registryKey,
            workspaceKeyStoreForCandidate: InMemoryRestoreWorkspaceKeys().store,
            signingIdentityStore: ReadbackFailingSigningIdentityStore(),
            injectedFault: .afterImport
        ))

        do {
            _ = try await worker.restore(request)
            XCTFail("A signing identity that remains present must keep cleanup pending.")
        } catch let error as PortableArchiveRestoreError {
            guard case .candidateCleanupPending = error else { return XCTFail("Unexpected error: \(error)") }
        }
    }

    func testRestoreRejectsMutatedAndUnsupportedArchivesBeforeCandidateReservation() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("restore-untrusted-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let recoveryKey = try RecoveryKey.generate()
        let archiveURL = root.appendingPathComponent("archive.rekonarchive")
        _ = try PortableArchiveService.writeAndVerify(snapshot: emptyCanonicalSnapshot(), recoveryKey: recoveryKey, signingKey: .init(), archiveID: UUID(), createdAt: Date(timeIntervalSince1970: 1_704_067_200), to: archiveURL)
        let package = try Data(contentsOf: archiveURL)

        for (index, offset) in [(0, package.index(before: package.endIndex)), (1, 8)] {
            var tampered = package
            tampered[offset] ^= 0x01
            let candidateURL = root.appendingPathComponent("tampered-\(index).rekonarchive")
            try tampered.write(to: candidateURL)
            let candidates = root.appendingPathComponent("candidates-\(index)")
            let worker = PortableArchiveRestoreWorker(restoreService: PortableArchiveRestoreService(candidatesRoot: candidates, candidateKeyStore: InMemoryRestoreCandidateKeyStore(), workspaceKeyStoreForCandidate: InMemoryRestoreWorkspaceKeys().store, signingIdentityStore: InMemoryRestoreCandidateSigningIdentityStore()))
            await assertRestoreFails { _ = try await worker.restore(.init(archiveURL: candidateURL, recoveryKey: recoveryKey, confirmation: nil)) }
            XCTAssertFalse(FileManager.default.fileExists(atPath: candidates.path))
        }
    }

    func testRegistryPersistenceFailureAndInterruptedReservationFailClosedUntilCleanupOnlyPass() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("restore-registry-failure-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let recoveryKey = try RecoveryKey.generate()
        let archiveURL = root.appendingPathComponent("archive.rekonarchive")
        let verified = try PortableArchiveService.writeAndVerify(
            snapshot: emptyCanonicalSnapshot(), recoveryKey: recoveryKey, signingKey: .init(), archiveID: UUID(),
            createdAt: Date(timeIntervalSince1970: 1_704_067_200), to: archiveURL
        )
        let request = PortableArchiveRestoreRequest(
            archiveURL: archiveURL,
            recoveryKey: recoveryKey,
            confirmation: .init(archiveID: verified.archiveID, createdAt: verified.createdAt, signingKeyFingerprint: verified.signingKeyFingerprint)
        )
        let candidates = root.appendingPathComponent("candidates", isDirectory: true)

        let initialFailureWorker = PortableArchiveRestoreWorker(restoreService: PortableArchiveRestoreService(
            candidatesRoot: candidates,
            candidateKeyStore: FailingRestoreRegistryKeyStore(),
            workspaceKeyStoreForCandidate: { _ in CleanupFailingWorkspaceKeyStore() },
            signingIdentityStore: InMemoryRestoreCandidateSigningIdentityStore()
        ))
        await assertRestoreFails { _ = try await initialFailureWorker.restore(request) }
        XCTAssertFalse(FileManager.default.fileExists(atPath: candidates.path), "A failed initial registry persistence must precede every candidate root or key.")

        let durableRegistryKey = InMemoryRestoreCandidateKeyStore()
        let interruptedWorker = PortableArchiveRestoreWorker(restoreService: PortableArchiveRestoreService(
            candidatesRoot: candidates,
            candidateKeyStore: durableRegistryKey,
            workspaceKeyStoreForCandidate: { _ in CleanupFailingWorkspaceKeyStore() },
            signingIdentityStore: InMemoryRestoreCandidateSigningIdentityStore(),
            injectedFault: .afterReservation
        ))
        await assertRestoreFails { _ = try await interruptedWorker.restore(request) }

        let workspaceKeys = InMemoryRestoreWorkspaceKeys()
        let relaunchedWorker = PortableArchiveRestoreWorker(restoreService: PortableArchiveRestoreService(
            candidatesRoot: candidates,
            candidateKeyStore: durableRegistryKey,
            workspaceKeyStoreForCandidate: workspaceKeys.store,
            signingIdentityStore: InMemoryRestoreCandidateSigningIdentityStore()
        ))
        // The relaunch performs cleanup only and deliberately does not create
        // a second candidate in the same request.
        await assertRestoreFails { _ = try await relaunchedWorker.restore(request) }
        let restored = try await relaunchedWorker.restore(request)
        XCTAssertTrue(FileManager.default.fileExists(atPath: candidates.appendingPathComponent(restored.candidateID.uuidString.lowercased()).path))
    }

    func testLifecycleFailurePersistsOnlyRedactedRegistryCategory() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("restore-registry-redaction-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let recoveryKey = try RecoveryKey.generate()
        let archiveURL = root.appendingPathComponent("archive.rekonarchive")
        let verified = try PortableArchiveService.writeAndVerify(
            snapshot: emptyCanonicalSnapshot(), recoveryKey: recoveryKey, signingKey: .init(), archiveID: UUID(),
            createdAt: Date(timeIntervalSince1970: 1_704_067_200), to: archiveURL
        )
        let registryKey = InMemoryRestoreCandidateKeyStore()
        let service = PortableArchiveRestoreService(
            candidatesRoot: root.appendingPathComponent("candidates"),
            candidateKeyStore: registryKey,
            workspaceKeyStoreForCandidate: InMemoryRestoreWorkspaceKeys().store,
            signingIdentityStore: InMemoryRestoreCandidateSigningIdentityStore(),
            injectedFault: .afterImport
        )
        let worker = PortableArchiveRestoreWorker(restoreService: service)

        await assertRestoreFails {
            _ = try await worker.restore(.init(
                archiveURL: archiveURL,
                recoveryKey: recoveryKey,
                confirmation: .init(
                    archiveID: verified.archiveID,
                    createdAt: verified.createdAt,
                    signingKeyFingerprint: verified.signingKeyFingerprint
                )
            ))
        }

        let records = try service.restoreCandidateRecordsForTesting()
        XCTAssertEqual(records.count, 1)
        let record = try XCTUnwrap(records.first)
        XCTAssertEqual(record.state, .unavailable)
        XCTAssertEqual(record.failureCategory, .bootstrap)
        XCTAssertEqual(record.cleanupAttempts, 0)
        let labels = Mirror(reflecting: record).children.compactMap(\.label)
        XCTAssertFalse(labels.contains("error"))
        XCTAssertFalse(labels.contains("message"))
        XCTAssertFalse(labels.contains("path"))
        XCTAssertFalse(labels.contains("root"))
    }

    func testReadyPersistenceFailureIsNeverMarkedReadyAndRelaunchCleansBeforeRetry() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("restore-ready-persistence-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let recoveryKey = try RecoveryKey.generate()
        let archiveURL = root.appendingPathComponent("archive.rekonarchive")
        let verified = try PortableArchiveService.writeAndVerify(
            snapshot: emptyCanonicalSnapshot(), recoveryKey: recoveryKey, signingKey: .init(), archiveID: UUID(),
            createdAt: Date(timeIntervalSince1970: 1_704_067_200), to: archiveURL
        )
        let request = PortableArchiveRestoreRequest(
            archiveURL: archiveURL,
            recoveryKey: recoveryKey,
            confirmation: .init(
                archiveID: verified.archiveID,
                createdAt: verified.createdAt,
                signingKeyFingerprint: verified.signingKeyFingerprint
            )
        )
        let candidates = root.appendingPathComponent("candidates")
        let registryKey = InMemoryRestoreCandidateKeyStore()
        let workspaceKeys = ToggleCleanupWorkspaceKeyStore()
        let signingIdentities = InMemoryRestoreCandidateSigningIdentityStore()
        let failingService = PortableArchiveRestoreService(
            candidatesRoot: candidates,
            candidateKeyStore: registryKey,
            workspaceKeyStoreForCandidate: { _ in workspaceKeys },
            signingIdentityStore: signingIdentities,
            injectedFault: .markReadyPersistence
        )
        let failingWorker = PortableArchiveRestoreWorker(restoreService: failingService)

        do {
            _ = try await failingWorker.restore(request)
            XCTFail("A failed ready-state persistence must not return a candidate.")
        } catch let error as PortableArchiveRestoreError {
            guard case .candidateCleanupPending = error else { return XCTFail("Unexpected error: \(error)") }
        }

        let pendingRecords = try failingService.restoreCandidateRecordsForTesting()
        XCTAssertEqual(pendingRecords.count, 1)
        let pending = try XCTUnwrap(pendingRecords.first)
        XCTAssertEqual(pending.state, .cleanupRetry)
        XCTAssertNotEqual(pending.state, .ready)
        XCTAssertEqual(pending.failureCategory, .cleanup)

        workspaceKeys.allowCleanup()
        let relaunchedService = PortableArchiveRestoreService(
            candidatesRoot: candidates,
            candidateKeyStore: registryKey,
            workspaceKeyStoreForCandidate: { _ in workspaceKeys },
            signingIdentityStore: signingIdentities
        )
        let relaunchedWorker = PortableArchiveRestoreWorker(restoreService: relaunchedService)
        do {
            _ = try await relaunchedWorker.restore(request)
            XCTFail("The first relaunch must perform cleanup only, not restore another candidate.")
        } catch let error as PortableArchiveRestoreError {
            guard case .candidateCleanupPending = error else { return XCTFail("Unexpected error: \(error)") }
        }
        let cleaned = try XCTUnwrap(relaunchedService.restoreCandidateRecordsForTesting().first)
        XCTAssertEqual(cleaned.state, .unavailable)
        XCTAssertNotEqual(cleaned.state, .ready)
        XCTAssertTrue(candidateDirectoryNames(in: candidates).isEmpty)

        let restored = try await relaunchedWorker.restore(request)
        XCTAssertTrue(FileManager.default.fileExists(atPath: candidates.appendingPathComponent(restored.candidateID.uuidString.lowercased()).path))
    }

    func testAuthenticatedDuplicatePrimaryKeySnapshotLeavesNoCandidateMaterial() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("restore-duplicate-primary-key-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        var snapshot = try snapshotWithOpportunities(count: 2)
        var mutable = try MutablePortableArchiveSnapshot(snapshot)
        let opportunityRows = try XCTUnwrap(mutable.rows(named: "opportunities"))
        XCTAssertEqual(opportunityRows.count, 2)
        mutable.setValue(opportunityRows[0][0], table: "opportunities", row: 1, column: 0)
        snapshot = mutable.encoded()

        let outcome = try await restoreAuthenticatedInvalidSnapshot(snapshot, in: root)

        XCTAssertTrue(candidateDirectoryNames(in: outcome.candidatesRoot).isEmpty)
        let records = try outcome.service.restoreCandidateRecordsForTesting()
        XCTAssertEqual(records.count, 1)
        let record = try XCTUnwrap(records.first)
        XCTAssertEqual(record.state, .unavailable)
        XCTAssertEqual(record.failureCategory, .bootstrap)
        XCTAssertNil(outcome.workspaceKeys.key(for: record.candidateID))
        XCTAssertNil(outcome.signingIdentities.identity(for: record.candidateID))
    }

    func testAuthenticatedInvalidForeignKeySnapshotLeavesNoCandidateMaterial() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("restore-invalid-foreign-key-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        var snapshot = try snapshotWithTaskReminder()
        var mutable = try MutablePortableArchiveSnapshot(snapshot)
        let taskRows = try XCTUnwrap(mutable.rows(named: "task_reminders"))
        XCTAssertEqual(taskRows.count, 1)
        mutable.setText("missing-opportunity-id", table: "task_reminders", row: 0, column: 1)
        snapshot = mutable.encoded()

        let outcome = try await restoreAuthenticatedInvalidSnapshot(snapshot, in: root)

        XCTAssertTrue(candidateDirectoryNames(in: outcome.candidatesRoot).isEmpty)
        let records = try outcome.service.restoreCandidateRecordsForTesting()
        XCTAssertEqual(records.count, 1)
        let record = try XCTUnwrap(records.first)
        XCTAssertEqual(record.state, .unavailable)
        XCTAssertEqual(record.failureCategory, .bootstrap)
        XCTAssertNil(outcome.workspaceKeys.key(for: record.candidateID))
        XCTAssertNil(outcome.signingIdentities.identity(for: record.candidateID))
    }

    func testVerifiedArchiveRestoresIntoANewInactiveWorkspaceWithoutChangingSource() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("archive-restore-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let sourceURL = root.appendingPathComponent("source.sqlite")
        let sourceKey = Data(repeating: 1, count: 32)
        let sourceDatabase = try EncryptedDatabase.open(url: sourceURL, key: sourceKey)
        let source = try WorkspaceStore(
            database: sourceDatabase,
            now: Date(timeIntervalSince1970: 1_704_067_200),
            actorID: "test",
            correlationID: "source"
        )
        let sourceOpportunity = try source.create(CreateOpportunity(title: "Source role", company: "Rekon"))
        _ = try source.recordDocumentReference(RecordDocumentReference(
            opportunityID: sourceOpportunity.id,
            kind: .resume,
            filename: "resume.pdf",
            contentType: "application/pdf",
            sourceHash: String(repeating: "b", count: 64),
            byteCount: 42,
            bookmarkData: Data("source-bookmark".utf8)
        ))
        let deletedSourceOpportunity = try source.create(CreateOpportunity(title: "Deleted role", company: "Rekon"))
        try source.deleteOpportunity(id: deletedSourceOpportunity.id)
        let snapshot = try PortableArchiveSnapshotCodec.encode(from: sourceDatabase)
        let recoveryKey = try RecoveryKey.generate()
        let archiveURL = root.appendingPathComponent("source.rekonarchive")
        let sourceSigningKey = Curve25519.Signing.PrivateKey()
        let verified = try PortableArchiveService.writeAndVerify(
            snapshot: snapshot,
            recoveryKey: recoveryKey,
            signingKey: sourceSigningKey,
            archiveID: UUID(),
            createdAt: Date(timeIntervalSince1970: 1_704_067_200),
            to: archiveURL
        )

        let workspaceKeys = InMemoryRestoreWorkspaceKeys()
        let candidatesRoot = root.appendingPathComponent("candidates", isDirectory: true)
        let candidateSigningIdentities = InMemoryRestoreCandidateSigningIdentityStore()
        let restorer = PortableArchiveRestoreWorker(restoreService: PortableArchiveRestoreService(
            candidatesRoot: candidatesRoot,
            candidateKeyStore: InMemoryRestoreCandidateKeyStore(),
            workspaceKeyStoreForCandidate: workspaceKeys.store,
            signingIdentityStore: candidateSigningIdentities
        ))
        let restored = try await restorer.restore(
            .init(
                archiveURL: archiveURL,
                recoveryKey: recoveryKey,
                confirmation: .init(
                archiveID: verified.archiveID,
                createdAt: verified.createdAt,
                signingKeyFingerprint: verified.signingKeyFingerprint
            )
            )
        )

        XCTAssertNotEqual(restored.candidateID.uuidString, "")
        XCTAssertEqual(try source.opportunities(), [sourceOpportunity])

        let restoredRoot = candidatesRoot.appendingPathComponent(restored.candidateID.uuidString.lowercased(), isDirectory: true)
        XCTAssertNotEqual(try XCTUnwrap(workspaceKeys.key(for: restored.candidateID)), sourceKey)
        XCTAssertNotEqual(try XCTUnwrap(candidateSigningIdentities.identity(for: restored.candidateID)), sourceSigningKey.rawRepresentation)

        let restoredDatabase = try EncryptedDatabase.open(
            url: restoredRoot.appendingPathComponent("workspace.sqlite"),
            key: try XCTUnwrap(workspaceKeys.key(for: restored.candidateID)),
            createIfMissing: false
        )
        let restoredStore = try WorkspaceStore(database: restoredDatabase, actorID: "test", correlationID: "restored")
        XCTAssertEqual(try restoredStore.opportunities().map(\.title), ["Source role"])
        let restoredDocument = try XCTUnwrap(try restoredStore.documentReferences(forOpportunityID: sourceOpportunity.id).first)
        XCTAssertNil(restoredDocument.bookmarkData)
        XCTAssertEqual(restoredDocument.availability, .relinkRequired)
        XCTAssertFalse(try restoredStore.recoveryEnrollmentState().isEnabled)
        XCTAssertTrue(try restoredStore.portableArchiveCatalogue().isEmpty)
    }

    func testVerifiedArchiveRestoresPublicURLCheckResultAfterItsOperation() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("archive-restore-public-url-check-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let sourceURL = root.appendingPathComponent("source.sqlite")
        let sourceDatabase = try EncryptedDatabase.open(url: sourceURL, key: Data(repeating: 6, count: 32))
        defer { try? sourceDatabase.close() }
        let source = try WorkspaceStore(database: sourceDatabase, actorID: "test", correlationID: "source")
        let opportunity = try source.create(CreateOpportunity(title: "Public URL check role", company: "Rekon"))
        try sourceDatabase.execute(
            "INSERT INTO reconciliation_check_operations (id, opportunity_id, correlation_id, url_snapshot, state, started_at, terminal_at) VALUES (?, ?, ?, ?, ?, ?, ?)",
            values: [.text("operation-1"), .text(opportunity.id), .text("correlation-1"), .text("https://example.com/jobs/1"), .text("completed"), .real(1_704_067_200), .real(1_704_067_201)]
        )
        try sourceDatabase.execute(
            "INSERT INTO reconciliation_results (id, opportunity_id, url, recorded_at, outcome, classification, reason, confidence, evidence, error, check_operation_id) VALUES (?, ?, ?, ?, ?, ?, ?, NULL, ?, ?, ?)",
            values: [.text("result-1"), .text(opportunity.id), .text("https://example.com/jobs/1"), .real(1_704_067_201), .text("Still open"), .text("Confirmed"), .text("HTTP response"), .text("200 OK"), .text(""), .text("operation-1")]
        )

        let snapshot = try PortableArchiveSnapshotCodec.encode(from: sourceDatabase)
        let recoveryKey = try RecoveryKey.generate()
        let archiveURL = root.appendingPathComponent("source.rekonarchive")
        let verified = try PortableArchiveService.writeAndVerify(
            snapshot: snapshot,
            recoveryKey: recoveryKey,
            signingKey: .init(),
            archiveID: UUID(),
            createdAt: Date(timeIntervalSince1970: 1_704_067_200),
            to: archiveURL
        )
        let workspaceKeys = InMemoryRestoreWorkspaceKeys()
        let candidatesRoot = root.appendingPathComponent("candidates", isDirectory: true)
        let worker = PortableArchiveRestoreWorker(restoreService: PortableArchiveRestoreService(
            candidatesRoot: candidatesRoot,
            candidateKeyStore: InMemoryRestoreCandidateKeyStore(),
            workspaceKeyStoreForCandidate: workspaceKeys.store,
            signingIdentityStore: InMemoryRestoreCandidateSigningIdentityStore()
        ))

        let restored = try await worker.restore(.init(
            archiveURL: archiveURL,
            recoveryKey: recoveryKey,
            confirmation: .init(archiveID: verified.archiveID, createdAt: verified.createdAt, signingKeyFingerprint: verified.signingKeyFingerprint)
        ))
        let restoredRoot = candidatesRoot.appendingPathComponent(restored.candidateID.uuidString.lowercased(), isDirectory: true)
        let restoredDatabase = try EncryptedDatabase.open(
            url: restoredRoot.appendingPathComponent("workspace.sqlite"),
            key: try XCTUnwrap(workspaceKeys.key(for: restored.candidateID)),
            createIfMissing: false
        )
        defer { try? restoredDatabase.close() }
        XCTAssertEqual(try restoredDatabase.scalarInt("SELECT count(*) FROM reconciliation_check_operations"), 1)
        XCTAssertEqual(try restoredDatabase.scalarInt("SELECT count(*) FROM reconciliation_results WHERE check_operation_id = 'operation-1'"), 1)
    }
    func testArchiveStagingUsesAppTemporaryDirectoryInsteadOfUserSelectedDirectory() {
        let selectedDestination = URL(fileURLWithPath: "/Users/example/Desktop/Recovery Archive.rekonarchive")
        let appTemporaryDirectory = URL(fileURLWithPath: "/private/var/folders/example/RekonPursuit/")

        let stagingURL = PortableArchiveStagingLocation.url(
            temporaryDirectory: appTemporaryDirectory,
            temporaryID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        )

        XCTAssertEqual(stagingURL.deletingLastPathComponent(), appTemporaryDirectory)
        XCTAssertNotEqual(stagingURL.deletingLastPathComponent(), selectedDestination.deletingLastPathComponent())
        XCTAssertEqual(stagingURL.pathExtension, "tmp")
    }

    func testPostCreateMetadataFailureReportsOutputMayRemain() throws {
        let source = FileManager.default.temporaryDirectory
            .appendingPathComponent("archive-source-\(UUID().uuidString).tmp")
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("archive-\(UUID().uuidString).rekonarchive")
        defer {
            try? FileManager.default.removeItem(at: source)
            try? FileManager.default.removeItem(at: destination)
        }
        try Data("archive".utf8).write(to: source)

        XCTAssertThrowsError(
            try PortableArchiveOutputWriter.copyExclusively(
                from: source,
                to: destination,
                metadataReader: { _, _ in -1 }
            )
        ) { error in
            XCTAssertTrue(error is PortableArchiveOutputWriteFailure)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
    }

    func testPostCopyVerificationFailureLeavesOutputUncatalogued() async throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("archive-post-copy-failure-\(UUID().uuidString).sqlite")
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("archive-\(UUID().uuidString).rekonarchive")
        defer {
            removeDatabase(at: databaseURL)
            try? FileManager.default.removeItem(at: destination)
        }
        let database = try EncryptedDatabase.open(url: databaseURL, key: Data(repeating: 6, count: 32))
        let worker = PortableArchiveWorker(
            configuration: database.portableArchiveConnectionConfiguration(),
            signingKeyStore: InMemoryArchiveSigningKeyStore(),
            archiveVerifier: { _, _ in throw PortableArchiveError.verificationFailed }
        )
        let store = try WorkspaceStore(
            database: database,
            now: Date(timeIntervalSince1970: 1_704_067_200),
            actorID: "test",
            correlationID: "test",
            portableArchiveWorker: worker
        )
        let recoveryKey = try RecoveryKey.generate()
        try store.enroll(recoveryKey: recoveryKey)

        do {
            _ = try await store.createPortableArchive(recoveryKey: recoveryKey, at: destination)
            XCTFail("An archive that fails final verification must not be accepted.")
        } catch let error as LocalizedError {
            XCTAssertEqual(error.errorDescription, "Final archive writing or verification failed. The selected file may remain; treat it as unusable and remove it yourself.")
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
        XCTAssertTrue(try store.portableArchiveCatalogue().isEmpty)
    }

    func testPartialFinalCopyIsLeftUncatalogued() async throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("archive-partial-copy-\(UUID().uuidString).sqlite")
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("archive-\(UUID().uuidString).rekonarchive")
        defer {
            removeDatabase(at: databaseURL)
            try? FileManager.default.removeItem(at: destination)
        }
        let database = try EncryptedDatabase.open(url: databaseURL, key: Data(repeating: 7, count: 32))
        let worker = PortableArchiveWorker(
            configuration: database.portableArchiveConnectionConfiguration(),
            signingKeyStore: InMemoryArchiveSigningKeyStore(),
            finalOutputWriter: { _, output in
                try Data("partial".utf8).write(to: output)
                throw PortableArchiveOutputWriteFailure()
            }
        )
        let store = try WorkspaceStore(
            database: database,
            now: Date(timeIntervalSince1970: 1_704_067_200),
            actorID: "test",
            correlationID: "test",
            portableArchiveWorker: worker
        )
        let recoveryKey = try RecoveryKey.generate()
        try store.enroll(recoveryKey: recoveryKey)

        do {
            _ = try await store.createPortableArchive(recoveryKey: recoveryKey, at: destination)
            XCTFail("A partial final copy must not be accepted.")
        } catch let error as LocalizedError {
            XCTAssertEqual(error.errorDescription, "Final archive writing or verification failed. The selected file may remain; treat it as unusable and remove it yourself.")
        }
        XCTAssertEqual(try Data(contentsOf: destination), Data("partial".utf8))
        XCTAssertTrue(try store.portableArchiveCatalogue().isEmpty)
    }

    func testReplacementAfterCreationIsNotRemovedOrCatalogued() async throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("archive-replacement-\(UUID().uuidString).sqlite")
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("archive-\(UUID().uuidString).rekonarchive")
        let replacementContents = Data("replacement-by-another-operation".utf8)
        defer {
            removeDatabase(at: databaseURL)
            try? FileManager.default.removeItem(at: destination)
        }
        let database = try EncryptedDatabase.open(url: databaseURL, key: Data(repeating: 10, count: 32))
        let worker = PortableArchiveWorker(
            configuration: database.portableArchiveConnectionConfiguration(),
            signingKeyStore: InMemoryArchiveSigningKeyStore(),
            archiveVerifier: { _, _ in
                try replacementContents.write(to: destination, options: .atomic)
                throw PortableArchiveError.verificationFailed
            }
        )
        let store = try WorkspaceStore(
            database: database,
            now: Date(timeIntervalSince1970: 1_704_067_200),
            actorID: "test",
            correlationID: "test",
            portableArchiveWorker: worker
        )
        let recoveryKey = try RecoveryKey.generate()
        try store.enroll(recoveryKey: recoveryKey)

        do {
            _ = try await store.createPortableArchive(recoveryKey: recoveryKey, at: destination)
            XCTFail("A replacement output must not be accepted.")
        } catch let error as LocalizedError {
            XCTAssertEqual(error.errorDescription, "Final archive writing or verification failed. The selected file may remain; treat it as unusable and remove it yourself.")
        }
        XCTAssertEqual(try Data(contentsOf: destination), replacementContents)
        XCTAssertTrue(try store.portableArchiveCatalogue().isEmpty)
    }

    func testConcurrentDestinationIsNotRemovedWhenThisOperationDidNotCreateIt() async throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("archive-concurrent-destination-\(UUID().uuidString).sqlite")
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("archive-\(UUID().uuidString).rekonarchive")
        let preexistingContents = Data("another-operation".utf8)
        defer {
            removeDatabase(at: databaseURL)
            try? FileManager.default.removeItem(at: destination)
        }
        let database = try EncryptedDatabase.open(url: databaseURL, key: Data(repeating: 8, count: 32))
        let worker = PortableArchiveWorker(
            configuration: database.portableArchiveConnectionConfiguration(),
            signingKeyStore: InMemoryArchiveSigningKeyStore(),
            finalOutputWriter: { _, output in
                try preexistingContents.write(to: output)
                throw PortableArchiveError.destinationExists
            }
        )
        let store = try WorkspaceStore(
            database: database,
            now: Date(timeIntervalSince1970: 1_704_067_200),
            actorID: "test",
            correlationID: "test",
            portableArchiveWorker: worker
        )
        let recoveryKey = try RecoveryKey.generate()
        try store.enroll(recoveryKey: recoveryKey)

        do {
            _ = try await store.createPortableArchive(recoveryKey: recoveryKey, at: destination)
            XCTFail("A destination created by another operation must not be accepted.")
        } catch let error as LocalizedError {
            XCTAssertEqual(error.errorDescription, "Choose a new archive file name; Rekon Pursuit will not overwrite an existing archive.")
        }
        XCTAssertEqual(try Data(contentsOf: destination), preexistingContents)
        XCTAssertTrue(try store.portableArchiveCatalogue().isEmpty)
    }

    func testManifestV1MatchesFrozenSixtyThreeByteEncoding() throws {
        let archiveID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        let createdAt = Date(timeIntervalSince1970: 1.25)
        let snapshot = Data([0xAA, 0xBB])
        var expected = Data("RPMAN01".utf8)
        expected.append(contentsOf: [
            0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 1
        ])
        expected.append(contentsOf: [0, 0, 0, 0, 0, 0, 4, 0xE2])
        expected.append(Data(SHA256.hash(data: snapshot)))

        let manifest = PortableArchiveService.manifestBytes(
            archiveID: archiveID,
            createdAt: createdAt,
            snapshot: snapshot
        )

        XCTAssertEqual(manifest.count, 63)
        XCTAssertEqual(manifest, expected)
    }

    func testVerifierRejectsEveryBoundHeaderAndPayloadMutation() throws {
        let recoveryKey = try RecoveryKey.generate()
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("archive-\(UUID().uuidString).tmp")
        defer { try? FileManager.default.removeItem(at: destination) }
        _ = try PortableArchiveService.writeAndVerify(
            snapshot: emptyCanonicalSnapshot(),
            recoveryKey: recoveryKey,
            signingKey: Curve25519.Signing.PrivateKey(),
            archiveID: UUID(),
            createdAt: Date(timeIntervalSince1970: 1_704_067_200),
            to: destination
        )
        let package = try Data(contentsOf: destination)
        let mutationOffsets = [
            14, 30, 38, 46, 47, 79, 111, 143, 175, 207, 267,
            package.index(before: package.endIndex)
        ]

        for offset in mutationOffsets {
            var mutated = package
            mutated[offset] ^= 0x01
            XCTAssertThrowsError(
                try PortableArchiveService.verify(data: mutated, recoveryKey: recoveryKey),
                "Mutation at package byte \(offset) must be rejected."
            )
        }
    }

    func testWorkerSuspensionLeavesMainActorResponsive() async throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("archive-worker-\(UUID().uuidString).sqlite")
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("archive-\(UUID().uuidString).rekonarchive")
        defer {
            try? FileManager.default.removeItem(at: databaseURL)
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: databaseURL.path + "-wal"))
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: databaseURL.path + "-shm"))
            try? FileManager.default.removeItem(at: destination)
        }
        let database = try EncryptedDatabase.open(url: databaseURL, key: Data(repeating: 9, count: 32))
        let keyStore = GatedArchiveSigningKeyStore()
        let store = try WorkspaceStore(
            database: database,
            now: Date(timeIntervalSince1970: 1_704_067_200),
            actorID: "test",
            correlationID: "test",
            archiveSigningKeyStore: keyStore
        )
        let recoveryKey = try RecoveryKey.generate()
        try store.enroll(recoveryKey: recoveryKey)

        let archiveTask = Task {
            try await store.createPortableArchive(recoveryKey: recoveryKey, at: destination)
        }
        while !(await keyStore.hasStarted) {
            await Task.yield()
        }

        XCTAssertTrue(Thread.isMainThread)
        let keyStoreFinished = await keyStore.hasFinished
        XCTAssertFalse(keyStoreFinished)

        await keyStore.release()
        _ = try await archiveTask.value
    }

    func testArchiveActivityCorrelatesOutcomeToOpaqueArchiveID() async throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("archive-audit-\(UUID().uuidString).sqlite")
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("archive-\(UUID().uuidString).rekonarchive")
        defer {
            removeDatabase(at: databaseURL)
            try? FileManager.default.removeItem(at: destination)
        }
        let database = try EncryptedDatabase.open(url: databaseURL, key: Data(repeating: 4, count: 32))
        let store = try WorkspaceStore(
            database: database,
            now: Date(timeIntervalSince1970: 1_704_067_200),
            actorID: "test",
            correlationID: "ordinary-command-correlation",
            archiveSigningKeyStore: StaticArchiveSigningKeyStore()
        )
        let recoveryKey = try RecoveryKey.generate()
        try store.enroll(recoveryKey: recoveryKey)

        let archive = try await store.createPortableArchive(recoveryKey: recoveryKey, at: destination)
        let activity = try XCTUnwrap(try store.activityEvents().last)
        let catalogue = try store.portableArchiveCatalogue()

        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
        XCTAssertNoThrow(try PortableArchiveService.verify(data: Data(contentsOf: destination), recoveryKey: recoveryKey))
        XCTAssertEqual(catalogue.count, 1)
        XCTAssertEqual(catalogue.first?.archiveID, archive.archiveID)
        XCTAssertEqual(catalogue.first?.verificationState, "Verified")
        XCTAssertEqual(activity.kind, "portable_backup_created")
        XCTAssertEqual(activity.correlationID, archive.archiveID.uuidString)
        XCTAssertFalse(activity.correlationID.contains(destination.path))
    }

    func testReadBackRejectsSnapshotRowsWithNoncanonicalColumnCount() throws {
        var snapshot = Data("RPSNAP01".utf8)
        let tableNames = [
            "opportunities",
            "task_reminders",
            "opportunity_stage_history",
            "opportunity_response_history",
            "contacts",
            "contact_opportunities",
            "interactions",
            "import_reports",
            "import_report_rows",
            "posting_checks",
            "reconciliation_reviews",
            "reconciliation_results",
            "reconciliation_check_operations",
            "document_references",
            "activity_events",
            "deletion_tombstones"
        ]
        appendUInt32(UInt32(tableNames.count), to: &snapshot)
        for (index, tableName) in tableNames.enumerated() {
            appendText(tableName, to: &snapshot)
            appendUInt32(index == 0 ? 1 : 0, to: &snapshot)
            if index == 0 {
                appendUInt32(0, to: &snapshot)
            }
        }

        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("archive-\(UUID().uuidString).tmp")
        defer { try? FileManager.default.removeItem(at: destination) }

        XCTAssertThrowsError(
            try PortableArchiveService.writeAndVerify(
                snapshot: snapshot,
                recoveryKey: RecoveryKey.generate(),
                signingKey: Curve25519.Signing.PrivateKey(),
                archiveID: UUID(),
                createdAt: Date(timeIntervalSince1970: 1_704_067_200),
                to: destination
            )
        )
    }

    func testSnapshotEncodesDateColumnsAsSignedUnixMilliseconds() throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("archive-date-codec-\(UUID().uuidString).sqlite")
        defer { removeDatabase(at: databaseURL) }
        let database = try EncryptedDatabase.open(url: databaseURL, key: Data(repeating: 7, count: 32))
        let store = try WorkspaceStore(
            database: database,
            now: Date(timeIntervalSince1970: 1.25),
            actorID: "test",
            correlationID: "test"
        )
        _ = try store.create(CreateOpportunity(title: "Active role", company: "Example"))

        let snapshot = try PortableArchiveSnapshotCodec.encode(from: database)
        let opportunity = try snapshotRows(snapshot, named: "opportunities").first

        XCTAssertEqual(opportunity?.values[3].tag, 1)
        XCTAssertEqual(opportunity?.values[3].integer, 1_250)
    }

    func testSnapshotExcludesOrphanInteractionsAndActivityEvents() throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("archive-active-subjects-\(UUID().uuidString).sqlite")
        defer { removeDatabase(at: databaseURL) }
        let database = try EncryptedDatabase.open(url: databaseURL, key: Data(repeating: 8, count: 32))
        let store = try WorkspaceStore(
            database: database,
            now: Date(timeIntervalSince1970: 2),
            actorID: "test",
            correlationID: "test"
        )
        _ = try store.create(CreateOpportunity(title: "Active role", company: "Example"))
        try database.execute(
            "INSERT INTO interactions (id, contact_id, opportunity_id, kind, summary, occurred_at, next_touch_at) VALUES ('orphan-interaction', NULL, NULL, 'Note', 'orphan', 2, NULL)"
        )
        try database.execute(
            "INSERT INTO activity_events (id, kind, opportunity_id, contact_id, actor_id, correlation_id, occurred_at) VALUES ('orphan-activity', 'orphan', NULL, NULL, 'test', 'test', 2)"
        )

        let snapshot = try PortableArchiveSnapshotCodec.encode(from: database)

        XCTAssertTrue(try snapshotRows(snapshot, named: "interactions").isEmpty)
        XCTAssertEqual(try snapshotRows(snapshot, named: "activity_events").count, 1)
    }

    func testSnapshotExcludesMixedActiveAndDeletedInteractionAndActivitySubjects() throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("archive-mixed-subjects-\(UUID().uuidString).sqlite")
        defer { removeDatabase(at: databaseURL) }
        let database = try EncryptedDatabase.open(url: databaseURL, key: Data(repeating: 5, count: 32))
        let store = try WorkspaceStore(
            database: database,
            now: Date(timeIntervalSince1970: 4),
            actorID: "test",
            correlationID: "test"
        )
        let activeOpportunity = try store.create(CreateOpportunity(title: "Active role", company: "Example"))
        let deletedOpportunity = try store.create(CreateOpportunity(title: "Deleted role", company: "Example"))
        let activeContact = try store.createContact(CreateContact(name: "Active person"))
        let deletedContact = try store.createContact(CreateContact(name: "Deleted person"))
        try store.deleteOpportunity(id: deletedOpportunity.id)
        try store.deleteContact(id: deletedContact.id)

        try database.execute(
            "INSERT INTO interactions (id, contact_id, opportunity_id, kind, summary, occurred_at, next_touch_at) VALUES ('keep-interaction', ?, ?, 'Note', 'keep', 4, NULL)",
            values: [.text(activeContact.id), .text(activeOpportunity.id)]
        )
        try database.execute(
            "INSERT INTO interactions (id, contact_id, opportunity_id, kind, summary, occurred_at, next_touch_at) VALUES ('drop-deleted-opportunity', ?, ?, 'Note', 'drop', 4, NULL)",
            values: [.text(activeContact.id), .text(deletedOpportunity.id)]
        )
        try database.execute(
            "INSERT INTO interactions (id, contact_id, opportunity_id, kind, summary, occurred_at, next_touch_at) VALUES ('drop-deleted-contact', ?, ?, 'Note', 'drop', 4, NULL)",
            values: [.text(deletedContact.id), .text(activeOpportunity.id)]
        )
        try database.execute(
            "INSERT INTO activity_events (id, kind, opportunity_id, contact_id, actor_id, correlation_id, occurred_at) VALUES ('keep-activity', 'keep', ?, ?, 'test', 'test', 4)",
            values: [.text(activeOpportunity.id), .text(activeContact.id)]
        )
        try database.execute(
            "INSERT INTO activity_events (id, kind, opportunity_id, contact_id, actor_id, correlation_id, occurred_at) VALUES ('drop-deleted-opportunity-activity', 'drop', ?, ?, 'test', 'test', 4)",
            values: [.text(deletedOpportunity.id), .text(activeContact.id)]
        )
        try database.execute(
            "INSERT INTO activity_events (id, kind, opportunity_id, contact_id, actor_id, correlation_id, occurred_at) VALUES ('drop-deleted-contact-activity', 'drop', ?, ?, 'test', 'test', 4)",
            values: [.text(activeOpportunity.id), .text(deletedContact.id)]
        )

        let snapshot = try PortableArchiveSnapshotCodec.encode(from: database)
        let interactionIDs = try snapshotRows(snapshot, named: "interactions").compactMap { $0.values.first?.text }
        let activityIDs = try snapshotRows(snapshot, named: "activity_events").compactMap { $0.values.first?.text }

        XCTAssertTrue(interactionIDs.contains("keep-interaction"))
        XCTAssertFalse(interactionIDs.contains("drop-deleted-opportunity"))
        XCTAssertFalse(interactionIDs.contains("drop-deleted-contact"))
        XCTAssertTrue(activityIDs.contains("keep-activity"))
        XCTAssertFalse(activityIDs.contains("drop-deleted-opportunity-activity"))
        XCTAssertFalse(activityIDs.contains("drop-deleted-contact-activity"))
    }

    func testReadBackRejectsRealTimestampInSnapshotRegistryColumn() throws {
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("archive-\(UUID().uuidString).tmp")
        defer { try? FileManager.default.removeItem(at: destination) }

        XCTAssertThrowsError(
            try PortableArchiveService.writeAndVerify(
                snapshot: canonicalSnapshotWithRealOpportunityTimestamp(),
                recoveryKey: RecoveryKey.generate(),
                signingKey: Curve25519.Signing.PrivateKey(),
                archiveID: UUID(),
                createdAt: Date(timeIntervalSince1970: 1_704_067_200),
                to: destination
            )
        )
    }

    func testSnapshotExcludesDeletedContentAndStripsDocumentBookmarks() throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("archive-privacy-projection-\(UUID().uuidString).sqlite")
        defer { removeDatabase(at: databaseURL) }
        let database = try EncryptedDatabase.open(url: databaseURL, key: Data(repeating: 6, count: 32))
        let store = try WorkspaceStore(
            database: database,
            now: Date(timeIntervalSince1970: 3),
            actorID: "test",
            correlationID: "test"
        )
        let active = try store.create(CreateOpportunity(title: "Active role", company: "Example"))
        let deleted = try store.create(CreateOpportunity(title: "Deleted confidential role", company: "Example"))
        _ = try store.recordDocumentReference(RecordDocumentReference(
            opportunityID: active.id,
            kind: .resume,
            filename: "resume.pdf",
            contentType: "application/pdf",
            sourceHash: String(repeating: "a", count: 64),
            byteCount: 100,
            bookmarkData: Data("opaque-bookmark-bytes".utf8)
        ))
        try store.deleteOpportunity(id: deleted.id)

        let snapshot = try PortableArchiveSnapshotCodec.encode(from: database)
        let opportunities = try snapshotRows(snapshot, named: "opportunities")
        let document = try XCTUnwrap(try snapshotRows(snapshot, named: "document_references").first)

        XCTAssertEqual(opportunities.count, 1)
        XCTAssertEqual(opportunities.first?.values[0].text, active.id)
        XCTAssertEqual(document.values[7].tag, 0)
        XCTAssertEqual(document.values[7].data, Data())
        XCTAssertEqual(document.values[8].text, "relink_required")
        XCTAssertFalse(snapshot.contains(Data("Deleted confidential role".utf8)))
        XCTAssertFalse(snapshot.contains(Data("opaque-bookmark-bytes".utf8)))
    }

    private func assertRestoreFails(_ operation: () async throws -> Void) async {
        do {
            try await operation()
            XCTFail("The restore operation was expected to fail.")
        } catch {
            // The exact redacted error varies by failure phase; the invariant
            // under test is that no candidate is returned or activated.
        }
    }

    private func appendText(_ value: String, to data: inout Data) {
        let bytes = Data(value.utf8)
        data.append(3)
        appendUInt32(UInt32(bytes.count), to: &data)
        data.append(bytes)
    }

    private func candidateDirectoryNames(in root: URL) -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: root.path))?
            .filter { $0 != ".staging" } ?? []
    }

    private func appendUInt32(_ value: UInt32, to data: inout Data) {
        data.append(contentsOf: withUnsafeBytes(of: value.bigEndian, Array.init))
    }

    private func emptyCanonicalSnapshot() -> Data {
        var snapshot = Data("RPSNAP01".utf8)
        appendUInt32(UInt32(PortableArchiveSnapshotRegistry.tables.count), to: &snapshot)
        for table in PortableArchiveSnapshotRegistry.tables {
            appendText(table.name, to: &snapshot)
            appendUInt32(0, to: &snapshot)
        }
        return snapshot
    }

    private func snapshotWithOpportunities(count: Int) throws -> Data {
        let databaseURL = FileManager.default.temporaryDirectory.appendingPathComponent("restore-snapshot-opportunities-\(UUID().uuidString).sqlite")
        defer { removeDatabase(at: databaseURL) }
        let database = try EncryptedDatabase.open(url: databaseURL, key: Data(repeating: 7, count: 32))
        defer { try? database.close() }
        let store = try WorkspaceStore(database: database, actorID: "restore-fixture", correlationID: "fixture")
        for index in 0..<count {
            _ = try store.create(CreateOpportunity(title: "Role \(index)", company: "Rekon"))
        }
        return try PortableArchiveSnapshotCodec.encode(from: database)
    }

    private func snapshotWithTaskReminder() throws -> Data {
        let databaseURL = FileManager.default.temporaryDirectory.appendingPathComponent("restore-snapshot-task-\(UUID().uuidString).sqlite")
        defer { removeDatabase(at: databaseURL) }
        let database = try EncryptedDatabase.open(url: databaseURL, key: Data(repeating: 8, count: 32))
        defer { try? database.close() }
        let store = try WorkspaceStore(database: database, actorID: "restore-fixture", correlationID: "fixture")
        let opportunity = try store.create(CreateOpportunity(title: "Role", company: "Rekon"))
        try database.execute(
            "INSERT INTO task_reminders (id, opportunity_id, title, due_at, is_complete) VALUES (?, ?, ?, ?, ?)",
            values: [.text("task-reminder-id"), .text(opportunity.id), .text("Follow up"), .real(1_704_067_200), .integer(0)]
        )
        return try PortableArchiveSnapshotCodec.encode(from: database)
    }

    private func restoreAuthenticatedInvalidSnapshot(_ snapshot: Data, in root: URL) async throws -> InvalidRestoreOutcome {
        let recoveryKey = try RecoveryKey.generate()
        let archiveURL = root.appendingPathComponent("invalid.rekonarchive")
        let verified = try PortableArchiveService.writeAndVerify(
            snapshot: snapshot,
            recoveryKey: recoveryKey,
            signingKey: .init(),
            archiveID: UUID(),
            createdAt: Date(timeIntervalSince1970: 1_704_067_200),
            to: archiveURL
        )
        let candidatesRoot = root.appendingPathComponent("candidates")
        let workspaceKeys = InMemoryRestoreWorkspaceKeys()
        let signingIdentities = InMemoryRestoreCandidateSigningIdentityStore()
        let service = PortableArchiveRestoreService(
            candidatesRoot: candidatesRoot,
            candidateKeyStore: InMemoryRestoreCandidateKeyStore(),
            workspaceKeyStoreForCandidate: workspaceKeys.store,
            signingIdentityStore: signingIdentities
        )
        let worker = PortableArchiveRestoreWorker(restoreService: service)
        await assertRestoreFails {
            _ = try await worker.restore(.init(
                archiveURL: archiveURL,
                recoveryKey: recoveryKey,
                confirmation: .init(
                    archiveID: verified.archiveID,
                    createdAt: verified.createdAt,
                    signingKeyFingerprint: verified.signingKeyFingerprint
                )
            ))
        }
        return .init(candidatesRoot: candidatesRoot, service: service, workspaceKeys: workspaceKeys, signingIdentities: signingIdentities)
    }

    private func canonicalSnapshotWithRealOpportunityTimestamp() -> Data {
        var snapshot = Data("RPSNAP01".utf8)
        appendUInt32(UInt32(PortableArchiveSnapshotRegistry.tables.count), to: &snapshot)
        for table in PortableArchiveSnapshotRegistry.tables {
            appendText(table.name, to: &snapshot)
            if table.name != "opportunities" {
                appendUInt32(0, to: &snapshot)
                continue
            }

            appendUInt32(1, to: &snapshot)
            appendUInt32(UInt32(table.columns.count), to: &snapshot)
            for index in table.columns.indices {
                if index == 3 {
                    snapshot.append(2)
                    appendUInt32(8, to: &snapshot)
                    snapshot.append(contentsOf: withUnsafeBytes(of: Double(1.25).bitPattern.bigEndian, Array.init))
                } else {
                    snapshot.append(0)
                    appendUInt32(0, to: &snapshot)
                }
            }
        }
        return snapshot
    }

    private func removeDatabase(at url: URL) {
        for candidate in [url, URL(fileURLWithPath: url.path + "-wal"), URL(fileURLWithPath: url.path + "-shm")] {
            try? FileManager.default.removeItem(at: candidate)
        }
    }

    private func makeStoreAtVersion26(withArchiveCatalogueRow: Bool) throws -> (store: WorkspaceStore, database: EncryptedDatabase, databaseURL: URL) {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("archive-catalogue-v26-\(UUID().uuidString).sqlite")
        let database = try EncryptedDatabase.open(url: databaseURL, key: Data(repeating: 7, count: 32))
        _ = try WorkspaceStore(database: database, actorID: "test", correlationID: "test")
        if withArchiveCatalogueRow {
            try database.execute(
                "INSERT INTO portable_archive_catalogue (archive_id, destination_bookmark, display_filename, format_version, created_at, expires_at, verification_state, ciphertext_checksum, signing_key_fingerprint) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
                values: [
                    .text("00000000-0000-0000-0000-000000000001"),
                    .blob(Data([0x01])),
                    .text("archive.rekonarchive"),
                    .integer(1),
                    .real(1_704_067_200),
                    .real(1_706_659_200),
                    .text("Verified"),
                    .blob(Data(repeating: 0x02, count: 32)),
                    .blob(Data(repeating: 0x03, count: 32))
                ]
            )
        }
        try database.execute("ALTER TABLE portable_archive_catalogue DROP COLUMN lifecycle_state")
        try database.execute("ALTER TABLE portable_archive_catalogue DROP COLUMN last_expiry_outcome")
        try database.execute("UPDATE schema_migrations SET version = 26")
        try database.execute("DELETE FROM migration_history WHERE version = 27")

        return (try WorkspaceStore(database: database, actorID: "test", correlationID: "test"), database, databaseURL)
    }

    private func snapshotRows(_ snapshot: Data, named expectedName: String) throws -> [SnapshotRow] {
        var reader = SnapshotReader(snapshot)
        XCTAssertEqual(try reader.data(count: 8), Data("RPSNAP01".utf8))
        let tableCount = try reader.uint32()
        for _ in 0..<tableCount {
            let name = try reader.text()
            let rowCount = try reader.uint32()
            var rows: [SnapshotRow] = []
            for _ in 0..<rowCount {
                let valueCount = try reader.uint32()
                rows.append(SnapshotRow(values: try (0..<valueCount).map { _ in try reader.value() }))
            }
            if name == expectedName { return rows }
        }
        XCTFail("Missing table \(expectedName)")
        return []
    }
}

private struct InvalidRestoreOutcome {
    let candidatesRoot: URL
    let service: PortableArchiveRestoreService
    let workspaceKeys: InMemoryRestoreWorkspaceKeys
    let signingIdentities: InMemoryRestoreCandidateSigningIdentityStore
}

private struct MutablePortableArchiveSnapshot {
    private struct Table {
        let name: String
        var rows: [[SnapshotValue]]
    }

    private var tables: [Table]

    init(_ data: Data) throws {
        var reader = SnapshotReader(data)
        guard try reader.data(count: 8) == Data("RPSNAP01".utf8) else {
            throw PortableArchiveError.archiveInvalid
        }
        let count = try reader.uint32()
        var decoded: [Table] = []
        decoded.reserveCapacity(Int(count))
        for _ in 0..<count {
            let name = try reader.text()
            let rowCount = try reader.uint32()
            var rows: [[SnapshotValue]] = []
            rows.reserveCapacity(Int(rowCount))
            for _ in 0..<rowCount {
                let valueCount = try reader.uint32()
                rows.append(try (0..<valueCount).map { _ in try reader.value() })
            }
            decoded.append(.init(name: name, rows: rows))
        }
        tables = decoded
    }

    func rows(named name: String) -> [[SnapshotValue]]? {
        tables.first(where: { $0.name == name })?.rows
    }

    mutating func setValue(_ value: SnapshotValue, table: String, row: Int, column: Int) {
        guard let tableIndex = tables.firstIndex(where: { $0.name == table }) else { return }
        tables[tableIndex].rows[row][column] = value
    }

    mutating func setText(_ value: String, table: String, row: Int, column: Int) {
        setValue(.init(tag: 3, integer: nil, data: Data(value.utf8)), table: table, row: row, column: column)
    }

    func encoded() -> Data {
        var data = Data("RPSNAP01".utf8)
        appendUInt32(UInt32(tables.count), to: &data)
        for table in tables {
            appendText(table.name, to: &data)
            appendUInt32(UInt32(table.rows.count), to: &data)
            for row in table.rows {
                appendUInt32(UInt32(row.count), to: &data)
                for value in row {
                    data.append(value.tag)
                    appendUInt32(UInt32(value.data.count), to: &data)
                    data.append(value.data)
                }
            }
        }
        return data
    }

    private func appendText(_ value: String, to data: inout Data) {
        let bytes = Data(value.utf8)
        data.append(3)
        appendUInt32(UInt32(bytes.count), to: &data)
        data.append(bytes)
    }

    private func appendUInt32(_ value: UInt32, to data: inout Data) {
        data.append(contentsOf: withUnsafeBytes(of: value.bigEndian, Array.init))
    }
}

private struct SnapshotRow {
    let values: [SnapshotValue]
}

private struct SnapshotValue {
    let tag: UInt8
    let integer: Int64?
    let data: Data

    var text: String? {
        guard tag == 3 else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

private struct SnapshotReader {
    private let source: Data
    private var offset = 0

    init(_ source: Data) { self.source = source }

    mutating func data(count: Int) throws -> Data {
        guard count >= 0, offset + count <= source.count else { throw PortableArchiveError.archiveInvalid }
        defer { offset += count }
        return source.subdata(in: offset..<(offset + count))
    }

    mutating func uint32() throws -> UInt32 {
        try data(count: 4).reduce(0) { ($0 << 8) | UInt32($1) }
    }

    mutating func text() throws -> String {
        guard try data(count: 1).first == 3,
              let text = String(data: try data(count: Int(try uint32())), encoding: .utf8) else {
            throw PortableArchiveError.archiveInvalid
        }
        return text
    }

    mutating func value() throws -> SnapshotValue {
        let tag = try data(count: 1).first!
        let bytes = try data(count: Int(try uint32()))
        guard tag <= 4 else { throw PortableArchiveError.archiveInvalid }
        let integer: Int64?
        if tag == 1 {
            guard bytes.count == 8 else { throw PortableArchiveError.archiveInvalid }
            integer = Int64(bitPattern: bytes.reduce(0) { ($0 << 8) | UInt64($1) })
        } else {
            integer = nil
        }
        return SnapshotValue(tag: tag, integer: integer, data: bytes)
    }
}

private actor GatedArchiveSigningKeyStore: ArchiveSigningKeyStoring {
    private let rawKey = Curve25519.Signing.PrivateKey().rawRepresentation
    private(set) var hasStarted = false
    private(set) var hasFinished = false
    private var isReleased = false

    func privateKeyRawRepresentation(
        for workspaceID: String,
        catalogueExists: Bool
    ) async throws -> Data {
        hasStarted = true
        while !isReleased {
            await Task.yield()
        }
        hasFinished = true
        return rawKey
    }

    func release() {
        isReleased = true
    }
}

private actor StaticArchiveSigningKeyStore: ArchiveSigningKeyStoring {
    private let rawKey = Curve25519.Signing.PrivateKey().rawRepresentation

    func privateKeyRawRepresentation(
        for workspaceID: String,
        catalogueExists: Bool
    ) async throws -> Data {
        rawKey
    }
}

private enum RestoreTestFailure: Error {
    case injected
}

private final class FailingRestoreRegistryKeyStore: RestoreCandidateKeyStoring {
    func readOrCreateKey() throws -> Data {
        throw RestoreTestFailure.injected
    }
}

private final class CleanupFailingWorkspaceKeyStore: WorkspaceKeyStore {
    func readWorkspaceKey() throws -> Data? { nil }
    func writeWorkspaceKey(_: Data) throws {}
    func deleteWorkspaceKey() throws { throw RestoreTestFailure.injected }
    func readPendingWorkspaceKey() throws -> Data? { nil }
    func writePendingWorkspaceKey(_: Data) throws {}
    func promotePendingWorkspaceKey() throws {}
    func deletePendingWorkspaceKey() throws {}
}

private final class ToggleCleanupWorkspaceKeyStore: WorkspaceKeyStore {
    private var primaryKey: Data?
    private var pendingKey: Data?
    private var cleanupAllowed = false

    func readWorkspaceKey() throws -> Data? { primaryKey }
    func writeWorkspaceKey(_ key: Data) throws { primaryKey = key }
    func deleteWorkspaceKey() throws {
        guard cleanupAllowed else { throw RestoreTestFailure.injected }
        primaryKey = nil
    }
    func readPendingWorkspaceKey() throws -> Data? { pendingKey }
    func writePendingWorkspaceKey(_ key: Data) throws { pendingKey = key }
    func promotePendingWorkspaceKey() throws { primaryKey = pendingKey; pendingKey = nil }
    func deletePendingWorkspaceKey() throws { pendingKey = nil }
    func allowCleanup() { cleanupAllowed = true }
}

private final class ReadbackFailingSigningIdentityStore: RestoreCandidateSigningIdentityStoring {
    func createAndVerify(for _: UUID) throws {}
    func delete(for _: UUID) throws {}
    func isAbsent(for _: UUID) throws -> Bool { false }
}

private final class RestoreWorkerThreadObservation: @unchecked Sendable {
    private let lock = NSLock()
    private var observed: Bool?
    func record(isMainThread: Bool) { lock.lock(); observed = isMainThread; lock.unlock() }
    var mainThreadValue: Bool? { lock.lock(); defer { lock.unlock() }; return observed }
}
