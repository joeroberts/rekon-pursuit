# VD2-06 Contacts Master/Detail Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver the approved adaptive, read-first Contacts master/detail workspace without changing persistence ownership, schemas, or canonical opportunity routing.

**Architecture:** `ContentView` remains the sole owner of `WorkspaceViewModel`, opportunity routing, and destructive confirmation. Before presentation work, Task 1 adds only two deterministic Contacts fixtures to the existing signed `REKON_UI_TEST_HOST` and focused low-layer/UI RED contracts. Store failures are proved without new failure machinery by exercising the existing model against a deliberately closed test store and reopening the unchanged encrypted fixture. The later extracted `ContactsView` consumes existing view-model commands and closures only.

**Tech Stack:** Swift/SwiftUI/AppKit, SQLCipher-backed `WorkspaceStore`, XCTest/XCUITest, signed Debug `RekonPursuit` and `RekonPursuitUITestHost` schemes.

## Global Constraints

- Delivery may release **Task 1** after the approved plan/brief and independent Architecture, TPM, QA, and Delivery approvals are recorded. The currently absent contacts fixtures are Task 1's deliverable, not a precondition to Task 1.
- **Task 2 is blocked** until an independent QA re-review accepts Task 1's source, host-inventory GREEN evidence, focused low-layer failure/no-write evidence, and signed UI RED bundle showing that Contacts is reached and failures are only missing VD2-06 presentation.
- Do not add data fields, migrations, dependencies, cloud/network behavior, fictional product data, or a competing visual system. VD2-07 remains blocked; do not begin VD2-08 broad acceptance work.
- `ContentView` alone owns `WorkspaceViewModel`, `OpportunityRoute`, and `pendingContactDeletion`. `ContactsView` creates neither a model nor a store and never writes directly.
- Preserve `filteredContacts`, `contactEmployers`, `selectContact(_:)`, `beginNewContact()`, `createContact()`, `saveSelectedContact()`, `deleteContact(_:)`, `linkSelectedContact(to:)`, and `unlinkSelectedContact(from:)`, including validation, activity/audit refresh, employer rules, and relaunch behavior.
- The test host remains compiled only by `REKON_UI_TEST_HOST`, uses its existing fixed clock, UUID-qualified temporary encrypted root, and explicit relaunch retention. No test uses personal workspace data, generated record IDs, database damage, private SwiftUI state, sleeps, or coordinate-only menu selection. Do not add a new store failure hook, schema option, or production launch argument for VD2-06.
- Use stable fixture labels and fixed accessibility identifiers; destructive UI cases each use a fresh UUID fixture session. Wait for named identifiers or value transitions.
- Preserve existing IDs `contact-search`, `contact-name`, `contact-employer-search`, `save-contact`, `contact-save-error`, and `manage-contact-opportunities`. New IDs must be deterministic and scoped to the Contacts contract.
- Automation and owner launches use a normally signed Debug product. Never launch with `CODE_SIGNING_ALLOWED=NO`.
- Do not commit or update reports, dashboards, roadmap, status, or delivery evidence in this work. Evidence capture is for independent review only and is recorded by Delivery only when separately authorized.

## Planned File Structure

| File | Responsibility |
| --- | --- |
| `RekonPursuit/RekonVisualTheme.swift` | Existing `REKON_UI_TEST_HOST` fixture enum, parser, and isolated Contacts seeding only. |
| `RekonPursuitUITestHostTests/RekonPursuitUITestHostTests.swift` | Fixture parser, inventory, isolation, and relaunch proof. |
| `RekonPursuitTests/WorkspaceViewModelTests.swift` | Low-layer selection/draft/no-write/relaunch/audit behavior. |
| `RekonPursuitUITests/RekonPursuitUITests.swift` | Focused signed UI contracts, each with its own session and named-state waits. |
| `RekonPursuit/ContentView.swift` | Later only: retain model, route, and delete-confirmation ownership. |
| `RekonPursuit/ContactsView.swift` | Later only: extracted presentation state and Contacts UI; no store ownership. |
| `RekonPursuit.xcodeproj/project.pbxproj` | Later only: source registration for `ContactsView.swift`. |

---

### Task 1: Build the bounded signed Contacts fixtures and RED contracts

**Depends on:** The approved VD2-06 design, this amended plan/brief, and recorded Architecture, TPM, QA, and Delivery approvals.
**Release:** Delivery may release this task with those approvals; neither Contacts fixture exists yet.
**Files:** Modify only `RekonVisualTheme.swift`, `RekonPursuitUITestHostTests/RekonPursuitUITestHostTests.swift`, `WorkspaceViewModelTests.swift`, and `RekonPursuitUITests.swift`.

