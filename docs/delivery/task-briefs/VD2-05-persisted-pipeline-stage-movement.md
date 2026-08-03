# VD2-05 — Persisted Pipeline Board stage movement

## Outcome and fixed scope

VD2-05 turns the accepted VD2-04 Board from presentation into one truthful
local workflow: a single opportunity may change precise `PipelineStage` only
when the encrypted local store commits the stage, exactly one activity event,
exactly one stage-history entry, and the Board's replacement projection in one
transaction. The Board must not relocate a card optimistically.

The accepted VD2-04 presentation is a hard baseline: retain its four primary
lanes (Saved; Applied containing Applied and Screening; Interviewing; Offer),
conditional Closed lane, exact Screening chip, Table, inspector, toolbar,
filters, routes, compact drawer, and identifiers. VD2-05 does not redesign
the Board. It adds no migration/schema/data field, cloud/network work, undo,
bulk move, collaboration, fabricated data, CSV work, Contacts/Settings work,
or VD2-06–08 work.

## One shared dependency sequence

Every release and gate uses these names and ordering:

1. **Contracts** — Planning, Architecture, QA, TPM, and Delivery review only;
   no source/test/dashboard edit is released as implementation.
2. **Transactional Core + view-model result** — the first and only initial
   implementation release. It creates the sole typed mutation boundary. It
   contains no Board interaction UI.
3. **Board interaction** — released only after fresh acceptance of the
   transactional slice. It adds native drag/drop and the equivalent keyboard/
   VoiceOver action, routed only through the accepted view-model command.
4. **Independent proof and owner handoff** — released only after fresh
   acceptance of the Board slice; evidence/accessibility strings only, no new
   behavior. Delivery then requests product-owner acceptance.

`VD2-06`–`VD2-08` remain Backlog throughout. Dashboard/roadmap/SDD status is
changed only by Delivery at a real transition.

## Binding transaction and result contract

`WorkspaceStore` remains the sole writer. Its existing `Void` stage write may
not be followed by a broad throwing `refreshCounts()` and reported as failed.
The implementation follows `ADR-VD2-05-stage-move-transaction` exactly:

```swift
enum StageMoveStoreOutcome: Equatable {
    case persisted(PipelineStageMoveCommit)
    case noOp(opportunityID: String, stage: PipelineStage)
    case reconciliationBlocked(opportunityID: String, target: PipelineStage)
    case unavailable(opportunityID: String)
}

struct PipelineStageMoveCommit: Equatable {
    let opportunityID: String
    let from: PipelineStage
    let to: PipelineStage
    let projection: PipelineStageMoveProjection
}

struct PipelineStageMoveProjection: Equatable {
    let opportunities: [Opportunity]
    let activityEvents: [ActivityEvent]
    let needsAttention: [TaskReminder]
    let stageHistoryForTransition: [StageHistoryEntry]
}

enum StageMoveResult: Equatable {
    case persisted(opportunityID: String, from: PipelineStage, to: PipelineStage)
    case noOp(opportunityID: String, stage: PipelineStage)
    case reconciliationBlocked(opportunityID: String, target: PipelineStage)
    case unavailable(opportunityID: String)
    case failed(opportunityID: String)
}
```

The Core method validates active availability; detects precise same-stage
no-op before the Close reconciliation guard; applies the unconfirmed-
reconciliation guard only for a real move to `Closed`; and, inside one
`BEGIN IMMEDIATE` transaction, writes stage/activity/history then reads the
four projection fields through private non-lock-taking queries before commit.
The commit object is returned only after commit succeeds.

`WorkspaceViewModel.changeStage(_:to:)` maps that Core outcome once. On
`.persisted` it replaces `opportunities`, `activityEvents`, and
`needsAttention`, derives their counts from those arrays, and updates the
selected opportunity only from the committed `opportunities` projection. It
replaces selected history with `stageHistoryForTransition` only if the current
selected opportunity ID equals `commit.opportunityID`; it never asks Core for
UI selection. It calls no post-commit throwing refresh. On every other result,
the current Board projection and selection remain unchanged.

`.persisted` means one committed transition, one new
`opportunity_stage_changed` event, one new matching history row, and the
returned post-transition projection. `.noOp`, `.reconciliationBlocked`, and
`.unavailable` write none. `.failed` means no committed mutation: a write,
projection-read, or commit exception rolls back stage/activity/history and is
reported without diagnostics, paths, keys, or record facts.

## Isolated, deterministic test-host contract

Core failure injection is an internal `@testable` constructor dependency,
defaulting to `nil`:

```swift
enum StageMoveFailurePoint { case beforeWrite, beforeProjectionRead }
```

