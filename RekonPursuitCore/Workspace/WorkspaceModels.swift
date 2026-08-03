import CryptoKit
import Foundation
import Security

nonisolated struct RecoveryKey: Equatable, Sendable {
    private static let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")
    private static let keyCharacterCount = 52
    private static let checksumCharacterCount = 6
    private let bytes: Data

    let displayValue: String

    static func generate() throws -> RecoveryKey {
        var bytes = Data(repeating: 0, count: 32)
        let result = bytes.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!) }
        guard result == errSecSuccess else { throw RecoveryKeyError.randomnessUnavailable }
        return try RecoveryKey(bytes: bytes)
    }

    static func parse(_ input: String) -> RecoveryKey? {
        let compact = input.uppercased().filter { $0.isLetter || $0.isNumber }
        guard compact.count == keyCharacterCount + checksumCharacterCount else { return nil }
        let keyText = String(compact.prefix(keyCharacterCount))
        let suppliedChecksum = String(compact.suffix(checksumCharacterCount))
        guard let bytes = decodeBase32(keyText), bytes.count == 32,
              suppliedChecksum == checksum(for: bytes) else { return nil }
        return try? RecoveryKey(bytes: bytes)
    }

    var fingerprint: String {
        "v1:" + SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }

    var operationBytes: Data { bytes }

    private init(bytes: Data) throws {
        guard bytes.count == 32 else { throw RecoveryKeyError.invalidLength }
        self.bytes = bytes
        let text = Self.encodeBase32(bytes)
        displayValue = Self.group(text) + "-" + Self.checksum(for: bytes)
    }

    private static func checksum(for bytes: Data) -> String {
        String(encodeBase32(Data(SHA256.hash(data: bytes))).prefix(checksumCharacterCount))
    }

    private static func group(_ text: String) -> String {
        stride(from: 0, to: text.count, by: 4).map { start in
            let lower = text.index(text.startIndex, offsetBy: start)
            let upper = text.index(lower, offsetBy: min(4, text.distance(from: lower, to: text.endIndex)))
            return String(text[lower..<upper])
        }.joined(separator: "-")
    }

    private static func encodeBase32(_ data: Data) -> String {
        var buffer = 0
        var bits = 0
        var result = ""
        for byte in data {
            buffer = (buffer << 8) | Int(byte)
            bits += 8
            while bits >= 5 {
                result.append(alphabet[(buffer >> (bits - 5)) & 31])
                bits -= 5
            }
        }
        if bits > 0 { result.append(alphabet[(buffer << (5 - bits)) & 31]) }
        return result
    }

    private static func decodeBase32(_ text: String) -> Data? {
        var buffer = 0
        var bits = 0
        var result = Data()
        for character in text {
            guard let value = alphabet.firstIndex(of: character) else { return nil }
            buffer = (buffer << 5) | value
            bits += 5
            while bits >= 8 {
                result.append(UInt8((buffer >> (bits - 8)) & 255))
                bits -= 8
            }
        }
        return result
    }
}

enum RecoveryKeyError: Error { case randomnessUnavailable, invalidLength }

struct RecoveryEnrollmentState: Equatable { let isEnabled: Bool }
struct RecoveryEnrollmentRecord: Equatable { let fingerprint: String, enrolledAt: Date }

nonisolated enum PortableArchiveLifecycleState: String, Equatable, Sendable {
    case verified = "Verified"
    case expiredPendingRemoval = "expired_pending_removal"
    case expiredRetryable = "expired_retryable"
    case expiredBlocked = "expired_blocked"
    case expiredMissing = "expired_missing"
    case expiredManualRemovalRequired = "expired_manual_removal_required"
    case expiredPrepared = "expired_prepared"
    case expiredQuarantined = "expired_quarantined"
}

nonisolated enum PortableArchiveExpiryOutcome: String, Equatable, Sendable {
    case none
    case scopeUnavailable
    case targetMissing
    case targetUnsafe
    case identityMismatch
    case archiveMismatch
    case ioFailure
    case removed
    case manualRemovalRequired = "manual_removal_required"
    case deferredByPurge = "deferred_by_purge"
}