**Produces:** Signed-host-ready `contacts` and `contacts-empty` fixtures, low-layer no-write/failure/audit proof, and focused UI RED that reaches Contacts.

- [ ] **Step 1: Freeze the test-only fixture contract and write host RED inventory tests.**

  Add `.contacts` and `.contactsEmpty = "contacts-empty"` to the existing test-host-only `VisualFixtureID`. Define stable fixture labels, not generated IDs: `Contacts Primary` at `Fixture North`; `Contacts Secondary` at `Fixture South`; `Contacts Unlinked` at `Fixture North`; `Contacts Linked Opportunity`; and `Contacts Unlinked Opportunity`. The ready `contacts` encrypted workspace contains exactly those three contacts, links only Primary to Linked Opportunity, and leaves Unlinked Opportunity eligible for explicit management. The ready `contacts-empty` workspace opens normally with no contacts. Add host tests that open both fixtures, query the inventory by those labels, prove the link matrix, prove the root is session-owned and encrypted, and reopen a fresh model against the same session to prove deterministic inventory survives relaunch.

- [ ] **Step 2: Implement the minimum two-fixture host and prove it GREEN.**

  Seed the two ready fixtures through `VisualFixtureWorkspace.seedFixtureIfNeeded`; retain the existing UUID root, Keychain namespace, fixed clock, and cleanup guards. Add no failure scenario, larger-text launch mode, production preference, route, schema, or direct database mutation. Run the named host parser/inventory/isolation/relaunch tests GREEN.

- [ ] **Step 3: Add and run low-layer Contacts contracts before SwiftUI implementation.**

  Using `makeStore()` and `.disabledForTesting`, add focused tests that prove: selection loads persisted fields and links without writes; `beginNewContact()` clears only the draft; edit/new cancel restoration has no contact/link/audit write; invalid email and profile make no write; explicit Link/Unlink alone changes the association; save, Link/Unlink, and delete have the applicable existing activity/audit evidence; a fresh model sees each intended persisted result; and delete clears stale selection/draft/related-opportunity cache or selects a valid remaining state. For create/update/link/unlink store-failure behavior, close the test store before dispatch, assert the draft or association remains unchanged and the existing error/status projection is truthful, then reopen the encrypted test workspace to prove no mutation. Add no new store failure hook. Record existing correct behavior as an honest GREEN baseline; only missing contracts are RED.

- [ ] **Step 4: Add narrowly scoped signed UI RED contracts and run them in a normally signed host.**

  Create only presentation-expectation tests that launch the ready fixtures and first navigate with `sidebar-contacts`, then wait for `contact-search`. Split the contracts into: wide regions/independent scroll containment/selected non-color value; compact replacement, Back, and focus return; stable empty/no-result/no-selection/no-related state; and named controls for New/Edit/overflow/disclosure/Manage. Use fixture labels with identifiers such as `contact-row-contacts-primary`, never record IDs. Each test must attach a screenshot only as supplemental evidence and fail specifically on missing presentation identifiers or states.

  Run the signed focused selectors. The required RED outcome is: fixture launch succeeds, Contacts is visible, and each failure is solely a missing VD2-06 presentation contract. A host launch, signing, inventory, route-to-Contacts, or failure-seam defect blocks rather than qualifies as RED.

- [ ] **Step 5: Run the exact focused commands and capture Task 1 evidence.**

  ```bash
  xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -configuration Debug -destination 'platform=macOS,arch=arm64' \
    -only-testing:RekonPursuitUITestHostTests/RekonPursuitUITestHostTests/testVD206ContactsFixtureInventoryAndRelaunch \
    -only-testing:RekonPursuitUITestHostTests/RekonPursuitUITestHostTests/testVD206ContactsEmptyFixtureIsReady

  xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -configuration Debug -destination 'platform=macOS,arch=arm64' \
    -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testVD206ContactSelectionAndNewDraftDoNotWrite \
    -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testVD206ContactFailuresRetainDraftAndAssociations \
    -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testVD206ContactAuditAndRelaunchContracts

  xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -configuration Debug -destination 'platform=macOS,arch=arm64' \
    -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD206ContactsWideMasterDetailContract \
    -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD206ContactsCompactDetailBackContract \
    -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD206ContactsTruthfulEmptyStatesContract
  ```

  The host and model selectors must be GREEN. The signed UI selectors must reach Contacts and be RED only on missing VD2-06 presentation contracts.

  Preserve the exact signed test result bundle paths, scheme/configuration/destination, fixture/session UUIDs, host inventory GREEN summary, low-layer result summary, and UI RED failure names. Capture the built host/app paths and run `codesign --verify --deep --strict <built-host-or-app-path>` plus `codesign -dvv <built-host-or-app-path>` for each launched product; record the identity, executable path, and launch arguments/environment used. Do not update a delivery evidence file.

