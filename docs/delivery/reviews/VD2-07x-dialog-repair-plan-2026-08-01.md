# VD2-07x — Dialog visual repair planning review

**Date:** 2026-08-01
**Reviewer role:** Independent planning
**Decision:** Ready for independent release review; no implementation is
authorized by this planning record.

## Materials reviewed

- Approved owner visual amendment:
  `docs/delivery/reviews/VD2-07x-owner-feedback-visual-amendment-2026-08-01.md`
- Independent Task 2 code review:
  `docs/delivery/reviews/VD2-07x-task2-code-review-2026-08-01.md`
- Task 2 delivery report:
  `.superpowers/sdd/2026-08-01-vd207-reference-faithful-recovery-screen/task-2-report.md`
- Controlling Task 2 brief:
  `docs/delivery/task-briefs/VD2-07x-reference-faithful-settings.md`
- Proposed repair brief:
  `docs/delivery/task-briefs/VD2-07x-dialog-visual-repair.md`

## Confirmed repair boundary

The evidence supports exactly two P1 implementation defects in
`SettingsProtectedExportSuccessDialog`:

1. the `Done` label is expanded after `RekonPrimaryButtonStyle` paints the
   background, leaving the visible gradient at intrinsic width; and
2. the modal panel has an outline but no deliberate elevation shadow.

The repair brief limits production code to the dialog declaration. It neither
changes the global button style nor modifies the root export-success event,
real-write guard, safe filename projection, export destination selection,
fixture state, Settings navigation, dashboard, or carried VD2-08
accessibility assertions.

## Test strategy assessment

The brief takes a justified two-part approach:

1. a focused source-consumer check makes the style-ordering and single-shadow
   contract reproducible without creating a forbidden fixture or test-only
   success state; and
2. the existing focused fixture UI tests prove the Recovery surface and the
   absence of invented success, while a normal signed Debug real export supplies
   the only valid visual evidence of the dialog itself.

The normal-Debug capture cannot be automated safely because it requires the
product owner's ordinary enrolled workspace, recovery-key entry, and newly
empty destination. The brief correctly keeps those credentials and destination
under product-owner control and requires an app-window-only image with no
sensitive content.

## Required independent decisions before implementation

| Role | Decision needed |
| --- | --- |
| Architecture | Confirm no root ownership, event, or safe-data boundary widens. |
| QA | Confirm the focused build/UI/source-consumer/capture procedure is sufficient and no fixture success is introduced. |
| Security/privacy | Confirm no credential, raw path, key, or document metadata can enter source, test, log, or evidence. |
| TPM | Confirm the repair remains the only eligible VD2-07x slice and VD2-08 stays separate. |
| Delivery | Issue a bounded release to one fresh implementer and record the eventual evidence. |

## Planning result

The brief is granular, test-first, and limited to a single independently
rejectable visual repair. It is appropriate to seek the required independent
release decisions. This review does not approve source changes or update task
status.
