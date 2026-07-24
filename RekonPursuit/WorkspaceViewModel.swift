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
            activityCount = try store?.activityEvents().count ?? 0
            needsAttentionCount = try store?.needsAttention().count ?? 0
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
