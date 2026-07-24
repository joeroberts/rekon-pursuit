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

struct TaskReminder: Equatable {
    let id: String
    let opportunityID: String
    let title: String
    let dueAt: Date
    let isComplete: Bool
}

struct Contact: Equatable {
    let id: String
    let name: String
    let employer: String
}

struct CreateContact {
    let name: String
    let employer: String
}

struct ActivityEvent: Equatable {
    let id: String
    let kind: String
    let opportunityID: String
    let actorID: String
    let correlationID: String
    let occurredAt: Date
}

struct CreateOpportunity {
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

    var errorDescription: String? {
        switch self {
        case .invalidOpportunity:
            return "Enter a job title and company."
        case .injectedFailure:
            return "The opportunity could not be saved."
        case .unexpectedDatabaseValue:
            return "The workspace contains unreadable data."
        }
    }
}
