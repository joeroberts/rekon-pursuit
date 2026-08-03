# VD2-04 fidelity rebuild — QA strategy and Task 1 gate

**Date:** 2026-07-30  
**Role:** independent QA/test gate  
**Controlling design:** `docs/superpowers/specs/2026-07-30-vd204-pipeline-fidelity-rebuild-design.md`  
**Verdict:** **REJECT — do not release Task 2 yet**

## Gate finding

The proposed `pipeline` fixture is isolated, synthetic, UUID-session scoped,
and fixed-clock deterministic. It is therefore the correct fixture *mechanism*.
It is not, however, sufficient for the approved Board mapping contract: its
current seeded records are only Applied, Screening, Interviewing, and Closed.
It has no Saved or Offer opportunity. A Board test using that fixture cannot
prove a four-primary-lane Board, lane counts, the Saved/Offer card treatment,
or exact-stage retention across all required primary stages.

Before a red contract is written, the Task 2 scope/brief must explicitly allow
a test-host-only deterministic fixture expansion (or name another existing
fixture that supplies all of the following):

| Required seeded fact | Current `pipeline` fixture | Required for release |
| --- | --- | --- |
| Saved opportunity | Missing | One stable record |
| Applied opportunity | Present | One stable record |
| Screening opportunity | Present | One stable record |
| Interviewing opportunity | Present | One stable record |
| Offer opportunity | Missing | One stable record |
| Closed opportunity | Present | One stable record, hidden by default |
| selection, next action, due date, locality | Partial | At least one rich deterministic selected record and one card in every primary visual lane |

This is a test-fixture change only: it must remain under
`#if REKON_UI_TEST_HOST`, use the existing fixture-specific encrypted temporary
workspace and fixed clock, and must not change production records, models,
persistence semantics, or Board behavior. Once Planning/Architecture/TPM make
that correction explicit, QA will approve release to Task 2.

## Deterministic capture matrix

All automated visual evidence launches the configured signed UI-test host using
the `pipeline` fixture and its per-test UUID session. Do not use a personal
workspace or an ad-hoc unsigned build. The known compact surface is **860×640**
(the shell minimum), even though the original requested nominal height was
860×600. The wide surface must be the established `wide` fixture window.

| Capture name | Fixture / presentation | Required state before attachment |
| --- | --- | --- |
| `vd204-fidelity-wide-table` | `pipeline`, wide, Table | all stages; one selected row; inspector visible; no external dialog |
| `vd204-fidelity-compact-table-drawer` | `pipeline`, compact, Table | one selected row; in-place right drawer open; no sheet/modal |
| `vd204-fidelity-wide-board` | `pipeline`, wide, Board | Include closed off; four primary lanes visible; no external dialog |
| `vd204-fidelity-compact-board` | `pipeline`, compact, Board | Include closed on; primary lanes plus secondary Closed lane are intentionally inspectable or horizontally reachable; no external dialog |

Attachments use `.keepAlways`, are named exactly as above, and are captured
after the surface has settled but before Import CSV is activated. They are
evidence for independent human comparison, not a substitute for semantic UI
assertions.

## RED-first contracts

### Pure mapping contract

The implementation must expose a pure, nonisolated, view-local mapping seam
that can be tested without rendering. Its test must prove:

1. Saved contains only `Saved`.
2. Applied contains exactly `Applied` and `Screening`.
3. Interviewing and Offer contain only their matching exact stages.
4. Closed is separate and is appended only when the existing Include closed
   filter is true.
5. A card’s displayed stage remains its precise underlying stage; `Screening`
   must never be presented as `Applied`.
6. The mapping does not call model mutation, store, routing, import, activity,
   or drag/drop code.

This test must be intentionally RED before production presentation changes;
compile, fixture, signing, or unrelated failures do not count as a valid RED.

### Wide Table contract

The signed UI test must assert stable, app-owned accessibility identifiers for
all of the following (the exact identifier spellings may be chosen by the
implementer and then frozen in the test):

- table region;
- five column headings: Role, Employer, Stage, Next action, Due date;
- result-count footer;
- selected row with selected semantic value and no radio/check-box child;
- inspector identity/mark, title, company/location, precise stage chip,
  structured facts, and outlined `Open details` action.

The test also taps a row, then **Open details**, and confirms the existing
canonical route still opens. It does not merely assert that static text exists.

### Compact Table/drawer contract

