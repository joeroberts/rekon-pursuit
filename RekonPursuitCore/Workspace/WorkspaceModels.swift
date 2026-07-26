import Foundation

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
    let location: String?
    let workArrangement: WorkArrangement
    let applicationDate: Date?
    let responseState: ResponseState
    let stageChangedAt: Date?

    init(id: String, title: String, company: String, createdAt: Date, stage: PipelineStage = .saved, nextAction: String = "", dueAt: Date? = nil, jobURL: String = "", jobDescription: String = "", notes: String = "", compensation: String? = nil, location: String? = nil, workArrangement: WorkArrangement = .notSpecified, applicationDate: Date? = nil, responseState: ResponseState = .noResponseRecorded, stageChangedAt: Date? = nil) {
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
        self.location = location
        self.workArrangement = workArrangement
        self.applicationDate = applicationDate
        self.responseState = responseState
        self.stageChangedAt = stageChangedAt
    }
}

enum WorkArrangement: String, CaseIterable, Equatable {
    case notSpecified = "Not specified"
    case onSite = "On-site"
    case hybrid = "Hybrid"
    case remote = "Remote"
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

struct DocumentReference: Equatable {
    let id: String
    let opportunityID: String
    let kind: DocumentReferenceKind
    let filename: String
    let contentType: String
    let sourceHash: String
    let byteCount: Int
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
    let location: String?
    let workArrangement: WorkArrangement
    let applicationDate: Date?
    let responseState: ResponseState
    let responseEffectiveDate: Date?
    let stageChangedAt: Date?

    init(title: String, company: String, stage: PipelineStage = .saved, nextAction: String = "", dueAt: Date? = nil, jobURL: String = "", jobDescription: String = "", notes: String = "", compensation: String? = nil, location: String? = nil, workArrangement: WorkArrangement = .notSpecified, applicationDate: Date? = nil, responseState: ResponseState = .noResponseRecorded, responseEffectiveDate: Date? = nil, stageChangedAt: Date? = nil) {
        self.title = title
        self.company = company
        self.stage = stage
        self.nextAction = nextAction
        self.dueAt = dueAt
        self.jobURL = jobURL
        self.jobDescription = jobDescription
        self.notes = notes
        self.compensation = compensation
        self.location = location
        self.workArrangement = workArrangement
        self.applicationDate = applicationDate
        self.responseState = responseState
        self.responseEffectiveDate = responseEffectiveDate
        self.stageChangedAt = stageChangedAt
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
    case injectedFailure
    case unexpectedDatabaseValue
    case unresolvedImportDecision
    case invalidContact
    case invalidInteraction
    case invalidReconciliationResult
    case closureNotConfirmed
    case reconciliationTaskRequiresClosure
    case invalidDocumentReference

    var errorDescription: String? {
        switch self {
        case .invalidOpportunity:
            return "Enter a job title and company."
        case .injectedFailure:
            return "The opportunity could not be saved."
        case .unexpectedDatabaseValue:
            return "The workspace contains unreadable data."
        case .unresolvedImportDecision:
            return "Choose Skip or Keep separate for each duplicate CSV row."
        case .invalidContact:
            return "Enter a contact name."
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
        }
    }
}