nonisolated struct PortableArchiveCatalogueRow: Equatable, Sendable {
    let archiveID: UUID
    let displayFilename: String
    let formatVersion: Int
    let createdAt: Date
    let expiresAt: Date
    let verificationState: String
    let ciphertextChecksum: Data
    let signingKeyFingerprint: Data
    let lifecycleState: PortableArchiveLifecycleState
    let lastExpiryOutcome: PortableArchiveExpiryOutcome

    init(
        archiveID: UUID,
        displayFilename: String,
        formatVersion: Int,
        createdAt: Date,
        expiresAt: Date,
        verificationState: String,
        ciphertextChecksum: Data,
        signingKeyFingerprint: Data,
        lifecycleState: PortableArchiveLifecycleState = .verified,
        lastExpiryOutcome: PortableArchiveExpiryOutcome = .none
    ) {
        self.archiveID = archiveID
        self.displayFilename = displayFilename
        self.formatVersion = formatVersion
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.verificationState = verificationState
        self.ciphertextChecksum = ciphertextChecksum
        self.signingKeyFingerprint = signingKeyFingerprint
        self.lifecycleState = lifecycleState
        self.lastExpiryOutcome = lastExpiryOutcome
    }
}

nonisolated enum RetainedDataPurgeState: String, Equatable, Sendable {
    case running, complete, incomplete, cancelled, blocked
}

nonisolated enum RetainedDataPurgeArchivePhase: String, Equatable, Sendable {
    case scoped, notAffected = "not_affected", replacementWriting = "replacement_writing", replacementVerified = "replacement_verified", replacementCatalogued = "replacement_catalogued", predecessorRemovalPending = "predecessor_removal_pending", purged, cancelled, expiryDeferred = "expiry_deferred", retryableFailure = "retryable_failure", blocked
}

nonisolated struct RetainedDataPurgeResult: Equatable, Sendable {
    let jobID: UUID
    let state: RetainedDataPurgeState
    let purgedArchiveIDs: [UUID]
    let incompleteArchiveIDs: [UUID]
}

nonisolated struct RetainedDataPurgeStatus: Equatable, Sendable {
    let jobID: UUID
    let state: RetainedDataPurgeState
    let startedAt: Date
    let finishedAt: Date?
}

nonisolated struct VerifiedPortableArchive: Equatable, Sendable {
    let archiveID: UUID
    let createdAt: Date
    let expiresAt: Date
    let ciphertextChecksum: Data
    let signingKeyFingerprint: Data
}

nonisolated enum PortableArchiveError: Error, LocalizedError, Sendable {
    case enrollmentRequired, invalidRecoveryKey, destinationExists, invalidDestination, destinationUnavailable, archiveInvalid, verificationFailed, signingKeyUnavailable, catalogueUnavailable, archiveMayRemainAfterOutputFailure, operationCancelled

    var errorDescription: String? {
        switch self {
        case .enrollmentRequired: return "Set up portable recovery before creating an archive."
        case .invalidRecoveryKey: return "The recovery key could not unlock this archive operation."
        case .destinationExists: return "Choose a new archive file name; Rekon Pursuit will not overwrite an existing archive."
        case .invalidDestination: return "Choose a new .rekonarchive destination."
        case .destinationUnavailable: return "Rekon Pursuit could not write to that destination. Choose another folder or file name."
        case .archiveInvalid, .verificationFailed: return "The archive could not be verified, so it was not saved."
        case .signingKeyUnavailable: return "The archive signing identity is unavailable; no archive was created."
        case .catalogueUnavailable: return "The archive was verified but could not be recorded locally. It may still exist at the chosen destination."
        case .archiveMayRemainAfterOutputFailure: return "Final archive writing or verification failed. The selected file may remain; treat it as unusable and remove it yourself."
        case .operationCancelled: return "The retained-data purge was cancelled before an archive was removed. Existing archives were left intact."
        }
    }
}

