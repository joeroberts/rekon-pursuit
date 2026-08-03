# ADR-VD2-04: Pipeline navy-control seam

**Status:** Accepted for VD2-04 navy-surface correction
**Date:** 2026-07-30
**Decision owner:** Architecture review

## Context

`PipelineView` currently composes the Stage `Picker`, Include closed checkbox,
and Table/Board segmented picker inside `RekonControlSurface`. The wrapper
correctly paints a navy surface and focus outline, but it is behind opaque
AppKit controls. Consequently the controls can retain generic macOS gray
bezel/fill chrome even though the surrounding surface uses Rekon's navy
tokens. The global `RekonTextFieldStyle` has the same limitation for the
Pipeline search field.

The owner-approved Pipeline references require app-owned navy fills and
cyan/blue resting outlines in Table and Board. Existing UI contracts require
the concrete accessibility projections now used by the focused tests:

- `opportunity-search` is an editable text field;
- `pipeline-stage-filter` is an `NSPopUpButton`-projected popup button with
  label `Stage`;
- `pipeline-include-closed` is an `NSButton`-projected checkbox with label
  `Include closed`;
- `pipeline-view-mode` retains mutually-exclusive Table/Board radio choices;
- `pipeline-import-csv` remains a normal actionable secondary button.

Changing an AppKit window or application appearance globally is outside this
card and risks changing non-Pipeline forms and window chrome.

## Decision

Introduce a **Pipeline-local AppKit control seam** in
`RekonVisualTheme.swift`. The seam owns the complete visual drawing of the
four gray-producing Pipeline input types while retaining the native AppKit
control classes as the actual accessibility, keyboard, and menu owners.

The renderer must not put an opaque native bezel on top of a SwiftUI navy
wrapper. Each control is a small `NSViewRepresentable` backed by one of the
following native control classes (or a transparent-hosted instance of it):

| Pipeline capability | Required native interaction owner | Required AX projection |
| --- | --- | --- |
| Search | `NSTextField` | editable text field |
| Stage | `NSPopUpButton` | popup button, label `Stage` |
| Include closed | checkbox-configured `NSButton` | checkbox, label `Include closed` |
| Table / Board | `NSSegmentedControl` | exclusive Table/Board choices, including radio descendants |

The representables use a Pipeline-specific AppKit renderer/cell (or a
transparent native content control hosted by an app-drawn `NSView`) to draw
the navy fill, rounded border, selected segment, and interaction overlays.
Native controls must be configured so their stock bezel/background is not
drawn. Their text, popup menu, checkbox state, segmented selection,
first-responder ownership, accessibility actions, and standard keyboard
behavior remain native.

`RekonSecondaryButtonStyle` is already a SwiftUI button style, so it does not
need an AppKit replacement. It must instead consume the same semantic
Pipeline presentation mapping for its fill/outline/hover/pressed/focus states.

### Selected-state semantic mapping

`selected` is a persistent choice/selection base state, not a gradient or a
replacement for keyboard focus. Its exact mapping is deliberately shared by
the table row, selected Board card, and the selected item within the
Table/Board segmented control:

| State / layer | Fill token | Outline token | Outline width | Opacity |
| --- | --- | --- | ---: | ---: |
| Resting unselected | `surface` | `border` | 1 pt | 1.00 |
| Selected base | `elevatedSurface` | `accent` | 1 pt | 1.00 |
| Selected + pointer hover | `elevatedSurface` | `accent` | 1 pt | 1.00 |
| Selected + keyboard focus | `elevatedSurface` | `violet` | 2 pt | 1.00 |
| Selected + pressed | `elevatedSurface` | `accent` | 1 pt | 0.62 |
| Disabled (whether previously selected or not) | `surface` | `border` | 1 pt | 0.42 |

The selected base is `elevatedSurface` rather than an opacity-blended accent:
it is an existing Rekon navy tier, keeps selection legible over the Pipeline
canvas, and prevents a neutral-gray selected fill. `accent` is the stable
blue/cyan selection affordance; it is not an action gradient. Keyboard focus
has a higher-priority, 2-point `violet` outline so the actual focused control
remains identifiable without losing the selected navy fill. Implementers must
render that focus outline on the real native control/host, never by making a
separate selection wrapper focusable.

For the segmented control, these values apply to the selected *segment*, not
the outer group: the group remains `surface` with its normal `border` hairline
when unfocused. For Table and Board opportunities, the same selected base is
applied to the selected row/card container while the existing text and status
semantics are unchanged. No selected state may use `actionGradient`, a
literal color, an AppKit system fill, or a neutral gray.

## Required implementation interface

