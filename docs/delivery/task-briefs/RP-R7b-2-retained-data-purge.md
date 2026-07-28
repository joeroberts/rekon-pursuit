# RP-R7b-2 — Explicit purge of logically deleted data from retained managed portable archives

**State:** Accepted — product-owner hands-on verification completed.
**Depends on:** RP-R7b-1 accepted; [ADR-001](../../architecture/adr/ADR-001-local-data-lifecycle.md); [R7b expiry and purge design](../../superpowers/specs/2026-07-27-r7b-expiry-and-purge-design.md)  
**Blocks:** No other R7b work is released by this brief.

## User-visible outcome

An enrolled user can explicitly choose **Purge deleted data from retained
backups**, acknowledge that the operation is destructive and cannot be undone,
and re-enter the recovery key. Rekon Pursuit identifies only eligible
workspace-managed portable archives that contain material now logically
deleted, recreates and verifies a replacement archive without that material,
then removes each verified predecessor on a best-effort basis. The user sees a
truthful final result: complete only when every scoped predecessor was
successfully replaced and removed; otherwise incomplete or blocked with safe,
actionable per-archive status.

The recovery key is held only in job memory and discarded on confirmation
failure, cancellation, success, and every error path. The user may cancel
before or during the operation. Cancellation never removes a predecessor and
is recorded as an incomplete job that can be retried only by starting a new
purge and re-entering the recovery key.

## Release boundary

This slice owns only the explicit purge of logically deleted material from
retained archives in the workspace-private managed archive directory. It is a
single serial job per workspace. It must not change automatic expiry semantics
or reuse expiry as an implicit purge mechanism.

It does not:

- delete, move, rename, open, or otherwise mutate an external/user-selected
  or legacy archive;
- change archive v1 encoding, restore/new-workspace behavior, archive creation
  outside the replacement operation, encrypted or unencrypted export, or the
  logical-deletion UI/transaction;
- add a V2 visual design or unrelated Settings/archive UI; or
- claim physical secure overwrite. Predecessor removal is best effort on
  APFS/SSD media and must be described as such.

## Required transaction and safety contract

1. The destructive confirmation must name the effect: deleted content that is
   still recoverable from affected retained archives will become unrecoverable
   from those archives. The final confirmation is invalidated if the planned
   scope changes before the job starts.
2. Before taking work, require valid recovery-key re-entry against the existing
   enrollment fingerprint. An invalid, malformed, or cancelled key entry
   creates no durable job/scope/replacement or success activity and mutates no
   archive or catalogue state. Never persist, log, place in activity/catalogue
   metadata, fixture, diagnostic, or UI state beyond operation memory the
   entered key or derived plaintext key material.
3. In one durable setup transaction, capture the immutable job scope: job ID,
   eligible managed archive IDs, each catalogue version/revision, expiry time,
   purge-compatible lifecycle state, and signed identity facts required to
   reject replacement, plus the logical-deletion tombstone-set version/snapshot
   used for comparison. An archive already expired, not verified, or at/past
   its fixed expiry time at job start is excluded. Record an empty scope as a
   completed no-op only after key verification and explicit confirmation. Once
   captured, the worker must not silently add, drop, or substitute an archive
   or deletion set. If the review scope changes after confirmation but before
   this transaction, invalidate the confirmation and require a fresh review
   and recovery-key re-entry.
4. A purge-eligible archive is a verified workspace-managed archive with an
   active, purge-compatible catalogue lifecycle state and fixed expiry strictly
   later than job start. `expired_prepared`, `expired_quarantined`,
   `expired_missing`, expiry-blocked, expired, or otherwise expiry-claimed
   rows are never purge-eligible and remain under R7b-1's authoritative state.
   While the job is active, acquire one shared durable per-archive operation
   lease used by archive creation, catalogue mutation, and R7b-1 expiry. A
   conflicting operation must visibly defer/retry rather than race the job or
   alter its scope. Before replacement catalogue promotion and again before
   predecessor removal, recheck the captured lifecycle/version and fixed
   expiry time. If expiry has won, the row is no longer purge-compatible, or
   the deadline has passed, retain the predecessor and report an explicit
   incomplete/blocked outcome—never publish a replacement that revives or
   extends expired retention. Relaunch resumes the same durable scope only far
   enough to report/recover its recorded state; retrying destructive rewrite
   work requires a new recovery-key entry.
