# VD2-07x protected-export destination feedback — Architecture verification

**Date:** 2026-08-01

**Role:** Fresh independent postimplementation Architect

**Implementation:** `776f7b18e33a3c3e336a77bc65de7fdc8c6566a4..84a99a3df374ceb133b00175cd61285677224e1e`

**Verdict:** **ACCEPT**

**ADR disposition:** **No ADR required**

## Decision

Commit `84a99a3` conforms to the pre-approved immutable internal fault seam and
classification boundary. It does not materially change the protected-export
architecture: the fault mode remains immutable, worker-local, internal, and
defaulted to `.none`; production construction is unchanged; and the four modes
occur only at the approved pre-parent-open, pre-parent-inspection,
pre-exclusive-create, and post-created-state boundaries.

The worker initializer gains only the exact internal, defaulted parameter
approved by the preimplementation architecture gate. That is the authorized
test seam, not a public or production-selection API. There is no additional
Worker surface, no `WorkspaceStore` or `WorkspaceViewModel` API expansion, and
no route by which production UI, settings, environment, serialization, or
persistence can select a non-`.none` mode.

No ADR is required because the implementation does not deviate from the gate's
approved seam, data/security contracts, filesystem state machine, or
persistence boundary. A new ADR and architecture review would be required for
a production-injectable filesystem adapter, mutable/runtime-selectable fault
state, changed review or digest inputs, changed Darwin operations or flags,
persisted fault state, or a broader classification boundary; none is present.

## Independent evidence

| Architecture boundary | Commit evidence | Result |
| --- | --- | --- |
| Scope and isolation | The commit is one descendant of base `776f7b18` and changes exactly `ProtectedExportWorker.swift`, `ProtectedExportTests.swift`, and `WorkspaceViewModelTests.swift`. `WorkspaceViewModel.swift`, `WorkspaceStore.swift`, `ProtectedExportService`, migrations/models, project files, UI, dashboard, plans/briefs, and prior delivery records have no commit-range diff. | Preserved |
| Immutable internal seam | `ProtectedExportWorkerFaultMode` is an internal `Sendable` enum; the actor stores it in `private let faultMode`; the initializer defaults it to `.none`. The only non-default constructions at `84a99a3` are in the two focused test files. Production `WorkspaceStore` still calls `ProtectedExportWorker(configuration: database.portableArchiveConnectionConfiguration())`. Private helper signatures alone thread the value to the approved boundaries. | Matches pre-gate |
| Classification boundary | Only the existing final-component predicate throws `invalidDestinationName`. Parent `open`/`fstat` failures and non-`EEXIST` failed `openat` before output creation throw `destinationUnavailable`. The real `openat` is followed immediately by an `errno` capture; `EEXIST` remains `destinationExists`. Parent identity mismatch remains `destinationChanged`, and every failure after `created = true` remains `outputMayRemainAfterFailure`. | Preserved and narrowed as approved |
| Cryptographic and destination binding | `ProtectedExportReview` and `ProtectedExportRequest` fields are unchanged. Parent device/inode binding, normalized filename input, destination digest domain and inputs, confirmation fingerprint domain/version and inputs, source revision, and create-time comparison order have no changed lines. Fault mode is absent from reviews, requests, receipts, digests, fingerprints, and stored records. | Unchanged |
| Parent filesystem boundary | The filename predicate still precedes `open(parent, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)`. `parentOpenUnavailable` is immediately before that unchanged call. `parentInspectionUnavailable` occurs only after a successful open, closes the descriptor, and precedes the unchanged `fstat`; the ordinary `fstat` failure also closes the descriptor. Caller-owned parent descriptors retain their existing `defer` close. | Unchanged operations/flags/order, approved checks inserted |
| Final filesystem boundary | The current-parent-identity guard and conservative `fstatat(..., AT_SYMLINK_NOFOLLOW)` existence check remain unchanged. `exclusiveCreateUnavailable` follows the identity guard and precedes `openat`, so it cannot create output. Final creation remains `openat(parentFD, filename, O_RDWR | O_CREAT | O_EXCL | O_NOFOLLOW, S_IRUSR | S_IWUSR)`. Descriptor assignment precedes `created = true`; `afterOutputCreation` follows both and flows through the existing conservative catch. Subsequent `fstat`, copy, `fsync`, identity recheck, seek, and read-back order is unchanged. | Unchanged operations/flags/order, approved checks inserted |
| Persistence, activity, and schema | No store, migration, model, or schema file changes. The worker still stages and verifies temporary output, exclusively creates and reads back final output, verifies receipt equality, and only then inserts `protected_export_events` and `protected_export_verified` in the existing single transaction. Fault state is not serialized or persisted. Database failure remains may-remain. | No impact |
| Owner disclosure | The only new owner-facing values are the two approved static messages for invalid name and unavailable folder. `WorkspaceViewModel` is unchanged and still publishes known `ProtectedExportWorkerError.errorDescription` values while retaining a generic fallback for uncontrolled errors. No path/URL, `errno`, security-scope result, device/inode, digest/fingerprint, identifier, receipt, recovery key, key material, or fault mode is interpolated or logged. | Safe copy preserved |

## Reviewed evidence package

This verification read the repository `AGENTS.md`, preimplementation
Architecture gate, task brief, hunk-isolation release, gitignored implementer
report, exact commit diff, independent code review, postimplementation QA
verification, and postimplementation Security/privacy verification. The latter
three records independently report ACCEPT/PASS and preserved focused evidence:
executable RED 10/10 assertion failures, final GREEN 10/10 passing, and
regression 8/8 passing with zero skips or expected failures. The preliminary
compile-only RED remains correctly classified as non-gating history; the
separate executable `red-fixed` bundle is the qualifying RED artifact.

## Residual risk

The seam is module-internal rather than test-target-only, so future production
call sites could technically pass a non-default mode. That was the explicitly
approved design tradeoff and is currently controlled by `private let`, default
`.none`, absence of Store/ViewModel exposure, repository-wide construction-site
review, and code review. No current call site makes the mode owner- or
runtime-selectable, so this does not require an ADR or block the bounded commit.

## Verification

- `git diff --check 776f7b18 84a99a3`: clean.
- `git diff --check`: clean for the current tracked worktree diff.
- No implementation tests were rerun for this architecture verification; the
  preserved bundles and independent QA/Security readbacks provide the behavioral
  evidence, while this gate independently inspected the exact frozen diff.

## Final disposition

**ACCEPT.** Commit `84a99a3` has no material architecture deviation from the
approved internal immutable fault seam and classification boundary. **No ADR is
needed.**
