# VD2-02 — Navigation interaction regression brief

## Scope

Correct only the VD2-02 rail interaction defects:

1. A destination must activate when the user clicks anywhere inside its visible
   row, not only its icon or text.
2. A mouse click must select the destination without leaving a cyan/white
   keyboard-focus outline. The cyan outline is pointer-hover feedback only.
3. The shell must expose one sidebar-collapse control only; remove the duplicate
   custom/system presentation while retaining one accessible, keyboard-operable
   native collapse/restore action.

Do not alter routing ownership, persistence, recovery behavior, workflow
content, macOS traffic lights, or the broader visual-design scope.

## Test-first regression contract

Add focused UI tests that first fail against the reported behavior:

- For every rail destination, tap a coordinate in the row's trailing blank
  area. The matching daily route activates and exactly one rail item is
  selected.
- After a mouse/touch click selects a destination, its accessibility value does
  not report `Keyboard focus`; screenshot/semantic assertion confirms no
  persistent focus ring. Pointer hover shows the cyan outline, and pointer exit
  removes it without changing selection.
- Keyboard Tab focus still shows the visible focus treatment and Space/Return
  still activates the focused destination. Keyboard focus must remain distinct
  from selection and pointer hover.
- Exactly one hittable control with the semantic identifier/label pair
  `sidebar-collapse` / `Collapse sidebar` (or `Show sidebar` after collapse)
  exists at a time. It toggles the sidebar and remains available by keyboard.

## Exact acceptance criteria

- Each visible rail row has a contiguous tappable hit target spanning its full
  rendered width and full row height, including whitespace after the label.
- Selected state is shown by the approved filled surface plus left cyan
  indicator; it does not require or retain an outline after pointer activation.
- Hover state alone draws the cyan outline. Keyboard focus is visible while the
  row owns keyboard focus, disappears when focus moves away, and does not
  persist after a pointer click unless that click deliberately transfers actual
  keyboard focus under macOS accessibility behavior.
- There is no duplicate collapse glyph/control in normal, compact, expanded,
  or full-screen layouts. The remaining control has an explicit label, help
  text, focus path, and stable identifier.
- Existing tests for all five destinations, recovery containment, safe
  opportunity departure, and collapse/restore continue to pass.
- Independent code review and QA verify the focused tests plus a hands-on
  pointer/keyboard smoke at compact, default, wide, and full-screen window
  sizes. No delivery dashboard or status transition occurs until those gates
  and product-owner verification complete.