- [ ] **Step 6: Gate Task 2; do not commit.**

  A fresh independent QA reviewer, not the Task 1 implementer, must inspect source and execute/review the evidence above. Task 2 may be released only when QA confirms fixture isolation/inventory/relaunch, low-layer no-write/failure/audit proof, and that the signed UI RED reaches Contacts and fails only for missing presentation. Architecture, TPM, and Delivery then record their independent continuation decision. This is a post-Task-1 gate, not a circular requirement that the Task 1 deliverables already exist before Task 1 starts.

### Task 2: Extract and implement the read-first adaptive Contacts presentation

**Depends on:** Independent QA acceptance of Task 1's evidence and Delivery release.
**Files:** Create `RekonPursuit/ContactsView.swift`; modify `ContentView.swift` and only the required `ContactsView.swift` project entries.
**Produces:** `ContactsView(model:open:delete:)` with no changed persistence/route/delete ownership.

- [ ] **Step 1: Re-run the Task 1 signed UI RED selectors unchanged.**

  Verify the fixture reaches Contacts and each outstanding failure remains presentation-only. A changed fixture/inventory/signature failure stops the task and returns to Task 1 remediation.

- [ ] **Step 2: Extract the presentation boundary without changing ownership.**

  Define `ContactsView` with `@ObservedObject var model`, `let open: (Opportunity) -> Void`, and `let delete: (Contact) -> Void`. Move only the private Contacts presentation and management sheet; retain the `ContentView` contacts route and `Delete contact?` confirmation. Register the new file only. Do not introduce a store, `@StateObject`, route, direct delete, schema, or production test seam.

- [ ] **Step 3: Implement wide/compact and truthful read states.**

  At wide size render independently scrolling `contacts-master-list` and `contacts-detail-region`; selected row value must expose text/semantic selected state in addition to color. At compact size a selection replaces the list and `Back to Contacts` returns focus to its initiating row or search. Render stable `contacts-new`, `contact-edit`, `contact-overflow`, `contact-related-opportunities`, and `contact-manage-opportunities`; rows never contain Delete. Render truthful `contacts-empty`, no-result, no-selection, and no-related states using persisted data only.

- [ ] **Step 4: Implement edit/create/failure/recovery and related management.**

  New/Edit uses existing draft bindings and exactly `createContact()` or `saveSelectedContact()`; Cancel restores the original persisted contact or clears a new draft without a write. Present a scoped accessible `contact-operation-error` from the existing view-model error/status projection; a narrowly scoped view-model error projection may be added only if focused low-layer proof shows the existing projection is ambiguous. Do not add a store failure hook. Disclosure and Open are read-only; Open invokes the supplied closure. Only explicit Manage Link/Unlink invokes existing commands. Overflow invokes the supplied delete closure only.

- [ ] **Step 5: Run the Task 1 layout/state selectors GREEN; do not commit.**

  Require stable named-state and containment assertions, not screenshots alone. Keep broad regression and VD2-08 work out of scope.

### Task 3: Add focused deterministic regression, safety, and accessibility evidence

**Depends on:** Task 2 GREEN and Delivery release.
**Files:** Modify contacts unit/UI tests; modify `ContactsView.swift` or `WorkspaceViewModel.swift` only for a test-proven boundary defect.
**Produces:** Focused GREEN behavior evidence.

- [ ] **Step 1: Add separate UI contracts for writes, relaunch, and destructive safety.**

  In isolated sessions, test edit Cancel and new Cancel each leave contacts, links, and audit count unchanged; valid Save persists after relaunch with the expected audit record; Link and Unlink each persist after relaunch with their expected audit evidence; disclosure and canonical Open do not write contacts, links, or audit; delete Cancel preserves selected row/detail; delete Confirm removes row/links, leaves no stale selection/detail/related cache, and has the expected deletion activity evidence. Never combine destructive confirmation paths in one session.

- [ ] **Step 2: Prove failure recovery at the lowest practical layer.**

  Keep deterministic create/update/link/unlink store-failure and no-write assertions in the view-model suite using the deliberately closed test store and reopened encrypted workspace. In signed UI, use validation failure to prove `contact-operation-error`, retained draft, Save/Cancel availability, and no false success copy. Review the shared error rendering path rather than adding host-only persistence machinery.

