# VD2-07x protected-export destination feedback — Architecture gate

**Date:** 2026-08-01  
**Role:** Fresh independent Architect  
**Verdict:** **ACCEPT**

## Decision

The proposed classification split preserves the current protected-export
security architecture, provided the implementation observes the exact seam and
state-boundary constraints below. It changes only owner-safe interpretation of
failures that already stop the operation; it does not authorize a new write
path, retry, overwrite, destination normalization, persistence contract, or
export format.

No ADR is required for the recommended immutable internal fault-mode seam. An
ADR and fresh architecture review are required if implementation instead adds
a production-injectable filesystem abstraction, changes any Darwin operation
or flag, changes review/request fields or digest inputs, persists fault state,
or broadens the controlled errors beyond this worker boundary.

## Security-boundary assessment

| Invariant | Current boundary | Required result |
| --- | --- | --- |
| Parent traversal resistance | `open(parent, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)` occurs after the filename predicate. | Keep the call and flags unchanged. A forced parent-open failure runs before this call; a forced inspection failure closes any opened descriptor. Both map only to `destinationUnavailable`. |
| Exclusive, non-overwriting final creation | `openat(parentFD, filename, O_RDWR | O_CREAT | O_EXCL | O_NOFOLLOW, S_IRUSR | S_IWUSR)` follows an identity recheck and an existence check. | Keep flags, mode, order, and `EEXIST -> destinationExists` unchanged. A deterministic pre-create fault must run before `openat`, so it cannot create or replace a file. |
| Parent identity and review binding | Review stores parent device/inode, a destination digest over normalized filename plus parent identity, and a confirmation fingerprint over filename, digest, and source revision; create recomputes all three before staging/final creation. | Do not change these types, inputs, versions, comparisons, or their order. Fault mode is never stored in a review, digest, fingerprint, request, receipt, or database row. |
| Security-scoped access | Review and create call `startAccessingSecurityScopedResource()` before parent work and conditionally stop it with `defer`. | Leave this lifetime unchanged. A fault must be evaluated inside the existing defer scope and must not expose whether scope acquisition returned true or false. |
| Pre- versus post-output state | `copyExclusivelyAndReadBack` sets `created = true` only after successful `openat`; its catch converts every later failure to `outputMayRemainAfterFailure`. | Preserve this conservative state machine. Never map a failure after a successful `openat` to `destinationUnavailable`, even if the subsequent error looks like a folder or descriptor failure. |
| Verified-write-only activity | The worker stages and verifies a temporary export, exclusively creates and reads back the final file, verifies the read-back receipt, and only then inserts `protected_export_events` and `protected_export_verified` in one database transaction. | Do not move, split, or pre-create either row. Every invalid-name, parent, or pre-create fault leaves both queries empty and never returns a receipt or success presentation. Database failure after final verification remains `outputMayRemainAfterFailure`. |
| Safe owner copy | `WorkspaceViewModel.protectedExportMessage(for:fallback:)` publishes only known controlled errors; other errors receive a generic fallback. Success contains only `displayFilename`. | Add only the two exact controlled messages. Do not interpolate URL/path, `errno`, security-scope state, database/internal identifiers, fingerprints, receipt data, recovery key, or key material. Do not add logging or diagnostics to owner-visible copy. |

`ProtectedExportService` requires no change. Its temporary container generation,
encryption, read-back verification, and receipt equality are upstream of final
exclusive creation and remain part of the existing verified-write chain.

## Required classification contract

1. Only failure of the existing final-component predicate becomes
   `invalidDestinationName` with exactly
   `Choose a new file name ending in .rekonexport.`
2. Parent `open` or `fstat` failure after that predicate succeeds becomes
   `destinationUnavailable` with exactly
   `Rekon Pursuit can’t use that folder. Choose another local folder and review the export again.`
3. A real final `openat` failure captures `errno` immediately. `EEXIST` remains
   `destinationExists`; another error becomes `destinationUnavailable` only
   because `openat` failed and this worker has not created a descriptor/file.
4. `destinationExists`, `destinationChanged`, `sourceChanged`,
   `verificationFailed`, and `outputMayRemainAfterFailure` retain their current
   meanings. In particular, the current parent-identity check immediately
   before `openat` remains `destinationChanged`, not folder-unavailable.
