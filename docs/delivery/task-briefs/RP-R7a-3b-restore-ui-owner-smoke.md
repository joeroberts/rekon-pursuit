# RP-R7a-3b — Restore UI and owner smoke

**State:** Accepted — verified restore UI and owner smoke completed.
**Depends on:** `RP-R7a-3a` accepted; the in-progress `RP-R7a-3` parent;
[ADR-001](../../architecture/adr/ADR-001-local-data-lifecycle.md); and the
[local-data lifecycle contract](../../architecture/local-data-lifecycle-contract.md).  
**Blocks:** Acceptance of `RP-R7a-3`; any workspace activation/switch and all
export work.

## Outcome

In **Settings → Recovery & export**, a user can select one `.rekonarchive`,
enter its recovery key, review the verified archive identity, explicitly
confirm restoration, and receive an unambiguous success or safe failure
result. The restore worker creates only an inactive candidate; the current
workspace stays open and unchanged.

## Fixed scope

- Add one Settings restore entry point, disabled while archive creation or a
  restore is in progress. Use `NSOpenPanel` for one `.rekonarchive` file.
- Start the selected URL's security-scoped access before launching the worker
  task and release it only after that task finishes, is cancelled, or fails.
  Pass that exact scoped URL directly to the worker and retain the scope across
  the whole awaited call; do not stage, copy, bookmark, or otherwise retain the
  selected archive. Do not persist its path, archive data, or recovery key.
- Present recovery-key entry after selection. Parse the key only at the action
  boundary; clear the entered string and parsed key on cancel, completion, and
  failure. Never include either in activity, errors, preferences, or UI text.
- Verify through `PortableArchiveRestoreWorker` off the main actor. Show the
  verified archive ID, creation time, and signing-key fingerprint in a compact
  confirmation sheet. Confirmation is required for **every** verified archive,
  not only the clean-Mac case.
- On confirmation, call the worker with the optional current local catalogue
  and the exact typed `PortableArchiveRestoreConfirmation` generated from the
  preview. The worker must reauthenticate the selected archive and bind the
  same ID/time/fingerprint confirmation before candidate reservation; a
  matching catalogue row must never bypass that confirmation. An absent
  recovery enrollment or local catalogue must not prevent v1 restore; an
  available matching catalogue is additional same-Mac verification only.
  Present only: verifying, restoring,
  ready (archive ID), or redacted safe-failure/cleanup-pending copy. Do not
  show a candidate root, candidate ID, archive path, snapshot data, or key.
- Success copy must state: “Restored workspace ready. It remains inactive; a
  future workspace-open action is required.” It must not imply that the
  restored workspace is currently open or selectable.
- Preserve every exclusion from `RP-R7a-3a`: no candidate list, open/switch,
  archive creation changes, legacy same-Mac backup staging/copy/restore,
  export, expiry, purge, deletion-flow changes, external network, or legacy
  workspace route.

## File-level implementation shape

| Area | Responsibility |
| --- | --- |
| `RekonPursuit/ContentView.swift` | Settings presentation only: picker trigger, key sheet, verified-identity confirmation, progress/result surface. |
| `RekonPursuit/WorkspaceViewModel.swift` | Main-actor UI state machine and short-lived security-scope lifetime; obtain the current catalogue and await the existing worker. No synchronous archive read, crypto, import, or database bootstrap. |
| `RekonPursuitCore/Workspace/PortableArchiveRestore.swift` | Amend the restore service contract so every restore re-reads and authenticates the selected archive, then requires an exact ID/time/fingerprint confirmation before reservation—even when an optional local catalogue row matches. Reuse the existing Sendable request/result API; do not alter candidate lifecycle semantics. |
| `RekonPursuitTests/WorkspaceViewModelTests.swift` | Deterministic panel/scope/worker seams and state-transition tests. |
| `RekonPursuitCoreTests/PortableArchiveTests.swift` | Only add a core regression if UI integration exposes a worker-contract defect. |

## Focused implementation and evidence

1. Add a small injected picker/security-scope seam to the view-model tests;
   prove picker cancellation never invokes the worker, and that a URL whose
   `startAccessingSecurityScopedResource()` returns `false` never invokes the
   worker or presents a false success state.
2. Add a failing test for valid verification → confirmation-required → explicit
   confirmation → inactive-ready result. Assert the security scope spans the
   entire awaited worker call and stops exactly once afterwards. Assert the
   worker is off-main and that restore/archive-create controls remain disabled
   until the awaited operation completes.
   Add core regression coverage that a `nil`, stale, or mismatched confirmation
   with an otherwise matching local catalogue is rejected after re-read/
   authentication and before any registry reservation, candidate root, or
   candidate Keychain material exists.
3. Add failing tests for malformed key, worker verification failure,
   cancellation at confirmation, and `candidateCleanupPending`. Each must clear
   transient key/selection state, keep the current store selected, release an
   acquired scope exactly once, and expose only safe redacted user copy.
4. Implement the smallest Settings sheets/progress surface that passes those
   tests. Use the existing Rekon Settings visual language and the archive
   catalogue, when present, as optional same-Mac matching data.
5. Run the focused view-model restore tests, the accepted R7a-3a archive suite,
   and a signed Debug build. Then launch the signed app for product-owner smoke.

## User-visible acceptance

- Settings offers **Restore portable archive** only when no archive/restore
  operation is running.
- Restore remains available when the current workspace has no recovery
  enrollment and no local archive catalogue.
- Choosing an archive and entering a valid key displays its verified identity
  before any candidate is created; confirmation is required for every verified
  archive and **Cancel** creates nothing.
- Confirming a valid archive visibly progresses and ends at “restored workspace
  ready,” while the worker re-verifies and binds the displayed identity before
  reservation and the current workspace remains open and unchanged.
- Bad key, tampered archive, catalogue mismatch, cleanup-pending, or any worker
  failure is understandable without revealing a key, path, candidate identity,
  or archive content; the app remains responsive.
- No UI control can list, open, activate, switch to, export from, or otherwise
  mutate the candidate.

## Product-owner smoke

On a signed Debug build: create/select a known archive, choose **Restore
portable archive**, paste the recovery key, verify the displayed ID/time/
fingerprint, and confirm. Verify the ready result says the candidate remains
inactive and that the current pipeline is unchanged. Run once more and cancel
at identity confirmation; verify the current workspace is still open and no
result claims restoration.

## Release rule

Planning, Architect/Security, TPM, QA, and Delivery Manager must approve this
brief before a fresh implementer is released. Separate code review, QA and
Architecture/Security verification, plus the product-owner smoke above, are
required before `RP-R7a-3` can be accepted. Planning alone does not change the
dashboard or remediation ledger.
