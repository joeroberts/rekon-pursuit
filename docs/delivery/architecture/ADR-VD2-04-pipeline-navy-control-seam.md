# ADR-VD2-04: Pipeline navy-control seam

**Status:** Accepted for VD2-04 navy-surface correction
**Date:** 2026-07-30
**Amended:** 2026-08-04 — VD2-10 Search ownership only
**Decision owner:** Architecture review

## Context

`PipelineView` currently composes the Stage `Picker`, Include closed checkbox,
and Table/Board segmented picker inside `RekonControlSurface`. The wrapper
correctly paints a navy surface and focus outline, but it is behind opaque
AppKit controls. Consequently the controls can retain generic macOS gray
bezel/fill chrome even though the surrounding surface uses Rekon's navy
tokens.

The initial seam also put Search behind a custom `NSSearchField` host. During
VD2-10, that made the AppKit cell and the SwiftUI query binding two owners of
the same value. In particular, the native cancel control clears the AppKit
cell through its cancel path without reliably delivering the normal
text-change delegate callback. A subsequent representable refresh could then
restore the stale binding value, leaving the visible field and the filtering
query out of sync. Attempts to patch that behavior while preserving custom
cell geometry also regressed typing, vertical text placement, and the clear
hit target. This is a search-control ownership failure, not a reason to
broaden the AppKit seam or alter Pipeline data behavior.

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
three gray-producing Pipeline controls that require native AppKit menu or
segmented behavior. The AppKit control classes remain the actual
accessibility, keyboard, and menu owners for those controls.

Search is the sole VD2-10 amendment to that ownership boundary. It is a
Pipeline-local SwiftUI `TextField` bound directly to the existing query state;
it is not an `NSViewRepresentable`, `NSSearchField`, hidden native peer, or
dual-bound value. This deliberately gives the displayed editor, clear action,
and filtering input one binding owner.

The retained native renderer must not put an opaque AppKit bezel on top of a
SwiftUI navy wrapper. Stage, Include closed, and Table/Board are small
`NSViewRepresentable` controls backed by the following native control classes
(or a transparent-hosted instance of them); Search remains the direct binding
described above:

| Pipeline capability | Required interaction owner | Required AX projection |
| --- | --- | --- |
| Search | direct SwiftUI `TextField` bound to the existing query | editable text field |
| Stage | `NSPopUpButton` | popup button, label `Stage` |
| Include closed | checkbox-configured `NSButton` | checkbox, label `Include closed` |
| Table / Board | `NSSegmentedControl` | exclusive Table/Board choices, including radio descendants |

The AppKit representables use a Pipeline-specific renderer/cell (or a
transparent native content control hosted by an app-drawn `NSView`) to draw
the navy fill, rounded border, selected segment, and interaction overlays.
Their stock bezel/background must not be drawn. Their popup menu, checkbox
state, segmented selection, first-responder ownership, accessibility actions,
and standard keyboard behavior remain native. The direct SwiftUI Search
control uses the same semantic navy presentation mapping without a native
bezel or a focusable wrapper.

`RekonSecondaryButtonStyle` is already a SwiftUI button style, so it does not
need an AppKit replacement. It must instead consume the same semantic
Pipeline presentation mapping for its fill/outline/hover/pressed/focus states.

### VD2-10 Search ownership amendment and invariants

This amendment supersedes **only** the Search native-owner row above. It does
not supersede the AppKit ownership of the Stage popup, Include closed
checkbox, or Table/Board segmented control.

- `opportunity-search` remains the actual editable text field with the
  existing `Search opportunities` accessibility label. Keyboard focus lands
  on that text field; no visual wrapper, gesture surface, hidden native
  control, or proxy may own focus or typing.
- Its placeholder remains intentionally blank. A leading magnifying-glass
  image with the retained `pipeline-search-icon` identifier and `Search`
  label is visible only while the direct query binding is empty. It is not an
  action owner and disappears as soon as a user types.
- A visible `pipeline-clear-search` control labeled `Clear search` appears
  only while the query is nonempty. It clears that same direct binding,
  returns focus to the editable text field, and leaves no stale cell value
  that can be reapplied by an AppKit update cycle.
- The existing Pipeline filtering projection continues to read the same query
  state. Typing and clearing therefore update the displayed opportunities
  immediately without changing filtering semantics, stage filtering, closed
  visibility, selection, persistence, or activity behavior.
- The direct binding must keep the existing navy fill, one-point idle outline,
  keyboard-focus treatment, compact/wide sizing behavior, and accessibility
  identifier. It is an implementation seam change, not a new search feature.

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
4. A Pipeline-local direct SwiftUI `TextField` for Search, bound to the
   existing query and carrying the existing accessibility identifier and
   label. Its blank placeholder, conditional decorative magnifier,
   conditional clear action, and real focus state are derived from that same
   binding; the clear action must write only that binding.
5. Pipeline-local AppKit representables with bindings for stage,
   include-closed, and view mode. Each accepts the existing accessibility
   identifier and label, passes both to its actual native control, and reports
   its real focus/hover/pressed/selected/disabled state to the shared mapping.
6. AppKit controls expose their standard actions without gesture overlays,
   hidden hit targets, event monitors, or a focusable visual wrapper. A custom
   focus outline is drawn by the same control/host after its native focus
   state changes; it does not replace first-responder ownership. Search
   follows the equivalent rule through its real SwiftUI editor, not an AppKit
   proxy.

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
- The Search amendment must not introduce or alter a model, store, routing,
  persistence, import, activity, audit, or filtering contract. It changes
  only the local presentation/input ownership of the existing query binding.
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
5. **Repair the `NSSearchField` bridge with more delegates or cell hooks.**
   Rejected: the native cancel path and SwiftUI refresh cycle would still
   leave two value owners. The direct SwiftUI query binding removes that
   desynchronization without changing the query's consumer.

## Acceptance checklist

- [ ] Search visibly has an app-drawn navy fill and cyan/blue one-point idle
      outline while remaining the direct, editable `opportunity-search` text
      field. Its placeholder is blank; its non-actionable
      `pipeline-search-icon` magnifier is visible only while empty and
      disappears on typing.
- [ ] Search keyboard focus lands on the real editor. Its clear action appears
      only for a nonempty query with the retained `pipeline-clear-search`
      identifier and `Clear search` label, clears the direct query binding,
      restores editor focus, and immediately restores the unfiltered
      projection without a stale AppKit cell value.
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
- [ ] Focus lands on the real Search editor or the real native Stage,
      Include-closed, and Table/Board control, as applicable, and produces a
      visible violet two-point focus outline; hover, pressed, selected, and
      disabled states remain distinguishable.
- [ ] Compact and wide Table and Board show no large neutral-gray Pipeline
      surface or generic gray input chrome, as independently inspected against
      the supplied references.

## Rejection checklist

Reject the implementation if it introduces a global appearance mutation,
changes any of the listed accessibility roles/identifiers, makes a wrapper
focusable or intercepting, restores a gray native bezel to a retained AppKit
control, reintroduces a separate native Search value owner, changes Board
workflow/data behavior, changes a model/store/routing/audit contract, or
weakens existing VD2-04 tests to pass restyling.
