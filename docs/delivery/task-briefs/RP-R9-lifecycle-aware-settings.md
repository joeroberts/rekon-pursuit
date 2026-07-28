# RP-R9 — Lifecycle-aware Settings

**State:** Accepted — product-owner hands-on verification completed.
**Depends on:** RP-R6, the accepted RP-R7a recovery sequence, accepted RP-R7b-1 archive expiry, and accepted RP-R8 empty AI ledger.  
**Does not depend on:** RP-R7b-2 retained-data purge/rebuild, which remains unreleased.  
**Blocks:** RP-R10 final hands-on acceptance.

## User-visible outcome

Settings becomes the single, truthful place to understand the local workspace lifecycle without adding new lifecycle operations. It must show only facts already represented by local state:

- Workspace data remains local and is retained until the user explicitly deletes it.
- Recovery is either not configured or configured; existing recovery, archive, protected-export, and restore actions retain their accepted behavior.
- Each available archive continues to show its filename, creation date, exact expiry date, and durable verification/lifecycle state. Copy must say automatic archive expiry is checked when the workspace opens or becomes active, not by a background service.
- Deleted records are removed from the active workspace immediately; earlier encrypted archives may retain them until their displayed expiry. Do not show a purge control: retained-data purge/rebuild is RP-R7b-2 and is not shipped.
- Protected export remains an explicit, encrypted, user-initiated action requiring its accepted recovery-key confirmation. Do not claim a durable export history or a destination unless that fact is persisted.
- A compact, read-only document-reference summary shows counts for available references and references requiring relinking. It must not show document paths, bookmarks, hashes, filenames, or open/relink controls.
- The AI section truthfully states that the local Activity & AI ledger is empty/read-only in this MVP: no AI request, cost, model runtime, cloud connection, Gmail, or Calendar integration is configured.

## Scope boundary

This is a Settings status and information-architecture task. Preserve the existing accepted recovery, archive, export, restore, document-reference, and ledger behavior.

Explicit non-goals:

- New recovery-key, archive, protected-export, restore, or expiry mechanics.
- Restore activation, workspace switching, RP-R7b-2 purge/rebuild, or any destructive-data workflow.
- AI execution, network connections, model configuration, budgets, Gmail, Calendar, or other integrations.
- Broad Settings or visual-polish redesign.

## Implementation shape

1. Reorganize the existing Settings content into concise read-only lifecycle sections: Workspace, Recovery & archives, Document references, and AI & connections. Keep existing action entry points where they are needed; do not duplicate them elsewhere.
2. Derive archive wording from the existing durable archive catalogue only. If the catalogue cannot prove a lifecycle condition, omit that condition rather than synthesizing a status. Do not expose archive identifiers, checksums, keys, or file-system paths.
3. Add one read-only aggregate query for active opportunity document references: total available and total relink-required. The query must not open files or security-scoped bookmarks, write activity, migrate data, or expose sensitive reference metadata.
4. Refresh these read-only summaries through the existing workspace refresh path so their displayed state survives relaunch and matches the active local workspace.

## Focused verification

- Add deterministic store coverage in `RekonPursuitCoreTests/WorkspaceStoreTests.swift` for the document-reference summary, including an available reference, a relink-required reference, and a logically deleted opportunity excluded from the active summary.
- Add focused view-model coverage in `RekonPursuitTests/WorkspaceViewModelTests.swift` that refreshes the Settings lifecycle summary from stored state; do not add a broad UI-test suite.
- In the signed Debug owner smoke, verify: no-recovery and configured-recovery wording; archive created/expires/verification display; no fabricated purge action; document counts; empty/offline AI wording; and the same summary after relaunch.

## Required gates before release

- **Architect:** confirm the aggregate query cannot disclose document access metadata and that archive labels map only to durable state.
- **TPM/Delivery Manager:** confirm RP-R9 remains after accepted R8 and before R10, with RP-R7b-2 explicitly deferred.
- **QA:** approve the fixture cases and signed Debug smoke above.
- **Planning:** confirm no recovery/export/restore behavior expands through this Settings task.

## Acceptance criteria

- Settings reports only persisted or derivable local facts and does not present unavailable capabilities as controls.
- Archive expiry and deleted-data retention are understandable without implying background deletion or shipped purge/rebuild.
- Document-reference and empty AI-ledger state are concise, private, and consistent after relaunch.
- Existing accepted recovery/export/restore behavior is unchanged.