It is consulted inside the transaction. It is not a product launch argument,
preference, persisted field, UI control, user-data value, or arbitrary string.

Board UI scenarios use a sealed test-host-only fixture factory, compiled under
`#if REKON_UI_TEST_HOST`. Tests continue to choose one existing typed fixture
identifier via `-rekon-visual-fixture` plus their UUID session. The fixture
identifier is an enum case, not an argument that carries failure points,
paths, SQL, IDs, or data. The factory maps only these predeclared scenarios to
fixed fixture data and fixed injected dependencies:

| Sealed scenario | Deterministic state | UI assertion |
| --- | --- | --- |
| `pipeline` | active Saved subject | Saved → Screening success/relaunch |
| `stage-move-blocked-close` | active subject with unconfirmed review | source retained; reconciliation instruction |
| `stage-move-unavailable` | initial Board-visible subject removed by the canonical store immediately before dispatch | source retained; unavailable copy; no record facts |
| `stage-move-write-failure` | Core factory has `.beforeWrite` | source retained; local-not-changed copy |
| `stage-move-projection-failure` | Core factory has `.beforeProjectionRead` | source retained; local-not-changed copy |

The stale scenario uses the canonical store for removal before dispatch and
never creates a second stage writer or a synthetic relocated card. Each UI
test owns a fresh UUID fixture session, temporary encrypted workspace, fixed
clock, and isolated key namespace; it never opens a personal workspace.

## Interaction, accessibility, and exact scenarios

- A native macOS drag payload serializes only the opportunity ID. Empty,
  oversized, malformed, unknown, cancelled, and outside-target payloads never
  call `changeStage`.
- Each card exposes an identified `Move to stage` control with all exact
  target labels: `Saved`, `Applied`, `Screening`, `Interviewing`, `Offer`, and
  `Closed`. It has a keyboard-operable path and exposes current-stage state to
  VoiceOver. Native drag is additive and never the sole way to move.
- The successful visible/relaunch scenario is **Saved → Screening**, preserving
  visibility with Include closed off. A precise same-stage request is exercised
  by native drop (or an explicitly reachable test command), not a disabled
  menu item.
- Close is tested through the dedicated blocked fixture. A successful move to
  Closed is asserted only after Include closed is enabled, and moving into/out
  of Closed must not alter that session-local filter by itself.
- Card position changes only after `.persisted`; all other outcomes retain the
  source lane. Successful, no-op, blocked, unavailable, and failed outcomes
  have distinct concise live/announcement copy. Failure says the local stage
  was not changed; blocked directs confirmation of reconciliation; neither
  exposes sensitive data.
- Reduce Motion disables spatial lift/relocation animation but keeps visible
  focus plus textual/non-color feedback. The Board remains horizontally
  scrollable and all accepted VD2-04 behavior remains intact.

## Required implementation slices and acceptance contracts

### Slice 1 — Transactional Core + view-model result

**Allowed:** `WorkspaceStore.swift`, `WorkspaceModels.swift` only for the
Core types above, Core tests, `WorkspaceViewModel.swift`, and view-model tests.
**Forbidden:** Board view/UI tests/fixture routing/dashboard changes.

Test-first Core contracts prove, with exact baseline equality before and after
close/reopen of the encrypted store:

1. valid move commits target stage, one activity, one matching history row,
   and the four-field committed projection;
2. same-stage (including Closed), missing/deleted, and blocked Close produce
   the correct outcome with zero new activity/history;
3. `beforeWrite` and `beforeProjectionRead` failures preserve opportunities,
   events, subject history, and relevant task projection after reopen; and
4. a committed move survives reopen.

View-model contracts prove all five `StageMoveResult` cases, result copy,
no optimistic relocation, committed arrays/counts, conditional selected-history
replacement, and that a thrown store/projection error is `.failed`, not
`.unavailable`. A selected subject move must prove selected history comes from
the typed committed projection and no broad refresh occurs.

Fresh code review, QA, Architecture, TPM, and Delivery accept this slice before
the Board slice is released.

### Slice 2 — Board interaction

**Allowed:** focused `PipelineBoardView.swift` (create), narrowly delegated
`PipelineView.swift`, test-host fixture factory in `RekonVisualTheme.swift`
behind `REKON_UI_TEST_HOST`, Board/unit/UI tests, and minimal semantic focus/
motion styles. After fresh Architecture, QA, TPM, and Delivery approval of the
project-registration amendment and a successor Delivery rebaseline only,
`RekonPursuit.xcodeproj/project.pbxproj` is the sixth allowed file solely to
register `PipelineBoardView.swift`. **Forbidden:** Core/schema changes,
routes, Table/inspector redesign, new data, fabricated success, and every
project change other than that registration.

