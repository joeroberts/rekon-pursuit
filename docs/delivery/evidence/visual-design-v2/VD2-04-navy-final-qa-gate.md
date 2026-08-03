# VD2-04 navy-surface correction — final QA visual gate

**Role:** Independent QA/test verifier  
**Date:** 2026-07-30  
**Verdict:** **Accepted for renewed product-owner review.**

## Evidence independently inspected

| Evidence | Result | QA finding |
| --- | --- | --- |
| Signed-Debug recovery suite: `/tmp/rekon-vd204-recovery-qa-20260730-1.xcresult` | `xcresulttool` reports `Passed`: 7 total, 7 passed, 0 failed, 0 skipped on arm64 macOS. | Covers the navy presentation contract plus Table/Board semantic operation, compact right drawer, no row radio child, compact View treatment, control accessibility/activation, and the one app-owned sidebar toggle. |
| Recovery attachment manifest: `/tmp/vd204-delivery-attachments.YmQ4n6/manifest.json` | Four retained, non-failure-associated captures exist: `VD204 navy surface — wide Table`, `wide Board`, `compact Table`, and `compact Board`. | I manually inspected those four captures and the compact selected-row/drawer capture. They show layered navy content surfaces; a compact right-side details drawer; an unwrapped `View` control; no row radio/check-circle selector; and one app-owned sidebar control. |
| Configured Debug product: `/tmp/rekon-vd204-current-product-qa/Build/Products/Debug/RekonPursuit.app` | `codesign -dvv` identifies `com.rekonlabs.RekonPursuit`, signed by `Apple Development: jaroberts4@gmail.com (PT7GS96H3L)`, team `2UA854NLX4`. | This is a signed product, not the isolated test host. |
| Actual signed-product captures | Inspected at normal scale: [Table](</var/folders/g8/tb13s4dd31vbnlx91kq133j40000gn/T/com.openai.sky.CUAService/RekonPursuit Screenshot 2026-07-30 at 6.49.39 PM.jpeg>), [Board](</var/folders/g8/tb13s4dd31vbnlx91kq133j40000gn/T/com.openai.sky.CUAService/RekonPursuit Screenshot 2026-07-30 at 6.50.01 PM.jpeg>), and [focused Board control](</var/folders/g8/tb13s4dd31vbnlx91kq133j40000gn/T/com.openai.sky.CUAService/RekonPursuit Screenshot 2026-07-30 at 6.50.10 PM.jpeg>). | Confirms the product—not only XCTest—renders deep navy Pipeline canvas, list rows, Board columns/cards, Search, Stage, Include closed, segmented Table/Board control, and Import CSV secondary action. No dominant neutral-gray surface, opaque gray native well, gray segmented track, or gray checkbox surround is visible. |

## Visual comparison against the approved references

The owner-provided Table and Board references establish the intended hierarchy:
deep-navy surfaces, restrained blue/cyan outlines, a navy outlined Import CSV
action, and a single cyan-to-violet Add opportunity primary action. The signed
product captures meet that system-level comparison:

- Search, Stage, Include closed, and Table/Board use navy fills with blue/cyan
  outlines; their native macOS gray chrome is not visible.
- Import CSV is a distinct navy outlined secondary action, while Add
  opportunity is the sole gradient primary action.
- Table rows and Board columns/cards are layered navy with restrained borders;
  they do not revert to the large gray blocks reported by the product owner.
- The `View` label remains on one line in the evidence. The recovery capture
  verifies its compact treatment is label omission rather than wrapping.
- The focused Board capture visibly retains the cyan focus/selection treatment.
  The recovery suite also verifies keyboard discoverability and activation of
  the actual controls.

## Retained VD2-04 behavior

The fresh 7/7 bundle names and passes all retained VD2-04 regression tests:

1. `testVD204PipelineNavySurfacePresentationContract`
2. `testVD204PipelineNavySurfaceControlsRemainSemanticallyOperableInTableAndBoard`
3. `testVD204PipelineCompactWindowUsesAnInPlaceRightDrawer`
4. `testVD204PipelineTableSelectionHasNoRadioChildControl`
5. `testVD204PipelineCompactToolbarKeepsTheViewSwitcherOnOneLine`
6. `testVD204PipelineControlsRemainKeyboardDiscoverableAndStyled`
7. `testVD204ShellExposesOnlyTheAppOwnedSidebarToggle`

This is sufficient evidence for the VD2-04 visual-correction gate. It does
not change Pipeline data, persistence, routing, import semantics, or Board
workflow scope.

## Honest limitation

The actual-product captures supplied for this review are **wide only**. The
wide signed product demonstrates the gray-chrome correction in Table and
Board and a focused Board state; compact Table/Board, right-drawer, no-radio,
unwrapped-View, and single-sidebar-control evidence comes from the freshly
signed 7/7 UI-test host and its retained attachments. I do not claim a new
wide-and-compact actual-product capture matrix beyond the three files listed
above.

That limitation does not invalidate the narrowly scoped final QA verdict: the
product-level gray regression is visibly resolved in both Pipeline modes, and
the signed UI suite independently preserves the compact VD2-04 contracts.
VD2-04 remains **in progress** until renewed explicit product-owner
acceptance; this QA gate does not release VD2-05 or mark the card accepted.