struct Opportunity: Equatable {
    let id: String
    let title: String
    let company: String
    let createdAt: Date
    let stage: PipelineStage
    let nextAction: String
    let dueAt: Date?
    let jobURL: String
    let jobDescription: String
    let notes: String
    let compensation: String?
    let compensationMinimum: Double?
    let compensationMaximum: Double?
    let compensationPayPeriod: CompensationPayPeriod?
    let location: String?
    let workArrangement: WorkArrangement
    let applicationDate: Date?
    let responseState: ResponseState
    let stageChangedAt: Date?
    let actionType: OpportunityActionType
    let actionCustomText: String?

    init(id: String, title: String, company: String, createdAt: Date, stage: PipelineStage = .saved, nextAction: String = "", dueAt: Date? = nil, jobURL: String = "", jobDescription: String = "", notes: String = "", compensation: String? = nil, compensationMinimum: Double? = nil, compensationMaximum: Double? = nil, compensationPayPeriod: CompensationPayPeriod? = nil, location: String? = nil, workArrangement: WorkArrangement = .notSpecified, applicationDate: Date? = nil, responseState: ResponseState = .noResponseRecorded, stageChangedAt: Date? = nil, actionType: OpportunityActionType = .noAction, actionCustomText: String? = nil) {
        self.id = id
        self.title = title
        self.company = company
        self.createdAt = createdAt
        self.stage = stage
        self.nextAction = nextAction
        self.dueAt = dueAt
        self.jobURL = jobURL
        self.jobDescription = jobDescription
        self.notes = notes
        self.compensation = compensation
        self.compensationMinimum = compensationMinimum
        self.compensationMaximum = compensationMaximum
        self.compensationPayPeriod = compensationPayPeriod
        self.location = location
        self.workArrangement = workArrangement
        self.applicationDate = applicationDate
        self.responseState = responseState
        self.stageChangedAt = stageChangedAt
        self.actionType = actionType
        self.actionCustomText = actionCustomText
    }
}

enum WorkArrangement: String, CaseIterable, Equatable {
    case notSpecified = "Not specified"
    case onSite = "On-site"
    case hybrid = "Hybrid"
    case remote = "Remote"
}

enum CompensationPayPeriod: String, CaseIterable, Equatable {
    case year = "Year"
    case month = "Month"
    case hour = "Hour"
}

enum OpportunityActionType: String, CaseIterable, Equatable {
    case noAction = "No action"
    case apply = "Apply"
    case followUp = "Follow up"
    case interviewPrep = "Prepare for interview"
    case other = "Other"
}

enum ResponseState: String, CaseIterable, Equatable {
    case noResponseRecorded = "No response recorded"
    case awaitingResponse = "Awaiting response"
    case responseReceived = "Response received"
    case declined = "Declined"
}

struct ResponseHistoryEntry: Equatable {
    let id: String
    let opportunityID: String
    let fromState: ResponseState
    let toState: ResponseState
    let occurredAt: Date
}

enum ReconciliationOutcome: String, CaseIterable, Equatable {
    case stillOpen = "Still open"
    case possiblyClosed = "Possibly closed"
    case closedSuggested = "Closed suggested"
    case needsManualReview = "Needs manual review"
}

enum ReconciliationClassification: String, CaseIterable, Equatable {
    case confirmed = "Confirmed"
    case ambiguous = "Ambiguous"
    case failed = "Failed"
    case offlineUnchecked = "Offline unchecked"
}

enum ReconciliationReason: String, CaseIterable, Equatable {
    case manualReview = "manual review"
    case changedURL = "changed URL"
    case accessBlocked = "access blocked"
    case sourceFailed = "source failed"
    case offlineUnchecked = "offline — check not run"
    case other = "other"
}

enum ReconciliationConfidence: String, CaseIterable, Equatable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"
}