Task 2 must add these semantics to `RekonVisualTheme.swift`; exact private
type names may differ, but the ownership boundary may not:

1. A nonisolated, Equatable `RekonPipelineControlInteractionState` covering
   `idle`, `pointerHover`, `keyboardFocus`, `pressed`, `selected`, and
   `disabled`.
2. A nonisolated, Equatable presentation value that contains *semantic* fill
   tier, outline tier, outline width, and opacity. The pure mapping returns
   semantic tones (not `Color`/`NSColor`) so unit tests can prove the idle and
   selected fills are navy tiers, the selected outline is `accent` at one
   point, the selected opacity is `1.00`, the idle outline is one point, and
   keyboard focus is violet at two points. The selected-state table above is
   the controlling mapping for Task 2.
3. A Pipeline-only color resolver used by both SwiftUI secondary buttons and
   AppKit renderers. It maps only existing `RekonTheme` navy tiers, `border`,
   `accent`, and `violet`; it introduces no literal neutral-gray color and no
   `NSAppearance` mutation.
4. Pipeline-local SwiftUI views/modifiers with bindings for text, stage,
   include-closed, and view mode. Each accepts the existing accessibility
   identifier and label, passes both to the actual native control, and reports
   its real focus/hover/pressed/selected/disabled state to the shared mapping.
5. Native controls expose their standard actions without gesture overlays,
   hidden hit targets, event monitors, or a focusable visual wrapper. A custom
   focus outline is drawn by the same control/host after its native focus
   state changes; it does not replace first-responder ownership.

`PipelineView` must consume these Pipeline-local controls only for the four
Pipeline inputs above. It must not apply them to general forms elsewhere in
the app. The existing IDs, labels, state values, fixture behavior, and
`ViewThatFits` compact-label behavior are retained verbatim.

## Explicit constraints

- No broad `NSApplication`, `NSWindow`, or global `NSAppearance` override;
  no mutation of unrelated standard control defaults.
- No hidden native `Picker`/`Toggle` paired with a custom `Button`, because
  that duplicates focus/action owners and breaks the stated role contract.
- No SwiftUI gesture on a surrounding surface that intercepts Return, Space,
  arrows, click, or popup-menu activation.
- No changes to opportunity data, filtering semantics, import implementation,
  routing, persistence, Board movement, or activity/audit flows.
- The existing right drawer, no-radio table row, one-line/omitted `View`
  label, and single app-owned sidebar control remain untouched.

## Rejected alternatives

1. **Keep native controls and only darken `RekonControlSurface`.** Rejected:
   the native opaque bezel still visibly wins, which is the reported defect.
2. **Set a global dark appearance or broadly theme AppKit controls.** Rejected:
   it changes the window/application boundary and can regress unrelated forms
   without providing a stable per-control visual contract.
3. **Replace inputs with plain SwiftUI buttons plus hidden native controls.**
   Rejected: it creates duplicate accessibility elements and splits keyboard,
   value, and action ownership.
4. **Use private AppKit styling or appearance-key hacks.** Rejected: these are
   not stable or reviewable product behavior.

## Acceptance checklist

- [ ] Search visibly has an app-drawn navy fill and cyan/blue one-point idle
      outline while remaining an editable text field with
      `opportunity-search`.
- [ ] Stage has no stock gray bezel, opens/cancels its native popup, and
      remains a popup button labeled `Stage` with `pipeline-stage-filter`.
- [ ] Include closed has no stock gray checkbox/fill, toggles natively, and
      remains the `pipeline-include-closed` checkbox with the retained value
      contract.
- [ ] Table/Board has no stock gray segmented chrome, remains one exclusive
      control with radio descendants, and keeps `pipeline-view-mode`.
- [ ] Import CSV uses the same navy/cyan secondary presentation and stays the
      sole normal button owner for `pipeline-import-csv`; Add opportunity is
      still the only gradient primary action.
- [ ] A selected table row, selected Board card, and selected Table/Board
      segment each use `elevatedSurface` with a 1-point `accent` outline at
      full opacity; selected keyboard focus uses the 2-point `violet` outline.
      None uses a gradient or a gray system fill.
- [ ] Native focus lands on the real control and produces a visible violet
      two-point focus outline; hover, pressed, selected, and disabled states
      remain distinguishable.
- [ ] Compact and wide Table and Board show no large neutral-gray Pipeline
      surface or generic gray input chrome, as independently inspected against
      the supplied references.

## Rejection checklist

Reject the implementation if it introduces a global appearance mutation,
changes any of the listed accessibility roles/identifiers, makes a wrapper
focusable or intercepting, restores a gray native bezel, changes Board
workflow/data behavior, or weakens existing VD2-04 tests to pass restyling.
