# VD2-04 — Pipeline navy-surface QA strategy

**Role:** Independent QA/test agent  
**Date:** 2026-07-30  
**Status:** Task 0 QA release gate — approved with required evidence conditions

## Scope and baseline

This strategy verifies the owner-approved VD2-04 presentation correction in
`docs/superpowers/specs/2026-07-30-vd204-pipeline-navy-surface-correction-design.md`
and its task brief. It applies to the shared Pipeline presentation in both
Table and Board, not to Board behavior, data, routing, persistence, activity,
or import semantics.

The visual comparison baseline is the owner-supplied reference set:

| Reference | Intended comparison use |
| --- | --- |
| `/Users/jroberts/Downloads/rekon_pursuit_pipeline.png` | Wide Table: layered navy canvas/table/inspector, cyan-outline secondary controls, and a single gradient primary action. |
| `/Users/jroberts/Downloads/ rekon_pursuit_pipeline_2.png` | Wide Board: shared top-control treatment and layered navy board/card surfaces. |
| `/Users/jroberts/Downloads/rekon_pursuit_pipeline_3.png` | Wide Board: alternate board/card hierarchy and control treatment. |

The references establish a visual system, not a pixel-perfect content or data
fixture. QA compares hierarchy, contrast, chrome ownership, and interaction
states; it does not require the sample opportunities, avatars, dates, or board
column counts in those images.

## Current test inventory and gap

The existing VD2-04 UI suite already exercises the native Pipeline semantics:

- `testVD204PipelineCompactWindowUsesAnInPlaceRightDrawer`
- `testVD204PipelineTableSelectionHasNoRadioChildControl`
- `testVD204PipelineCompactToolbarKeepsTheViewSwitcherOnOneLine`
- `testVD204PipelineControlsRemainKeyboardDiscoverableAndStyled`
- `testVD204ShellExposesOnlyTheAppOwnedSidebarToggle`

Those tests are valuable regressions, but their role/identifier assertions and
generic screenshots do **not** prove that AppKit no longer paints gray native
chrome. The new named navy-surface contract and its four intentional captures
are mandatory; a green semantic test alone cannot release this correction.

## Red-first test strategy

### 1. Pure presentation contract

Before production restyling, add
`testVD204PipelineNavySurfacePresentationContract` in
`RekonPursuitTests/RekonPursuitTests.swift`. The test must use a nonisolated,
equatable semantic-token seam rather than compare `SwiftUI.Color` directly.

It must cover every interaction state: idle, pointer hover, keyboard focus,
pressed, selected, and disabled. At minimum, it asserts:

| State | Required fill / outline | Required measurable treatment |
| --- | --- | --- |
| Idle | `surface` + `border` | 1-point outline, full opacity |
| Pointer hover | `elevatedSurface` + `accent` | Visibly distinct from idle |
| Keyboard focus | `elevatedSurface` + `violet` | 2-point outline |
| Pressed | Navy tier only | 0.62 opacity, not a gray system press fill |
| Selected | Architect-recorded navy selected tier | Distinct selected outline/fill |
| Disabled | Navy tier only | 0.42 opacity |

The initial focused signed-Debug unit run must be deliberately RED because the
new presentation API is absent or still maps to an invalid token. Preserve
that result bundle. A setup, fixture, signing, or unrelated test failure is
not an acceptable RED result.

### 2. Semantic operation and capture contract

Before production restyling, add
`testVD204PipelineNavySurfaceControlsRemainSemanticallyOperableInTableAndBoard`
in `RekonPursuitUITests/RekonPursuitUITests.swift`. It launches the isolated
`pipeline` fixture at both supported sizes:

- **wide**: current wide fixture host size;
- **compact**: requested 860x600 host, whose established actual window is
  860x640 and must be asserted as such.

For each size, the test must produce a pre-dialog `XCTAttachment` screenshot
in both Table and Board, with these exact, durable names:

1. `VD204 navy surface — wide Table`
2. `VD204 navy surface — wide Board`
3. `VD204 navy surface — compact Table`
4. `VD204 navy surface — compact Board`

Attachments are retained with `.keepAlways`, taken only after the controls are
visible and before Import CSV opens the file chooser. The tests may prove that
the fixture rendered and controls operate; they are evidence for later visual
inspection, not a pixel/color oracle.

The semantic assertions must exercise all existing control contracts in Table
and Board without loosening current roles or labels:

| Control / ID | Required role and operation |
| --- | --- |
| `opportunity-search` | Editable `textField`; type a deterministic non-match, see truthful no-results state, then clear. |
| `pipeline-stage-filter` | Discoverable `popUpButton` labelled `Stage`; open it, observe `All stages`, then cancel without changing the fixture. |
| `pipeline-include-closed` | Discoverable `checkBox` labelled `Include closed`; activate it and prove seeded closed data becomes visible. |
| `pipeline-view-mode` | Hittable exclusive Table/Board chooser with its retained identifier and child radio-button activation; Table -> Board -> Table restores the proper region. |
| `pipeline-import-csv` | Hittable `button` labelled `Import CSV`; capture first, then invoke until existing `choose-csv-file` appears. |

Run the new UI test as RED before production changes. Its intentional initial
failure must be the absent new contract/capture path or an expected
navy-presentation assertion—not a test-host or signing failure.

