# VD2-01 — Visual foundation and tokens

## Authority and boundary

This brief implements only Task 1 of the approved
[Visual Design v2 plan](../../superpowers/plans/2026-07-28-visual-design-v2.md)
and its [design specification](../../superpowers/specs/2026-07-28-visual-design-v2-design.md).
It is the dependency-safe first child of the `DESIGN-V2` program.

Do not alter workflow behavior, workspace persistence, recovery/export/archive
semantics, opportunity routing, activity/audit behavior, or the product scope.
Do not create mock records, raster decorations, fictional logos, avatars, or
network behavior.

## Deliverable

- A semantic SwiftUI visual-token layer: deep navy backgrounds/surfaces,
  restrained cyan/violet accents, type/spacing/radius/elevation scales,
  card/field/button/focus styles, non-color status cues, and reduced-motion
  behavior.
- Correct use of the existing `RekonEmblem`/approved existing logo treatment.
- Decorative native SwiftUI geometry/gradient treatment that is accessibility
  hidden and noninteractive.
- A deterministic, non-personal UI-test fixture launch contract with explicit
  argument and fixture ID, isolated temporary store/keychain namespace, fixed
  clock/time-zone, named deterministic states, and teardown.

## Test-first acceptance

Before implementation, add and observe focused failing tests for token/component
semantics, existing emblem identity, fixture isolation, and stable shell/focus
identifiers. Then run focused XCTest/XCUITest, Debug build, compact/default/wide
visual smoke, Dynamic Type, and Reduce Motion checks.

Independent code review, QA verification, and proportional security/privacy
verification must confirm that no data collection, network, persistence,
entitlement, or local-data exposure behavior changed. The product owner must
complete the signed Debug hands-on path before the card can be Accepted.

## Hands-on verification

Open the signed Debug handoff, visit existing destinations, use keyboard focus,
enable Reduce Motion, and confirm that the visual foundation is coherent while
workspace behavior remains unchanged.
