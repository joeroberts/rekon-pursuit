# Visual Design v2 — SDD progress ledger

> Local operating evidence. The committed product-delivery record is the
> `Visual Design v2 program` section in `docs/delivery/roadmap.md`, synchronized
> with `docs/delivery/dashboard-status.json` and generated dashboard HTML.

## Program map

`DESIGN-V2` is the program parent. Child sequence:

1. `VD2-01` Visual foundation and tokens — Accepted
2. `VD2-02` App shell and navigation — Accepted
3. `VD2-03` Home redesign — Accepted
4. `VD2-04` Pipeline table and inspector — Accepted
5. `VD2-05` Pipeline board and persisted stage movement — Accepted (approved, non-blocking macOS XCTest submenu-oracle debt)
6. `VD2-06` Contacts master/detail redesign — Accepted
7. `VD2-07` Settings information architecture — Backlog
8. `VD2-08` Visual QA and accessibility acceptance — Backlog

## VD2-06 product-owner acceptance — 2026-08-01

- The product owner explicitly accepted VD2-06 (`approved`). The acceptance
  closes the Contacts master/detail redesign, based on the signed Debug
  handoff and the completed independent technical gates recorded in
  `docs/delivery/evidence/visual-design-v2/VD2-06-owner-handoff-2026-08-01.md`.
- The three owner-approved VD2-08 accessibility/recovery automation debts
  remain open: precise `contact-operation-error` accessibility values; verified
  Tab then Space/Return activation for Back, Cancel, and Save; and automated
  failed Link/Unlink UI injection. No broad VD2-08 campaign is accepted.
- VD2-07 is eligible only for a separate TPM dependency-safe release. It
  remains Backlog and is neither released nor in progress. VD2-08 remains
  Backlog and blocked until VD2-03 through VD2-07 are accepted.

## VD2-06 Task 2 technical completion and Task 3 release — 2026-08-01

- Independent Code Review, fresh QA/accessibility, Architecture, TPM, and
  Delivery gates accepted Task 2's bounded Contacts presentation extraction.
  Fresh normally signed Debug QA evidence reports 3/0/0 GREEN for the unchanged
  wide master/detail, compact detail/Back, and truthful-state selectors.
- VD2-06 remains **In progress at Task 3 only**. Delivery released only the
  focused deterministic regression, safety, persistence/audit, destructive,
  keyboard, accessibility, and responsive evidence slice. Required regressions
  include edit/new Cancel no-write, association failure/Retry recovery, live
  editor resize retention, and duplicate normalized contact-ID disambiguation.
- Task 4 remains blocked pending Task 3 GREEN and independent Code Review, QA,
  Architecture, and Security/Privacy gates. VD2-07 and VD2-08 remain Backlog
  and blocked; no product-owner acceptance or VD2-06 feature acceptance is
  implied. Task evidence under `/tmp` and the pre-existing dirty-baseline
  exact-symbol integration risk remain open.

## VD2-03 delivery transition — 2026-07-30

- Product owner explicitly accepted VD2-03.
- Independent architecture, code-review, QA, security/privacy, and TPM/delivery
  gates accepted the final source. The known same-user path-swap race is confined
  to the non-shipping UI-test host and is recorded as a test-harness limitation.
- Final evidence: focused model tests 6/6; fixture-host tests 21/21 at
  `/tmp/rekon-vd203-hostqa-20260730c.xcresult`; Home UI tests 12/12 at
  `/tmp/vd203-ui-final-20260730-100738.xcresult`.
- VD2-04 is Next up but remains blocked on its own planning, architecture, TPM,
  QA, and delivery release gates.

## VD2-04 product-scope decision — 2026-07-30

- The product owner approved the narrow removal of the obsolete global **Show
  closed opportunities** Settings control and its `UserDefaults`-backed model
  state. Pipeline owns Closed visibility as local, ephemeral session state.
- Architect rationale: retaining the global preference would either produce a
  deceptive no-effect Setting or violate the Pipeline presentation-state
  boundary through a hidden global input.
- This is not a Settings redesign. VD2-07 retains all other Settings
  information architecture and visual work. Durable decision record:
  `docs/delivery/evidence/visual-design-v2/VD2-04-closed-filter-scope-decision-2026-07-30.md`.
- This scope decision was recorded before implementation release. The completed
  implementation is now awaiting its separate product-owner handoff gate.