At 860×640, the test selects a row and asserts an app-owned drawer whose right
edge equals the table region's right edge and whose bounds are within the table
region. It asserts no `sheet`, no below-list inspector/empty state, no radio
or check-box row selector, and a functional compact close control. It asserts
the defined compact metadata policy (hidden columns/abbreviated cells) rather
than accepting a return to an unstructured, tall-card list.

### Board contract

With Include closed off, assert exactly four primary app-owned lane headers
and counts: Saved, Applied, Interviewing, Offer. For each primary lane assert
an add affordance and an icon/menu affordance when that presentation is
implemented. Assert at least one rich card across the fixture with employer
identity, **exact** stage chip, location/work arrangement, next action, and
due date. Assert the `Screening` card is in Applied lane while retaining a
`Screening` chip.

Toggle the existing `pipeline-include-closed` checkbox and assert one
secondary Closed lane and its Closed card appear. Toggle it back and assert
both disappear. Cards must retain the existing `pipeline-opportunity-<id>`
identity and selection/open route behavior. The test must not attempt or
expect drag/drop, stage mutation, or persistence changes.

### Retained VD2-04 regression suite

The fidelity suite is additive. None of these current checks may be deleted,
weakened, or replaced by screenshot-only evidence:

| Existing test | Required retained behavior |
| --- | --- |
| `testVD204PipelineTableSelectsAnEphemeralInspectorAndOnlyOpenDetailsRoutes` | selection is local; only Open details routes |
| `testVD204PipelineCompactWindowUsesAnInPlaceRightDrawer` | drawer geometry, close behavior, no sheet/below-list inspector |
| `testVD204PipelineTableSelectionHasNoRadioChildControl` | no radio/check-box selector |
| `testVD204PipelineCompactToolbarKeepsTheViewSwitcherOnOneLine` | compact label omitted; wide label exists |
| `testVD204PipelineControlsRemainKeyboardDiscoverableAndStyled` | native controls, local filters, Import route, Table/Board switch |
| `testVD204PipelineNavySurfaceControlsRemainSemanticallyOperableInTableAndBoard` | semantic activation in both layouts and existing captures |
| `testVD204ShellExposesOnlyTheAppOwnedSidebarToggle` | exactly one app-owned toggle/no framework duplicate |
| `testVD202CompactRailKeepsNativeWindowControlsReachable` | compact native window chrome remains reachable |
| `testVD204PipelineOpenDetailsSavesAndRelaunchesCanonicalEditWithActivityEvidence` | canonical persistence/activity evidence remains intact |
| `testVD204PipelineFiltersUseOnlyTheSessionLocalControlsAndExposeTruthfulNoResults` | filters remain session-local and truthful |
| `testVD204DeletingASelectedTableRowUsesTheExistingConfirmationAndClearsTheInspector` | existing destructive confirmation/selection behavior remains intact |

## Visual acceptance/rejection protocol

Independent QA compares the four named signed captures side-by-side with the
three supplied Pipeline mockups at like viewport scale. Passing XCTest alone
does not satisfy this gate.

| Surface | Accept only if | Reject if |
| --- | --- | --- |
| Desktop Table | compact aligned five-column table, employer identity/mark, stage chips, date/action hierarchy, result footer, cyan/violet selected row, and a rich inspector are visibly present | vertically stacked generic cards, missing columns/footer, a neutral-gray selected band, or a generic Selection summary panel |
| Toolbar | navy/cyan controls have mockup-like spacing and icon-led clarity; Import is outlined secondary; Add opportunity is the sole gradient primary | wrapped View, hidden/ambiguous Table/Board choice, Import shown as a gray/generic primary, or second gradient action |
| Inspector/drawer | employer mark/identity, hierarchy, structured facts, close treatment at compact size, and outlined Open details are visible | modal, below-list details, missing hierarchy, or an inspector that simply repeats a card summary |
| Wide Board | four broad primary lanes use the approved grouped mapping, rich compact cards, counts, intentional empty state, and add affordances | six narrow equal stage columns, a predominantly blank canvas, stripped title/company-only cards, or a changed drag/drop workflow |
| Compact Board | controlled overflow/adaptation keeps cards/lane headers usable and preserves the app’s native accessible controls | arbitrarily squeezed columns, clipped controls, loss of stage distinction, or a fabricated responsive workflow |
| Shared surface language | deep navy tiers with restrained cyan/violet borders; readable type hierarchy; no gray native wells or large gray surfaces | literal/system gray chrome, flat generic controls, visible wrapper stealing focus/activation, or broken native roles |

