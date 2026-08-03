import CryptoKit
import XCTest
@testable import RekonPursuit

@MainActor
final class ProtectedExportTests: XCTestCase {
    func testProtectedExportUsesDistinctVersionedContainer() {
        XCTAssertEqual(ProtectedExportService.formatVersion, 1)
        XCTAssertEqual(ProtectedExportService.magic, Data("RPEXPT01".utf8))
    }

    func testProtectedExportIsEncryptedAndVerifiableWithRecoveryKey() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("protected-export-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let database = try EncryptedDatabase.open(url: root.appendingPathComponent("workspace.sqlite"), key: Data(repeating: 7, count: 32), createIfMissing: true)
        let store = try WorkspaceStore(database: database, actorID: "test", correlationID: "test")
        let key = try RecoveryKey.generate()
        try store.enroll(recoveryKey: key)
        let destination = root.appendingPathComponent("job-search.rekonexport")

        let review = try await store.reviewProtectedExport(recoveryKey: key, at: destination)
        let receipt = try await store.createProtectedExport(review: review, recoveryKey: key)

        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
        XCTAssertEqual(try ProtectedExportService.verify(data: Data(contentsOf: destination), recoveryKey: key), receipt)
        XCTAssertThrowsError(try ProtectedExportService.verify(data: Data(contentsOf: destination), recoveryKey: try RecoveryKey.generate()))
        var tampered = try Data(contentsOf: destination)
        tampered[20] ^= 0x01
        XCTAssertThrowsError(try ProtectedExportService.verify(data: tampered, recoveryKey: key))
        try store.close()
    }

    func testProtectedExportCopiesAndVerifiesLargeWorkspaceData() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("protected-export-large-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let database = try EncryptedDatabase.open(url: root.appendingPathComponent("workspace.sqlite"), key: Data(repeating: 17, count: 32), createIfMissing: true)
        let store = try WorkspaceStore(database: database, actorID: "test", correlationID: "test")
        let key = try RecoveryKey.generate()
        try store.enroll(recoveryKey: key)
        _ = try store.create(.init(title: "Large export", company: "Example", jobDescription: String(repeating: "A", count: 1_200_000)))
        let destination = root.appendingPathComponent("large-workspace.rekonexport")

        let review = try await store.reviewProtectedExport(recoveryKey: key, at: destination)
        let receipt = try await store.createProtectedExport(review: review, recoveryKey: key)

        XCTAssertGreaterThan((try Data(contentsOf: destination)).count, 1_048_576)
        XCTAssertEqual(try ProtectedExportService.verify(data: Data(contentsOf: destination), recoveryKey: key), receipt)
        try store.close()
    }