struct ReconciliationResult: Equatable {
    let id: String
    let opportunityID: String
    let url: String
    let recordedAt: Date
    let outcome: ReconciliationOutcome
    let classification: ReconciliationClassification
    let reason: ReconciliationReason
    let confidence: ReconciliationConfidence?
    let evidence: String
    let error: String
    let reviewTaskID: String?
    let closureConfirmedAt: Date?
    let legacyPostingCheckID: String?
    let legacyStatus: String?
    let checkOperationID: String?
    let method: String?
    let checkerVersion: String?
    let httpStatus: Int?
    let mimeType: String?
    let declaredBytes: Int?
    let receivedBytes: Int?
    let contentSHA256: String?
    let responseDate: String?
    let lastModified: String?
    let etag: String?
    let retryAfter: String?
    let redirectTargetRedacted: String?
    let evidenceExcerpt: String?
    let redactedErrorCode: String?

    init(
        id: String,
        opportunityID: String,
        url: String,
        recordedAt: Date,
        outcome: ReconciliationOutcome,
        classification: ReconciliationClassification,
        reason: ReconciliationReason,
        confidence: ReconciliationConfidence?,
        evidence: String,
        error: String,
        reviewTaskID: String?,
        closureConfirmedAt: Date?,
        legacyPostingCheckID: String?,
        legacyStatus: String?,
        checkOperationID: String? = nil,
        method: String? = nil,
        checkerVersion: String? = nil,
        httpStatus: Int? = nil,
        mimeType: String? = nil,
        declaredBytes: Int? = nil,
        receivedBytes: Int? = nil,
        contentSHA256: String? = nil,
        responseDate: String? = nil,
        lastModified: String? = nil,
        etag: String? = nil,
        retryAfter: String? = nil,
        redirectTargetRedacted: String? = nil,
        evidenceExcerpt: String? = nil,
        redactedErrorCode: String? = nil
    ) {
        self.id = id
        self.opportunityID = opportunityID
        self.url = url
        self.recordedAt = recordedAt
        self.outcome = outcome
        self.classification = classification
        self.reason = reason
        self.confidence = confidence
        self.evidence = evidence
        self.error = error
        self.reviewTaskID = reviewTaskID
        self.closureConfirmedAt = closureConfirmedAt
        self.legacyPostingCheckID = legacyPostingCheckID
        self.legacyStatus = legacyStatus
        self.checkOperationID = checkOperationID
        self.method = method
        self.checkerVersion = checkerVersion
        self.httpStatus = httpStatus
        self.mimeType = mimeType
        self.declaredBytes = declaredBytes
        self.receivedBytes = receivedBytes
        self.contentSHA256 = contentSHA256
        self.responseDate = responseDate
        self.lastModified = lastModified
        self.etag = etag
        self.retryAfter = retryAfter
        self.redirectTargetRedacted = redirectTargetRedacted
        self.evidenceExcerpt = evidenceExcerpt
        self.redactedErrorCode = redactedErrorCode
    }
}

enum ReconciliationCheckOperationState: String, Equatable {
    case started
    case completed
    case failed
    case cancelled
    case interrupted

    var isTerminal: Bool { self != .started }
}

struct ReconciliationCheckOperation: Equatable {
    let id: String
    let opportunityID: String
    let correlationID: String
    let urlSnapshot: String
    let state: ReconciliationCheckOperationState
    let startedAt: Date
    let terminalAt: Date?
}

struct BeginPublicURLCheck: Equatable {
    let operation: ReconciliationCheckOperation
    let isNew: Bool
}

struct PublicURLCheckCompletion: Equatable {
    let terminalState: ReconciliationCheckOperationState
    let outcome: ReconciliationOutcome
    let classification: ReconciliationClassification
    let reason: ReconciliationReason
    let confidence: ReconciliationConfidence?
    let evidence: String
    let error: String
    let method: String
    let checkerVersion: String
    let httpStatus: Int?
    let mimeType: String?
    let declaredBytes: Int?
    let receivedBytes: Int?
    let contentSHA256: String?
    let responseDate: String?
    let lastModified: String?
    let etag: String?
    let retryAfter: String?
    let redirectTargetRedacted: String?
    let evidenceExcerpt: String?
    let redactedErrorCode: String?

