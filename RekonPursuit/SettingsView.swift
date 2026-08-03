import Foundation
import SwiftUI

private enum SettingsSection: CaseIterable, Hashable {
    case workspace
    case recoveryArchives
    case documentReferences
    case aiConnections

    var title: String {
        switch self {
        case .workspace: return "Workspace"
        case .recoveryArchives: return "Recovery & archives"
        case .documentReferences: return "Document references"
        case .aiConnections: return "AI & connections"
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .workspace: return "settings-section-workspace"
        case .recoveryArchives: return "settings-section-recovery-archives"
        case .documentReferences: return "settings-section-document-references"
        case .aiConnections: return "settings-section-ai-connections"
        }
    }
}

struct SettingsArchiveSummary: Identifiable, Equatable {
    let id: UUID
    let text: String
    let accessibilityValue: String

    init(archive: PortableArchiveCatalogueRow) {
        id = archive.archiveID
        text = SettingsArchiveSummary.makeText(archive)
        accessibilityValue = SettingsArchiveSummary.makeAccessibilityValue(archive)
    }

    private static func lifecycleText(_ archive: PortableArchiveCatalogueRow) -> String {
        switch archive.lifecycleState {
        case .verified: return archive.verificationState
        case .expiredPendingRemoval, .expiredPrepared: return "Expired — removal pending"
        case .expiredRetryable: return "Expired — retry pending"
        case .expiredBlocked: return "Expired — removal blocked"
        case .expiredMissing: return "Expired — file unavailable"
        case .expiredManualRemovalRequired: return "Expired — manual removal required"
        case .expiredQuarantined: return "Expired — quarantined"
        }
    }

    private static func makeText(_ archive: PortableArchiveCatalogueRow) -> String {
        "\(archive.displayFilename) · created \(archive.createdAt.formatted(date: .abbreviated, time: .shortened)) · expires \(archive.expiresAt.formatted(date: .abbreviated, time: .omitted)) · \(lifecycleText(archive))"
    }

    private static func makeAccessibilityValue(_ archive: PortableArchiveCatalogueRow) -> String {
        let formatter = ISO8601DateFormatter()
        return "created=\(formatter.string(from: archive.createdAt));expires=\(formatter.string(from: archive.expiresAt));lifecycle=\(lifecycleText(archive))"
    }
}

struct SettingsRecoveryPresentation: Equatable {
    let recoveryEnrollmentEnabled: Bool
    let archiveSummaries: [SettingsArchiveSummary]
    let isCreatingPortableArchive: Bool
    let isCreatingProtectedExport: Bool
    let isPurgingRetainedArchiveData: Bool
    let isRestoringPortableArchive: Bool
    let restoreProgressText: String?
    let retainedDataPurgeStatusText: String?
    let restoreReady: Bool

    var createPortableArchiveIsDisabled: Bool {
        isCreatingPortableArchive || isRestoringPortableArchive
    }

    var protectedExportIsDisabled: Bool {
        isCreatingProtectedExport || isCreatingPortableArchive || isRestoringPortableArchive
    }

    var retainedDataPurgeIsDisabled: Bool {
        archiveSummaries.isEmpty || isPurgingRetainedArchiveData || isCreatingPortableArchive || isRestoringPortableArchive
    }

    var portableArchiveRestoreIsDisabled: Bool {
        isCreatingPortableArchive || isRestoringPortableArchive
    }

    var archiveProgressText: String? {
        isCreatingPortableArchive ? "Creating and verifying archive…" : nil
    }

    var protectedExportProgressText: String? {
        isCreatingProtectedExport ? "Preparing protected export…" : nil
    }

    var retainedDataPurgeProgressText: String? {
        isPurgingRetainedArchiveData ? "Purging retained archive data…" : nil
    }

    var inactiveRestoreCandidateText: String? {
        restoreReady ? "Restored workspace ready. It remains inactive; a future workspace-open action is required." : nil
    }

    var recoveryEnrollmentStatusText: String {
        recoveryEnrollmentEnabled ? "Recovery key enrolled" : "Recovery key not set up"
    }

    var recoveryArchiveStatusText: String {
        guard recoveryEnrollmentEnabled else {
            return "Set up a recovery key to protect this workspace."
        }
        return archiveSummaries.isEmpty ? "No verified archive available" : "Verified archive available"
    }
}

struct SettingsRootModalPresentation: Equatable {
    let portableArchiveRestoreState: PortableArchiveRestoreState
    let protectedExportErrorMessage: String?
    let protectedExportSuccess: ProtectedExportSuccess?

