# VD2-04 Pipeline navy-surface correction

## Decision

The supplied Pipeline references are the visual acceptance baseline for this
correction. Pipeline must read as a layered deep-navy product surface; generic
system-gray fills are not an acceptable substitute for that system.

This is a presentation-only completion of VD2-04. It applies to both Table and
Board where they share Pipeline controls or card/list surfaces, but does not
change Board's columns, drag/drop behavior, routing, data, or persistence.

## Chosen approach

Use app-owned, accessibility-preserving controls whose visual chrome is fully
owned by Rekon, rather than placing navy wrappers behind system controls that
continue to render gray. The controls retain their existing labels,
identifiers, keyboard operation, and equivalent accessibility semantics.

The rejected alternatives are:

1. Leave native controls in place and intensify their outer wrappers. This has
   already failed visually because the native gray fill remains visible.
2. Apply broad macOS appearance changes. That would risk altering unrelated
   native window chrome and does not provide a stable per-control contract.

## Surface and control contract

1. Pipeline canvas, table/list rows, cards, inspector/drawer, and empty states
   use the existing Rekon navy tiers (`background`, `backgroundRaised`,
   `surface`, and `elevatedSurface`) with the established border hierarchy.
   No large neutral-gray fills appear in the Pipeline content region.
2. Search, Stage, view switching, Include closed, and Import CSV each receive
   a navy fill and a 1-point blue/cyan outline in their resting state. Hover,
   focus, pressed, selected, and disabled states remain visibly distinct.
3. `Add opportunity` remains the only gradient primary action. `Import CSV`
   remains a styled secondary action, consistent with the reference.
4. Table and Board share only the visual primitives they already consume. This
   correction adds no Board workflow or drag/drop behavior.
5. Existing responsive behavior remains: `View` never wraps, compact table
   details stay a right drawer, rows have no redundant radio glyph, and there
   is one app-owned sidebar-toggle action.

## Accessibility and interaction

- Keyboard focus is visible on the actual interactive element; visual wrappers
  never consume activation or replace identifiers.
- Search remains an editable text field. Stage remains a discoverable chooser,
  closed state remains a discoverable toggle, and Table/Board remains a
  mutually exclusive choice.
- VoiceOver labels, values, focus order, and current VD2-04 UI contracts stay
  intact.

## Verification

- Add red-first tests for the navy-surface rendering contract and the native
  semantic contracts of every replaced/re-styled control.
- Run the focused Pipeline UI, drawer, compact toolbar, sidebar, and native
  control activation tests in a signed Debug run.
- Capture the actual signed product at compact and wide sizes in Table and
  Board. Independently compare the captures with the supplied references,
  specifically rejecting visible large gray Pipeline surfaces or generic gray
  input chrome.
- Obtain independent code review, QA, architect, TPM, and delivery-manager
  gates before asking for product-owner acceptance of VD2-04.

## Scope boundary

This does not alter opportunities, stages, import behavior, board movement,
activity, persistence, routes, or any VD2-05+ work.
