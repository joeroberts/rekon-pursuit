# VD2-07x protected-export destination feedback — Security/privacy verification

**Date:** 2026-08-01

**Role:** Fresh independent postimplementation Security/privacy verifier

**Implementation:** `776f7b18e33a3c3e336a77bc65de7fdc8c6566a4..84a99a3df374ceb133b00175cd61285677224e1e`

**Verdict:** **ACCEPT**

## Decision

Commit `84a99a3` preserves the protected-export filesystem, review-binding,
audit, and owner-disclosure boundaries required by the preimplementation gate.
The implementation is limited to controlled pre-output classification, exact
static owner copy, an immutable worker-local fault mode, and focused tests. No
release-blocking security or privacy deviation was found.

This verification inspected the security pre-gate, delivery task brief,
hunk-isolation release, SDD task brief/progress/report and stored review patch,
and the exact commit diff against `776f7b18`. Implementer tests were not rerun;
the preserved result bundles were inspected read-only.

## Security/privacy evidence

| Property | Concrete commit evidence | Result |
| --- | --- | --- |
| Security-scoped lifetime | `review` and `create` still call `startAccessingSecurityScopedResource()` before `openParent` and conditionally stop access with the existing `defer`. All four injected checks execute below those calls and inside that lifetime. The scope Boolean is neither branched on for owner copy nor exposed. | Preserved |
| Parent traversal and descriptor handling | `openParent` retains `open(parent, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)`. `parentOpenUnavailable` is immediately before that call. `parentInspectionUnavailable` is immediately after successful open and closes the descriptor before throwing; the ordinary `fstat` failure also closes it. A returned parent descriptor is still closed by the caller defer. | Preserved |
| Conservative existence and exclusive creation | `destinationExists` remains byte-for-byte unchanged and uses `fstatat(..., AT_SYMLINK_NOFOLLOW)`, treating only proven `ENOENT` as absent. Final creation remains descriptor-relative `openat(..., O_RDWR | O_CREAT | O_EXCL | O_NOFOLLOW, S_IRUSR | S_IWUSR)`. The current-parent identity guard remains before the injected pre-create check and `openat`. | Preserved |
| Immediate `errno` and no overwrite | `let openError = errno` is the immediate statement after the real `openat`. `EEXIST` still maps to `destinationExists`; every other failed pre-create `openat` maps to `destinationUnavailable`. `O_EXCL` remains in place and the regression bundle includes the byte-preserving existing-target test. | Preserved |
| Parent identity, digest, and fingerprint | Parent device/inode types, normalized filename input, `RekonPursuit/export/destination/v1` digest domain, `RekonPursuit/export/review/v1` confirmation domain/version, source-revision input, and the create-time comparison order are unchanged by the commit. Fault mode is absent from review/request/receipt types, hashes, fingerprints, and persistence. | Preserved |
| Created-state may-remain boundary | `created` remains false until `openat >= 0`; descriptor assignment precedes `created = true`; `afterOutputCreation` follows both. The existing catch still converts every error after `created` to `outputMayRemainAfterFailure`. Pre-create injection occurs before `openat` and cannot create a final path. | Preserved |
| Verified-write-only audit | Staging and temporary verification, exclusive final creation/read-back, receipt verification, then the single database transaction remain in the original order. The transaction still inserts the verified export row first and filtered verified activity row second, and no success receipt returns before it completes. Transaction failure remains may-remain. | Preserved |
| Owner disclosure | The only new owner strings are the approved static invalid-name and folder-unavailable messages. No path, raw/normalized URL, POSIX value, security-scope state, device/inode, digest/fingerprint, identifier, receipt, recovery material, database key, or fault mode is interpolated or logged. `WorkspaceViewModel` is unchanged and continues to publish only controlled descriptions, with generic fallback for uncontrolled errors. | Preserved |

## Fault seam and reachability

- `ProtectedExportWorkerFaultMode` is one internal `Sendable` enum.
- The worker stores it only as `private let faultMode`; the initializer default
  is `.none`.
- Production `WorkspaceStore` remains
  `ProtectedExportWorker(configuration: ...)`, with no fault argument.
- Repository-wide Swift searches at commit `84a99a3` and in the current
  worktree found every explicit protected-export non-`.none` construction only
  in `RekonPursuitCoreTests/ProtectedExportTests.swift` and
  `RekonPursuitTests/WorkspaceViewModelTests.swift`.
- No environment, launch argument, preference, persisted value, mutable/global
  switch, UI route, service/store parameter, logging route, or serialization
  route selects or exposes the mode.
- The four branches occur only at their approved decision points; they do not
  wrap or replace a syscall, digest, verification, or transaction operation.

## Behavioral evidence inspected

The final focused bundle
`/private/tmp/rekon-vd207x-export-feedback-green-final.xcresult` reports exactly
10 resolved selected tests, 10 passed, 0 failed, 0 skipped, and 0 expected
failures. Its resolved list covers invalid name, both parent failures,
pre-create failure, post-create may-remain, and all five owner-state/copy
contracts.

The regression bundle
`/private/tmp/rekon-vd207x-export-feedback-regression.xcresult` reports exactly
8 resolved selected tests, 8 passed, 0 failed, 0 skipped, and 0 expected
failures. Its resolved list covers encrypted/read-back verification, parent
binding, source-change no-output behavior, existing-target byte preservation,
exactly one verified export/activity after a real write, retained correction,
nil success for non-success, and filename-only success presentation after real
writing.

The added worker assertions directly establish zero final output and zero
verified export/activity evidence for invalid-name, parent-open,
parent-inspection, and pre-create faults; final output present with zero
verified evidence for post-create failure; and receipt verification plus
exactly one verified export row and one filtered verified activity row for the
ordinary default worker. Model assertions establish exact error/status copy,
retained root error, nil success, false root-success presentation, and the
required nil-versus-retained review state.

## Scope isolation

`git diff --name-status 776f7b18 84a99a3` contains exactly:

1. `RekonPursuitCore/Workspace/ProtectedExportWorker.swift`
2. `RekonPursuitCoreTests/ProtectedExportTests.swift`
3. `RekonPursuitTests/WorkspaceViewModelTests.swift`

This exactly matches the hunk-isolation release's effective path set. The
commit does not change `WorkspaceViewModel`, `ProtectedExportService`,
`WorkspaceStore`, `ContentView`, Settings, project configuration,
persistence/schema, dashboards, roadmap, or prior review/delivery artifacts.
The stored SDD review package identifies the same base, tip, commit, path set,
and patch content; its larger hunks differ from ordinary `git diff` only by
context width.

## Checks

- Inspected exact commit and stored SDD review patch.
- Inspected all protected-export fault-mode definitions, uses, and worker
  construction sites in production and tests.
- Inspected focused GREEN and regression result summaries and resolved test
  lists without rerunning implementer tests.
- `git diff --check 776f7b18 84a99a3`: clean.
- `git diff --check`: clean for the current tracked worktree diff.

## Residual risk

This is a static diff and preserved-bundle verification, not a new hostile
filesystem or sandbox run. Existing race resistance continues to depend on the
unchanged descriptor-relative `fstatat`/`openat` sequence and Darwin semantics;
the focused regression evidence covers parent binding and no-overwrite but does
not newly stress every possible filesystem or permission error. The internal
fault enum remains callable by other code compiled into the core module, so
future production call sites must continue to be blocked by source review and
the repository-wide non-default-use check. Neither residual risk blocks this
bounded commit.

## Verdict

**ACCEPT.** Commit `84a99a3` satisfies the postimplementation
Security/privacy gate for VD2-07x protected-export destination feedback.