    init(
        terminalState: ReconciliationCheckOperationState,
        outcome: ReconciliationOutcome,
        classification: ReconciliationClassification,
        reason: ReconciliationReason = .manualReview,
        confidence: ReconciliationConfidence? = nil,
        evidence: String,
        error: String = "",
        method: String = "GET",
        checkerVersion: String = "1",
        httpStatus: Int? = nil,
        mimeType: String? = nil,
        declaredBytes: Int? = nil,
        receivedBytes: Int? = nil,
        contentSHA256: String? = nil,
        responseDate: String? = nil,
        lastModified: String? = nil,
        etag: String? = nil,
        retryAfter: String? = nil,
        redirectTargetRedacted: String? = nil,
        evidenceExcerpt: String? = nil,
        redactedErrorCode: String? = nil
    ) {
        self.terminalState = terminalState
        self.outcome = outcome
        self.classification = classification
        self.reason = reason
        self.confidence = confidence
        self.evidence = evidence
        self.error = error
        self.method = method
        self.checkerVersion = checkerVersion
        self.httpStatus = httpStatus
        self.mimeType = mimeType
        self.declaredBytes = declaredBytes
        self.receivedBytes = receivedBytes
        self.contentSHA256 = contentSHA256
        self.responseDate = responseDate
        self.lastModified = lastModified
        self.etag = etag
        self.retryAfter = retryAfter
        self.redirectTargetRedacted = redirectTargetRedacted
        self.evidenceExcerpt = evidenceExcerpt
        self.redactedErrorCode = redactedErrorCode
    }
}

struct RecordReconciliationResult {
    let opportunityID: String
    let url: String
    let outcome: ReconciliationOutcome
    let classification: ReconciliationClassification
    let reason: ReconciliationReason
    let confidence: ReconciliationConfidence?
    let evidence: String
    let error: String

    init(opportunityID: String, url: String, outcome: ReconciliationOutcome, classification: ReconciliationClassification, reason: ReconciliationReason = .manualReview, confidence: ReconciliationConfidence? = nil, evidence: String = "", error: String = "") {
        self.opportunityID = opportunityID
        self.url = url
        self.outcome = outcome
        self.classification = classification
        self.reason = reason
        self.confidence = confidence
        self.evidence = evidence
        self.error = error
    }
}

enum DocumentReferenceKind: String, CaseIterable, Equatable {
    case resume = "Résumé"
    case coverLetter = "Cover letter"
}

enum DocumentReferenceAvailability: String, Equatable {
    case available = "available"
    case relinkRequired = "relink_required"
}

nonisolated struct DocumentReferenceSummary: Equatable, Sendable {
    let availableCount: Int
    let relinkRequiredCount: Int
}

struct DocumentReference: Equatable {
    let id: String
    let opportunityID: String
    let kind: DocumentReferenceKind
    let filename: String
    let contentType: String
    let sourceHash: String
    let byteCount: Int
    let bookmarkData: Data?
    let availability: DocumentReferenceAvailability
    let attachedAt: Date
    let finalSentAt: Date?
}

struct RecordDocumentReference {
    let opportunityID: String
    let kind: DocumentReferenceKind
    let filename: String
    let contentType: String
    let sourceHash: String
    let byteCount: Int
    let bookmarkData: Data?

    init(opportunityID: String, kind: DocumentReferenceKind, filename: String, contentType: String, sourceHash: String, byteCount: Int, bookmarkData: Data? = nil) {
        self.opportunityID = opportunityID
        self.kind = kind
        self.filename = filename
        self.contentType = contentType
        self.sourceHash = sourceHash
        self.byteCount = byteCount
        self.bookmarkData = bookmarkData
    }
}

enum PipelineStage: String, CaseIterable, Equatable {
    case saved = "Saved"
    case applied = "Applied"
    case screening = "Screening"
    case interviewing = "Interviewing"
    case offer = "Offer"
    case closed = "Closed"
}

enum StageMoveStoreOutcome: Equatable {
    case persisted(PipelineStageMoveCommit)
    case noOp(opportunityID: String, stage: PipelineStage)
    case reconciliationBlocked(opportunityID: String, target: PipelineStage)
    case unavailable(opportunityID: String)
}