## VD2-04 owner handoff — 2026-07-30

- Independent implementation gates completed: focused model verification 3/3,
  fixture-host verification 22/22, and independent final UI QA r5 10/10 named
  paths. Independent code review and security/privacy review accepted the
  bounded card.
- VD2-04 is **In progress**, not accepted. It is now awaiting only the
  product-owner hands-on visual/workflow acceptance recorded in
  `docs/delivery/evidence/visual-design-v2/VD2-04-owner-handoff-2026-07-30.md`.
- `VD2-05` remains Backlog. No successor release or acceptance is inferred from
  this handoff.

## VD2-04 fidelity responsive-width repair release — 2026-07-30

- Independent architecture accepted
  `ADR-VD2-04-table-responsive-width-policy.md` after visual review showed
  that the former 1100×760 wide test host clipped the desktop Due-date column
  beside the inspector. A passing identifier was not accepted as a readability
  proof.
- Delivery keeps Task 3 **rejected** and releases only the following repair:
  set the wide test-host fixture to 1600×1000; use the mock-aligned five-column
  Table with a persistent 320–340 pt inspector only when Pipeline content width
  is at least 1220 pt; otherwise keep a dense compact Table with the existing
  selected-row in-place right drawer. Desktop column minima are 180/140/108/
  150/104 pt for Role, Employer, Stage, Next action, and Due date.
- Board markup/workflow, models, stores, persistence, filters, routes, Import,
  sidebar behavior, signing/configuration, fixture data, production minimum
  window policy, VD2-05, and all successor work remain unreleased. The retained
  filter correction and compact-drawer alignment repair remain separate required
  gates.
- Fresh Code Review and QA must inspect signed 1600×1000 and 860×640 evidence,
  alongside finalized retained controls, before Task 3 can be reconsidered.

## VD2-04 Task 3 acceptance and Task 4 Board-fidelity release — 2026-07-30

- Independent Code Review and QA accepted the responsive Table repair. They
  visually inspected signed 1600×1000 desktop and 860×640 compact captures;
  the former now has five readable columns beside the persistent inspector and
  the latter remains a dense Table with an in-place trailing drawer.
- `/private/tmp/rekon-vd204-responsive-table-green-final.xcresult` finalized
  1/1 signed green. The ten independently serialized
  `/private/tmp/rekon-vd204-responsive-retained-*.xcresult` bundles each
  finalized 1/1 green with no skips. Earlier failed serial attempts are
  historical diagnostics, not acceptance evidence.
- Delivery accepts Task 3 only and releases Task 4 only: use the previously
  approved, pure `PipelineBoardLane` mapping to implement the presentation-only
  four-primary Board with a fifth Closed lane only when the existing local
  Include closed filter is on, rich cards, wide/compact visual proof, and fresh
  Code Review, QA, Architecture, TPM, and Security/Privacy gates.
- VD2-04 remains **In progress** pending those gates and renewed explicit
  product-owner acceptance. VD2-05 remains **Backlog/dependency-blocked**;
  no persistent stage movement, drag/drop, workflow, model/store, storage,
  import, route, or successor work has been released.

## VD2-04 acceptance and VD2-05 Core + view-model release — 2026-07-30

- The product owner explicitly accepted VD2-04 as good enough for now. Its
  fidelity rebuild remains the accepted presentation baseline; later visual
  refinement is separate work.
- Fresh Planning, Architecture, QA, TPM, and Delivery reviews accepted the
  amended VD2-05 transaction package. Delivery released only the first
  **Transactional Core + view-model result** implementation slice, recorded in
  `docs/delivery/evidence/visual-design-v2/VD2-05-core-delivery-release-2026-07-30.md`.
- The release is limited to the typed atomic Core outcome/projection, one
  sole-writer transaction command, deterministic test-only rollback seams,
  and the view-model result/application path plus their Core/VM tests. It
  explicitly excludes Board interaction, card relocation, drag/drop, keyboard
  controls, UI fixture routing, motion, Table/inspector, filters, routes,
  imports, and all successor cards.
- VD2-05 is **In progress**; there is no eligible successor. VD2-06 through
  VD2-08 remain Backlog. Fresh independent review/QA/architecture/TPM/Delivery
  acceptance of the Core slice is required before Board interaction can be
  released; security/privacy and product-owner acceptance remain later gates.

