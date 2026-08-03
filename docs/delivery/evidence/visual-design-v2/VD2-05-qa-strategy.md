# VD2-05 persisted Pipeline stage movement — QA strategy and pre-implementation gate

**Date:** 2026-07-30  
**Role:** independent QA/test gate  
**Inputs:** `docs/delivery/task-briefs/VD2-05-persisted-pipeline-stage-movement.md`, `docs/superpowers/plans/2026-07-30-vd205-persisted-pipeline-stage-movement.md`, current `WorkspaceStore`, `WorkspaceViewModel`, signed fixture host, and retained VD2-04 suites.  
**Initial verdict:** **REJECT — superseded by the fresh re-review below.**

## What is already sound

The proposed boundary correctly keeps `WorkspaceStore` as the only writer and identifies the existing unsafe behavior: `changeStage` commits, then the view model does a broad best-effort refresh. The plan also correctly requires precise-stage semantics, activity and history rollback evidence, relaunch proof, an accessible alternative to drag/drop, and signed isolated fixture execution. Current source confirms the risk: the store returns `Void` after the write transaction and the view model then calls `refreshCounts()`.

The current `pipeline` UI-test fixture is appropriate for the successful stage-move path: it is temporary, encrypted, fixed-clock, and UUID-session scoped. It already has a deterministic record at each exact stage. It is not by itself sufficient to prove the failure, stale-record, and reconciliation branches below.

## Required amendments before implementation release

### 1. Make every result case testable without weakening production isolation

The brief requires deterministic UI/manual proof for `.noOp`, `.reconciliationBlocked`, `.unavailable`, and `.failed`, but names no test-host setup that can create each state. It simultaneously says the failure hook must not be controllable through a launch argument. Add a test-host-only dependency factory, compiled only for `REKON_UI_TEST_HOST`, which chooses a predeclared fixture scenario inside the test host. The production app must not parse a failure-point argument or persist a test setting. The fixture selector may choose an isolated scenario; it must not accept arbitrary failure-point values, paths, SQL, or record data.

The amended fixture contract must provide all of the following:

| Scenario | Required deterministic setup | Required assertion |
| --- | --- | --- |
| persisted | Existing active Pipeline fixture record, e.g. Saved → Screening | Exactly one activity/history increment and returned projection/lane change |
| no-op | Existing card dropped/moved to its exact current stage | Source remains; zero activity/history increment; explicit no-op status |
| blocked Close | Isolated active record with an unconfirmed reconciliation review | Source remains; zero increments; status tells the user to confirm reconciliation |
| unavailable | A Board-visible stale card command whose store record is deleted before dispatch, created only by an injected test-host command seam | Source remains; zero increments; no title/company/error detail in status |
| write failure | Pre-write deterministic failure | Exact pre-command baseline remains after reopening the store |
| projection-read failure | Failure thrown *inside* the transaction before commit | Exact pre-command baseline remains after reopening the store |

The stale-record seam must be test-only and must not introduce a second stage writer. It can remove the existing fixture record through the canonical store before the UI dispatch, but must never synthesize a visible relocated card.

### 2. Specify the transactional projection and its assertions

`PipelineStageMoveProjection` currently lists selected history but does not say how selection is chosen, nor does it explicitly require the current opportunity list, activity list, lane counts, selected-stage history, and needs-attention snapshot to be read under the same transaction boundary. Architecture must settle the exact projection contents and selection rule. QA requires a test that causes the selected card to move and proves the returned projection updates its exact stage, relevant lane count, and selected history without calling the broad independent `refreshCounts()` path.

For both injected failure points, Core tests must compare the complete baseline of opportunities, activity events, history for the subject, and relevant task projection *after closing and reopening the encrypted store*. The current in-memory connection alone is not sufficient rollback evidence. Tests must distinguish a true `.failed` from a post-commit read failure; a commit that is merely hidden by the UI is a rejection.

### 3. Close the input/accessibility proof gaps

The plan says keyboard/VoiceOver and native drag/drop, but its named UI tests only explicitly invoke the menu action. Amend the acceptance matrix with:

1. A pure payload test that serializes only the opportunity ID and proves invalid, empty, oversized, and unknown payloads cannot call the command.
2. A signed native-drag test or explicitly documented signed manual native-drag evidence using the actual test host. It must prove source retention before persistence and the precise destination chip/lane after a successful accepted drop. A unit-only item-provider test is not native-drag proof.
3. A keyboard test that focuses and opens the Move to stage control by keyboard and activates a target, rather than tapping its menu with the pointer.
4. AX checks for the menu control's role, each exact label (`Saved`, `Applied`, `Screening`, `Interviewing`, `Offer`, `Closed`), current-stage state, and a live/announcement element for each outcome. VoiceOver review remains a required manual gate; XCUITest label lookup alone is not a VoiceOver test.
5. A pure, injected Reduce-Motion policy test plus a signed UI-host launch in Reduce Motion mode. It must prove that the move uses no spatial relocation animation while retaining focus and textual/non-color feedback. Screenshot comparison alone cannot prove the absence of animation.

### 4. Resolve target visibility and audit assertions