/// An internal, test-only transaction failure seam for the persisted stage-move
/// command. It is supplied through `WorkspaceStore` construction and is never
/// derived from workspace data or presentation state.
enum StageMoveFailurePoint: Equatable {
    case beforeWrite
    case beforeProjectionRead
}

struct PipelineStageMoveCommit: Equatable {
    let opportunityID: String
    let from: PipelineStage
    let to: PipelineStage
    let projection: PipelineStageMoveProjection
}

struct PipelineStageMoveProjection: Equatable {
    let opportunities: [Opportunity]
    let activityEvents: [ActivityEvent]
    let needsAttention: [TaskReminder]
    let stageHistoryForTransition: [StageHistoryEntry]
}

struct StageHistoryEntry: Equatable {
    let id: String
    let opportunityID: String
    let fromStage: PipelineStage?
    let toStage: PipelineStage
    let occurredAt: Date
}

struct TaskReminder: Equatable {
    let id: String
    let opportunityID: String
    let title: String
    let dueAt: Date?
    let isComplete: Bool
    /// Reconciliation review tasks are complete only through an explicit
    /// closure confirmation. The UI must not offer the ordinary complete
    /// command for these tasks.
    let requiresClosureConfirmation: Bool

    init(
        id: String,
        opportunityID: String,
        title: String,
        dueAt: Date?,
        isComplete: Bool,
        requiresClosureConfirmation: Bool = false
    ) {
        self.id = id
        self.opportunityID = opportunityID
        self.title = title
        self.dueAt = dueAt
        self.isComplete = isComplete
        self.requiresClosureConfirmation = requiresClosureConfirmation
    }
}

enum ContactEmailValidator {
    private static let maximumAddressByteCount = 254
    private static let maximumLocalPartByteCount = 64
    private static let maximumDomainByteCount = 253
    private static let maximumDomainLabelByteCount = 63

    static func isValid(_ value: String) -> Bool {
        guard !value.isEmpty else { return true }
        guard value.utf8.count <= maximumAddressByteCount else { return false }

        let parts = value.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return false }
        let localPart = parts[0]
        let domain = parts[1]
        guard !localPart.isEmpty,
              localPart.utf8.count <= maximumLocalPartByteCount,
              !localPart.hasPrefix("."),
              !localPart.hasSuffix("."),
              !localPart.contains(".."),
              localPart.unicodeScalars.allSatisfy(isAllowedLocalPartCharacter) else { return false }
        guard domain.utf8.count <= maximumDomainByteCount else { return false }

        let labels = domain.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2, labels.allSatisfy(isValidDomainLabel),
              let publicLabel = labels.last,
              publicLabel.unicodeScalars.allSatisfy(isASCIIAlpha) else { return false }
        return true
    }

    private static func isAllowedLocalPartCharacter(_ scalar: UnicodeScalar) -> Bool {
        switch scalar.value {
        case 43, 45, 46, 95:
            return true
        default:
            return isASCIIAlphanumeric(scalar)
        }
    }

    private static func isValidDomainLabel(_ label: Substring) -> Bool {
        guard !label.isEmpty, label.utf8.count <= maximumDomainLabelByteCount,
              let first = label.unicodeScalars.first,
              let last = label.unicodeScalars.last,
              isASCIIAlphanumeric(first), isASCIIAlphanumeric(last) else { return false }
        return label.unicodeScalars.allSatisfy { isASCIIAlphanumeric($0) || $0.value == 45 }
    }

    private static func isASCIIAlphanumeric(_ scalar: UnicodeScalar) -> Bool {
        isASCIIAlpha(scalar) || (48...57).contains(scalar.value)
    }

    private static func isASCIIAlpha(_ scalar: UnicodeScalar) -> Bool {
        (65...90).contains(scalar.value) || (97...122).contains(scalar.value)
    }
}