    func testSelectedLeafDigestUsesCanonicalLeafLocator() async throws {
        let fixture = try makeProtectedExportFeedbackFixture(
            faultMode: .none,
            destinationName: "Cafe\u{301}.rekonexport"
        )
        defer { fixture.close() }

        let review = try await fixture.store.reviewProtectedExport(
            recoveryKey: fixture.recoveryKey,
            at: fixture.destination
        )
        let canonicalLeaf = fixture.destination.standardizedFileURL.path
            .precomposedStringWithCanonicalMapping
        var input = Data("RekonPursuit/export/leaf-destination/v2\0".utf8)
        input.append(contentsOf: canonicalLeaf.utf8)
        XCTAssertEqual(review.destinationIdentityDigest, Data(SHA256.hash(data: input)))
        XCTAssertEqual(review.displayFilename, fixture.destination.lastPathComponent.precomposedStringWithCanonicalMapping)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.destination.path))
    }

    func testSourceRevisionChangeRejectsReviewedExportWithoutCreatingAFile() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("protected-export-revision-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let database = try EncryptedDatabase.open(url: root.appendingPathComponent("workspace.sqlite"), key: Data(repeating: 9, count: 32), createIfMissing: true)
        let store = try WorkspaceStore(database: database, actorID: "test", correlationID: "test")
        let key = try RecoveryKey.generate()
        try store.enroll(recoveryKey: key)
        let destination = root.appendingPathComponent("changed.rekonexport")
        let review = try await store.reviewProtectedExport(recoveryKey: key, at: destination)
        _ = try store.create(.init(title: "Changed", company: "Example"))

        do {
            _ = try await store.createProtectedExport(review: review, recoveryKey: key)
            XCTFail("Expected the reviewed export to be rejected after source data changed.")
        } catch {
            XCTAssertEqual(error as? ProtectedExportWorkerError, .sourceChanged)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
        XCTAssertEqual(try database.rows("SELECT id FROM protected_export_events").count, 0)
        XCTAssertEqual(try store.activityEvents().filter { $0.kind == "protected_export_verified" }.count, 0)
        try store.close()
    }

    func testExistingTargetIsRejectedWithoutOverwritingIt() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("protected-export-existing-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let database = try EncryptedDatabase.open(url: root.appendingPathComponent("workspace.sqlite"), key: Data(repeating: 10, count: 32), createIfMissing: true)
        let store = try WorkspaceStore(database: database, actorID: "test", correlationID: "test")
        let key = try RecoveryKey.generate()
        try store.enroll(recoveryKey: key)
        let destination = root.appendingPathComponent("existing.rekonexport")
        let original = Data("do not replace".utf8)
        try original.write(to: destination)

        do { _ = try await store.reviewProtectedExport(recoveryKey: key, at: destination); XCTFail("Expected existing target rejection.") }
        catch { XCTAssertEqual(error as? ProtectedExportWorkerError, .destinationExists) }
        XCTAssertEqual(try Data(contentsOf: destination), original)
        XCTAssertEqual(try database.rows("SELECT id FROM protected_export_events").count, 0)
        XCTAssertEqual(try store.activityEvents().filter { $0.kind == "protected_export_verified" }.count, 0)
        try store.close()
    }

    func testTerminalSymlinkIsRejectedWithoutChangingTargetBytesOrEvidence() async throws {
        let fixture = try makeProtectedExportFeedbackFixture(faultMode: .none)
        defer { fixture.close() }
        let sentinel = fixture.root.appendingPathComponent("terminal-sentinel.bin")
        let original = Data("terminal symlink sentinel bytes".utf8)
        try original.write(to: sentinel)
        try FileManager.default.createSymbolicLink(at: fixture.destination, withDestinationURL: sentinel)

        do {
            _ = try await fixture.store.reviewProtectedExport(recoveryKey: fixture.recoveryKey, at: fixture.destination)
            XCTFail("Expected terminal symlink rejection.")
        } catch {
            XCTAssertEqual(error as? ProtectedExportWorkerError, .destinationExists)
        }
        XCTAssertEqual(try Data(contentsOf: sentinel), original)
        try assertNoVerifiedProtectedExportEvidence(in: fixture)
    }

    func testInvalidDestinationNameUsesDedicatedControlledError() async throws {
        let fixture = try makeProtectedExportFeedbackFixture(faultMode: .none, destinationName: "invalid-name.txt")
        defer { fixture.close() }

        do {
            _ = try await fixture.store.reviewProtectedExport(recoveryKey: fixture.recoveryKey, at: fixture.destination)
            XCTFail("Expected invalid final filename to be rejected.")
        } catch {
            XCTAssertEqual((error as? LocalizedError)?.errorDescription,
                           "Choose a new file name ending in .rekonexport.")
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.destination.path))
        try assertNoVerifiedProtectedExportEvidence(in: fixture)
    }

    func testSentinelCreatedAfterReviewIsNotOverwrittenOrRecorded() async throws {
        let fixture = try makeProtectedExportFeedbackFixture(faultMode: .none)
        defer { fixture.close() }
        let review = try await fixture.store.reviewProtectedExport(recoveryKey: fixture.recoveryKey, at: fixture.destination)
        let sentinel = Data("post-review sentinel bytes".utf8)
        try sentinel.write(to: fixture.destination)

        do {
            _ = try await fixture.store.createProtectedExport(review: review, recoveryKey: fixture.recoveryKey)
            XCTFail("Expected post-review collision rejection.")
        } catch {
            XCTAssertEqual(error as? ProtectedExportWorkerError, .destinationExists)
        }
        XCTAssertEqual(try Data(contentsOf: fixture.destination), sentinel)
        try assertNoVerifiedProtectedExportEvidence(in: fixture)
    }

    func testLeafProbeENOTDIRBeforeOutputUsesDestinationUnavailableWithoutEvidence() async throws {
        let fixture = try makeProtectedExportFeedbackFixture(
            faultMode: .none,
            destinationName: "blocked-parent/export.rekonexport"
        )
        defer { fixture.close() }
        let review = try await fixture.store.reviewProtectedExport(recoveryKey: fixture.recoveryKey, at: fixture.destination)
        let blockedParent = fixture.destination.deletingLastPathComponent()
        try Data("regular file prevents leaf lookup".utf8).write(to: blockedParent)

        do {
            _ = try await fixture.store.createProtectedExport(review: review, recoveryKey: fixture.recoveryKey)
            XCTFail("Expected exact leaf probe ENOTDIR to reject the unavailable destination.")
        } catch {
            XCTAssertEqual(error as? ProtectedExportWorkerError, .destinationUnavailable)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.destination.path))
        try assertNoVerifiedProtectedExportEvidence(in: fixture)
    }

    func testChangedLeafLocatorIsRejectedBeforeOutputOrEvidence() async throws {
        let fixture = try makeProtectedExportFeedbackFixture(faultMode: .none)
        defer { fixture.close() }
        let review = try await fixture.store.reviewProtectedExport(recoveryKey: fixture.recoveryKey, at: fixture.destination)
        let changedReview = reconstructReview(
            review,
            destinationURL: fixture.root.appendingPathComponent("changed-leaf.rekonexport")
        )

        do {
            _ = try await fixture.store.createProtectedExport(review: changedReview, recoveryKey: fixture.recoveryKey)
            XCTFail("Expected changed leaf locator rejection.")
        } catch {
            XCTAssertEqual(error as? ProtectedExportWorkerError, .destinationChanged)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.destination.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: changedReview.destinationURL.path))
        try assertNoVerifiedProtectedExportEvidence(in: fixture)
    }

    func testChangedDestinationDigestIsRejectedBeforeOutputOrEvidence() async throws {
        let fixture = try makeProtectedExportFeedbackFixture(faultMode: .none)
        defer { fixture.close() }
        let review = try await fixture.store.reviewProtectedExport(recoveryKey: fixture.recoveryKey, at: fixture.destination)
        let changedReview = reconstructReview(review, destinationIdentityDigest: Data(repeating: 0, count: 32))

        do {
            _ = try await fixture.store.createProtectedExport(review: changedReview, recoveryKey: fixture.recoveryKey)
            XCTFail("Expected changed destination digest rejection.")
        } catch {
            XCTAssertEqual(error as? ProtectedExportWorkerError, .destinationChanged)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.destination.path))
        try assertNoVerifiedProtectedExportEvidence(in: fixture)
    }

    func testChangedConfirmationFingerprintIsRejectedBeforeOutputOrEvidence() async throws {
        let fixture = try makeProtectedExportFeedbackFixture(faultMode: .none)
        defer { fixture.close() }
        let review = try await fixture.store.reviewProtectedExport(recoveryKey: fixture.recoveryKey, at: fixture.destination)
        let changedReview = reconstructReview(review, confirmationFingerprint: "changed-confirmation-fingerprint")

        do {
            _ = try await fixture.store.createProtectedExport(review: changedReview, recoveryKey: fixture.recoveryKey)
            XCTFail("Expected changed confirmation fingerprint rejection.")
        } catch {
            XCTAssertEqual(error as? ProtectedExportWorkerError, .destinationChanged)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.destination.path))
        try assertNoVerifiedProtectedExportEvidence(in: fixture)
    }

    func testDirectLeafFailureBeforeOutputUsesDestinationUnavailableWithoutActivity() async throws {
        let fixture = try makeProtectedExportFeedbackFixture(faultMode: .directLeafUnavailable)
        defer { fixture.close() }
        let review = try await fixture.store.reviewProtectedExport(recoveryKey: fixture.recoveryKey, at: fixture.destination)

        do {
            _ = try await fixture.store.createProtectedExport(review: review, recoveryKey: fixture.recoveryKey)
            XCTFail("Expected direct selected-leaf creation failure before output creation.")
        } catch {
            XCTAssertEqual((error as? LocalizedError)?.errorDescription,
                           "Rekon Pursuit can’t use that folder. Choose another local folder and review the export again.")
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.destination.path))
        try assertNoVerifiedProtectedExportEvidence(in: fixture)
    }

    func testPostCreateFailureRemainsOutputMayRemainAfterFailure() async throws {
        let fixture = try makeProtectedExportFeedbackFixture(faultMode: .afterOutputCreation)
        defer { fixture.close() }
        let review = try await fixture.store.reviewProtectedExport(recoveryKey: fixture.recoveryKey, at: fixture.destination)

        do {
            _ = try await fixture.store.createProtectedExport(review: review, recoveryKey: fixture.recoveryKey)
            XCTFail("Expected post-create failure to retain conservative output warning.")
        } catch {
            XCTAssertEqual((error as? LocalizedError)?.errorDescription,
                           "Final export writing or verification failed. The selected file may remain; treat it as unusable and remove it yourself.")
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.destination.path))
        try assertNoVerifiedProtectedExportEvidence(in: fixture)
    }

    func testBeforeEvidenceCommitLeavesVerifiedOutputWithoutEvidence() async throws {
        let fixture = try makeProtectedExportFeedbackFixture(faultMode: .beforeEvidenceCommit)
        defer { fixture.close() }
        let review = try await fixture.store.reviewProtectedExport(recoveryKey: fixture.recoveryKey, at: fixture.destination)

        do {
            _ = try await fixture.store.createProtectedExport(review: review, recoveryKey: fixture.recoveryKey)
            XCTFail("Expected evidence-commit fault after verified output.")
        } catch {
            XCTAssertEqual(error as? ProtectedExportWorkerError, .outputMayRemainAfterFailure)
        }
        XCTAssertNoThrow(try ProtectedExportService.verify(data: Data(contentsOf: fixture.destination), recoveryKey: fixture.recoveryKey))
        try assertNoVerifiedProtectedExportEvidence(in: fixture)
    }

    func testVerifiedProtectedExportCreatesExactlyOneVerifiedEventAndActivity() async throws {
        let fixture = try makeProtectedExportFeedbackFixture(faultMode: .none)
        defer { fixture.close() }
        let review = try await fixture.store.reviewProtectedExport(recoveryKey: fixture.recoveryKey, at: fixture.destination)
        let receipt = try await fixture.store.createProtectedExport(review: review, recoveryKey: fixture.recoveryKey)

        XCTAssertEqual(try ProtectedExportService.verify(data: Data(contentsOf: fixture.destination), recoveryKey: fixture.recoveryKey), receipt)
        XCTAssertEqual(try fixture.database.rows("SELECT id FROM protected_export_events WHERE outcome = 'verified'").count, 1)
        XCTAssertEqual(try fixture.store.activityEvents().filter { $0.kind == "protected_export_verified" }.count, 1)
    }

    private func makeProtectedExportFeedbackFixture(
        faultMode: ProtectedExportWorkerFaultMode,
        destinationName: String = "feedback.rekonexport"
    ) throws -> ProtectedExportFeedbackFixture {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("protected-export-feedback-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let database = try EncryptedDatabase.open(
            url: root.appendingPathComponent("workspace.sqlite"),
            key: Data(repeating: 21, count: 32),
            createIfMissing: true
        )
        let worker = ProtectedExportWorker(
            configuration: database.portableArchiveConnectionConfiguration(),
            faultMode: faultMode
        )
        let store = try WorkspaceStore(
            database: database,
            actorID: "protected-export-feedback",
            correlationID: "protected-export-feedback",
            protectedExportWorker: worker
        )
        let recoveryKey = try RecoveryKey.generate()
        try store.enroll(recoveryKey: recoveryKey)
        _ = try store.create(.init(title: "Protected export feedback", company: "Rekon Labs"))
        return .init(root: root, database: database, store: store, recoveryKey: recoveryKey,
                     destination: root.appendingPathComponent(destinationName))
    }

    private func assertNoVerifiedProtectedExportEvidence(in fixture: ProtectedExportFeedbackFixture) throws {
        XCTAssertEqual(try fixture.database.rows("SELECT id FROM protected_export_events").count, 0)
        XCTAssertEqual(try fixture.store.activityEvents().filter { $0.kind == "protected_export_verified" }.count, 0)
    }

    private func reconstructReview(
        _ review: ProtectedExportReview,
        destinationURL: URL? = nil,
        destinationIdentityDigest: Data? = nil,
        confirmationFingerprint: String? = nil
    ) -> ProtectedExportReview {
        .init(
            destinationURL: destinationURL ?? review.destinationURL,
            sourceRevision: review.sourceRevision,
            destinationIdentityDigest: destinationIdentityDigest ?? review.destinationIdentityDigest,
            confirmationFingerprint: confirmationFingerprint ?? review.confirmationFingerprint
        )
    }

    @MainActor
    private struct ProtectedExportFeedbackFixture {
        let root: URL
        let database: EncryptedDatabase
        let store: WorkspaceStore
        let recoveryKey: RecoveryKey
        let destination: URL

        func close() {
            try? store.close()
            try? FileManager.default.removeItem(at: root)
        }
    }
}