The plan must name the move used for the main success/relaunch contract as Saved → Screening (or another non-Closed target) so the card remains visible with Include closed off. A successful move to Closed requires Include closed on before asserting a target lane. The same-stage accessible menu entry may be disabled as specified, but the no-op contract then needs a same-stage native drop or an equivalent explicitly reachable test command; it cannot be claimed from an unavailable disabled menu item.

The relaunch/History test must assert the subject opportunity ID plus exactly one **new** `opportunity_stage_changed` activity and exactly one new matching history entry relative to that test's baseline. It must not mistake fixture creation history or another card's activity for the transition. Every scenario uses a new UUID fixture session and no personal workspace.

### 5. Capture and retained-regression matrix

The four named captures are necessary but incomplete unless their pre-capture states are fixed. Add the following matrix to the plan/brief:

| Attachment | Required state before capture |
| --- | --- |
| `vd205-board-wide-persisted-move` | Wide Board, exact source and target proven, precise target chip/lane/count visible, no external dialog |
| `vd205-board-compact-keyboard-move` | Compact Board, focus visibly on/accessibly announced Move to stage control, keyboard target move completed, source/target evidence visible |
| `vd205-board-close-reconciliation-blocked` | Close target attempted for the dedicated blocked fixture; source card remains and concise reconciliation instruction is visible; no record facts in error copy |
| `vd205-board-local-failure-recovery` | Deterministic failure fixture, source card unchanged, local-not-changed feedback visible, no diagnostics or sensitive data |

The final suite must retain all accepted VD2-04 Table, Board lane mapping, Closed filter, compact drawer, no-radio, toolbar/native-control, route-return, and filter-locality contracts. It must also recheck that moving a card into or out of Closed does not silently change the session-local Include closed filter.

## Required RED/GREEN evidence

RED is valid only when the newly named test fails because the implementation does not yet expose the required transactional result or Board affordance. A fixture, signing, compilation, accessibility-query, or build-cache failure is not valid RED evidence. Green requires signed Debug result bundles for:

- all seven Core transaction/reopen tests;
- all five view-model result cases plus status/selected-projection tests;
- pure payload and Reduce-Motion policy tests;
- signed Board UI success, keyboard, blocked, unavailable, failed, no-op/cancel/invalid-payload, Closed-filter, and relaunch/History tests;
- the retained VD2-04 regression set.

For every bundle, QA will inspect the test summary, attachments, AX hierarchy, and signature of the generated test host/product. `CODE_SIGNING_ALLOWED=NO` is not permitted.

## Gate disposition

This rejection is limited to pre-implementation testability and does not reject the product direction. After Planning and Architecture amend the fixture/failure seam, transactional projection, input proof, and capture matrix above, QA can re-review and, if satisfied, authorize only the first transactional implementation slice. No Board interaction implementation, dashboard status transition, or VD2-06–08 release is authorized by this file.

---

## Fresh QA re-review — 2026-07-30

**Role:** independent QA/test gate (fresh reviewer)  
**Decision:** **ACCEPT — authorize only the named Transactional Core + view-model result slice.**

### Re-review evidence

I re-read the amended brief and implementation plan against every initial QA
finding and the accepted transaction ADR. The package now binds the following
controls:

| Initial QA concern | Accepted control |
| --- | --- |
| Deterministic non-happy-path setup | A sealed `REKON_UI_TEST_HOST` fixture enum selects only fixed persisted, blocked-Close, unavailable, pre-write-failure, and pre-projection-failure scenarios. UUID sessions, temporary encrypted workspaces, a fixed clock, and isolated keys are required. Production does not parse a failure control. |
| Unavailable/stale correctness | The Board-visible subject is removed by the canonical store immediately before dispatch; no second writer or fabricated relocated card is allowed. |
| Atomic projection and selection | Opportunities, activities, attention tasks, and transition history are read inside the transaction. The view model applies selected history only when its current selected ID equals the commit ID, and derives its arrays/counts/selected stage from that committed projection without broad refresh. |
| Transaction, rollback, and relaunch | Seven Core contracts require baseline equality after encrypted-store reopen for blocked/unavailable/failure paths, plus atomic success and committed reopen. Five VM contracts cover all public results, conditional selection, no optimistic mutation, and thrown-error-to-`.failed`. |
| Native drag, keyboard, and VoiceOver | The plan now requires ID-only pure payload coverage; signed native drag; keyboard-only activation; AX role/current-state, live outcome, and all six exact labels; and manual VoiceOver review. |
| Motion, captures, filtering, audit | Pure and signed Reduce-Motion proof, four fixed capture states, Saved → Screening success/relaunch, Closed-filter locality, and subject-ID-plus-exactly-one-new activity/history checks are explicit. All accepted VD2-04 regressions remain required. |

### QA conditions on release

This is not implementation acceptance and does not release Board interaction.
QA must independently inspect signed Debug Core + VM bundles before Board work
is released. Before owner handoff it must rerun the entire Core/VM/pure/UI/
relaunch matrix, inspect signatures, AX hierarchy, captures, native drag,
VoiceOver, and Reduce Motion. Build/cache/fixture/signing/AX-query failures
remain invalid as RED/GREEN evidence.

### Gate effect

QA accepts the amended pre-implementation package and authorizes **only** the
dependency-safe **Transactional Core + view-model result** implementation slice
after matching fresh TPM and Delivery approvals. Board interaction, dashboard
transition, VD2-06–08 work, and owner acceptance remain blocked.