struct Contact: Equatable {
    let id: String
    let name: String
    let employer: String
    let title: String
    let workEmail: String
    let personalEmail: String
    let mobilePhone: String
    let officePhone: String
    let linkedInURL: String
    let instagramURL: String
    let facebookURL: String
    let relationshipContext: String
    let notes: String
}

struct CreateContact {
    let name: String
    let employer: String
    let title: String
    let workEmail: String
    let personalEmail: String
    let mobilePhone: String
    let officePhone: String
    let linkedInURL: String
    let instagramURL: String
    let facebookURL: String
    let relationshipContext: String
    let notes: String

    init(
        name: String,
        employer: String = "",
        title: String = "",
        workEmail: String = "",
        personalEmail: String = "",
        mobilePhone: String = "",
        officePhone: String = "",
        linkedInURL: String = "",
        instagramURL: String = "",
        facebookURL: String = "",
        relationshipContext: String = "",
        notes: String = ""
    ) {
        self.name = name
        self.employer = employer
        self.title = title
        self.workEmail = workEmail
        self.personalEmail = personalEmail
        self.mobilePhone = mobilePhone
        self.officePhone = officePhone
        self.linkedInURL = linkedInURL
        self.instagramURL = instagramURL
        self.facebookURL = facebookURL
        self.relationshipContext = relationshipContext
        self.notes = notes
    }
}

struct Interaction: Equatable {
    let id: String
    let opportunityID: String
    let summary: String
    let occurredAt: Date
}

enum InteractionKind: String, CaseIterable, Equatable {
    case call = "Call"
    case email = "Email"
    case meeting = "Meeting"
    case note = "Note"
}

struct ContactInteraction: Equatable {
    let id: String
    let contactID: String
    let opportunityID: String?
    let kind: InteractionKind
    let summary: String
    let occurredAt: Date
    let nextTouchAt: Date?
}

struct OpportunityInteraction: Equatable {
    let id: String
    let contactID: String?
    let contactName: String?
    let kind: InteractionKind
    let summary: String
    let occurredAt: Date
    let nextTouchAt: Date?
}

struct CreateContactInteraction {
    let contactID: String
    let opportunityID: String?
    let kind: InteractionKind
    let summary: String
    let occurredAt: Date
    let nextTouchAt: Date?

    init(contactID: String, opportunityID: String? = nil, kind: InteractionKind, summary: String, occurredAt: Date = .now, nextTouchAt: Date? = nil) {
        self.contactID = contactID
        self.opportunityID = opportunityID
        self.kind = kind
        self.summary = summary
        self.occurredAt = occurredAt
        self.nextTouchAt = nextTouchAt
    }
}

struct ActivityEvent: Equatable {
    let id: String
    let kind: String
    let opportunityID: String?
    let contactID: String?
    let actorID: String
    let correlationID: String
    let occurredAt: Date

    init(id: String, kind: String, opportunityID: String?, contactID: String? = nil, actorID: String, correlationID: String, occurredAt: Date) {
        self.id = id
        self.kind = kind
        self.opportunityID = opportunityID
        self.contactID = contactID
        self.actorID = actorID
        self.correlationID = correlationID
        self.occurredAt = occurredAt
    }
}

struct DeletionTombstone: Equatable {
    let subjectID: String
    let subjectType: String
    let deletedAt: Date
    let displayValue: String
}

struct CreateOpportunity: Equatable {
    let title: String
    let company: String
    let stage: PipelineStage
    let nextAction: String
    let dueAt: Date?
    let jobURL: String
    let jobDescription: String
    let notes: String
    let compensation: String?
    let compensationMinimum: Double?
    let compensationMaximum: Double?
    let compensationPayPeriod: CompensationPayPeriod?
    let location: String?
    let workArrangement: WorkArrangement
    let applicationDate: Date?
    let responseState: ResponseState
    let responseEffectiveDate: Date?
    let stageChangedAt: Date?
    let actionType: OpportunityActionType?
    let actionCustomText: String?