## Green verification protocol

### Automated, signed Debug evidence

After the implementation, run the focused green command from the task brief
without `CODE_SIGNING_ALLOWED=NO`, preserving the result bundle at
`/tmp/rekon-vd204-navy-surface-green.xcresult` (or a documented unique rerun
path). It must include the new unit/UI tests and all existing VD2-04 checks:

- navy presentation mapping;
- Table/Board semantic operation and four capture attachments;
- compact right drawer;
- no row radio child control;
- compact/wide unwrapped View treatment;
- native-control discoverability and activation;
- one app-owned sidebar control.

The runner additionally verifies the produced Debug application with
`codesign --verify --deep --strict --verbose=2`. The result evidence records
the exact bundle path, test count, command, date, and configured signing
identity. The test-host captures are regression evidence; they do not replace
the product capture below.

### Actual signed-product visual review

Independently build the configured **Debug** product, verify its signature,
and launch that product—not an ad-hoc or unsigned test host—using the
deterministic `pipeline` fixture and the same wide/compact sizes. Capture four
product screenshots matching the attachment matrix above. Before each capture:

1. Navigate to Pipeline and confirm Table or Board is selected as named.
2. Ensure the import file chooser is not present.
3. Keep the sidebar visible for the primary comparison; compact captures also
   confirm the app-owned sidebar action remains singular.
4. For compact Table, select then close a row once during the session to show
   that the details treatment remains an in-place right drawer, never a dialog
   or below-list panel. Capture a no-selection state as the baseline image.

The QA reviewer inspects the four product captures against the supplied
references at normal scale and a 100% crop of each shared control. A second
manual pass uses keyboard focus and pointer hover on Search, Stage, Include
closed, Table/Board, and Import CSV. The reviewer records observations, the
product build path, signature result, image paths/attachments, and any
environmental limit in the owner handoff; no unsupported claim may be inferred
from XCTest AX output.

## Visual acceptance and rejection rubric

All of the following must pass in both Table and Board where applicable.

| Region | Accept | Reject |
| --- | --- | --- |
| Pipeline canvas and empty state | Deep navy tier hierarchy; no dominant neutral-gray block. | A large neutral-gray content region, gray empty-state icon, or system-material-looking canvas. |
| Search, Stage, Include closed, View | Navy resting fill with a 1-point blue/cyan outline; hover, focus, pressed, selected, disabled states are visibly distinguishable. | Native opaque gray well, gray segmented track, gray checkbox surround, or a wrapper whose navy is hidden beneath native chrome. |
| Import CSV | Navy outlined secondary action with visible hover/focus/press feedback; no gradient. | Flat/generic gray button, no visible interactive response, or use of the Add opportunity gradient. |
| Add opportunity | The sole gradient primary action. | A second gradient primary action or loss of its distinct primary treatment. |
| Table/list rows, Board cards/columns, drawer/inspector | Layered navy surfaces, restrained established borders, readable text hierarchy. | Large gray rows/cards/inspector/empty panel, or a gray selected-row fill. |
| Focus and hover | Actual control receives visible focus (violet, 2-point); pointer hover is cyan and does not steal activation. | Wrapper-only focus, no focus visibility, incorrect focus owner, or broken keyboard/click activation. |
| Responsive VD2-04 fixes | Compact Table has a right drawer, View never wraps (label omitted when constrained), no redundant row radio glyph, one sidebar action. | Sheet/below-list details, wrapped `View`, radio/check-circle row selector, or duplicate framework sidebar button. |

Any single reject condition blocks QA approval and requires a fresh capture
set after remediation. A visually navy wrapper around an obvious gray native
well also blocks approval, even when every automated semantic test passes.

## Regression, accessibility, and non-scope checks

- Preserve the existing `pipeline` fixture isolation and its UUID-qualified
  storage session; no test may use real workspace data.
- Preserve filtering locality: Search/Stage/Include closed remain ephemeral
  Pipeline controls, and the seeded closed opportunity only appears after the
  checkbox is enabled.
- Preserve Table selection as ephemeral presentation state, the compact drawer
  contract, canonical **Open details** routing, and associated activity/audit
  regression coverage.
- Confirm VoiceOver/XCTest labels, values, identifier ownership, hit targets,
  and tab/key activation for the five controls. Visual wrappers must not become
  the accessibility element or consume activation.
- Diff review must confirm no changed models, stores, providers, network,
  import behavior, Board drag/drop/columns, routes, persistence, or activity
  code. Such a change is outside this QA release and must be separately gated.

## Release evidence and gate verdict

**QA Task 0 verdict: approved to release Task 1, conditionally.** The task
brief has a valid red/green method, provided the implementer adds the missing
four-capture test and uses the actual signed-product visual-review protocol
above. This approval does **not** certify the current gray rendering, does
not approve an implementation choice, and does not grant final QA acceptance.

Final QA remains blocked until a fresh independent verifier has: (1) inspected
the intentional RED and focused signed-Debug GREEN bundles, (2) reviewed all
four test attachments, (3) reviewed all four actual signed-product captures
against the supplied references, (4) exercised the manual focus/hover states,
and (5) confirmed every retained VD2-04 regression remains green.