    init(
        portableArchiveRestoreState: PortableArchiveRestoreState,
        protectedExportErrorMessage: String?,
        protectedExportSuccess: ProtectedExportSuccess? = nil
    ) {
        self.portableArchiveRestoreState = portableArchiveRestoreState
        self.protectedExportErrorMessage = protectedExportErrorMessage
        self.protectedExportSuccess = protectedExportSuccess
    }

    var isPortableArchiveRestoreSheetPresented: Bool {
        switch portableArchiveRestoreState {
        case .awaitingRecoveryKey, .verifying, .awaitingConfirmation, .restoring:
            true
        case .idle, .ready, .failed:
            false
        }
    }

    var isPortableArchiveRestoreFailureAlertPresented: Bool {
        if case .failed = portableArchiveRestoreState { return true }
        return false
    }

    var portableArchiveRestoreFailureMessage: String? {
        if case let .failed(failure) = portableArchiveRestoreState { return failure.message }
        return nil
    }

    var isProtectedExportSuccessPresented: Bool {
        protectedExportSuccess != nil
    }

    var protectedExportSuccessDisplayFilename: String? {
        protectedExportSuccess?.displayFilename
    }

    var protectedExportSuccessDestinationLabel: String {
        "Selected local folder"
    }
}

enum SettingsRootModalBindings {
    static func dismissPortableArchiveRestore(
        clearRestoreEntry: () -> Void,
        cancelPortableArchiveRestore: () -> Void
    ) {
        clearRestoreEntry()
        cancelPortableArchiveRestore()
    }

    static func dismissPortableArchiveRestoreFailure(
        dismissPortableArchiveRestoreFailure: () -> Void
    ) {
        dismissPortableArchiveRestoreFailure()
    }

    static func dismissProtectedExportSuccess(
        dismissProtectedExportSuccess: () -> Void
    ) {
        dismissProtectedExportSuccess()
    }
}

struct SettingsView: View {
    let usingSeparateLocalWorkspace: Bool
    let recovery: SettingsRecoveryPresentation
    let documentReferenceSummary: DocumentReferenceSummary
    let returnToPreservedWorkspaceRecovery: () -> Void
    let beginRecoveryKeyEnrollment: () -> Void
    let presentArchiveCreation: () -> Void
    let presentProtectedExport: () -> Void
    let presentRetainedDataPurge: () -> Void
    let cancelRetainedDataPurge: () -> Void
    let choosePortableArchiveForRestore: () -> Void
    @State private var selectedSection: SettingsSection = .recoveryArchives
    @FocusState private var focusedSection: SettingsSection?

    private func selectorAccessibilityValue(for section: SettingsSection) -> String {
        let selection = selectedSection == section ? "Selected" : "Not selected"
        return focusedSection == section ? "\(selection); Keyboard focus" : selection
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RekonTheme.Spacing.section) {
                Text("Settings")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(RekonTheme.primaryText)

                settingsNavigation
                selectedSectionContent
            }
            .padding(RekonTheme.Spacing.screen)
            .frame(maxWidth: 1_280, alignment: .leading)
        }
    }

    private var settingsNavigation: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .bottom, spacing: 0) {
                        sectionSelector(.workspace, isCompact: false)
                        sectionSelector(.recoveryArchives, isCompact: false)
                        sectionSelector(.documentReferences, isCompact: false)
                        sectionSelector(.aiConnections, isCompact: false)
                    }
                    VStack(alignment: .leading, spacing: RekonTheme.Spacing.micro) {
                        sectionSelector(.workspace, isCompact: true)
                        sectionSelector(.recoveryArchives, isCompact: true)
                        sectionSelector(.documentReferences, isCompact: true)
                        sectionSelector(.aiConnections, isCompact: true)
                    }
                }
                Divider()
                    .overlay(RekonTheme.borderSubtle)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("settings-reference-tab-strip")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings-secondary-navigation")
    }

    @ViewBuilder private func sectionSelector(_ section: SettingsSection, isCompact: Bool) -> some View {
        SettingsReferenceTab(
            title: section.title,
            symbol: section.symbol,
            isSelected: selectedSection == section,
            isCompact: isCompact,
            referenceAccessibilityIdentifier: section == .recoveryArchives ? section.referenceAccessibilityIdentifier : nil
        ) {
            selectedSection = section
        }
        .focusable()
        .focused($focusedSection, equals: section)
        .onKeyPress(.space) {
            selectedSection = section
            return .handled
        }
        .focusEffectDisabled(true)
        .accessibilityLabel(section.title)
        .accessibilityValue(selectorAccessibilityValue(for: section))
        .accessibilityIdentifier(section.accessibilityIdentifier)
        .accessibilityAddTraits(selectedSection == section ? .isSelected : [])
    }

    @ViewBuilder private var selectedSectionContent: some View {
        switch selectedSection {
        case .workspace:
            WorkspaceSettingsSection(
                usingSeparateLocalWorkspace: usingSeparateLocalWorkspace,
                returnToPreservedWorkspaceRecovery: returnToPreservedWorkspaceRecovery
            )
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("settings-section-workspace-panel")
        case .recoveryArchives:
            RecoveryArchivesSettingsSection(
                recovery: recovery,
                beginRecoveryKeyEnrollment: beginRecoveryKeyEnrollment,
                presentArchiveCreation: presentArchiveCreation,
                presentProtectedExport: presentProtectedExport,
                presentRetainedDataPurge: presentRetainedDataPurge,
                cancelRetainedDataPurge: cancelRetainedDataPurge,
                choosePortableArchiveForRestore: choosePortableArchiveForRestore
            )
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("settings-section-recovery-archives-panel")
        case .documentReferences:
            DocumentReferencesSettingsSection(summary: documentReferenceSummary)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("settings-section-document-references-panel")
        case .aiConnections:
            AIConnectionsSettingsSection()
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("settings-section-ai-connections-panel")
        }
    }
}