The project registration is an implementation precondition, not a route to
expand scope. Preserve the original held-release manifest unchanged. Delivery
must first issue a successor manifest and record an immutable
`project.pbxproj` baseline (byte count, SHA-256, and `git hash-object -w`
blob), which the fresh implementer reproduces before RED. The accepted diff
contains exactly one `PBXFileReference` in the existing `RekonPursuit` group,
exactly two new `PBXBuildFile` entries that both reference it, and exactly one
new `PBXSourcesBuildPhase` membership in each existing app target:
`RekonPursuit` and `RekonPursuitUITestHost`. It changes no build setting,
signing setting, target, dependency, product, scheme, framework, or resource.

Before Board GREEN, preserve before/after project hashes and blobs; inspect a
zero-context structural diff; confirm the precise reference/build-file/source
membership counts; run `plutil -lint RekonPursuit.xcodeproj/project.pbxproj`;
confirm `xcodebuild -list -project RekonPursuit.xcodeproj` lists both app
targets; and perform signed Debug builds of both targets with the new file
compiled. A project parse/build failure, extra structural difference, or
baseline/manifest drift stops the slice and returns it to Delivery. Moving the
new source into `PipelineView.swift` is not an allowed alternative because it
violates the focused-file requirement.

Test-first contracts include:

- pure ID-only payload serialization/validation for valid, empty, oversized,
  malformed, unknown, cancel, and outside-target input;
- pure result-to-presentation and Reduce-Motion policy tests;
- signed native-drag proof that source remains before accepted persistence and
  target chip/lane appears only afterward;
- signed keyboard proof that focuses and opens the control without pointer
  taps and activates `Screening`;
- AX role/identifier/current-stage state, all six exact target labels, and
  live outcome element assertions; and
- signed UI cases for persisted, no-op, blocked Close, unavailable, both
  failure points, invalid/cancelled drop, closed-filter locality, relaunch,
  and canonical History audit proof.

Success/relaunch/history compares test-local baselines and asserts the subject
ID plus exactly one *new* `opportunity_stage_changed` and exactly one new
matching history entry. Fresh review and QA must accept this slice before proof
and handoff.

### Slice 3 — Independent proof and owner handoff

**Allowed:** tests/evidence and narrowly necessary accessibility identifiers or
copy. **No new workflow behavior.** Signed captures have fixed states:

| Attachment | Required pre-capture state |
| --- | --- |
| `vd205-board-wide-persisted-move` | wide Board; Saved source and Screening target/count/chip are proven and visible |
| `vd205-board-compact-keyboard-move` | compact Board; keyboard focus and completion feedback are visible |
| `vd205-board-close-reconciliation-blocked` | dedicated blocked Close scenario; source retained and redacted instruction visible |
| `vd205-board-local-failure-recovery` | deterministic failure scenario; source unchanged and local-not-changed copy visible |

QA independently reruns Core/VM/pure/UI/relaunch suites and inspects result
bundles, AX hierarchy, signatures, captures, wide/compact focus, VoiceOver
manual review, native drag manual/signed evidence, and a signed Reduce Motion
launch. It also retains all accepted VD2-04 Table, Board lane mapping, Closed
filter, compact drawer, no-radio, toolbar/native-control, route-return, and
filter-locality tests. Security/privacy independently verifies local encrypted
continuity, no network/entitlement change, fixture isolation, ID-only payload,
redacted errors, and audit/rollback integrity. Architecture/TPM/Delivery then
record their independent decisions and Delivery updates the dashboard to
awaiting owner acceptance. VD2-05 is accepted only after explicit owner
acceptance.

## Evidence standard

RED fails solely because the named contract/symbol/behavior is absent; build,
fixture, signing, cache, or AX-query failures are not RED evidence. GREEN uses
signed Debug result bundles and must verify the product, UI-test host, and test
bundle signatures; `CODE_SIGNING_ALLOWED=NO` is prohibited.

## Board Task 3 review-repair addendum — 2026-07-31

This addendum is a bounded correction to the rejected Board Task 3 review. It
does not reopen the transaction/VM contract, project registration, Board
layout, route, schema, fixture data, or retained VD2-04 product behavior.
Delivery must issue a new successor manifest before any repair edit.

Only this subset of the already approved six implementation paths may change:
`PipelineBoardView.swift`, `RekonVisualTheme.swift` under
`REKON_UI_TEST_HOST`, `RekonPursuitTests.swift`, and
`RekonPursuitUITests.swift`. `project.pbxproj` and `PipelineView.swift` are
read-only final-source controls. No other path is released.

