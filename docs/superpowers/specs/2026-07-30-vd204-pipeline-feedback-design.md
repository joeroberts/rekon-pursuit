# VD2-04 pipeline visual feedback correction

## Decision

The compact Pipeline inspector is a right-side drawer, not a modal sheet and
not a stacked panel below the list. It slides over the right edge of the table,
keeps the selected row visible where space permits, and closes back to an
unobstructed table. Wide windows retain the persistent adjacent inspector.

## Visual corrections

1. Replace the compact inspector sheet/disclosure flow with an in-place,
   accessible right drawer. The empty selection state stays within the Pipeline
   content region and uses a details-panel icon that matches its wording.
2. Remove the radio/check-circle visual from Pipeline rows. A row is selected
   through its full-row highlight and accessibility selected state; it is not a
   separate radio choice.
3. Make the toolbar responsive: the Table/Board segmented control never wraps
   its visual label. At constrained widths, retain its accessibility label but
   omit the visible `View` label before allowing wrapping.
4. Apply the Rekon dark-surface, border, focus, hover, and pressed treatment to
   Pipeline text input, stage picker, Closed checkbox, and segmented control.
   Import CSV receives the same responsive secondary-action affordance as other
   styled controls, including visible hover/focus feedback.
5. Restore exactly one sidebar expansion/collapse affordance. The app uses the
   custom accessible rail control; the system toolbar counterpart stays removed.

## Constraints

- Pipeline selection remains local and ephemeral. The drawer does not change
  canonical opportunity selection, routes, drafts, store rows, or activity.
- Only `Open details` leaves Pipeline through the existing canonical callback.
- No stage movement, board workflow changes, schema, persistence, or VD2-05
  work is included.
- Keyboard and VoiceOver retain a discoverable selected row, drawer close/open,
  toolbar controls, and one sidebar-toggle action.

## Verification

- Test compact drawer open, close, replacing content on row selection, and the
  absence of the former sheet/stacked empty inspector.
- Test row selection without a radio-style child control; selected state remains
  exposed to accessibility.
- Test 860×600 and large-text toolbar layout without a wrapped `View` label.
- Test styled control focus/keyboard navigation and exactly one sidebar-toggle
  accessibility element.
- Re-run all existing VD2-04 model, fixture-host, Pipeline UI, and sidebar UI
  checks; then repeat signed-Debug product-owner visual/accessibility review.
