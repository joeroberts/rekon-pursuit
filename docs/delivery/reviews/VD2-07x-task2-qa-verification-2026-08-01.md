# VD2-07x Task 2 — independent QA verification

**Date:** 2026-08-01  
**Role:** Fresh independent QA/test verifier  
**Verdict:** **NEEDS CHANGE — the automated and fixture visual evidence is accepted; the required normal-Debug, real-export dialog verification remains outstanding.**

## Scope and method

I reviewed the controlling Task 2 brief, the owner-feedback visual amendment,
the Task 2 implementation report, the VD2-08 accessibility deferral, the
current screenshot seam, and the referenced signed result bundles and
attachment manifests. I did not alter production source, tests, fixtures,
dashboard state, or result bundles.

Reviewed records:

- `docs/delivery/task-briefs/VD2-07x-reference-faithful-settings.md`
- `docs/delivery/reviews/VD2-07x-owner-feedback-visual-amendment-2026-08-01.md`
- `.superpowers/sdd/2026-08-01-vd207-reference-faithful-recovery-screen/task-2-report.md`
- `docs/delivery/task-briefs/VD2-07x-vd208-accessibility-deferral-addendum.md`

## Signed execution evidence

| Evidence | Direct xcresult summary | QA result |
| --- | --- | --- |
| Literal Task 2 matrix: `/private/tmp/rekon-vd207x-task-2-owner-final.xcresult` | 43 total: **40 passed**, **3 failed**, **0 skipped**, **0 expected failures**. Signed Debug, macOS arm64, macOS 26.5.2 (25F84). | Accepted for VD2-07x under the owner-approved VD2-08 classification. |
| Required companion: `/private/tmp/rekon-vd207x-task-2-companion.xcresult` | `testVD207ReferenceTabsSelectByPointerAtCompactWidth` and `testVD207ReferenceAIVisualContentBoundary` each ran once and passed: **2/2**, 0 failed/skipped/expected. | Accepted. |
| Owner correction: `/private/tmp/rekon-vd207x-owner-correction.xcresult` | Pointer compact selection, wide Recovery composition, and AI visual boundary each ran once and passed: **3/3**, 0 failed/skipped/expected. | Accepted. |
| Wide supplemental: `/private/tmp/rekon-vd207x-owner-correction-wide-other.xcresult` | `testVD207ReferenceOtherSettingsSectionsUseTruthfulInformationalCards` ran once and passed: **1/1**, 0 failed/skipped/expected. | Accepted. |

The literal matrix's three failures are exactly the unchanged VD2-08 handoff
tests, and no other selector failed:

1. `testVD207ReferenceTabsKeepKeyboardSelectionAtCompactWidth` — the expected
   `Not selected; Keyboard focus` / `Selected; Keyboard focus` values instead
   observed `Not selected`, followed by the existing Tab/Space panel snapshot
   failure.
2. `testVD207SettingsSecondaryNavigationIsKeyboardOperableAtCompactWidth` —
   the same compact keyboard-focus/Tab/Space observation.
3. `testVD207SettingsDocumentAndAISectionsStayAggregateAndUnavailable` — its
   unchanged `Any` and `StaticText` AI informational-label predicates for `No
   AI requests`, `Gmail`, and `Calendar` failed. The focused AI visual/content
   boundary test independently passed its visible-copy, aggregate, privacy,
   no-control, and no-metadata assertions.

Those tests executed and failed; none was skipped, expected-failed, guarded,
or reclassified as passing. This matches the bounded VD2-08 deferral and does
not carry any visual, rail, route, fixture-date, export, privacy, metadata, or
action-control failure forward.

## Fixture attachment review

The older desktop-inclusive exports are explicitly rejected as visual-review
evidence. The current evidence was created through
`app.windows.firstMatch.screenshot()` and is limited to the application
window; it does not show the desktop, Finder, a chooser, or another app.

I inspected the current manifests and app-window captures:

- `/private/tmp/rekon-vd207x-visual-evidence/owner-correction-attachments/manifest.json`
  supplies wide Recovery and AI plus all four compact section captures. The
  compact Recovery capture shows the cyan-tinted rounded selected row and no
  detached underline; the wide Recovery capture retains the cyan bottom rule.
- `/private/tmp/rekon-vd207x-visual-evidence/owner-correction-wide-other-attachments/manifest.json`
  supplies the current wide Workspace, Document references, and AI captures.

Together they cover the required four wide and four compact Settings surfaces.
The reviewed captures are app-window-only and did not disclose a recovery key,
destination path, file chooser, document path/name, hash, bookmark, MIME type,
checksum, or receipt.

## Real-success dialog boundary

The success dialog has not been fabricated for a fixture or test-only state.
Current source presents it only when the root projection receives the existing
`protectedExportSuccess` event; that event is published after the real
protected-export creation call returns and its token/store checks hold. The
fixture/default source has no success injection, and no repository test/demo
control creates the dialog.

This is correctly retained as the separate manual normal-Debug owner export
verification. The required app-window-only artifact
`/private/tmp/rekon-vd207x-visual-evidence/VD2-07x-real-export-success.png`
is presently absent, so I cannot accept Task 2 in full. The tester must use an
ordinary enrolled local workspace and real empty destination, inspect the
safe-filename/`Selected local folder` dialog hierarchy against the supplied
reference, press `Done`, and verify that the active workspace is unchanged.
No recovery key, chooser, raw path, or desktop may be captured.

## Required closure

Provide the single normal-Debug real-export dialog capture and manual
verification described above. Then rerun only the independent acceptance
review; do not manufacture a fixture success or change the existing VD2-08
handoff tests to close this item.