## VD2-05 Core/VM contract-evidence repair release — 2026-07-31

- Security/privacy accepted the bounded production transaction implementation,
  but independent Code Review and QA rejected the Core/VM slice as incomplete
  evidence: audit/history identity, encrypted reopen baselines, result-specific
  state/copy/counts, selected-history locality, and signed Debug verification
  were not all bound by tests.
- Delivery recorded the rejection and released only
  `RekonPursuitCoreTests/WorkspaceStoreTests.swift`,
  `RekonPursuitTests/WorkspaceViewModelTests.swift`, and a new verification
  record. Production Core/ViewModel, Board/UI, fixtures, signing configuration,
  and dashboard behavior are out of scope.
- VD2-05 remains **In progress**. Board interaction remains withheld pending
  fresh Code Review, QA, Architecture, TPM, and Delivery acceptance of the
  repaired Core/VM evidence. VD2-06 through VD2-08 remain Backlog.

## Gate record — planning

| Role | Decision | Evidence |
| --- | --- | --- |
| Planning | Approved | Governed plan and task sequencing. |
| Architect | Approved after typed stage result and ephemeral inspector-selection contract. | Design specification and plan. |
| TPM | Approved after every-task security/privacy and per-child acceptance rules. | Plan. |
| QA | Approved after fixture, keyboard board action, evidence matrix, and fixed-clock revisions. | Plan. |
| Delivery Manager | Approved after named product-delivery record and attention/evidence lifecycle revisions. | Plan and roadmap. |

## Open risks

- Shared SwiftUI shell/theme seams require serial child release.
- No child acceptance may be inferred from implementation or tests; owner smoke
  is required before its successor can release.
- Visual test fixtures must never read a personal workspace.
- The broader pre-existing `WorkspaceStore` migration/schema test failures remain
  outside VD2-01 scope. They were not changed or used as acceptance evidence for
  this visual-foundation handoff.

## VD2-01 delivery transition — 2026-07-28

- Independent code review, QA, architecture, and security/privacy gates approved
  the isolated visual-foundation slice.
- Fresh focused unit verification completed with 33 tests and 0 failures in
  `/tmp/rekon-vd2-final-Qglnw7`; the handoff path does not launch the UI-test
  runner.
- Dashboard state remains **In progress** because product-owner hands-on
  verification is still required. `needsUserAction` is now set only for that
  verification, and `VD2-02` remains Backlog until VD2-01 is accepted.

## VD2-01 corrective visual handoff — 2026-07-28

- The product owner reported persistent gray window chrome/root canvas. Corrective
  commit `91928a4` updates the shared titlebar, root, and detail canvases.
- A fresh independent code reviewer and QA verifier approved the corrective pass.
- The card remains **In progress** pending the focused owner smoke: open the
  normal app at default, 860×600, and wide window sizes; visit Home, Contacts,
  Activity & AI, Settings, and recovery/onboarding if available; confirm a navy
  title/canvas with native traffic lights and no gray margins.
- `VD2-02` remains Backlog; this corrective pass does not release a successor.

## VD2-01 supported split-chrome handoff — 2026-07-28

- Corrective commit `ad312ae` replaces the previous window-chrome approach with
  the supported Rekon split-chrome configuration. Independent code review and QA
  cleared that corrective commit.
- Product-owner verification is now ready at the independently QA-built/signed
  app `/tmp/rekon-vd2-supported-chrome-qa-1785295233/Build/Products/Debug/RekonPursuit.app`.
  Check default, 860×600, and wide window sizes; visit Home, Contacts, Activity
  & AI, Settings, and recovery/onboarding if available; confirm a navy
  title/canvas with native traffic lights and no gray margins.
- VD2-01 remains **In progress** pending owner acceptance; no successor is
  released.

## VD2-01 resize/full-screen native-window correction — 2026-07-29

- The reported resize/full-screen regression was traced to the unsupported
  combination of a hidden-title-bar scene and an explicitly hidden window
  toolbar. The correction preserves AppKit's native titled-window host while
  using documented full-size-content and transparent-titlebar configuration.
- Implementer regression tests passed (3/3). Fresh independent code review
  found no material issues, and independent QA passed the same focused suite
  plus a signed Debug build.
