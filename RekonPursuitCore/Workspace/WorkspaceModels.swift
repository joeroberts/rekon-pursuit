import Foundation

struct Opportunity: Equatable {
    let id: String
    let title: String
    let company: String
    let createdAt: Date
    let stage: PipelineStage
    let nextAction: String
    let dueAt: Date?

    init(id: String, title: String, company: String, createdAt: Date, stage: PipelineStage = .saved, nextAction: String = "", dueAt: Date? = nil) {
        self.id = id
        self.title = title
        self.company = company
        self.createdAt = createdAt
        self.stage = stage
        self.nextAction = nextAction
        self.dueAt = dueAt
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

    init(title: String, company: String, stage: PipelineStage = .saved, nextAction: String = "", dueAt: Date? = nil) {
        self.title = title
        self.company = company
        self.stage = stage
        self.nextAction = nextAction
        self.dueAt = dueAt
    }
}

enum WorkspaceStoreError: Error, LocalizedError {
    case invalidOpportunity
    case injectedFailure
    case unexpectedDatabaseValue
    case unresolvedImportDecision
    case invalidContact
    case invalidInteraction

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
        }
    }
}
