# VD2-07x Save-panel leaf authority — architecture re-gate

**Date:** 2026-08-01
**Role:** Fresh independent Architect
**Verdict:** **ACCEPT**

## Decision

The scope reconciliation now embodied in the current task brief resolves the
test-boundary conflict that blocked the earlier architecture, QA, and
security/privacy gates. The implementation scope is accepted as one bounded,
three-path TDD slice. This acceptance approves no parent-directory continuity
claim and no broader filesystem authority.

The present worker remains the known pre-repair implementation: review opens
and binds the parent at `ProtectedExportWorker.swift:66-84`, confirmation
reopens and compares it at `:87-97`, and final creation uses `openat` at
`:197-225`. Those behaviors are the defect to remove, not compatibility that
the implementation must retain.

## ADR-005 conformance required for the slice

| Boundary | Accepted requirement |
| --- | --- |
| Selected-leaf authority | The exact transient `NSSavePanel` leaf URL is the sole external-write authority. Review validates the NFC final filename and computes the in-memory v2 canonical leaf digest from the lexically standardized leaf path; it does not resolve, open, stat, bind, or inspect an ancestor. |
| Review binding | The confirmation fingerprint continues to bind export type, fixed category, NFC filename, canonical leaf digest, and captured source revision. Confirmation must recompute the digest and fingerprint from the reviewed leaf before staging or final creation; locator, digest, or fingerprint disagreement is `destinationChanged`, and a revision change is separately `sourceChanged`. |
| Exact create boundary | The selected leaf alone is created with `O_RDWR | O_CREAT | O_EXCL | O_NOFOLLOW` and mode `0600`. `EEXIST`, including an occupied leaf or terminal symlink, remains the no-overwrite result. A direct-leaf failure before a descriptor exists is `destinationUnavailable`; every failure after descriptor assignment is `outputMayRemainAfterFailure`, with no retry, overwrite, or pathname cleanup. |
| Verified-write chain | Final-FD `fstat`, streaming, `fsync`, same-FD read-back, and package verification remain in place. Exactly one verified export event and one `protected_export_verified` activity are committed only after verification. |
| Explicit limitation | Parent device/inode continuity is neither achievable from the one-step file selection nor required. If a replaced parent or changed permission makes the selected leaf unusable, the operation fails truthfully; exclusive leaf creation proves only creation of that selected leaf at confirmation time. |

## Atomic source and test boundary

Only these paths are authorized, and they must be reviewed and staged as the
same released slice:

1. `RekonPursuitCore/Workspace/ProtectedExportWorker.swift` — direct-leaf
   authority, binding, creation/error transitions, and worker-local immutable
   default-`.none` faults required by the focused tests.
2. `RekonPursuitCoreTests/ProtectedExportTests.swift` — real-store leaf
   authority, no-overwrite, binding, failure, and evidence-ordering proof.
3. `RekonPursuitTests/WorkspaceViewModelTests.swift` — only the clean
   feedback island at current lines 706–767 and its adjacent helpers at
   current lines 770–860. It may retire the two obsolete parent-review tests,
   rename/reassert the pre-descriptor case as direct selected-leaf unavailable
   feedback, and retain the post-descriptor may-remain assertion. Production
   `WorkspaceViewModel` remains inspection-only.

The isolation prerequisite is met. `git diff --unified=0` shows no changed
hunk in current lines 692–863: after the unrelated current-file insertion at
line 8, the next changed hunk starts at current line 1189. The clean island
therefore contains the two obsolete parent tests at lines 706–732, the
confirm-feedback test at lines 734–750, the may-remain test at lines 752–767,
and only their local helpers through line 860. `git diff --check` completed
without a whitespace error. The implementer must capture this same pre-task
context and stop for a new integration plan if the island gains an overlapping
hunk before work begins.

## Required proof safeguards

The accepted brief addresses the defects identified in the earlier gates:

- `ProtectedExportTests.swift` is compiled into the actual
  `RekonPursuitTests` target; the RED, GREEN, and regression commands use
  `-only-testing:RekonPursuitTests/ProtectedExportTests` and retain distinct
  DerivedData/result bundles with resolved test lists, zero skips, and zero
  expected failures.
- RED is an independent v2 canonical-leaf digest assertion using a decomposed
  Unicode filename, not a simulated sandbox denial. It must fail on the
  current v1 parent-identity implementation while the leaf has not yet been
  created.
- GREEN coverage separately proves an ordinary verified leaf export; invalid
  name; existing regular leaf, terminal symlink, and after-review sentinel
  collisions without byte changes; locator-only, digest-only, fingerprint-only,
  and source-revision rejection before output/evidence; direct pre-descriptor
  unavailability; and post-descriptor conservative handling.
- The immutable fault matrix includes a post-verification/pre-evidence case:
  the test independently verifies the retained output, then proves there is no
  verified export event or filtered activity. This establishes the required
  verification-before-evidence ordering rather than merely an early
  post-create failure.
- The signed Debug owner smoke remains mandatory after GREEN. It verifies the
  signed app and effective existing entitlement, then uses an actual
  `NSSavePanel` selection of a fresh leaf in a new Documents child folder.
  Its redacted evidence must show filename-safe review/success and one
  nonempty output, without a path, key, package, database, or entitlement dump.

## Unchanged contracts and release limits

The task does not change the one-step Save-panel interaction, filter, default
name, folder-creation capability, UI copy, persistence/schema, activity
schema, signing, bookmarks, preferences, or project files. The checked source
entitlement still declares App Sandbox and the existing
`com.apple.security.files.user-selected.read-write` authority; no entitlement
diff is present. The current worktree has unrelated dirty UI/model work, so
this finding is an allowlisted-slice constraint, not a claim that the whole
worktree is clean. No change outside the three paths above is authorized for
this task.

No additional ADR is needed for exact ADR-005 implementation. A new ADR and a
fresh architecture review are required before any parent-directory operation
or continuity claim, folder chooser, recursive authority, entitlement,
bookmark/persistent security scope, canonicalization or fingerprint change,
overwrite/cleanup change, or raw-path/key/export-data persistence or display.

## Release disposition

The scope-reconciled brief is architecture-approved for dispatch to a fresh
implementer once the independent TPM, QA/test, security/privacy, and Delivery
Manager release gates are also recorded. This is a pre-implementation
architecture acceptance only; it does not substitute for post-implementation
code review, result-bundle inspection, architect/security verification, or the
owner-native smoke.
