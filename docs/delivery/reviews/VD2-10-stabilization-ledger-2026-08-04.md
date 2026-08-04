# VD2-10 stabilization ledger — 2026-08-04

## Status

VD2-10 is **In progress**. VD2-09 is accepted; the canonical dashboard was corrected and regenerated in `visual-design-v2` commit `23ec950`.

## Reconciliation record

Independent Planning, Architecture, and TPM/Delivery passes compared `3a7e541..c3e8f20` with the current owner direction. The owner-approved inspector action expansion is recorded as a brief amendment, not a hidden presentation-only change. The existing model/store contracts remain unchanged.

## Validated concerns queued for repair

- The desktop inspector breakpoint is 1110pt while the accepted ADR requires 1220pt.
- The inspector stage menu discards existing transaction outcomes instead of presenting them consistently with Board behavior.
- UI tests still exercise the removed Table right-click/delete selector and lack focused coverage for the replacement action model and search clear control.
- Dead, unreferenced Pipeline native-control code must be removed only if the reviewer confirms it has no remaining consumer.

## Guardrails

`default.profraw` is an untracked user artifact and excluded. No GitHub issue closure or dashboard acceptance is authorized until repair, targeted coverage, independent QA/code/security review, architecture recheck, and TPM readiness are recorded. Three failed attempts on one repair require a GitHub deferral issue and an update here unless the defect is a hard blocker.

## Deferred after three attempts

- [GitHub issue #24](https://github.com/joeroberts/rekon-pursuit/issues/24) records the macOS XCTest accessibility-tree gap for the new inspector ellipsis. Three minimal selector/containment changes were attempted and reverted: outer inspector root, header root in the compact fixture, and drawer-containment adjustment. The visible feature and existing model/store persistence and audit tests remain unaffected; this is non-blocking testability debt. No further attempt is permitted in this stabilization pass.
- [GitHub issue #25](https://github.com/joeroberts/rekon-pursuit/issues/25) records distinct macOS 26.5.2 visual-test harness debt outside the VD2-10 acceptance surface: Home action-menu discovery, Board tooltip accessibility, reduced-motion fixture observation, and an off-screen Board hit point. The coverage-enabled full suite was stopped after these known unrelated failures and is not recorded as a passing result. VD2-10-specific tests below ran clean in isolated processes.

## Stabilization evidence

- `0e18868` restored the accepted 1220pt desktop/compact guard band. Its predicate test was red then green; `0a2d372` added a 1219/1220 UI boundary test with test-host fixtures.
- `e26f274` removed unreferenced Pipeline native-control classes after a reference audit and a fresh macOS Debug build.
- `85e39d1` removed the per-row asynchronous native-selection mutation. Independent review found its first bridge too broad; `62c9d07` replaced it with a List-owned table selection owner that restores only its own `.none` override. The ownership/replacement unit test was red then green.
- `282b2b7` replaced stale inspector-root and fragile native-row accessibility assertions with current inspector-fact selection checks. Its two focused UI tests passed. `4c5f0f4` removed the intentionally obsolete Table right-click deletion test; two existing deletion persistence/projection tests passed.
- `3bcab79` added stable search icon/clear identifiers and a focused clear-X regression test. The test was red for the absent seams and green after the minimal accessibility-only change.
- `35c6b32` surfaces persisted inspector-stage outcomes through the existing Pipeline presentation path; `4c19bae` removed the superseded inspector stage field. `0e08140` and `d6f5f34` add and cover the Pipeline-level notice required when a successful move filters the selected row out of Table.
- `b875ffa` restored the Pipeline-local native Table/Board segmented-control owner; `565899a` aligned its AppKit semantics, and its direct unit/UI tests cover full-segment targets, radio descendants, labels, and wide/compact operation. `46a97bd` corrected the Board fidelity fixture to its actual Screening destination and `51f36bb` stabilized the Board stage-move outcome oracle.
- The final native selection repair was test-first: its sibling-background mount test failed against the original owner and passed after the bounded ancestor fallback. The initial live repair still rendered opaque blue because SwiftUI had not constructed the sibling List table when installation ran; a synchronous layout retry fixed that lifecycle ordering without timers or asynchronous mutation. A manual macOS Table review then confirmed the selected row uses only the intended subdued/translucent SwiftUI highlight; Board mode, the inspector close-then-actions order, and the stage/delete menu were also rechecked without mutating data.
- A fresh root targeted suite passed **12/12** on macOS 26.5.2 at `/private/tmp/rekon-vd210-selection-final.xcresult`, including selection ownership/restoration, wide/compact Table behavior, search clear, view-mode segments, Table selection, Board fidelity, and persisted native Board drag. The earlier independent QA gate passed **17/17** at `/private/tmp/rekon-vd210-qa-gate-r2.xcresult`, `/private/tmp/rekon-vd210-qa-stage-r3.xcresult`, `/private/tmp/rekon-vd210-qa-selection-r4.xcresult`, and `/private/tmp/rekon-vd210-qa-model-r5.xcresult`.
- A fresh signed macOS Debug build passed at `/private/tmp/rekon-vd210-selection-final-build.log` after the final selection repair.

## Final-gate status

Independent architecture, security/privacy, and integration code-review gates approved the reconciled stabilization changes with no model, store, routing, audit, migration, or security concern. The final native-selection code review approved the bounded bridge repair; its documentation clarification was applied. A separate QA verifier then ran the four final selection/Table checks sequentially, passing **4/4** with no skips at `/private/tmp/rekon-vd210-selection-qa.N0asm1/`. The independent TPM/Delivery recheck reviewed the same evidence and marked the candidate **Ready for owner acceptance**.

GitHub #16 remains open and VD2-10 remains **In progress**. Neither the dashboard nor the issue may move to accepted/closed until those final gates and owner visual/workflow acceptance are recorded.
