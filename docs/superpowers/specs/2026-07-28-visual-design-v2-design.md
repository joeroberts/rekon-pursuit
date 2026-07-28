# Visual Design v2 — Native macOS Design System and Screen Recomposition

**Status:** Approved product direction; governed implementation planning

**Product-owner approval:** 2026-07-28 Visual Design v2 execution request.

## Purpose

Recompose Rekon Pursuit's existing native SwiftUI application around the
approved visual language: a deep navy, layered local-first workspace with
restrained cyan/violet accents, a left navigation rail, clear hierarchy, and
responsive card and list surfaces. This is a presentation and navigation
program. It must continue to show real local workspace data and preserve all
current persistence, recovery, audit, and privacy behavior.

The approved reference directions are the six product-owner-supplied images in
`/Users/jroberts/Downloads/rekon_pursuit_*.png`. They are a system reference,
not a pixel-copy target. The shipped app must adapt at its supported window
sizes and with accessibility settings enabled.

## Scope and boundaries

In scope:

- semantic visual tokens, component styles, logo treatment, and native
  geometric decorative treatment;
- a responsive app shell, Home, Pipeline table/inspector/board, Contacts, and
  Settings recomposition;
- native motion and accessible, persisted Pipeline board movement;
- visual, accessibility, persistence, recovery, and workflow regression
  acceptance.

Out of scope:

- UX-D10, UX-D11, UX-D12, Phase 2a/2b/2c, Phase 3, AI execution, Gmail,
  Calendar, research, document processing, connected services, web frontends,
  browser storage, plugins, and cloud services;
- replacing live data with mock values;
- new raster decorative assets, fictional employer marks, headshots, avatars,
  recruiters, dates, status labels, or metadata not represented by local data.

## Visual-system contract (ADR-VD2-01)

`RekonTheme` remains the single design-system seam and is expanded into
semantic—not screen-specific—tokens:

- deep navy background layers; elevated card/surface layers; semantic text,
  border, focus, status, and action colors;
- restrained cyan-to-violet action and selected-state gradients; no gradient
  may be the only indicator of state;
- typography scale, spacing scale, radii, elevations, button/field styles,
  icon sizing, and visible focus treatment;
- `accessibilityReduceMotion` disables decorative/drag lift motion or reduces
  it to non-spatial opacity/focus changes;
- current shipped `RekonEmblem` is the in-app emblem. Existing
  `rekon-pursuit-logo-light-v1.png` may only be used after deliberate
  asset-catalog inclusion. Screenshot art is never an app asset.

The sidebar background decoration is constructed with SwiftUI gradients,
paths, and geometry. It is noninteractive, excluded from accessibility, and
must not reduce content contrast.

## Navigation and state contract (ADR-VD2-02)

`ContentView` remains the sole owner of `WorkspaceViewModel`, canonical route
state, document dialogs, destructive confirmations, and recovery sheets.
Presentation views may be extracted, but must not create competing workspace
models or mutable opportunity drafts.

Table/board/contact selection, hover, and drag state are ephemeral view state.
The Pipeline inspector is a read-only summary that opens the existing canonical
opportunity overview route. Back/deep-link and selected-record deletion must
return safely to a valid route.

## Truthful-data contract

- Home metrics and attention cards are deterministic projections of real local
  workspace data. "Applied this week" uses the user's local calendar and week
  boundary, documented in its test fixtures. No decorative counters persist.
- Pipeline cards show only current persisted title, company, stage, location,
  arrangement, next action, due date, and derived urgency when those facts
  exist. Missing data is omitted or described honestly.
- Contacts list/detail use persisted contact and employer fields; linked
  opportunities are disclosed only on demand.
- Settings reuses current recovery/archive/export/document/AI facts and flows.
  It must not claim unconfigured cloud or AI capability.

## Pipeline board move contract (ADR-VD2-03)

Drag payloads contain only the opportunity ID. A drop target is validated
before any command. The board calls `WorkspaceViewModel.changeStage(_:to:)`,
which is the existing persisted transactional command. That command refreshes
the real workspace, records `opportunity_stage_changed`, keeps stage history,
and preserves the reconciliation requirement for closure.

The UI may animate lift/hover while dragging. It may not permanently reorder
the local view until a successful store refresh confirms the change. A failed
or rejected move restores the source lane, displays an actionable error, and
creates no fabricated success evidence. Keyboard/VoiceOver stage actions are
equivalent alternatives to drag/drop.

## Adaptive accessibility contract (ADR-VD2-04)

- all controls have visible keyboard focus, accessible labels/values/actions,
  and non-color state cues;
- VoiceOver and keyboard paths cover navigation, selection, board movement,
  inspector opening, cards, and destructive/recovery actions;
- layouts scale at the supported window sizes; board lanes horizontally scroll
  or compact rather than shrinking unreadably;
- Dynamic Type/large text supports truncation, scrolling, or wrapping without
  clipping primary content; contrast remains sufficient on all surfaces;
- empty, loading, validation, and store-error states are explicit and truthful.

## Cards and release order

Visual Design v2 is a program under the existing active **Post-MVP refinement**
phase. It does not create a new active dashboard phase. `DESIGN-V2` is the
program parent. Work is released serially because current screens share
`ContentView.swift` and theme seams:

1. `VD2-01` — Visual foundation and tokens
2. `VD2-02` — App shell and navigation
3. `VD2-03` — Home redesign
4. `VD2-04` — Pipeline table and inspector
5. `VD2-05` — Pipeline board and persisted stage movement
6. `VD2-06` — Contacts master/detail redesign
7. `VD2-07` — Settings information architecture
8. `VD2-08` — Visual QA and accessibility acceptance

`VD2-03`, `VD2-04`, `VD2-06`, and `VD2-07` become technically dependency-safe
after `VD2-02`, but are intentionally released serially to avoid overlapping
ownership of shared SwiftUI files. `VD2-05` follows `VD2-04`.

## Per-card acceptance summary

| Card | Acceptance boundary |
| --- | --- |
| VD2-01 | Tokens/logo/focus/reduced-motion work; no workflow/data behavior change. |
| VD2-02 | All current routes, onboarding/recovery gates, dialogs, and keyboard navigation survive the new shell. |
| VD2-03 | Home counts/tasks are live, deterministic, and read-only. |
| VD2-04 | Filtered table and inspector preserve canonical opportunity routing and persistence. |
| VD2-05 | Successful/invalid/failed moves are persisted, audited, accessible, and recover safely. |
| VD2-06 | Scrollable contacts and progressive related-opportunity disclosure preserve association/validation. |
| VD2-07 | Recovery/archive/export/document behavior is preserved and independently security/privacy verified. |
| VD2-08 | Whole-app visual, accessibility, persistence, failure-state, and owner verification pass. |

## Governance and evidence

Every card follows: Planning brief → Architect/TPM/QA/Delivery release → fresh
implementer → independent code review + QA verification → architectural effect
review (and security/privacy review for the required high-risk settings or
document/recovery changes) → Delivery Manager transition record. A commit or
test result alone never marks a card accepted; each card needs a hands-on
verification path.

At every real delivery transition, update together:

1. `docs/delivery/dashboard-status.json`
2. `docs/delivery/roadmap.md`
3. `docs/delivery/remediation-ledger.md` or the product-delivery entry that
   records this program
4. generated `docs/delivery/dashboard/index.html` and detail HTML
5. the SDD progress ledger and task review evidence.