- [ ] **Step 3: Add focused accessibility and responsive contracts.**

  Keep distinct tests for (a) wide concurrent regions and scroll containment, (b) compact replacement/Back/focus return, (c) selected/disclosure/error labels/values and non-color cues, (d) keyboard activation through named controls, and (e) truthful empty/error states. Use element/state waits and semantic menus, never sleeps or coordinates. Larger accessibility text and actual VoiceOver announcements remain in the signed manual QA/owner matrix; do not add new launch infrastructure solely for those checks.

- [ ] **Step 4: Run focused RED, apply the smallest proved correction, then run GREEN.**

  A RED failure must identify one missing behavior or presentation contract. Correct presentation in `ContactsView.swift`; change the model only when low-layer evidence proves its existing public contract cannot express the requirement. Run only the Task 1 host tests, affected low-layer tests, and the focused VD2-06 selectors; no broad suite is required.

  ```bash
  xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -configuration Debug -destination 'platform=macOS,arch=arm64' \
    -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testVD206ContactSelectionAndNewDraftDoNotWrite \
    -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testVD206ContactFailuresRetainDraftAndAssociations \
    -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testVD206ContactAuditAndRelaunchContracts \
    -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD206ContactsWideMasterDetailContract \
    -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD206ContactsCompactDetailBackContract \
    -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD206ContactsTruthfulEmptyStatesContract \
    -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD206ContactsEditCancelSaveAndRelaunchContract \
    -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD206ContactsRelatedOpportunitiesAndAssociationContract \
    -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD206ContactsDeleteSafetyContract \
    -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD206ContactsErrorAccessibilityContract \
    -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD206ContactsKeyboardContract
  ```

  Expected: PASS. If one selector is unstable, diagnose that selector only; do not expand to a broad suite or weaken its contract.

### Task 4: Signed review package and owner boundary

**Depends on:** Task 3 GREEN and independent reviewer/QA/Architecture/Security acceptance.
**Produces:** A review-ready signed Debug handoff, never automatic VD2-06 acceptance or successor release.

- [ ] **Step 1: Re-run the focused suite and produce the signed Debug product.**

  Run the approved focused host/unit/UI selectors, `xcodebuild build -project RekonPursuit.xcodeproj -scheme RekonPursuit -configuration Debug -destination 'platform=macOS,arch=arm64'`, and `git diff --check`. Verify the exact app and host artifacts with `codesign --verify --deep --strict` and capture `codesign -dvv` identity/output, built paths, test result bundle paths, and every automation fixture/session launch record before owner review.

- [ ] **Step 2: Obtain independent gates.**

  Fresh Code Review, QA, Architecture, and Security/Privacy independently review the bounded diff and evidence. QA's signed manual matrix includes actual VoiceOver announcement behavior and focus return; AX automation is not evidence of spoken VoiceOver announcements.

- [ ] **Step 3: Conduct the Delivery-authorized signed owner review, then stop.**

  With real-safe local data, manually verify normal/wide/default/compact/resized/larger text; keyboard and VoiceOver announcements/focus; empty/no-result/no-selection/no-related/error states; validation and failure recovery; association safety; activity/audit evidence; delete safety; and relaunch. Delivery records no acceptance until explicit owner approval. Do not release VD2-07 or start VD2-08.

## Plan Self-Review

- **QA-gate remediation:** Task 1 now builds and proves the currently absent signed fixtures before UI presentation; Task 2's independent QA gate is post-evidence and non-circular.
- **Safety/persistence:** Low-layer and UI contracts explicitly cover no-write selection/cancel/browse/Open, audit effects, relaunch, closed-store failure recovery, deletion cleanup, and isolated destructive sessions without a new failure framework.
- **Accessibility:** Deterministic AX/keyboard/resize contracts are split; only the signed manual path claims VoiceOver announcement verification.
- **Scope:** Two bounded test-only fixtures precede presentation. No new failure/larger-text framework, production storage path/schema/direct database mutation, broad VD2-08 work, VD2-07 release, delivery artifact update, or commit is authorized.
- **Placeholder/type scan:** All fixture names, stable labels, identifiers, commands, files, gates, and evidence items used by later tasks are defined above.

## Execution Handoff

Plan amended at `docs/superpowers/plans/2026-07-31-vd206-contacts-master-detail.md`. Delivery may release Task 1 after the approved pre-implementation gates; Task 2 remains blocked pending fresh independent QA review of Task 1 evidence.
