# VD2-07b Task 2 — Delivery release

**Date:** 2026-08-03  
**Role:** Independent Delivery Manager  
**Decision:** **RELEASE — one fresh implementer may begin Task 2 only.**

## Evidence accepted for this release

The following Task-1 checkpoint is the release baseline:

| Evidence | Delivery reading |
| --- | --- |
| `9ce5431` — `docs: align VD2-07b with approved form references` | Records the product-owner Contacts and Opportunity references as the controlling visual contract and rejects the prior nested/capsule/high-chrome direction. |
| `4cf0d73` — `docs: add VD2-07b visual evidence gate` | Adds the mandatory reference-faithful visual acceptance amendment and its independent 16-capture pre-merge gate. |
| `038211c` — `test: define VD2-07b shared control contract` | The final Task-1 test-only checkpoint. No Task-2 production source is present in this checkpoint. |
| `/private/tmp/rekon-vd207b-task1-exhaustive-final.xcresult` | Finalized signed Debug Task-1 matrix: four selected methods executed once; zero skips and zero expected failures. Each method fails only for its absent, additive, content-free `shared-control-surface-*` projection: Contacts multiline, Add title, recovery setup re-entry, and Pipeline search. No baseline failure is recorded. |
| Fresh independent Task-1 QA approval (`/root/vd207b_task1_exhaustive_qa`) | **APPROVE.** The exhaustive finalized RED classification is valid; the result bundle above is the authoritative evidence. |
| Fresh independent Task-1 code review approval (`/root/vd207b_task1_exhaustive_code_review`) | **APPROVE.** The corrected test checkpoint is within the Task-1 boundary. |
| Fresh Task-2 architecture approval (`/root/vd207b_task2_architecture_release`) | **APPROVE.** Confirms the presentation seam, production file boundary, responsive reference direction, and no-change contract below. |
| Fresh Task-2 security/privacy release (`/root/vd207b_reference_security_release`) | **RELEASE, scope only.** Confirms the branch contains no production/persistence/recovery/document/native-panel/network change and that Task 2 remains presentation-only. |

The fresh QA/code/architecture/security decisions above were delivered to
Delivery as independent coordination verdicts. They are not represented as
invented file reports; their identifiers and the retained signed bundle are
recorded here for the durable delivery ledger.

The previous TPM continuation record withheld Task 2 solely until fresh
Task-1 QA/code evidence, architecture/security continuation, and an explicit
Delivery transition existed. Those conditions are now fulfilled by the
evidence above and this release. No dependency outside VD2-07b is opened.

## Disposition of earlier blockers and worktree hygiene

- `docs/delivery/reviews/VD2-07b-task1-code-review-2026-08-03.md` and
  `docs/delivery/reviews/VD2-07b-task1-qa-verification-2026-08-03.md` are
  untracked earlier **BLOCK** reports. They describe superseded intermediate
  checkpoints, not the final `038211c` matrix. Preserve them as untracked
  historical notes; do not add them to the Task-2 implementation commit or
  use them as current gate evidence.
- The early scratch report was added in `4d5317b`, altered in `61954c8`, and
  removed in `35cf211`. `git diff --name-status origin/main...HEAD` now shows
  only `RekonPursuitUITests/RekonPursuitUITests.swift` and the approved visual
  amendment; `git diff --check origin/main...HEAD` is clean. The scratch file
  has no final-tree or delivery effect, so no cleanup is required before this
  release. It must not be reintroduced by Task 2.

## Task-2 authorization boundary

The implementer may modify only:

- `RekonPursuit/RekonVisualTheme.swift` — the sole shared semantic
  presentation seam;
- `RekonPursuit/ContentView.swift`;
- `RekonPursuit/ContactsView.swift`;
- `RekonPursuit/SettingsView.swift`; and
- `RekonPursuit/PipelineView.swift` only for invocation-level alignment that
  leaves the existing native controls intact.

Implement the smallest shared text/search, multiline, numeric-text, and
picker presentation family. It must match the approved references: labels
above compact single-surface controls, quiet idle navy borders, restrained
cyan only for real focus plus a non-color focus cue, subtle section dividers,
concise Contacts editing, and responsive multi-column Opportunity layout that
stacks cleanly in compact width.

`ContentView` retains all workspace, route, modal, recovery-string,
file-dialog, confirmation, and callback ownership. Pipeline AppKit controls
retain their responder/delegate/target-action, role, label, value, binding,
and keyboard ownership. Native macOS panels, model/store/core/persistence,
audit behavior, recovery/archive/restore/export behavior, fixture/launch
setup, project/signing, AI/provider/network routing, and VD2-07c/VD2-07d
scope are not authorized. Do not change labels, placeholders, identifiers,
accessibility labels/values, focus ownership, validation or disabled
predicates, picker tags, action order, bindings, or save behavior.

## Mandatory pre-merge gate

Task 2 is not acceptance and does not authorize merge. Before the VD2-07b PR
can merge, Task 3 and independent review must provide all of the following:

1. The four Task-1 methods GREEN with their preservation behavior intact,
   plus the specified Contacts, Pipeline, Settings, and lower-layer signed
   regression evidence; no skip or expected failure.
2. A finalized signed result bundle exactly named
   `VD2-07b-reference-faithful-visuals.xcresult` containing **16 distinct**
   captures: edit/new Contacts and add/overview Opportunity, each at
   1600 x 1000 and 860 x 640, idle and keyboard-focus states. The attachment
   names, app-frame tolerance, route readiness, label-above-control,
   no-clipping, and wide-column/compact-stack geometry assertions must meet
   `VD2-07b-reference-faithful-form-visual-amendment.md`.
3. An independent QA comparison of every finalized capture against the
   product-owner Contacts and Opportunity references, including idle/focus
   hierarchy, compactness, non-color focus proof, dividers/rhythm, Contacts
   concision, and Opportunity responsiveness. An implementer self-review or
   selector-only result is insufficient.
4. Fresh independent code review, QA, architecture, security/privacy, TPM,
   and Delivery acceptance; signed Debug build/signature evidence;
   attachment/privacy inspection; `git diff --check`; explicit
   unchanged-native-file-panel attestation; retained VD2-08 debt handoff;
   and product-owner hands-on verification.

Any failed behavior, persistence/audit, security/privacy, native-panel,
accessibility-debt, signing, fixture, or visual evidence condition revokes
this release and returns the work to diagnosis. This release covers VD2-07b
Task 2 only; VD2-07c, VD2-07d, and VD2-08 remain closed.
