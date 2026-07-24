import Combine
import Foundation

@MainActor
final class WorkspaceViewModel: ObservableObject {
    @Published var title = ""
    @Published var company = ""
    @Published var stage: PipelineStage = .saved
    @Published var nextAction = ""
    @Published var dueAt = Date.now
    @Published private(set) var opportunityCount = 0
    @Published private(set) var activityCount = 0
    @Published private(set) var needsAttentionCount = 0
    @Published private(set) var needsAttention: [TaskReminder] = []
    @Published private(set) var opportunities: [Opportunity] = []
    @Published var contactName = ""
    @Published var contactEmployer = ""
    @Published private(set) var contacts: [Contact] = []
    @Published private(set) var csvPreview: CSVImportPreview?
    @Published private(set) var statusMessage = "Opening local workspace…"
    @Published private(set) var canCreateWorkspace = false

    private let openWorkspace: () throws -> WorkspaceOpenState
    private let createWorkspace: () throws -> WorkspaceStore
    private var store: WorkspaceStore?

    init(
        openWorkspace: @escaping () throws -> WorkspaceOpenState,
        createWorkspace: @escaping () throws -> WorkspaceStore
    ) {
        self.openWorkspace = openWorkspace
        self.createWorkspace = createWorkspace
    }

    convenience init() {
        let session = WorkspaceSession(root: Self.defaultWorkspaceRoot())
        self.init(openWorkspace: session.open, createWorkspace: session.create)
    }

    func start() {
        do {
            apply(try openWorkspace())
        } catch {
            statusMessage = "The local workspace could not be opened."
        }
    }

    func createWorkspaceIfNeeded() {
        do {
            store = try createWorkspace()
            refreshCounts()
            statusMessage = "Local workspace created."
            canCreateWorkspace = false
        } catch {
            statusMessage = "The local workspace could not be created."
        }
    }

    func createOpportunity() {
        guard let store else {
            statusMessage = "Create or reopen the local workspace first."
            return
        }
        do {
            _ = try store.create(CreateOpportunity(title: title, company: company, stage: stage, nextAction: nextAction, dueAt: nextAction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : dueAt))
            title = ""
            company = ""
            nextAction = ""
            refreshCounts()
            statusMessage = "Saved locally."
        } catch let error as LocalizedError {
            statusMessage = error.errorDescription ?? "The opportunity could not be saved."
        } catch {
            statusMessage = "The opportunity could not be saved."
        }
    }

    func complete(_ task: TaskReminder) {
        do {
            try store?.completeTask(id: task.id)
            refreshCounts()
            statusMessage = "Action completed locally."
        } catch {
            statusMessage = "The action could not be completed."
        }
    }

    func snoozeOneDay(_ task: TaskReminder) {
        do {
            try store?.rescheduleTask(id: task.id, dueAt: task.dueAt.addingTimeInterval(86_400))
            refreshCounts()
            statusMessage = "Action snoozed for one day."
        } catch {
            statusMessage = "The action could not be rescheduled."
        }
    }

    func changeStage(_ opportunity: Opportunity, to stage: PipelineStage) {
        do {
            try store?.changeStage(opportunityID: opportunity.id, to: stage)
            refreshCounts()
            statusMessage = "Stage updated locally."
        } catch {
            statusMessage = "The stage could not be updated."
        }
    }

    func createContact() {
        do {
            _ = try store?.createContact(CreateContact(name: contactName, employer: contactEmployer))
            contactName = ""
            contactEmployer = ""
            refreshCounts()
            statusMessage = "Contact saved locally."
        } catch let error as LocalizedError {
            statusMessage = error.errorDescription ?? "The contact could not be saved."
        } catch {
            statusMessage = "The contact could not be saved."
        }
    }

    func previewCSV(at url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do {
            csvPreview = try CSVOpportunityImporter.preview(data: Data(contentsOf: url))
            statusMessage = "CSV preview ready. Review before importing."
        } catch {
            csvPreview = nil
            statusMessage = "The CSV file could not be read. It needs title and company columns."
        }
    }

    func importCSVPreview() {
        guard let preview = csvPreview, let store else { return }
        do {
            var seen = Set(try store.opportunities().map { "\($0.title.lowercased())\u{1F}\($0.company.lowercased())" })
            for row in preview.validRows {
                let key = "\(row.title.lowercased())\u{1F}\(row.company.lowercased())"
                guard seen.insert(key).inserted else { continue }
                _ = try store.create(row)
            }
            csvPreview = nil
            refreshCounts()
            statusMessage = "CSV rows imported locally. Existing matching opportunities were left unchanged."
        } catch {
            statusMessage = "The CSV rows could not be imported."
        }
    }

    private func apply(_ state: WorkspaceOpenState) {
        switch state {
        case let .ready(store):
            self.store = store
            refreshCounts()
            statusMessage = "Local workspace ready."
            canCreateWorkspace = false
        case .missingKey:
            statusMessage = "Workspace key is unavailable. Create a new local workspace only if you intend to start over."
            canCreateWorkspace = true
        case .locked:
            statusMessage = "Unlock your Mac to reopen the local workspace."
            canCreateWorkspace = false
        case .denied:
            statusMessage = "Keychain access was denied. Allow access to reopen the local workspace."
            canCreateWorkspace = false
        case .unavailable:
            statusMessage = "The local workspace could not be opened."
            canCreateWorkspace = false
        }
    }

    private func refreshCounts() {
        do {
            opportunityCount = try store?.opportunities().count ?? 0
            opportunities = try store?.opportunities() ?? []
            contacts = try store?.contacts() ?? []
            activityCount = try store?.activityEvents().count ?? 0
            needsAttention = try store?.needsAttention() ?? []
            needsAttentionCount = needsAttention.count
        } catch {
            statusMessage = "The local workspace could not be read."
        }
    }

    private static func defaultWorkspaceRoot() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RekonLabs", isDirectory: true)
            .appendingPathComponent("RekonPursuit", isDirectory: true)
    }
}
