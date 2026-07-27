import CryptoKit
import Foundation
import Security

struct RecoveryKey: Equatable {
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
}

struct Contact: Equatable {
    let id: String
    let name: String
    let employer: String
    let title: String
    let email: String
    let profileURL: String
    let relationshipContext: String
    let notes: String
}

struct CreateContact {
    let name: String
    let employer: String
    let title: String
    let email: String
    let profileURL: String
    let relationshipContext: String
    let notes: String

    init(name: String, employer: String = "", title: String = "", email: String = "", profileURL: String = "", relationshipContext: String = "", notes: String = "") {
        self.name = name
        self.employer = employer
        self.title = title
        self.email = email
        self.profileURL = profileURL
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
    case invalidContactEmail
    case invalidContactProfileURL
    case invalidInteraction
    case invalidReconciliationResult
    case closureNotConfirmed
    case reconciliationTaskRequiresClosure
    case invalidDocumentReference
    case invalidPublicURLCheck

    var errorDescription: String? {
        switch self {
        case .invalidOpportunity:
            return "Enter a job title and company."
        case .invalidOpportunityURL:
            return "Enter an absolute http or https job URL with a host."
        case .invalidCompensation:
            return "Compensation amounts must be non-negative, and the minimum cannot exceed the maximum."
        case .injectedFailure:
            return "The opportunity could not be saved."
        case .unexpectedDatabaseValue:
            return "The workspace contains unreadable data."
        case .unresolvedImportDecision:
            return "Choose Skip or Keep separate for each duplicate CSV row."
        case .invalidContact:
            return "Enter a contact name."
        case .invalidContactEmail:
            return "Enter an email address with a local part, @, and domain."
        case .invalidContactProfileURL:
            return "Enter an absolute http or https profile URL with a public hostname."
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