    init(title: String, company: String, stage: PipelineStage = .saved, nextAction: String = "", dueAt: Date? = nil, jobURL: String = "", jobDescription: String = "", notes: String = "", compensation: String? = nil, compensationMinimum: Double? = nil, compensationMaximum: Double? = nil, compensationPayPeriod: CompensationPayPeriod? = nil, location: String? = nil, workArrangement: WorkArrangement = .notSpecified, applicationDate: Date? = nil, responseState: ResponseState = .noResponseRecorded, responseEffectiveDate: Date? = nil, stageChangedAt: Date? = nil, actionType: OpportunityActionType? = nil, actionCustomText: String? = nil) {
        self.title = title
        self.company = company
        self.stage = stage
        self.nextAction = nextAction
        self.dueAt = dueAt
        self.jobURL = jobURL
        self.jobDescription = jobDescription
        self.notes = notes
        self.compensation = compensation
        self.compensationMinimum = compensationMinimum
        self.compensationMaximum = compensationMaximum
        self.compensationPayPeriod = compensationPayPeriod
        self.location = location
        self.workArrangement = workArrangement
        self.applicationDate = applicationDate
        self.responseState = responseState
        self.responseEffectiveDate = responseEffectiveDate
        self.stageChangedAt = stageChangedAt
        self.actionType = actionType
        self.actionCustomText = actionCustomText
    }
}

enum OpportunityCSVExport {
    static func render(_ opportunities: [Opportunity]) -> String {
        let header = ["title", "company", "stage", "next_action", "due_at", "job_url"]
        let rows = opportunities.map { opportunity in
            [
                opportunity.title,
                opportunity.company,
                opportunity.stage.rawValue,
                opportunity.nextAction,
                opportunity.dueAt?.ISO8601Format() ?? "",
                opportunity.jobURL
            ]
        }
        return ([header] + rows).map { $0.map(escape).joined(separator: ",") }.joined(separator: "\n") + "\n"
    }

    private static func escape(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}

enum WorkspaceStoreError: Error, LocalizedError {
    case invalidOpportunity
    case invalidOpportunityURL
    case invalidCompensation
    case injectedFailure
    case unexpectedDatabaseValue
    case unresolvedImportDecision
    case invalidContact
    case invalidContactWorkEmail
    case invalidContactPersonalEmail
    case invalidContactSocialURL
    case invalidInteraction
    case invalidReconciliationResult
    case closureNotConfirmed
    case reconciliationTaskRequiresClosure
    case invalidDocumentReference
    case invalidPublicURLCheck
    case recoveryAlreadyEnrolled

    var errorDescription: String? {
        switch self {
        case .invalidOpportunity:
            return "Enter a job title and company."
        case .invalidOpportunityURL:
            return "Enter an absolute http or https job URL with a host."
        case .invalidCompensation:
            return "Compensation amounts must be non-negative, and the minimum cannot exceed the maximum."
        case .recoveryAlreadyEnrolled:
            return "A recovery key is already enrolled and cannot be reset."
        case .injectedFailure:
            return "The opportunity could not be saved."
        case .unexpectedDatabaseValue:
            return "The workspace contains unreadable data."
        case .unresolvedImportDecision:
            return "Choose Skip or Keep separate for each duplicate CSV row."
        case .invalidContact:
            return "Enter a contact name."
        case .invalidContactWorkEmail:
            return "Enter a work email address with a local part, @, and domain."
        case .invalidContactPersonalEmail:
            return "Enter a personal email address with a local part, @, and domain."
        case .invalidContactSocialURL:
            return "Enter an absolute http or https social profile URL with a public hostname."
        case .invalidInteraction:
            return "Enter an interaction summary and choose a valid linked opportunity."
        case .invalidReconciliationResult:
            return "Enter a valid public posting URL and the required local review detail."
        case .closureNotConfirmed:
            return "Record a Closed suggested result before confirming closure."
        case .reconciliationTaskRequiresClosure:
            return "A reconciliation review action is completed only when you explicitly confirm a recorded closure."
        case .invalidDocumentReference:
            return "Choose a PDF or DOCX file to attach as a local reference."
        case .invalidPublicURLCheck:
            return "The public URL check could not be recorded safely."
        }
    }
}