5. For each scoped archive, authenticate and verify the existing managed,
   regular no-follow file against its catalogue and v1 signed/header/checksum
   bindings before reading its snapshot. Resolve only the canonical managed
   relative locator beneath the private archive store. A missing, unsafe,
   changed-identity, unreadable, malformed, or unauthenticated predecessor is
   never removed and leaves that archive explicitly blocked or retryable.
6. Compare the authenticated snapshot subject identifiers with the captured
   deletion tombstone set. Leave an archive that contains no captured deleted
   material untouched and record it as not requiring rebuild. Rebuild an
   affected archive from the snapshot projection with only the captured deleted
   material excluded; retain active content and the privacy-minimized tombstone
   data required by the frozen archive contract.
7. Write the replacement as a distinct sibling via an owner-only temporary
   artifact and exclusive, no-follow final creation. Never overwrite or rename
   over the predecessor. The replacement inherits the predecessor's original
   `created_at` and fixed `expires_at`; rebuilding deleted material never
   restarts or extends the 30-day retention window. Fully verify the
   replacement (archive framing, signature, envelope with the in-memory key,
   checksum, manifest/snapshot consistency, inherited creation/expiry values,
   required active-content preservation, and absence of the targeted deleted
   identifiers) before adding its replacement catalogue entry. On every
   non-promotion path, remove only the verified owner-only temporary artifact.
   After interruption, deterministic reconciliation may remove only an
   identified, no-follow temporary artifact associated with the durable job;
   it must never follow links or remove an unverified final archive.
8. Only after replacement catalogue promotion succeeds, re-open/recheck the
   predecessor's file identity and immutable scoped catalogue facts, then
   attempt best-effort removal. Remove its predecessor catalogue entry only
   after removal succeeds. If identity changes, predecessor removal fails, or
   process interruption occurs, preserve the predecessor and both accurate
   catalogue/job facts; mark the archive incomplete/blocked rather than
   complete. Do not delete a replacement merely because its predecessor-removal
   step failed.
9. Persist monotonic, precise per-archive phases sufficient to distinguish
   `scoped`, `not_affected`, `replacement_writing`, `replacement_verified`,
   `replacement_catalogued`, `predecessor_removal_pending`, `purged`,
   `cancelled`, `expiry_deferred`, `retryable_failure`, and `blocked` (or equivalent unambiguous
   versioned values). Persist the overall job as `running`, `complete`,
   `incomplete`, `cancelled`, or `blocked`; no path may call it complete while
   a scoped affected predecessor remains.
10. Emit privacy-minimized activity evidence for job requested/finished and
    safe outcome categories. It must not include archive paths/bookmarks, raw
    archive or deleted payload, subject text, recovery material, database
    keys, OAuth tokens, or plaintext archive keys.

## Expected implementation shape

The Architecture gate must approve the final schema names and state machine
before implementation, but the implementation must preserve these ownership
boundaries:

| Area | Expected responsibility |
| --- | --- |
| `RekonPursuitCore/Workspace/Migrations.swift` | Additive durable purge-job, immutable-scope, per-archive phase, and safe-outcome persistence; no destructive migration. |
| `RekonPursuitCore/Workspace/WorkspaceModels.swift` | Sendable purge request/result/progress models, typed errors, and versioned state enums. |
| `RekonPursuitCore/Workspace/PortableArchivePurgeWorker.swift` (new) | Serial actor that validates scope, authenticates/decrypts, rebuilds/verifies replacements, and coordinates failure-safe predecessor removal. |
| `RekonPursuitCore/Workspace/PortableArchiveService.swift` and `PortableArchiveWorker.swift` | Reuse only audited v1 encoding/verification and snapshot projection primitives; expose bounded replacement helpers without weakening creation semantics. |
| `RekonPursuitCore/Workspace/WorkspaceStore.swift` | Confirmation/key-validation boundary, durable scope transaction, archive-operation lock, job/status read API, safe activity, and worker delegation. |
| `RekonPursuit/WorkspaceViewModel.swift`, `RekonPursuit/ContentView.swift` | Minimal existing-settings entry point, destructive confirmation, key re-entry, cancellation, in-progress disabling, and durable truthful result display. No V2 visual work. |
| `RekonPursuitCoreTests/PortableArchiveTests.swift` and focused store/view-model tests | Deterministic multi-archive lifecycle and redaction evidence described below. |