5. `destinationExists(_:,filename:)` remains conservatively unchanged: any
   `fstatat` result other than a proven `ENOENT` continues to block creation.

## Exact recommended deterministic seam

Use one immutable, internal worker-only enum and preserve the existing
production initializer behavior:

```swift
nonisolated enum ProtectedExportWorkerFaultMode: Sendable {
    case none
    case parentOpenUnavailable
    case parentInspectionUnavailable
    case exclusiveCreateUnavailable
    case afterOutputCreation
}

actor ProtectedExportWorker {
    private let faultMode: ProtectedExportWorkerFaultMode

    init(
        configuration: PortableArchiveDatabaseConfiguration,
        faultMode: ProtectedExportWorkerFaultMode = .none
    ) {
        self.configuration = configuration
        self.faultMode = faultMode
    }
}
```

The production `WorkspaceStore` call remains
`ProtectedExportWorker(configuration: ...)`; no new `WorkspaceStore` parameter
is needed because it already accepts an injected worker for tests.

Placement is part of the contract:

- `parentOpenUnavailable`: after the filename predicate, immediately before
  the unchanged Darwin `open`.
- `parentInspectionUnavailable`: after a successful parent `open`, immediately
  before `fstat`; close that descriptor before throwing.
- `exclusiveCreateUnavailable`: after the unchanged current-parent-identity
  guard, immediately before Darwin `openat`. It simulates a non-`EEXIST`
  failure and must not call `openat`.
- `afterOutputCreation`: only after `openat` returned a nonnegative descriptor,
  the descriptor was assigned, and `created = true`. Throwing there must flow
  through the existing catch and become `outputMayRemainAfterFailure`.

Do not make the fault mutable, global, serialized, environment-driven,
owner-selectable, or capable of returning raw `errno`. Do not put a fault hook
inside `ProtectedExportService`, digest/fingerprint code, security-scope
acquisition, database transactions, or message mapping. A syscall-adapter
alternative is not approved by this gate without a fresh architecture review,
because it expands the seam that can alter production flag and descriptor
semantics.

## Required test constraints

- The invalid-name test must still win when no parent operation is attempted;
  assert no review, output, event, or verified activity.
- Exercise both parent-open and parent-inspection fault modes. One parameterized
  test is acceptable. Each uses a valid `.rekonexport` component and asserts
  `destinationUnavailable`, no review/output/event/activity, and exact safe
  copy at the model boundary.
- The exclusive-create test first obtains a real successful review, then uses
  the immutable `exclusiveCreateUnavailable` worker. Assert no final path,
  zero `protected_export_events`, and zero `activity_events` filtered to
  `kind = 'protected_export_verified'`.
- The post-create test asserts `outputMayRemainAfterFailure`, a remaining final
  path is possible/expected for this deterministic hook, and zero verified
  export/activity rows. It must never expect folder-unavailable copy.
- Retain the ordinary real-write, parent-binding, source-change, and existing
  target tests. The existing-target test must continue to compare original
  bytes, not merely check that an error occurred.
- The fault-mode tests supplement rather than replace inspection of the exact
  `O_DIRECTORY | O_NOFOLLOW`, `O_EXCL | O_NOFOLLOW`, `AT_SYMLINK_NOFOLLOW`,
  descriptor-close, parent-identity, digest/fingerprint, and `created` catch
  lines during code/security review.
- View-model assertions must prove `protectedExportReview == nil` after failed
  review, `protectedExportSuccess == nil` on every new failure, exact copy, and
  generic fallback for any non-controlled error. No test may assert or surface
  raw path, `errno`, scope state, or recovery material.

## Scope and release conditions

Implementation remains confined to the four allowed paths in the task brief.
`ContentView`, `ProtectedExportService`, `WorkspaceStore`, project files,
Settings IA, persistence/migrations, and accessibility are unchanged. Accept
this architecture gate only together with the still-mandatory independent QA,
TPM, Delivery Manager, code-review, and Security/privacy gates. Any deviation
from the placements or state transitions above changes this verdict to
**NEEDS CHANGE** pending re-review.
