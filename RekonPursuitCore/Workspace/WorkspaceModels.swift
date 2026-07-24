import Foundation

struct Opportunity: Equatable {
    let id: String
    let title: String
    let company: String
    let createdAt: Date
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
