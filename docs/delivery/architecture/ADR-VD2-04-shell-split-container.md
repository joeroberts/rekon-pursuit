# ADR-VD2-04 — Use an app-owned `HSplitView` shell for sidebar visibility

**Status:** Accepted for the VD2-04 correction  
**Date:** 2026-07-30  
**Decision owners:** Architecture review (independent of implementation)

## Context

VD2-04 requires exactly one sidebar expansion/collapse affordance: the
application-owned `sidebar-collapse` action. It must remain available at the
supported compact 860×640 window size, change between **Collapse sidebar** and
**Show sidebar**, and preserve the native traffic-light controls.

The existing `NavigationSplitView` shell exposes a second, framework-owned
toolbar button in that compact presentation. Accessibility identifies it as an
unidentified `AXButton`/XCTest `Button` labelled **Hide Sidebar** or **Show
Sidebar**. Its presence beside the identified app action caused the owner’s
visual rejection.

The directly inspectable result bundle
`/tmp/rekon-vd204-feedback-sidebar-green.xcresult` is valid/readable but is a
**failed** final attempt, not passing evidence: it records one failing
`testVD204ShellExposesOnlyTheAppOwnedSidebarToggle()` assertion, with the
framework-control count observed as `1` where the required value is `0`.
This is the empirical evidence that the current `NavigationSplitView`+
`.toolbar(removing: .sidebarToggle)` arrangement does not meet the contract on
the target macOS host. It must not be cited as a green gate.

## Decision

Replace the shell’s `NavigationSplitView` with an `HSplitView` whose sidebar
rail and detail remain entirely app-owned. The shell supplies the single
`sidebar-collapse` toolbar action; no framework sidebar toolbar control is
created for the app to suppress.

The state model is deliberately narrow:

- Keep the existing external route selection binding and destination callback.
- Replace `NavigationSplitViewVisibility` as the visibility authority with a
  local Boolean sidebar-visible state owned by `AppShellView`.
- The app action alone flips that Boolean and exposes the corresponding dynamic
  Show/Collapse accessibility label.
- The `HSplitView` owns only rail/detail layout while both are visible. When
  the Boolean is false, remove the rail from the layout and let the detail use
  the available width. Restoring it returns the same rail, selection binding,
  and detail state; it does not reset navigation or persistent workspace data.

This is a shell-container substitution only. It does not change Pipeline’s
compact right drawer, canonical opportunity routing, model/persistence
contracts, or VD2-05 board/stage-movement scope.

## Alternatives rejected

1. **Keep `NavigationSplitView` and reposition
   `.toolbar(removing: .sidebarToggle)`.** This was the initial Task 4 remedy.
   The readable result bundle above proves that the framework control still
   exists in the supported compact state. Modifier ordering is therefore not a
   sufficient correctness guarantee.
2. **Use only the framework sidebar button.** It has no stable application
   identifier and does not provide the approved app-owned accessibility/
   interaction contract. It also gives the product no durable control over its
   placement or styling.
3. **Hide, overlay, or accessibility-suppress the framework button.** This
   leaves an interactive framework control in the window hierarchy and risks a
   visual or keyboard duplicate. It treats a native container side effect as a
   cosmetic problem rather than removing its source.
4. **Accept two controls at compact width.** Explicit product-owner feedback
   rejects that experience.

## Boundaries and invariants

- Retain the branded rail, its destination semantics, the existing detail
  workspace, the application toolbar, and native macOS traffic-light controls.
- Keep the app-owned sidebar action keyboard reachable and accessibility
  identified as `sidebar-collapse`.
- Do not create a sheet, dialog, or a second window for the rail.
- Do not use this correction to redesign the rail, detail toolbar, window
  policy, or navigation data flow.
- The minimum supported compact verification frame remains 860×640 (the shell
  clamps the nominal 860×600 request to that production-supported height).

## Required proof before VD2-04 may be accepted

Run the focused sidebar test in a fresh signed Debug app and store a new,
passing result bundle. At 860×640 it must prove all of the following before
collapse, after collapse, and after restore:

1. exactly one identified `sidebar-collapse` button exists and is hittable;
2. its label transitions Collapse → Show → Collapse;
3. zero framework `Hide Sidebar`/`Show Sidebar` buttons exist; and
4. native close, miniaturize, and zoom controls remain reachable.

Independent code review, QA, security/privacy verification, delivery-ledger
updates, and renewed product-owner acceptance remain required after that proof.
This ADR authorizes only the architectural deviation needed to meet the
one-control contract; it does not accept VD2-04 or release VD2-05.