Evidence must be classified honestly. The signed QA 6/7 Board bundle ending in
`Already in Screening.` is the only accepted product-behavior RED. History,
successful Reduce Motion, the retained VD2-04 rerun, and proof/order
strengthening are evidence gaps, not product REDs. The invalid-payload item
gets one pre-seam signed integration RED: launch the existing sealed `pipeline`
fixture, open the Board, prove the real Applied drop target exists, then fail
only because `pipeline-invalid-drag-empty` is absent. Build, fixture launch,
Board navigation, lane lookup, signing, and AX-query failures are invalid RED.

The final pure inventory remains exactly these six selectors; none may be
added, removed, or renamed. Provider-delivery identity/dedup assertions are
added inside `testPersistedResultUsesExactStageChipAndBoardLane`; invalid-form
assertions remain inside
`testEmptyOversizedMalformedAndUnknownPayloadNeverInvokesCommand`:

1. `testStageMovePayloadContainsOnlyOpportunityID`
2. `testEmptyOversizedMalformedAndUnknownPayloadNeverInvokesCommand`
3. `testCancelledAndOutsideDropNeverInvokesCommand`
4. `testNonPersistedResultsKeepSourceLane`
5. `testPersistedResultUsesExactStageChipAndBoardLane`
6. `testReduceMotionDisablesSpatialMoveAnimationButKeepsFeedback`

The repair contracts are:

1. A Board-owned delivery gate accepts the first callback for one native
   provider identity/target and suppresses only a repeated callback for that
   same delivery. A distinct provider, later native gesture, or menu action is
   not deduplicated. The accepted 6/7 behavior RED must become GREEN with
   `Moved to Screening.` retained; a new real same-stage request must still
   dispatch and present `Already in Screening.`.
2. The History selector captures the opportunity ID and source Saved lane,
   opens that ID-bound canonical Activity & history view before dispatch, and
   records matching activity/history counts. After Saved → Screening and
   relaunch of the same UUID session, the same subject view must equal baseline
   + 1 for `opportunity_stage_changed`/`Opportunity Stage Changed` and baseline
   + 1 for Saved → Screening history. This is an assertion gap; validate the
   strengthened test with a reversible expected-`+2` mutation failure, then
   restore `+1` and record GREEN.
3. The sealed UI-test host exposes four fixed native drag sources only for the
   existing `pipeline` fixture: empty data, 129-byte oversized data, malformed
   UTF-8 `[0xFF, 0xFE]`, and fixed unknown ID
   `00000000-0000-4000-8000-000000000999`. Each publishes
   `UTType.utf8PlainText` and is dragged to the real Applied lane. Read-only
   test-host AX instrumentation at the actual drop delegate reports exactly
   four provider deliveries, four validation rejections, and zero command
   dispatches. Pre/post relaunch activity/history counts are equal, the subject
   remains Saved, no outcome appears, and production products contain neither
   the sources nor instrumentation. Cancel/outside stay direct gestures.
4. The retained VD2-04 result is an evidence-order rejection only. Rerun its
   unchanged 12 selectors after the last repair edit; do not manufacture RED.
5. The Reduce Motion selector uses the normal `pipeline` fixture and performs a
   successful native Saved → Screening drop after keyboard focus is placed on
   the subject move control. The exact production branch chooses either the
   normal `.easeInOut(duration: 0.2)` animation or `nil`; UI-test-host-only,
   read-only AX counters driven from that same branch expose executed and
   suppressed counts. A normal-mode control move must report executed 1 /
   suppressed 0. A Reduce Motion move must report executed 0 / suppressed 1,
   and fail if the normal branch executes, while the target lane, exact
   `Moved to Screening.` text, and restored focus remain. Validate sensitivity
   with a reversible normal-mode mutation run; this is not a product RED.

Before review, reproduce all six pre-repair file hashes, accepted Task 2
dependency hashes, project graph/signing controls, and the Delivery repair
manifest. Preserve the evidence order: accepted behavior RED; exact invalid
pre-seam RED; focused pure/UI GREEN and declared mutation checks; combined
pure 6/6; Board UI 7/7; final-source retained VD2-04 12/12; Core 114/114; then
ViewModel 91/91. Inspect zero skips/expected failures, captures, activity tree,
AX hierarchy/counters, signatures, source/executable/XCTest/result hashes,
exact baseline-relative diffs, production-binary seam absence, non-target
manifest preservation, and `git diff --check`. Fresh QA, Architecture, and
Security/privacy must accept the amended pre-repair package before Delivery
may release implementation; all later review and owner-handoff holds remain.