No catalogue field, activity event, or UI status may reinterpret an external
archive as managed or make an external archive eligible. R7b-1 expiry states
must remain readable and must not be overwritten by purge state.

## Focused acceptance evidence

- A deterministic multi-archive fixture contains: one affected managed archive,
  one managed archive with only active content, one external archive containing
  deleted material, and logically deleted tombstones created after the affected
  archive. The purge scope includes only the managed candidates, and only the
  affected managed archive is rebuilt.
- Before predecessor removal is allowed, the test observes a separately
  created replacement that authenticates/decrypts/verifies and contains active
  data but none of the captured deleted subject identifiers. The predecessor
  remains readable until that verification and replacement-catalogue promotion
  have succeeded.
- A purge immediately before expiry proves the verified replacement inherits
  the predecessor's original creation and exact fixed expiry timestamps; the
  rebuild never creates a new retention window.
- Cancellation before scope capture performs no work. Cancellation at temporary
  write, post-verification/predecessor-removal, and between archives leaves all
  not-yet-purged predecessors intact, discards the in-memory key, and persists
  a truthful `cancelled`/`incomplete` state with no false completion activity.
- Forced replacement verification failure preserves the predecessor and no
  successful replacement catalogue row. Forced replacement-catalogue failure
  preserves the predecessor. Forced predecessor identity mismatch or removal
  failure preserves the predecessor and verified replacement, records
  `predecessor_removal_pending`/`blocked` or equivalent, and keeps the overall
  job incomplete.
- Relaunch reads the durable job/per-archive state without a recovery key or
  silently continuing destructive work. A retry requires new confirmation and
  recovery-key re-entry, has an immutable new scope, and never removes a
  predecessor that lacks a verified replacement.
- An invalid or malformed recovery-key submission proves zero durable
  job/scope/replacement records, archive/catalogue mutation, or successful
  activity are created. A review-scope change before durable capture proves
  confirmation is invalidated and requires a new key entry.
- A scope-mutation test proves archive creation/catalogue mutation cannot
  change a captured archive revision or add a new archive to the running job.
  A tombstone created after scope capture is not silently incorporated.
- A coordination test proves the shared durable lease prevents R7b-1 expiry
  from racing a purge-owned archive. If the fixed expiry deadline passes or
  expiry completes before replacement promotion, the predecessor remains and
  the purge records an explicit incomplete/expiry-deferred result; no
  replacement extends the archive's retention.
- The eligibility fixture explicitly covers at/past-expiry archives and every
  R7b-1 expiry-claimed state (`expired_prepared`, `expired_quarantined`,
  `expired_missing`, and blocked); none is read, rebuilt, or reclassified by
  purge. A lease-collision case proves expiry receives a durable retry/defer
  outcome while purge owns an eligible archive.
- Inject abrupt interruption and relaunch after every durable boundary,
  including replacement verification, replacement catalogue promotion, and
  immediately before/during predecessor removal. Each case proves the
  predecessor remains unless verified removal completed, both catalogue/job
  facts are truthful, no destructive work resumes without new confirmation
  and recovery-key entry, and retry is safe and idempotent.
- Cancellation, verification/final-copy failure, and abrupt interruption at
  temporary-artifact boundaries prove owner-only temporary artifacts are
  either removed on the non-promotion path or safely reconciled from the
  durable job record on relaunch. No untracked temporary archive remains in
  the managed directory, and reconciliation never follows a link or removes
  an unverified final archive.
- Active workspace records, normal logical-deletion visibility/search behavior,
  and non-affected archive bytes remain unchanged. External archive bytes and
  catalogue state remain untouched.
- Redaction inspection of activity, errors, persisted job/scope rows,
  catalogue rows, logs, and fixtures finds no recovery key, derived key,
  database key, OAuth token, path/bookmark, raw deleted payload, or known
  deleted subject text.
- Relevant Core tests and the signed Debug macOS build pass. The independent
  Architect/Security, QA, code-review, TPM, and Delivery Manager gates approve
  the evidence before this slice is marked accepted.

## Completion gate

This task is complete only when the durable state machine makes every
non-success outcome visible and recoverable without misrepresenting deletion.
A partial purge is a valid operational result, but it is never a completed
purge. Product-facing copy must distinguish best-effort predecessor-file
removal from any guarantee of physical overwrite.