- A fresh owner-verification build is available at
  `/tmp/rekon-vd2-native-chrome-AdCdIo/Build/Products/Debug/RekonPursuit.app`.
  Confirm native traffic lights and navy chrome at normal, narrow, wide, and
  full-screen/exit-full-screen states before accepting VD2-01.
- VD2-01 remains **In progress**. No dashboard state transition is recorded and
  VD2-02 remains Backlog.

## VD2-01 acceptance and VD2-02 release — 2026-07-29

- The product owner accepted the fresh native-window handoff after the requested
  visual validation ("looks good~~").
- Independent code review found no material findings. Independent QA passed the
  focused native-chrome regressions (4/4) and recorded no blocking findings;
  its direct UI automation could not safely leave full screen, a non-blocking
  tool limitation covered by the owner verification.
- VD2-01 is **Accepted**. The canonical dashboard JSON, roadmap, SDD progress
  ledger, and generated static dashboard are synchronized with that transition.
- VD2-02 is **Next up** as the sole dependency-safe successor. No VD2-02
  implementation has started.

## VD2-01 corrective reopening and VD2-02 preflight — 2026-07-29

- Product-owner evidence after VD2-01 acceptance showed four shared-foundation
  defects: the existing Rekon logo was imperceptibly small; shell, rail, and
  collapse-control foregrounds depended on OS appearance; rail spacing/icon/
  selected-state treatment did not meet the approved mockups; and gray
  toolbar/rail-cap/border chrome returned on resize and full-screen paths.
- The Delivery Manager and TPM therefore reopened `VD2-01` as **In progress**
  for a narrow corrective pass. `VD2-02` returned from Next up to **Backlog**;
  this is normal dependency sequencing, not a material blocker.
- Planning and QA returned the VD2-02 preflight as **Needs change** with an
  expanded deterministic fixture, route/departure, keyboard/VoiceOver, layout,
  and signed-Debug matrix. Architect and Delivery Manager approved the route
  ownership/data-boundary proposal. TPM approved only after the corrective
  reopening and revised dependency order are recorded.
- The canonical dashboard JSON, roadmap, and generated static dashboard are
  synchronized with this real delivery-state transition. No remediation-ledger
  entry is appropriate because this is product delivery, not remediation work.

## VD2-01 corrective implementation release — 2026-07-29

- The amended controlling plan and the independent delivery/TPM release record
  (`reviews/vd2-01-corrective-delivery-release-2026-07-29.md`) authorize only
  the bounded VD2-01 presentation correction. VD2-02 remains Backlog.
- A fresh implementer must first record failing focused tests, then identify the
  single declarative toolbar-style owner and the single runtime native-window
  configuration owner before reporting passing verification.

## VD2-01 corrective readiness for owner smoke — 2026-07-29

- Fresh independent Architecture, Code Review, QA, and Security/Privacy reviews
  are clean for the bounded presentation-only correction. QA recorded 39
  focused unit tests with 0 failures, one UI smoke with 0 failures, and a
  signed Debug build; the owner smoke remains the acceptance gate.
- `VD2-01` remains **In progress** and is now ready for product-owner hands-on
  verification. The dashboard attention item asks for the real-logo/lockup,
  appearance-stable foregrounds, selected rail treatment, and resize/full-screen
  native-chrome/traffic-light smoke.
- `VD2-02` remains Backlog. No successor has been released and no acceptance is
  inferred from reviews, tests, or a build.

## VD2-01 product-owner acceptance and VD2-02 release preparation — 2026-07-29

- The product owner accepted VD2-01 after the corrected visual smoke. The
  accepted outcome is now reflected in the canonical delivery dashboard JSON,
  product roadmap, and regenerated static dashboard; no remediation-ledger
  change is appropriate for this product-delivery transition.
- VD2-02 is the sole dependency-safe **Next up** successor. Its work has not
  started: fresh independent Planning, Architecture, TPM, QA, and Delivery
  Manager gates must release its brief before a new implementer changes the
  shared app shell or navigation routes.

## VD2-02 delivery-state reconciliation — 2026-07-29

- The Delivery Manager reconciled a stale dashboard/roadmap claim of
  `In progress` against the controlling revised brief, current SDD record, and
  independent Architecture, TPM, and QA gates. No fresh implementer has
  recorded the required red-first regression evidence or changed the app shell.