## Required signed execution and QA verdict conditions

Run RED and GREEN with configured signing; do **not** use
`CODE_SIGNING_ALLOWED=NO`:

```sh
xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:RekonPursuitTests/RekonPursuitTests/testVD204PipelineBoardLaneMappingRetainsPreciseStages \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD204PipelineFidelityTableContract \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD204PipelineFidelityBoardContract \
  -resultBundlePath /tmp/rekon-vd204-pipeline-fidelity-red.xcresult
```

The final GREEN invocation uses the same focused test set and
`/tmp/rekon-vd204-pipeline-fidelity.xcresult`, then runs the retained suite
above. `codesign --verify --deep --strict` must pass for the generated Debug
product. A fresh QA verifier must inspect result-bundle attachments, exact AX
roles/identifiers, keyboard activation, and visual capture matrix.

**Release condition:** update the deterministic `pipeline` fixture requirement
in the work-item/plan, have Architect and TPM concur that this remains
test-host-only presentation evidence, and record Delivery Manager release.
Until then, QA rejects Task 2 because its promised Board proof is impossible
with the current fixture data.

---

## QA release addendum — fixture-gap correction reviewed

**Date:** 2026-07-30  
**Role:** independent QA/test gate  
**Verdict:** **Accepted for Task 2 only — deterministic fixture expansion,
fixture-inventory contract, and intentional RED fidelity contracts may begin.**

### Independent re-review

The amended [task brief](../../task-briefs/VD2-04-pipeline-fidelity-rebuild.md)
and [implementation plan](../../../superpowers/plans/2026-07-30-vd204-pipeline-fidelity-rebuild.md)
now explicitly correct the finding above. They authorize a change only in the
existing `#if REKON_UI_TEST_HOST` `VisualFixtureWorkspace.seedFixtureIfNeeded`
Pipeline branch and its `RekonPursuitUITestHostTests` contract. The source seam
is conditionally compiled for the dedicated UI-test host, and the plan retains
the UUID-scoped encrypted temporary workspace, fixed clock, and teardown
behavior. This is sufficient isolation for synthetic presentation evidence;
it does not authorize a product fixture, model/store, persistence, activity,
route, import, or Board-workflow change.

The fixture contract is now explicit and adequate: exactly one deterministic
record in each precise stage (`Saved`, `Applied`, `Screening`, `Interviewing`,
`Offer`, and `Closed`), with title, company, locality, specified work
arrangement, next action, and due date for every record. It also requires the
existing Include closed behavior to keep Closed absent from the default
visible set. This closes the prior inability to prove the Saved and Offer
lanes and allows the grouped Applied/Screening lane to prove that its cards
retain their exact stage.

### Conditions retained without relaxation

This release does **not** accept a fixture/build/signing failure as RED
evidence. The implementation sequence remains:

1. Prove the new fixture-inventory contract RED, then GREEN, before visual
   fidelity contracts are added.
2. Prove the pure mapping and Table/Board UI contracts intentionally RED only
   for missing presentation, never for fixture, compile, signing, or unrelated
   behavior failure.
3. Preserve every listed prior VD2-04 regression; no existing assertion may be
   deleted, weakened, or replaced with screenshot-only evidence.
4. Produce and retain the four named `.keepAlways` captures:
   `vd204-fidelity-wide-table`, `vd204-fidelity-compact-table-drawer`,
   `vd204-fidelity-wide-board`, and `vd204-fidelity-compact-board`, at the
   required fixture states and before an external dialog opens.
5. Run the final focused and retained suites in signed Debug without passing
   `CODE_SIGNING_ALLOWED=NO`, verify the generated product signature, and have
   a fresh QA verifier inspect result attachments, AX roles/identifiers,
   keyboard activation, and the visual acceptance matrix.

The existing test-host target's signing configuration is not changed or
accepted by this documentation release. At Task 2 execution, the stipulated
signed-artifact command/result must be demonstrated; otherwise neither the
fixture GREEN nor a visual RED/GREEN bundle can satisfy the QA gate.

### Scope and release boundary

The Architect ADR's view-local, reversible lane mapping and the TPM's
presentation-only boundary remain consistent with this strategy. This QA
decision authorizes **only Task 2**. It does not accept the fidelity rebuild,
does not release Tasks 3–4, does not authorize drag/drop or any workflow/data
change, does not advance VD2-05, and does not constitute product-owner
acceptance of VD2-04.