private extension SettingsSection {
    var symbol: String {
        switch self {
        case .workspace: "folder"
        case .recoveryArchives: "externaldrive"
        case .documentReferences: "doc"
        case .aiConnections: "link"
        }
    }

    var referenceAccessibilityIdentifier: String {
        switch self {
        case .recoveryArchives: "settings-reference-tab-recovery-archives"
        default: accessibilityIdentifier
        }
    }
}

private struct SettingsReferenceTab: View {
    let title: String
    let symbol: String
    let isSelected: Bool
    let isCompact: Bool
    let referenceAccessibilityIdentifier: String?
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            VStack(alignment: .leading, spacing: RekonTheme.Spacing.tight) {
                HStack(spacing: RekonTheme.Spacing.compact) {
                    Image(systemName: symbol)
                        .font(.title3.weight(.medium))
                    if let referenceAccessibilityIdentifier {
                        Text(title)
                            .font(.body.weight(.medium))
                            .lineLimit(1)
                            .accessibilityIdentifier(referenceAccessibilityIdentifier)
                    } else {
                        Text(title)
                            .font(.body.weight(.medium))
                            .lineLimit(1)
                    }
                }
                if !isCompact {
                    Rectangle()
                        .fill(isSelected ? RekonTheme.accent : .clear)
                        .frame(height: 2)
                }
            }
            .foregroundStyle(isSelected ? RekonTheme.accent : RekonTheme.secondaryText)
            .padding(.horizontal, isCompact ? RekonTheme.Spacing.compact : 0)
            .frame(
                minWidth: isCompact ? nil : 156,
                maxWidth: isCompact ? .infinity : nil,
                minHeight: 54,
                alignment: .leading
            )
            .background(
                isCompact && isSelected ? RekonTheme.accent.opacity(0.14) : .clear,
                in: RoundedRectangle(cornerRadius: RekonTheme.Radius.control)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsHeroCard: View {
    let symbol: String
    let symbolColor: Color
    let title: String
    let subtitle: String?
    let facts: [(String, String)]
    let accessibilityIdentifier: String
    let accessibilityLabel: String

    var body: some View {
        RekonCard {
            HStack(alignment: .center, spacing: RekonTheme.Spacing.section) {
                Image(systemName: symbol)
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(symbolColor)
                    .frame(width: 112, height: 112)
                    .background(symbolColor.opacity(0.08), in: Circle())
                    .overlay(Circle().stroke(symbolColor.opacity(0.85), lineWidth: 1))
                VStack(alignment: .leading, spacing: RekonTheme.Spacing.compact) {
                    Text(title)
                        .font(.title.bold())
                        .foregroundStyle(RekonTheme.primaryText)
                    if let subtitle {
                        Text(subtitle)
                            .foregroundStyle(RekonTheme.secondaryText)
                    }
                    HStack(alignment: .top, spacing: 64) {
                        ForEach(Array(facts.enumerated()), id: \.offset) { _, fact in
                            VStack(alignment: .leading, spacing: RekonTheme.Spacing.micro) {
                                Text(fact.0)
                                    .foregroundStyle(RekonTheme.secondaryText)
                                Text(fact.1)
                                    .font(.title3.weight(.medium))
                                    .foregroundStyle(RekonTheme.primaryText)
                            }
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private struct SettingsInfoCard: View {
    let symbol: String
    let color: Color
    let title: String
    let detail: String
    let accessibilityIdentifier: String
    let accessibilityLabel: String
    let accessibilityValue: String?

    init(
        symbol: String,
        color: Color,
        title: String,
        detail: String,
        accessibilityIdentifier: String,
        accessibilityLabel: String,
        accessibilityValue: String? = nil
    ) {
        self.symbol = symbol
        self.color = color
        self.title = title
        self.detail = detail
        self.accessibilityIdentifier = accessibilityIdentifier
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityValue = accessibilityValue
    }

    var body: some View {
        RekonCard {
            HStack(alignment: .center, spacing: RekonTheme.Spacing.compact) {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(color)
                    .frame(width: 42)
                VStack(alignment: .leading, spacing: RekonTheme.Spacing.micro) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(RekonTheme.primaryText)
                    Text(detail)
                        .foregroundStyle(RekonTheme.secondaryText)
                }
                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue ?? "")
        .accessibilityIdentifier(accessibilityIdentifier)
        .accessibilityRepresentation {
            Text(accessibilityLabel)
                .accessibilityValue(accessibilityValue ?? "")
                .accessibilityIdentifier(accessibilityIdentifier)
        }
    }
}

private struct WorkspaceSettingsSection: View {
    let usingSeparateLocalWorkspace: Bool
    let returnToPreservedWorkspaceRecovery: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: RekonTheme.Spacing.section) {
            SettingsHeroCard(
                symbol: "folder",
                symbolColor: RekonTheme.accent,
                title: "Local workspace",
                subtitle: nil,
                facts: [("Workspace status", "Active"), ("Storage", "Local only")],
                accessibilityIdentifier: "settings-workspace-overview-card",
                accessibilityLabel: "Local workspace, Workspace status, Active, Storage, Local only"
            )

            SettingsInfoCard(
                symbol: "shield.checkered",
                color: RekonTheme.secondaryText,
                title: "Workspace recovery",
                detail: "Returning does not modify the active workspace.",
                accessibilityIdentifier: "settings-workspace-recovery-card",
                accessibilityLabel: "Workspace recovery, Returning does not modify the active workspace."
            )

            if usingSeparateLocalWorkspace {
                RekonCard {
                    HStack(alignment: .center, spacing: RekonTheme.Spacing.compact) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.title2)
                            .foregroundStyle(RekonTheme.accent)
                            .frame(width: 42)
                        VStack(alignment: .leading, spacing: RekonTheme.Spacing.micro) {
                            Text("Return to preserved workspace")
                                .font(.headline)
                                .foregroundStyle(RekonTheme.primaryText)
                            Text("Your preserved workspace remains unchanged.")
                                .foregroundStyle(RekonTheme.secondaryText)
                        }
                        Spacer()
                        Button("Return", action: returnToPreservedWorkspaceRecovery)
                            .buttonStyle(RekonPrimaryButtonStyle())
                            .accessibilityIdentifier("return-to-preserved-workspace-recovery")
                    }
                }
                .accessibilityIdentifier("settings-workspace-return-card")
            } else {
                SettingsInfoCard(
                    symbol: "arrow.uturn.backward",
                    color: RekonTheme.secondaryText.opacity(0.5),
                    title: "Return to preserved workspace",
                    detail: "No preserved workspace is available to return to.",
                    accessibilityIdentifier: "settings-workspace-return-card",
                    accessibilityLabel: "Return to preserved workspace, No preserved workspace available",
                    accessibilityValue: "Disabled"
                )
                .opacity(0.58)
                .accessibilityValue("Disabled")
            }
        }
    }
}

private struct RecoveryArchivesSettingsSection: View {
    let recovery: SettingsRecoveryPresentation
    let beginRecoveryKeyEnrollment: () -> Void
    let presentArchiveCreation: () -> Void
    let presentProtectedExport: () -> Void
    let presentRetainedDataPurge: () -> Void
    let cancelRetainedDataPurge: () -> Void
    let choosePortableArchiveForRestore: () -> Void

    private var overviewTitle: String {
        guard recovery.recoveryEnrollmentEnabled else { return "Portable recovery is not set up" }
        return recovery.archiveSummaries.isEmpty ? "Portable recovery is set up" : "Portable recovery is set up"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RekonTheme.Spacing.section) {
            SettingsHeroCard(
                symbol: "checkmark.shield",
                symbolColor: RekonTheme.success,
                title: overviewTitle,
                subtitle: recovery.recoveryArchiveStatusText,
                facts: [("Status", recovery.recoveryEnrollmentEnabled ? "Enrolled" : "Not enrolled"), ("Recovery", recovery.archiveSummaries.isEmpty ? "No archive" : "Active")],
                accessibilityIdentifier: "settings-recovery-overview-card",
                accessibilityLabel: "Portable recovery status"
            )
            HStack(spacing: RekonTheme.Spacing.section) {
                Label(
                    recovery.recoveryEnrollmentEnabled ? "Enrollment active" : "Enrollment not active",
                    systemImage: "checkmark.circle"
                )
                .font(.footnote.weight(.medium))
                .foregroundStyle(RekonTheme.secondaryText)
                .accessibilityIdentifier("settings-recovery-status-enrollment")

                Label(recovery.recoveryArchiveStatusText, systemImage: "archivebox")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(RekonTheme.secondaryText)
                    .accessibilityIdentifier("settings-recovery-status-state")
            }

            archiveDetail
            recoveryActions
            recoveryNotice
        }
    }

    private var archiveDetail: some View {
        RekonCard {
            VStack(alignment: .leading, spacing: RekonTheme.Spacing.compact) {
                Text("Portable archive details")
                    .font(.headline)
                    .foregroundStyle(RekonTheme.primaryText)
                if recovery.archiveSummaries.isEmpty {
                    Text(recovery.recoveryArchiveStatusText)
                        .foregroundStyle(RekonTheme.secondaryText)
                } else {
                    ForEach(recovery.archiveSummaries) { summary in
                        Text(summary.text)
                            .foregroundStyle(RekonTheme.secondaryText)
                            .accessibilityIdentifier("settings-archive-summary-\(summary.id.uuidString)")
                            .accessibilityLabel(summary.text)
                            .accessibilityValue(summary.accessibilityValue)
                    }
                }
                if let text = recovery.archiveProgressText {
                    ProgressView(text)
                        .controlSize(.small)
                        .accessibilityIdentifier("portable-archive-progress")
                }
                if let text = recovery.protectedExportProgressText {
                    ProgressView(text)
                        .controlSize(.small)
                        .accessibilityIdentifier("protected-export-progress")
                }
                if let text = recovery.retainedDataPurgeStatusText {
                    Text(text)
                        .font(.footnote)
                        .foregroundStyle(RekonTheme.secondaryText)
                        .accessibilityIdentifier("retained-data-purge-status")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings-recovery-archive-detail-card")
    }

    private var recoveryActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: RekonTheme.Spacing.compact) {
                archiveCreationAction
                purgeAction
                restoreAction
            }
            VStack(alignment: .leading, spacing: RekonTheme.Spacing.compact) {
                archiveCreationAction
                purgeAction
                restoreAction
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var archiveCreationAction: some View {
        SettingsRecoveryActionCard(symbol: "archivebox", color: RekonTheme.success, title: "Create recovery archive") {
            if recovery.recoveryEnrollmentEnabled {
                Button("Create recovery archive", action: presentArchiveCreation)
                    .buttonStyle(RekonPrimaryButtonStyle())
                    .accessibilityIdentifier("create-portable-archive")
                    .disabled(recovery.createPortableArchiveIsDisabled)
            } else {
                Button("Set up recovery key", action: beginRecoveryKeyEnrollment)
                    .buttonStyle(RekonPrimaryButtonStyle())
                .accessibilityIdentifier("set-up-recovery-key")
            }
        }
    }

    private var purgeAction: some View {
        SettingsRecoveryActionCard(symbol: "trash", color: RekonTheme.violet, title: "Purge retained archive data") {
            Button("Purge deleted data from retained archives", action: presentRetainedDataPurge)
                .buttonStyle(RekonSecondaryButtonStyle())
                .accessibilityIdentifier("purge-retained-archive-data")
                .disabled(recovery.retainedDataPurgeIsDisabled)
            if recovery.isPurgingRetainedArchiveData {
                Button("Cancel purge", action: cancelRetainedDataPurge)
                    .buttonStyle(RekonSecondaryButtonStyle())
            }
            if let text = recovery.retainedDataPurgeProgressText {
                ProgressView(text)
                    .controlSize(.small)
                .accessibilityIdentifier("retained-data-purge-progress")
            }
        }
    }

    private var restoreAction: some View {
        SettingsRecoveryActionCard(symbol: "arrow.counterclockwise", color: RekonTheme.success, title: "Restore portable archive") {
            Button("Restore portable archive", action: choosePortableArchiveForRestore)
                .buttonStyle(RekonSecondaryButtonStyle())
                .accessibilityIdentifier("restore-portable-archive")
                .disabled(recovery.portableArchiveRestoreIsDisabled)
            if let text = recovery.restoreProgressText {
                ProgressView(text)
                    .controlSize(.small)
                .accessibilityIdentifier("portable-archive-restore-progress")
            }
        }
    }

    private var recoveryNotice: some View {
        VStack(alignment: .leading, spacing: RekonTheme.Spacing.compact) {
            SettingsInfoCard(
                symbol: "info.circle",
                color: RekonTheme.violet,
                title: "Restore safety",
                detail: "Restore creates an inactive local candidate. It does not replace or open your current workspace.",
                accessibilityIdentifier: "settings-recovery-restore-safety",
                accessibilityLabel: "Restore safety"
            )
            .accessibilityElement(children: .combine)

            RekonCard {
                HStack(alignment: .center, spacing: RekonTheme.Spacing.compact) {
                    Image(systemName: "lock.shield")
                        .font(.title2)
                        .foregroundStyle(RekonTheme.accent)
                    VStack(alignment: .leading, spacing: RekonTheme.Spacing.micro) {
                        Text("Protected copy")
                            .font(.headline)
                            .foregroundStyle(RekonTheme.primaryText)
                        Text("Create an encrypted portable copy after destination review and confirmation.")
                            .foregroundStyle(RekonTheme.secondaryText)
                    }
                    Spacer()
                    Button("Export protected copy", action: presentProtectedExport)
                        .buttonStyle(RekonPrimaryButtonStyle())
                        .accessibilityIdentifier("create-protected-export")
                        .disabled(recovery.protectedExportIsDisabled)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("settings-recovery-protected-export")

            if let text = recovery.inactiveRestoreCandidateText {
                Text(text)
                    .font(.footnote)
                    .foregroundStyle(RekonTheme.secondaryText)
                    .accessibilityIdentifier("portable-archive-inactive-candidate")
            }
        }
    }
}

private struct SettingsRecoveryActionCard<Content: View>: View {
    let symbol: String
    let color: Color
    let title: String
    @ViewBuilder let content: Content

    private var accessibilityIdentifier: String {
        switch title {
        case "Create recovery archive": "settings-recovery-action-create"
        case "Purge retained archive data": "settings-recovery-action-purge"
        default: "settings-recovery-action-restore"
        }
    }

    init(symbol: String, color: Color, title: String, @ViewBuilder content: () -> Content) {
        self.symbol = symbol
        self.color = color
        self.title = title
        self.content = content()
    }

    var body: some View {
        RekonCard {
            VStack(alignment: .leading, spacing: RekonTheme.Spacing.compact) {
                Image(systemName: symbol)
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(color)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(RekonTheme.primaryText)
                    .accessibilityIdentifier(accessibilityIdentifier)
                content
            }
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }
}

private struct DocumentReferencesSettingsSection: View {
    let summary: DocumentReferenceSummary

    private var documentReferenceSummaryText: String {
        if summary.availableCount == 0, summary.relinkRequiredCount == 0 {
            return "No document references are attached to active opportunities."
        }
        return "\(summary.availableCount) available · \(summary.relinkRequiredCount) require relinking"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RekonTheme.Spacing.section) {
            SettingsHeroCard(
                symbol: "doc",
                symbolColor: RekonTheme.accent,
                title: "Document references",
                subtitle: "Track availability without exposing file details.",
                facts: [("Available", "\(summary.availableCount)"), ("Needs relinking", "\(summary.relinkRequiredCount)")],
                accessibilityIdentifier: "settings-document-overview-card",
                accessibilityLabel: "Document references, Track availability without exposing file details, Available, \(summary.availableCount), Needs relinking, \(summary.relinkRequiredCount)"
            )

            Text(documentReferenceSummaryText)
                .foregroundStyle(RekonTheme.secondaryText)
                .accessibilityIdentifier("settings-document-reference-summary")
                .accessibilityLabel("Document reference summary")
                .accessibilityValue(documentReferenceSummaryText)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: RekonTheme.Spacing.compact) {
                    countCard(symbol: "doc.badge.checkmark", color: RekonTheme.accent, title: "Available", count: summary.availableCount, identifier: "settings-document-available-card")
                    countCard(symbol: "doc.badge.arrow.up", color: RekonTheme.warning, title: "Needs relinking", count: summary.relinkRequiredCount, identifier: "settings-document-relink-card")
                }
                VStack(spacing: RekonTheme.Spacing.compact) {
                    countCard(symbol: "doc.badge.checkmark", color: RekonTheme.accent, title: "Available", count: summary.availableCount, identifier: "settings-document-available-card")
                    countCard(symbol: "doc.badge.arrow.up", color: RekonTheme.warning, title: "Needs relinking", count: summary.relinkRequiredCount, identifier: "settings-document-relink-card")
                }
            }

            SettingsInfoCard(
                symbol: "info.circle",
                color: RekonTheme.violet,
                title: "Privacy",
                detail: "Document names and locations stay private.",
                accessibilityIdentifier: "settings-document-privacy-card",
                accessibilityLabel: "Document names and locations stay private"
            )
        }
    }

    private func countCard(symbol: String, color: Color, title: String, count: Int, identifier: String) -> some View {
        RekonCard {
            HStack(spacing: RekonTheme.Spacing.compact) {
                Image(systemName: symbol)
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(color)
                VStack(alignment: .leading, spacing: RekonTheme.Spacing.micro) {
                    Text(title)
                        .foregroundStyle(RekonTheme.primaryText)
                    Text("\(count)")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(color)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(count)")
        .accessibilityIdentifier(identifier)
    }
}

private struct AIConnectionsSettingsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: RekonTheme.Spacing.section) {
            SettingsHeroCard(
                symbol: "link",
                symbolColor: RekonTheme.violet,
                title: "AI & connections",
                subtitle: "No cloud services are connected to this workspace.",
                facts: [("AI activity", "No activity recorded"), ("Connection status", "Offline")],
                accessibilityIdentifier: "settings-ai-overview-card",
                accessibilityLabel: "AI & connections, No cloud services are connected to this workspace, AI activity, No activity recorded, Connection status, Offline"
            )

            ViewThatFits(in: .horizontal) {
                HStack(spacing: RekonTheme.Spacing.compact) {
                    statusCard(symbol: "brain", title: "AI assistant", detail: "Not configured", identifier: "settings-ai-assistant-card")
                    statusCard(symbol: "calendar", title: "Email & calendar", detail: "Not connected", identifier: "settings-ai-email-calendar-card")
                    statusCard(symbol: "icloud", title: "Cloud sync", detail: "Not configured", identifier: "settings-ai-cloud-card")
                }
                VStack(spacing: RekonTheme.Spacing.compact) {
                    statusCard(symbol: "brain", title: "AI assistant", detail: "Not configured", identifier: "settings-ai-assistant-card")
                    statusCard(symbol: "calendar", title: "Email & calendar", detail: "Not connected", identifier: "settings-ai-email-calendar-card")
                    statusCard(symbol: "icloud", title: "Cloud sync", detail: "Not configured", identifier: "settings-ai-cloud-card")
                }
            }

            SettingsInfoCard(
                symbol: "info.circle",
                color: RekonTheme.violet,
                title: "Privacy",
                detail: "This workspace remains local and private.",
                accessibilityIdentifier: "settings-ai-privacy-card",
                accessibilityLabel: "This workspace remains local and private"
            )

            Text("The local Activity & AI ledger is read-only and empty in this MVP. No AI requests, costs, model runtime, cloud connection, Gmail, or Calendar integration is configured.")
                .font(.footnote)
                .foregroundStyle(RekonTheme.secondaryText)
                .accessibilityIdentifier("settings-ai-connections-unavailable")
        }
    }

    private func statusCard(symbol: String, title: String, detail: String, identifier: String) -> some View {
        RekonCard {
            HStack(spacing: RekonTheme.Spacing.compact) {
                Image(systemName: symbol)
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(RekonTheme.violet)
                VStack(alignment: .leading, spacing: RekonTheme.Spacing.micro) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(RekonTheme.primaryText)
                    Text(detail)
                        .foregroundStyle(RekonTheme.secondaryText)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(detail)")
        .accessibilityIdentifier(identifier)
    }
}

struct SettingsProtectedExportSuccessDialog: View {
    let displayFilename: String
    let dismiss: () -> Void

    var body: some View {
        VStack(spacing: RekonTheme.Spacing.section) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 62, weight: .light))
                .foregroundStyle(RekonTheme.success)
                .frame(width: 100, height: 100)
                .background(RekonTheme.success.opacity(0.08), in: Circle())
                .overlay(Circle().stroke(RekonTheme.success, lineWidth: 1))
            VStack(spacing: RekonTheme.Spacing.tight) {
                Text("Protected copy exported")
                    .font(.title.bold())
                    .foregroundStyle(RekonTheme.primaryText)
                Text("Your protected copy was saved successfully.")
                    .foregroundStyle(RekonTheme.secondaryText)
            }
            RekonCard {
                VStack(alignment: .leading, spacing: RekonTheme.Spacing.tight) {
                    LabeledContent("Exported file", value: displayFilename)
                    Divider().overlay(RekonTheme.borderSubtle)
                    LabeledContent("Saved to", value: "Selected local folder")
                }
                .foregroundStyle(RekonTheme.primaryText)
            }
            HStack(spacing: RekonTheme.Spacing.tight) {
                Image(systemName: "lock")
                    .foregroundStyle(RekonTheme.success)
                Text("Keep the recovery key you used to protect this copy.")
                    .font(.footnote)
                    .foregroundStyle(RekonTheme.secondaryText)
                Spacer()
            }
            Button(action: dismiss) {
                Text("Done")
                    .frame(maxWidth: .infinity)
            }
                .buttonStyle(RekonPrimaryButtonStyle())
                .accessibilityIdentifier("settings-protected-export-success-done")
        }
        .padding(28)
        .frame(width: 560)
        .background(RekonTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: RekonTheme.Radius.large))
        .overlay(RoundedRectangle(cornerRadius: RekonTheme.Radius.large).stroke(RekonTheme.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.42), radius: 24, x: 0, y: 12)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings-protected-export-success-dialog")
    }
}

enum SettingsProtectedExportDialogMode: Equatable {
    case entry
    case confirmation(displayFilename: String)
}

struct SettingsProtectedExportDialog: View {
    let mode: SettingsProtectedExportDialogMode
    @Binding var recoveryKey: String
    let errorMessage: String?
    let isBusy: Bool
    let cancel: () -> Void
    let primaryAction: () -> Void

    var body: some View {
        VStack(spacing: RekonTheme.Spacing.section) {
            Image(systemName: "shield.checkered")
                .font(.system(size: 62, weight: .light))
                .foregroundStyle(RekonTheme.success)
                .frame(width: 100, height: 100)
                .background(RekonTheme.success.opacity(0.08), in: Circle())
                .overlay(Circle().stroke(RekonTheme.success, lineWidth: 1))

            VStack(spacing: RekonTheme.Spacing.tight) {
                Text(title)
                    .font(.title.bold())
                    .foregroundStyle(RekonTheme.primaryText)
                Text(detail)
                    .foregroundStyle(RekonTheme.secondaryText)
            }

            if case let .confirmation(displayFilename) = mode {
                RekonCard {
                    VStack(alignment: .leading, spacing: RekonTheme.Spacing.tight) {
                        LabeledContent("Filename", value: displayFilename)
                        Divider().overlay(RekonTheme.borderSubtle)
                        LabeledContent("Selected local folder", value: "")
                        Divider().overlay(RekonTheme.borderSubtle)
                        LabeledContent("Active tracker workspace data", value: "")
                    }
                    .foregroundStyle(RekonTheme.primaryText)
                }
                Text("Re-enter the recovery key to confirm.")
                    .font(.footnote)
                    .foregroundStyle(RekonTheme.secondaryText)
            }

            if let errorMessage {
                Text(verbatim: errorMessage)
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("protected-export-error")
                    .accessibilityLabel(errorMessage)
                    .accessibilityValue(errorMessage)
            }

            TextField("Recovery key", text: $recoveryKey)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: RekonTheme.Spacing.tight) {
                Button("Cancel", role: .cancel, action: cancel)
                    .keyboardShortcut(.cancelAction)
                Button(action: primaryAction) {
                    Text(primaryTitle)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(RekonPrimaryButtonStyle())
                .padding(.horizontal, -1)
                .disabled(isBusy)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 560)
        .background(RekonTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: RekonTheme.Radius.large))
        .overlay(RoundedRectangle(cornerRadius: RekonTheme.Radius.large).stroke(RekonTheme.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.42), radius: 24, x: 0, y: 12)
    }

    private var title: String {
        switch mode {
        case .entry: "Export protected copy"
        case .confirmation: "Confirm protected export"
        }
    }

    private var detail: String {
        switch mode {
        case .entry:
            "Choose a destination, then review the encrypted export before it is written. Your recovery key is used only for this action."
        case .confirmation:
            "A new encrypted .rekonexport file will be created. It contains your active tracker data only; document file access is excluded and requires relinking."
        }
    }

    private var primaryTitle: String {
        switch mode {
        case .entry: "Choose destination and review"
        case .confirmation: "Confirm and export"
        }
    }
}
