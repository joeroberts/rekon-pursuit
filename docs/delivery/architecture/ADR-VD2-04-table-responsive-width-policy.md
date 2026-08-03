# ADR-VD2-04: Pipeline Table responsive-width policy and fidelity capture size

**Status:** Accepted for the Task 3 responsive repair; requires Delivery
release before implementation  
**Date:** 2026-07-30  
**Decision owner:** Independent architecture review

## Context

The owner-approved Pipeline mocks establish a wide, information-dense desktop
Table: five readable columns beside a substantial inspector. Their baseline
canvas is 1600 pt wide. The current visual-test host defines its `wide` window
as 1100×760. At that size, the always-visible shell rail, Pipeline padding,
and 250 pt inspector leave the Table with a materially insufficient viewport.

The present implementation attempts to preserve five desktop identifiers in
that remaining width by assigning 64–78 pt tracks. Independent review of the
signed capture found the trailing Due date header and representative cells
unusable/clipped. That is not a valid implementation of either the mock or
the fidelity specification: identifier existence is not visual usability.

The approved compact behavior already has the correct architectural form: an
unstructured-card fallback is prohibited, but the dense Table may deliberately
collapse metadata and, after selection, use the in-place trailing right drawer.
The user explicitly rejected a modal and below-list details presentation.

## Decision

### 1. Make the `wide` fixture mock-aligned desktop evidence

`VisualFixtureWindowSize.wide` must be **1600×1000**. It is the normal
desktop-fidelity capture surface for the Table and Board; it is not a
production minimum-window change. The height aligns the owner-provided mock
canvas and avoids treating a partially visible vertical workspace as a
desktop-reference capture.

The fidelity UI contract must assert this actual wide window size before it
evaluates the desktop five-column surface. Existing compact evidence remains
860×640 (the shell-enforced minimum), unchanged.

### 2. Use two deliberate Table presentation regimes based on Pipeline content width

`PipelineView` must choose its Table regime from the geometry available *after*
the shell rail and Pipeline padding, not from a global window assumption.

| Available Pipeline content width | Table presentation | Details presentation |
| --- | --- | --- |
| **At least 1,220 pt** | Desktop dense Table: Role, Employer, Stage, Next action, and Due date are simultaneously readable and aligned. The Table must reserve its own minimum readable track widths; it may not depend on clipping, horizontal scrolling, or text truncation to fit all five columns. | Persistent right-hand inspector, 320–340 pt wide, alongside the Table. |
| **Below 1,220 pt** | Compact dense Table: a defined compact subset (Role, location/work arrangement, and precise Stage) remains aligned. Employer, Next action, and Due date are deliberately omitted from the table surface rather than squeezed or hidden beyond its viewport. This remains a table, not a vertically stacked-card list. | The existing in-place trailing right drawer appears only for a selected row. It shares the Table region's trailing edge, supports close/reselection, and is never a sheet/modal or below-list panel. |

The 1,220 pt threshold is deliberately above the calculated five-column plus
inspector minimum rather than tuned to make an 1100 pt host barely pass. It
gives the desktop Table approximately 860 pt after a 340 pt inspector and
spacing, which is comparable to the Table portion of the 1600 pt controlling
mock. It also creates a deterministic guard band against split-view and font
metric variation.

### 3. Desktop tracks are content-led, not test-minimum-led

For the desktop regime, Task 3 must replace the current 64–78 pt placeholder
tracks with readable track minima. The exact SwiftUI allocation may use flexible
Role/Next action tracks, but must preserve these lower bounds before padding
and inter-column spacing:

| Column | Minimum readable track |
| --- | ---: |
| Role | 180 pt |
| Employer | 140 pt |
| Stage | 108 pt |
| Next action | 150 pt |
| Due date | 104 pt |

At the desktop threshold, the Table must have enough remaining breadth for
those tracks, normal inner padding, and column gaps. A desktop column may
wrap controlled secondary content where the mock does, but the heading and a
representative value must remain wholly inside the Table viewport and legible.

## Required implementation boundary

The next Delivery release may authorize only the following narrow repair:

1. `RekonPursuit/PipelineView.swift` — Table regime predicate, readable
   desktop tracks, and reuse of the existing compact in-place drawer regime
   below the breakpoint. The persistent inspector must remain a right-hand
   pane in the desktop regime.
2. `RekonPursuitUITestHost/BootstrapApp.swift` — change only the `wide`
   fixture size to 1600×1000.
3. `RekonPursuitUITests/RekonPursuitUITests.swift` — strengthen the fidelity
   Table contract to assert the wide size and the two intentional regimes.
4. Delivery evidence/dashboard/roadmap records that describe this approved
   capture-policy change.

No change is authorized to Board markup or mapping, drag/drop, model/store,
persistence, filters, activity, canonical route, Import CSV, sidebar behavior,
signing, or compact-drawer semantics. In particular, changing a fixture size
does not waive signed verification or let Task 4 begin.

## Verification requirements

Before Task 3 can be reconsidered:

1. The focused signed Table contract launches the 1600×1000 fixture and
   records a selected-row desktop capture with all five headings and
   representative values wholly visible beside the inspector.
2. At the unchanged 860×640 compact fixture, the contract proves the defined
   compact columns, no radio/check-box row control, and the existing in-place
   right drawer (right edges aligned, no sheet, no below-list inspector).
3. New UI assertions must test actual geometry/readability boundaries, not
   merely identifier existence or artificially low widths.
4. The existing retained VD2-04 regression suite still passes in finalized,
   signed result bundles. The Task 2 Board RED contract remains intentional
   until Task 4 is independently released.
5. Fresh Code Review and QA visually inspect the signed 1600×1000 Table
   attachment against mock #1 and independently validate the compact drawer.

## Alternatives rejected

1. **Keep 1100×760 as the desktop capture and shrink all five tracks.**
   Rejected: this is the observed clipping regression and cannot meet the
   controlling mock's dense-workspace hierarchy.
2. **Hide one or more required columns at 1100 while retaining the desktop
   inspector.** Rejected: it makes a desktop state neither the full desktop
   table nor a deliberate compact regime.
3. **Allow horizontal scrolling in the desktop Table.** Rejected: the mock
   presents all five decision columns beside the inspector at once, and the
   delivery rejection explicitly prohibits this workaround.
4. **Replace the intermediate inspector with a modal or below-list panel.**
   Rejected: the approved details contract is an in-place right drawer below
   the desktop threshold.
5. **Change the production app's minimum window to 1600 pt.** Rejected: the
   test-host capture configuration is evidence-only; production must retain
   its responsive behavior.

