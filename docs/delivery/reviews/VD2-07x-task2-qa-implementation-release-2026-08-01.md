# VD2-07x Task 2 — QA implementation release

**Date:** 2026-08-01
**Role:** Independent QA/test reviewer
**Verdict:** **NEEDS CHANGE — one bounded test-plan correction is required before Task 2 is released.**

## Scope

This is a planning and test-strategy review only. It does not evaluate the
pre-implementation Settings rendering or claim Task 2 acceptance. The current
generic Settings UI is the expected pre-Task-2 state and is not a rejection
reason.

Reviewed:

- `docs/superpowers/plans/2026-08-01-vd207-reference-faithful-recovery-screen.md`
- `docs/delivery/task-briefs/VD2-07x-reference-faithful-settings.md`
- `docs/delivery/task-briefs/VD2-07x-vd208-accessibility-deferral-addendum.md`
- the current named VD2-07 UI contracts, solely to verify their coverage
  boundary.

## Coverage that is ready

The Task 2 plan retains the required deterministic fixtures and their fixed
archive date; the original 43-selector signed matrix; event/token, root-modal,
archive, lower-layer, route, privacy, no-control, and cancellation coverage;
and the eight required wide/compact fixture attachments plus the normal-app,
real-success dialog capture. The no-success-at-launch test remains correct.

The VD2-08 addendum is also clear that the existing compact Tab/Space/focus
tests and AI role/label/value test remain unchanged, execute as evidence, and
may be carried only for their specifically documented accessibility failures.
They cannot be skipped, weakened, or relabeled as green.

## Blocking test-plan gap

The addendum requires Task 2 to add both focused proof paths below, independent
of the deferred tests:

1. pointer selection of every compact local Settings tab; and
2. an AI visual/content-boundary check.

Neither is a named test in the Task 2 plan or brief, and neither is invoked by
the literal 43-selector Task 2 matrix. The existing compact reference test is
keyboard-only (`tabToKeyboardFocus` and Space), while the existing Document/AI
test is the semantic role/label/value evidence expressly carried to VD2-08.
They therefore cannot provide the required independent V2-07x proof.

## Required correction before release

Amend the Task 2 test procedure with a signed, parseable focused companion run
(the literal 43-selector matrix remains unchanged and is still required):

1. Add a compact `populated`-fixture pointer test. It must tap each existing
   selector — `settings-section-workspace`,
   `settings-section-recovery-archives`,
   `settings-section-document-references`, and
   `settings-section-ai-connections` — and, after each tap, prove the matching
   panel, selected global `sidebar-settings` rail, and selected local tab. It
   must attach the corresponding `VD2-07x-compact-*` screenshot after each
   selected panel. It must not change either deferred keyboard test.
2. Add a `document-relink`-fixture AI visual/content-boundary test. It must use
   the existing AI selector, prove the AI overview, assistant, email/calendar,
   cloud, and privacy cards plus their truthful visible copy; retain aggregate,
   no-actionable-control, and no-metadata checks; and attach
   `VD2-07x-wide-ai-connections`. It must leave the existing `Any` and
   `StaticText` semantic assertions intact as VD2-08 evidence rather than
   folding their role/label/value outcome into this visual pass.
3. Name both focused tests in the amended procedure and record their signed
   execution once, alongside the literal matrix. The companion result must
   report zero skip and zero expected failure. The release record must still
   list any carried keyboard or AI semantic result with its exact assertion,
   observed role/label/value, platform evidence, and VD2-08 requirement.

The required wide Workspace, Recovery, and Document screenshots remain part of
the original literal-matrix evidence procedure. The ordinary signed-Debug
real-export dialog check remains manual by design: it must show only the safe
filename, `Selected local folder`, reminder, and `Done`, and prove dismissal
does not change the active workspace.

## Release boundary after correction

Once that narrow test-procedure correction is accepted, QA considers Task 2
test-first and dependency-safe to implement, subject to the plan's existing
Task 1 checkpoint/continuation gate. This does not release Task 2 completion:
the eventual independent QA decision still requires the literal matrix,
focused companion run, fixture attachments, real-success dialog evidence, and
separate reporting of the retained VD2-08 accessibility observations.
