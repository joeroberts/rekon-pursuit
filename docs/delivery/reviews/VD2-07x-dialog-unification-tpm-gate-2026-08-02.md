# VD2-07x protected-export dialog unification — TPM gate

**Date:** 2026-08-02
**Role:** Fresh independent TPM pre-implementation gate
**Verdict:** **ACCEPT — conditional implementation release; do not dispatch yet.**

## Decision

The owner-approved dialog-unification design and amended one-slice plan are
the only dependency-safe candidate within the current `VD2-07` work, provided
the remaining independent gates and a Delivery-managed shared-file isolation
check pass first. It is a presentation-only correction to the already
root-owned protected-export journey: one custom root overlay supplies entry
and confirmation modes, while the existing verified-success overlay remains
unchanged and mutually exclusive.

The plan now resolves the open pre-gate requirements. It retains the custom
Cancel control's cancel role and cancel-action keyboard semantics; it adds the
post-cancel disappearance checks; it runs the three previously omitted model
protections with inspectable detailed results; and it requires a redacted,
state-only signed owner-native checklist for entry, native chooser,
confirmation, and verified success. The security/privacy gate accepts the
same narrow data and authority boundary.

This is a TPM approval of scope and sequencing, not an implementation
dispatch, acceptance of `VD2-07`, or a dashboard transition.

## Dependency and release audit

| Dependency | Current assessment | Required before a fresh implementer starts |
| --- | --- | --- |
| Product decision and bounded plan | The 2026-08-02 design is owner-approved and the amended plan is specific to one dialog-unification slice. | Planning records approval of this exact amended plan and its test-first procedure. |
| Program sequence | `VD2-06` is accepted; `VD2-07` is `in_progress`; the dashboard has no separately released next task. `VD2-08` is backlog and depends on accepted `VD2-07`. | Keep the parent state unchanged; this slice is a child correction within `VD2-07`, not a new dashboard card. |
| Architecture | The earlier architecture gate required a plan-only cancel-semantics correction. The amended plan contains that requirement. | A fresh Architecture recheck records **ACCEPT** for the amended root-owned, exclusive-overlay and safe-input contract. |
| QA/test | The earlier QA gate required stronger cancel proof, the complete selected model suite, detailed result inspection, and a state-only native checklist. The amended plan contains all four. | A fresh QA recheck records **ACCEPT** for the amended RED/GREEN and owner-native procedure. |
| Security/privacy | The fresh security/privacy pre-gate is **ACCEPT**, conditional on the other releases and the existing safe-value boundary. | Preserve that boundary and obtain the required Delivery release; post-implementation security/privacy verification remains required. |
| Shared-file isolation | The current worktree has uncommitted work in all three implementation paths (`ContentView`, `SettingsView`, and the UI-test target). The dialog plan may not absorb or overwrite that work. | Delivery must establish a reviewed baseline and explicit hunk-isolation/integration procedure, and confirm no concurrent slice edits those same source or test hunks. |
| Native protected-export prerequisite | The prior save-panel leaf-authority code has independent technical approvals, but its owner-native signed chooser smoke is still pending. This dialog slice neither changes nor revalidates that implementation. | It is not a code-start dependency for this visual slice. It is a mandatory condition for the later signed owner-native end-to-end handoff and `VD2-07` completion; any native-flow failure returns to its own Save-panel gate. |

## Implementation-release condition

The status is **HOLD → eligible for one fresh implementer** only when all of
the following are recorded for this exact amended dialog plan:

1. Planning approval, Architecture recheck, QA recheck, Security/privacy
   acceptance, this TPM gate, and a fresh Delivery Manager release all accept
   the same boundary.
2. Delivery records the shared-file baseline and hunk-isolation method; no
   overlapping implementation may proceed in parallel.
3. The implementer receives only the allowed `ContentView`, `SettingsView`,
   and focused UI-test hunks, applies test-first RED/GREEN evidence, and is
   not reused as reviewer or verifier.

After implementation, separate code review, QA, Architecture deviation
review, and Security/privacy verification must accept the narrowed diff. The
signed owner-native run must record only redacted state observations and must
not retain recovery material, raw paths, output, or workspace data.

## Status-transition condition

No delivery status changes under this gate. `VD2-07` remains
**In progress**, `VD2-08` remains **Backlog/blocked**, and `DESIGN-V2` remains
**Backlog**. A Delivery Manager may record only the one-slice implementation
release after the conditions above; it must not mark the slice, parent card,
or Visual Design v2 program accepted.

`VD2-07` can advance only after this slice's independent post-implementation
and owner-native evidence is accepted **and** the outstanding signed native
Save-panel smoke and the other required `VD2-07` acceptance evidence are
independently closed. A failed native chooser or verified-export observation
is a return to the applicable existing gate, not permission to expand this
dialog task.

## Explicit non-release of successor or adjacent work

This gate releases neither a successor nor an adjacent implementation. It
does not authorize:

- Pipeline/Kanban behavior, any dashboard or roadmap edit, or a new dashboard
  task/status transition.
- `VD2-08` keyboard-focus, semantic-label/value, or broad visual/accessibility
  acceptance work; the existing deferral remains a recorded debt, not a test
  waiver.
- Save-panel configuration or authority work; export worker, ViewModel,
  persistence/store, activity/audit, schema, entitlement, signing, security
  scope, filename-extension, or file-operation changes.
- New security/privacy functionality, recovery-key handling, success content
  or timing changes, fixtures, launch paths, global theme/navigation changes,
  or unrelated Settings work.

The native chooser remains an unchanged existing action. The only allowed
post-release outcome is the one bounded dialog-unification implementation,
followed by its independent verification gates; no `VD2-08` or successor
release follows automatically.
