import Foundation

struct AIUsageLedgerFilter: Equatable {
    enum Time: String, CaseIterable, Equatable {
        case allTime
        case last24Hours
        case last7Days
        case thisMonth

        var label: String {
            switch self {
            case .allTime: "All time"
            case .last24Hours: "Last 24 hours"
            case .last7Days: "Last 7 days"
            case .thisMonth: "This month"
            }
        }
    }

    enum Route: String, CaseIterable, Equatable {
        case any
        case local
        case sanitizedCloud
        case fullCloud

        var label: String {
            switch self {
            case .any: "Any route"
            case .local: "Local"
            case .sanitizedCloud: "Sanitized cloud"
            case .fullCloud: "Full cloud"
            }
        }
    }

    enum Completion: String, CaseIterable, Equatable {
        case any
        case completed
        case failed
        case cancelled
        case blocked

        var label: String {
            switch self {
            case .any: "Any completion"
            case .completed: "Completed"
            case .failed: "Failed"
            case .cancelled: "Cancelled"
            case .blocked: "Blocked"
            }
        }
    }

    var time: Time = .allTime
    var featureQuery = ""
    var opportunityID: String?
    var route: Route = .any
    var modelQuery = ""
    var completion: Completion = .any
    var minimumCostUSD = ""
    var maximumCostUSD = ""

    var isDefault: Bool {
        time == .allTime &&
            featureQuery.isEmpty &&
            opportunityID == nil &&
            route == .any &&
            modelQuery.isEmpty &&
            completion == .any &&
            minimumCostUSD.isEmpty &&
            maximumCostUSD.isEmpty
    }

    mutating func reset() {
        self = Self()
    }

    var costRangeValidationMessage: String? {
        let minimum = parseCost(minimumCostUSD)
        let maximum = parseCost(maximumCostUSD)

        if minimumCostUSD.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false, minimum == nil {
            return "Enter a valid USD amount."
        }
        if maximumCostUSD.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false, maximum == nil {
            return "Enter a valid USD amount."
        }
        if (minimum ?? 0) < 0 || (maximum ?? 0) < 0 {
            return "Cost values must be non-negative USD amounts."
        }
        if let minimum, let maximum, minimum > maximum {
            return "Minimum cost cannot exceed maximum cost."
        }
        return nil
    }

    private func parseCost(_ rawValue: String) -> Double? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false, let value = Double(trimmed), value.isFinite else {
            return nil
        }
        return value
    }
}