- `VD2-02` is therefore **Next up**, not In progress. This is a factual
  correction rather than a material blocker: no product-owner action is needed.
  The canonical dashboard JSON, product roadmap, and regenerated static
  dashboard were synchronized. The remediation ledger remains unchanged because
  Visual Design v2 is product delivery, not remediation work.
- The prior `vd2-02-delivery-release-2026-07-29.md` release note is superseded
  by the current gate record. Before a fresh implementation release, reconcile
  the TPM gate and record the planned observed red-first evidence; then obtain
  the required independent re-review under the revised brief.

## VD2-06 Task 1 delivery release — 2026-07-31

- Controlling artifacts are the product-owner-approved Contacts design at
  `10abc66`, the original plan/brief at `d915e9d`, and the test-foundation
  amendment at `4f065eb`.
- Independent Architecture recorded **ACCEPT**; independent QA recorded
  **ACCEPT for Task 1 only**; and independent TPM recorded **plan-readiness
  ACCEPT** while expressly leaving implementation unreleased. The Delivery
  Manager independently confirmed accepted `VD2-02` as the only prerequisite.
- Delivery releases **VD2-06 Task 1 only**: the four-file test/test-host
  foundation for ready signed `contacts` and `contacts-empty` fixtures,
  focused no-write/store-failure/relaunch/audit contracts, and signed UI RED
  that reaches Contacts and fails only for missing VD2-06 presentation.
  Production Contacts presentation, routes, schemas, launch options, failure
  hooks, broad regression, commits, and owner acceptance remain out of scope.
- `VD2-06` is **In progress at Task 1**. Task 2 is blocked pending fresh
  independent QA acceptance of Task 1 source and signed host-inventory/
  isolation/relaunch GREEN, low-layer no-write/failure/audit GREEN, and
  Contacts-reaching presentation-only RED evidence; Architecture, TPM, and
  Delivery must then independently release continuation.
- `VD2-07` and `VD2-08` remain **Backlog** and blocked from release by their
  recorded prerequisites. This is ordinary dependency sequencing, not a
  material blocker state. The authoritative delivery gate is
  `.superpowers/sdd/2026-07-31-vd206-contacts-master-detail/preimplementation-delivery-gate.md`.

## VD2-06 Task 1 technical completion and Task 2 release — 2026-08-01

- Independent Code Review, fresh QA, Architecture, TPM, and Delivery gates
  accept Task 1's technical exit only: fixture-host 2/0 GREEN, model 3/0
  GREEN, and signed UI 0/3 presentation-only RED after Contacts route
  readiness.
- `VD2-06` is **In progress at Task 2**. Delivery releases only the adaptive
  Contacts presentation slice; it is the sole eligible work. Task 3 remains
  blocked on Task 2 GREEN and Delivery release, and Task 4 remains blocked on
  Task 3 GREEN plus its independent gates.
- VD2-07 and VD2-08 remain Backlog/blocked. No product-owner acceptance,
  VD2-06 feature acceptance, or VD2-07 release is implied.
- Retained risks: `/tmp/rekon-vd206-task1-qa.iQ4zuE` evidence is ephemeral;
  the exact Task 1 fixture hunk cannot be safely isolated into a commit from
  the pre-existing dirty baseline. See the Task 1 delivery gate for detail.

## VD2-06 final acceptance closeout — 2026-08-01

- The product owner explicitly approved VD2-06 on 2026-08-01; all bounded
  technical gates are accepted. The three owner-approved VD2-08
  accessibility/recovery automation debts remain open.
- VD2-07 is eligible but neither released nor started. VD2-08 remains blocked
  pending VD2-03 through VD2-07 acceptance and retains those three debts.

## VD2-07c backlog correction — 2026-08-02

- The product owner clarified the authoritative `VD2-07c` scope: retain the
  global Activity & AI sidebar entry; use Settings-style local navigation for
  Activity ledger (default) and AI assistant; and avoid the generic narrow
  full-width underline behavior.
- The Local activity ledger uses a structured icon/label/timestamp row design
  and an independently scrolling, window-resizing viewport no taller than a
  50-row equivalent. Every retained entry remains scroll-accessible, and
  search queries the entire retained ledger.
- The existing AI filter form is replaced only by the exact approved coming-
  soon/local-private placeholder. No AI form, configuration, execution,
  provider, or network behavior is in scope. `VD2-07c` remains Backlog and
  unreleased; `VD2-08` accessibility ownership is unchanged.
