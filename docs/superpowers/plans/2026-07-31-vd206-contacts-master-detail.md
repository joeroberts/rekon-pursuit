# VD2-06 Contacts Master/Detail Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Recompose Contacts into an adaptive, read-first master/detail workspace while preserving every existing local contact, association, validation, activity, and routing contract.

**Architecture:** Keep `ContentView` as the sole owner of `WorkspaceViewModel`, canonical opportunity route, and contact-delete confirmation. Extract the current private Contacts presentation and management sheet into `ContactsView.swift`; that view owns only selection presentation, compact list/detail navigation, disclosure, focus restoration, and editor-mode state. It reads and writes exclusively through the existing `WorkspaceViewModel` draft/command surface and asks `ContentView` to open an opportunity or present deletion.

**Tech Stack:** Native macOS SwiftUI/AppKit, existing SQLCipher-backed `WorkspaceStore`, XCTest/XCUITest, signed `RekonPursuit` and `RekonPursuitUITestHost` schemes.

## Global Constraints

- Work only after independent Architecture, TPM, QA, and Delivery Manager approval and release; VD2-05 is accepted, VD2-06 is otherwise unreleased.
- Do not add data fields, persistence schema changes, dependencies, cloud/network behavior, fictional names/employers/counts/avatars, or an alternate visual system.
- `ContentView` remains the only owner of `WorkspaceViewModel`, `OpportunityRoute`, and `pendingContactDeletion`; `ContactsView` must never instantiate a model or write a store directly.
- Preserve the existing `WorkspaceViewModel` contacts surface: `filteredContacts`, `contactEmployers`, `selectContact(_:)`, `beginNewContact()`, `createContact()`, `saveSelectedContact()`, `deleteContact(_:)`, `linkSelectedContact(to:)`, and `unlinkSelectedContact(from:)`.
- Preserve validated email/profile behavior, employer typeahead/canonicalization, explicit employer association rules, `contactSaveError`, status messages, local activity/audit evidence, refresh behavior, and relaunch persistence.
- Use real persisted values only. Derive initials from a persisted contact name; omit unavailable fields and use truthful empty/error copy.
- Wide Contacts must have independent master-list and detail scrolling. At compact width detail replaces the list and exposes **Back to Contacts**; never render the detail beneath the list.
- Selection is ephemeral presentation state. It may load the existing model draft through `selectContact(_:)` but must not write until Save; Cancel must restore the pre-edit persisted selection or clear a new draft without a store write.
- Delete appears only in the selected-detail overflow beside the pencil action and continues through `ContentView`'s existing destructive confirmation. A cancelled confirmation changes neither contact nor selection.
- Retain existing stable IDs including `contact-search`, `contact-name`, `contact-employer-search`, `save-contact`, `contact-save-error`, and `manage-contact-opportunities`; add VD2-06 IDs only where the UI contract needs an unambiguous target.
- Test and owner handoffs use a normally signed Debug build. Never use `CODE_SIGNING_ALLOWED=NO` for a macOS app launch because the Data Protection Keychain is required.
- Do not update delivery status/dashboard/roadmap/evidence during implementation until the Delivery Manager opens the relevant transition. Do not start VD2-07 or broad VD2-08 whole-app acceptance from this card.

## Planned File Structure

- `RekonPursuit/ContentView.swift` — retain model/route/confirmation ownership; replace the old private Contacts invocation with the extracted view's explicit closures, retaining the current `Delete contact?` alert.
- `RekonPursuit/ContactsView.swift` — new, focused Contacts presentation unit containing `ContactsView`, the read-first detail/editor, and `ContactOpportunityManagementSheet`; no store access or app-shell ownership.
- `RekonPursuit.xcodeproj/project.pbxproj` — add only the `ContactsView.swift` file reference/build-file/group/source-build-phase entries required for the existing app target; preserve all unrelated dirty project changes.
- `RekonPursuitTests/WorkspaceViewModelTests.swift` — preserve existing contact model regressions and add only missing state-boundary coverage that is testable below SwiftUI.
- `RekonPursuitUITests/RekonPursuitUITests.swift` — signed deterministic-fixture UI contracts for wide/compact layout, edit/create/cancel/save, disclosure, association, canonical open, delete safety, keyboard accessibility, and relaunch.

---

### Task 1: Release the VD2-06 contract and deterministic test inventory

**Depends on:** Product-owner-approved `docs/superpowers/specs/2026-07-31-vd206-contacts-master-detail-design.md`; recorded Architecture, TPM, QA, and Delivery Manager approvals.

**Files:**

- Modify: `RekonPursuitTests/WorkspaceViewModelTests.swift`
- Modify: `RekonPursuitUITests/RekonPursuitUITests.swift`
- Modify only if the existing test-host fixture has no adequate contacts/opportunities: `RekonPursuit/RekonVisualTheme.swift` and `RekonPursuitUITestHostTests/RekonPursuitUITestHostTests.swift`

**Consumes:** Existing signed test-host `contacts` fixture launch contract (`-rekon-visual-fixture contacts`, UUID-qualified `REKON_VISUAL_FIXTURE_SESSION`).

**Produces:** Named deterministic RED contracts and a fixture inventory that later tasks use without reading personal workspace data.

- [ ] **Step 1: Have the four required pre-implementation roles approve scope and test strategy.**

  Architecture records that `ContentView` owns the model/route/delete confirmation and that `ContactsView` owns only ephemeral presentation state. QA records the exact fixture inventory: at least two persisted contacts with different employers, one linked opportunity, and one same-employer unlinked opportunity. TPM confirms VD2-07 remains blocked. Delivery Manager releases only this task after recording the Architecture, TPM, and QA approvals plus its own release decision.

- [ ] **Step 2: Write failing view-model tests for the already-supported no-write boundaries.**

  Add tests beside the current contact tests that create a contact with a linked opportunity, then assert: `selectContact(_:)` loads the persisted draft and associations; `beginNewContact()` clears only the draft and does not remove the stored contact/link; reselecting the contact restores the persisted fields; malformed email/profile leaves `store.contacts()` unchanged and exposes `contactSaveError`; link/unlink changes only through `linkSelectedContact(to:)` / `unlinkSelectedContact(from:)` and refreshes `selectedContactOpportunities`. Reuse `makeStore()` and `.disabledForTesting`; do not introduce a second test store abstraction.

- [ ] **Step 3: Run the new view-model tests RED.**

  Run:

  ```bash
  xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -configuration Debug -destination 'platform=macOS,arch=arm64' -only-testing:RekonPursuitTests/WorkspaceViewModelTests
  ```

  Expected: any intentionally new assertion against a missing cancellation/presentation seam fails for the stated behavior, while existing contact validation/association tests remain runnable. If the existing model already satisfies a pure behavior, record it as GREEN baseline rather than forcing a meaningless RED failure.

- [ ] **Step 4: Establish or verify the signed test-host fixture before UI RED contracts.**

  Inspect the existing fixture seeding in `RekonPursuit/RekonVisualTheme.swift` and its `REKON_UI_TEST_HOST` guards. If the `contacts` fixture lacks the exact inventory above, add only deterministic test-host seeding and a `RekonPursuitUITestHostTests` inventory assertion. Keep its fixed clock, temporary encrypted UUID-session root, relaunch behavior, and production path unchanged.

- [ ] **Step 5: Add focused failing UI contracts with stable identifiers.**

  In `RekonPursuitUITests/RekonPursuitUITests.swift`, add named tests that launch the signed `contacts` fixture at `wide` and compact window sizes. Assert: wide exposes `contacts-master-list` and `contacts-detail-region` concurrently; a row `contact-row-<id>` has text plus a non-color selected value; compact selection hides the list, exposes `Back to Contacts`, and returns to the list; `contacts-new`, `contact-edit`, `contact-overflow`, `contact-related-opportunities`, `contact-manage-opportunities`, and `contact-detail-empty`/truthful no-results states are discoverable. Attach wide and compact screenshots before dialogs.

- [ ] **Step 6: Run the UI contracts RED with the signed host.**

  Run:

  ```bash
  xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -configuration Debug -destination 'platform=macOS,arch=arm64' -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD206ContactsWideMasterDetailContract -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD206ContactsCompactDetailBackContract
  ```

  Expected: FAIL only because the required master/detail regions, compact replacement navigation, and new IDs do not exist; fixture launch/signing failures are blockers, not RED evidence.

- [ ] **Step 7: Do not commit.**

  The delivery workflow may record reviewed work later, but this delegated implementation is explicitly non-committing.

### Task 2: Extract and implement read-first adaptive Contacts presentation

**Depends on:** Task 1's fixture contract and named UI RED contracts.

**Files:**

- Create: `RekonPursuit/ContactsView.swift`
- Modify: `RekonPursuit/ContentView.swift:157` and the current private `ContactsView`/`ContactOpportunityManagementSheet` declarations beginning near line 742
- Modify: `RekonPursuit.xcodeproj/project.pbxproj` — register only `ContactsView.swift` in the `RekonPursuit` group and Sources build phase
- Test: `RekonPursuitUITests/RekonPursuitUITests.swift`

**Consumes:** `WorkspaceViewModel`'s public contact draft and association APIs; closures `open: (Opportunity) -> Void` and `delete: (Contact) -> Void` supplied by `ContentView`.

**Produces:** `ContactsView(model:open:delete:)`, an adaptive list/detail surface with explicit read, edit, and creation modes and no changed persistence ownership.

- [ ] **Step 1: Re-run the two Task 1 layout contracts and confirm RED.**

  Run the exact Task 1 focused UI command. Confirm the failures are still missing presentation contracts, not a changed fixture or an unrelated route failure.

- [ ] **Step 2: Move the private Contacts presentation into `ContactsView.swift` without changing its external closure contract.**

  Define `struct ContactsView: View` with `@ObservedObject var model`, `let open: (Opportunity) -> Void`, and `let delete: (Contact) -> Void`. Remove the duplicate private declarations from `ContentView.swift`; leave `ContentView`'s `.contacts` invocation and `pendingContactDeletion` alert as the canonical container boundary. Register only the new Swift file in `RekonPursuit.xcodeproj/project.pbxproj`; do not rewrite, revert, or absorb unrelated dirty project entries. Do not add a `WorkspaceStore`, `@StateObject`, route state, or deletion alert in the new file.

- [ ] **Step 3: Implement explicit presentation state and responsive split behavior.**

  In `ContactsView`, use local state for selected row ID, `isShowingCompactDetail`, `editorMode` (`.read`, `.edit`, `.new`), disclosure expansion, and a focus target. At wide width show an independently scrolling `contacts-master-list` and `contacts-detail-region`; selection calls `model.selectContact(contact)`, updates only local selection/display state, and moves focus to the detail heading. At compact width selection replaces the list with detail and exposes `Back to Contacts`; Back restores focus to the selected row/search control and does not clear persisted data. Use the existing theme tokens and an explicit selected label/value or checkmark in addition to the cyan/violet treatment.

- [ ] **Step 4: Implement truthful master and read-first detail states.**

  Put **Contacts**, `contacts-new`, `contact-search`, and the employer picker above the independently scrolling rows. Rows use only persisted initials/name/title/employer, get `contact-row-<id>`, and have no Delete action. Show truthful `No contacts yet.` and `No contacts match your search.` states. In read mode, show only nonempty persisted employer/title/email/profile/relationship context/notes/linked count; email/profile controls appear only for valid persisted values and preserve platform opening behavior. Use collapsed disclosures for relationship context and notes, retaining explicit accessibility values for expanded/collapsed state.

- [ ] **Step 5: Implement New/Edit/Cancel/Save without a second draft.**

  `contacts-new` calls `model.beginNewContact()` and sets `.new`; `contact-edit` enters `.edit` after the selected draft is already loaded. Reuse every existing draft binding, employer typeahead, warnings, `save-contact`, and `contact-save-error`. Save calls exactly `model.createContact()` in `.new` or `model.saveSelectedContact()` in `.edit`; only a cleared `contactSaveError` and refreshed selected contact exits edit mode. On failure keep the editor/draft visible, expose the error with text and VoiceOver, and keep Save/Cancel available. Cancel on edit reselects the original persisted `Contact` with `model.selectContact(_:)`; Cancel on new calls `model.beginNewContact()` and returns to the prior wide selection or compact list. Neither Cancel path writes.

- [ ] **Step 6: Implement safe detail actions and progressive opportunity disclosure.**

  Place `contact-edit` and a `contact-overflow` menu in the upper-right of selected detail. The overflow has only **Delete contact**, invoking `delete(selectedContact)`; it never deletes directly. `contact-related-opportunities` initially shows a real linked count; expansion lists only `model.selectedContactOpportunities`, has truthful no-related copy, and calls `open(opportunity)` from each **Open** control. `contact-manage-opportunities` explicitly opens the extracted management sheet, where only Link/Unlink calls the existing view-model commands; browsing/Open must not alter links. Keep employer-derived unlinked opportunities behind that management action.

- [ ] **Step 7: Run the focused layout contracts GREEN.**

  Run the Task 1 UI command. Expected: PASS, with attached wide and compact screenshots showing no list/detail vertical stacking and no row-level delete control.

- [ ] **Step 8: Do not commit.**

### Task 3: Complete changed-contract regression coverage and failure behavior

**Depends on:** Task 2 GREEN layout contracts.

**Files:**

- Modify: `RekonPursuitTests/WorkspaceViewModelTests.swift`
- Modify: `RekonPursuitUITests/RekonPursuitUITests.swift`
- Modify only if a test exposes an actual presentation-to-model boundary gap: `RekonPursuit/ContactsView.swift` or `RekonPursuit/WorkspaceViewModel.swift`

**Consumes:** Task 2 IDs and behavior; existing store-backed contact validation, link/unlink, activity refresh, and canonical `ContentView.openOpportunity(_:)` route closure.

**Produces:** Focused GREEN evidence for all changed interaction, failure, association, routing, deletion, keyboard, and relaunch requirements.

- [ ] **Step 1: Write RED UI tests for edit/create/cancel, validation, and safe deletion.**

  Add `testVD206ContactsNewEditCancelValidationAndDeleteContract`. It must: select a fixture contact; edit a field then Cancel and assert the read detail returns to its original persisted value after reselect/relaunch; create a blank/new draft then Cancel and assert no extra row; enter malformed email and assert `contact-save-error` remains while the editor and draft remain; save a valid edit and assert it persists after relaunch; open `contact-overflow`, select **Delete contact**, cancel the canonical alert, and assert the selected row/detail remain; confirm deletion in a separate fixture session and assert a valid remaining list or truthful empty state. The test must not inspect private SwiftUI state.

- [ ] **Step 2: Write RED UI tests for related opportunities and association boundaries.**

  Add `testVD206ContactsRelatedOpportunitiesOpenAndManageContract`. It must assert the related list is absent before disclosure, disclosure count/content matches a linked persisted opportunity, **Open** reaches the canonical opportunity overview with its existing Back control, navigating back preserves the contact list state, and merely expanding/browsing/opening did not change links. Then open `contact-manage-opportunities`, Link and Unlink only the fixture's same-employer opportunity, and assert the count/content changes and persists after relaunch.

- [ ] **Step 3: Write RED UI tests for no-result, accessibility, and resize behavior.**

  Add `testVD206ContactsAccessibilityAndTruthfulEmptyStates`. Exercise Tab/keyboard activation for search, employer filter, row selection, edit, disclosures, Manage, form fields, Cancel/Save, and overflow. Assert accessible labels/values identify selected state, disclosure state, related count, validation error, and Delete purpose. At compact/default/wide and a larger accessibility-text launch, assert visible primary actions with wrapping/truncation/scrolling rather than clipping; assert no selection, no contacts, no results, no related opportunities, and store/association error copy are truthful.

- [ ] **Step 4: Run the three new UI tests RED.**

  Run:

  ```bash
  xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -configuration Debug -destination 'platform=macOS,arch=arm64' -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD206ContactsNewEditCancelValidationAndDeleteContract -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD206ContactsRelatedOpportunitiesOpenAndManageContract -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD206ContactsAccessibilityAndTruthfulEmptyStates
  ```

  Expected: FAIL only for an uncovered behavior or missing deterministic test fixture/error seam. Do not make an existing test pass by weakening assertions.

- [ ] **Step 5: Make the minimum correction at the exposed boundary and rerun GREEN.**

  Presentation failures belong in `ContactsView.swift`. A missing truthful store/association error must retain the existing view-model status/error source; do not add direct store access. A model edit is allowed only when the unit test demonstrates that the existing public contract cannot represent the required no-write/recovery state, and must preserve existing command names, validation messages, store transactions, audit refresh, and relaunch behavior.

- [ ] **Step 6: Run focused model and Contacts UI suites GREEN.**

  Run:

  ```bash
  xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -configuration Debug -destination 'platform=macOS,arch=arm64' -only-testing:RekonPursuitTests/WorkspaceViewModelTests -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD206ContactsWideMasterDetailContract -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD206ContactsCompactDetailBackContract -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD206ContactsNewEditCancelValidationAndDeleteContract -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD206ContactsRelatedOpportunitiesOpenAndManageContract -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD206ContactsAccessibilityAndTruthfulEmptyStates
  ```

  Expected: PASS with no unrelated broad whole-app suite required at this stage.

- [ ] **Step 7: Do not commit.**

### Task 4: Proportional signed verification, independent gates, and owner review

**Depends on:** Task 3 focused suites GREEN and source diff limited to the released Contacts files/tests.

**Files:**

- Modify only if a concrete review/test defect requires it: `RekonPursuit/ContentView.swift`, `RekonPursuit/ContactsView.swift`, `RekonPursuit/WorkspaceViewModel.swift`, `RekonPursuitTests/WorkspaceViewModelTests.swift`, `RekonPursuitUITests/RekonPursuitUITests.swift`
- Create/modify only when the Delivery Manager authorizes a transition after reviews: `docs/delivery/evidence/visual-design-v2/VD2-06-owner-handoff-2026-07-31.md` and the program's governed progress record

**Consumes:** Task 3's passing focused evidence and actual signed build product.

**Produces:** Reviewer-ready signed Contacts handoff; not VD2-06 acceptance and not VD2-07 authorization.

- [ ] **Step 1: Run required focused automation and signed Debug build.**

  Run the Task 3 focused command, then:

  ```bash
  xcodebuild build -project RekonPursuit.xcodeproj -scheme RekonPursuit -configuration Debug -destination 'platform=macOS,arch=arm64'
  git diff --check
  ```

  Expected: focused tests/build pass and no whitespace errors. Do not substitute an unsigned build for the owner path.

- [ ] **Step 2: Obtain independent gates.**

  A fresh code reviewer checks spec compliance and diff scope; QA independently executes the focused automation and accessibility/manual matrix; Architecture confirms `ContentView` ownership, route, and persistence boundaries; security/privacy confirms this presentation slice adds no data collection, network, entitlement, keychain, storage, export, or data-exposure behavior. The implementer must not supply any of these verdicts.

- [ ] **Step 3: Perform the manual signed-app Contacts acceptance path before broad VD2-08 testing.**

  After the independent gates accept the slice, launch the normally signed Debug product with its configured signing identity. With real local-safe owner test data, review wide, default, compact, and resized windows; normal and larger accessibility text; keyboard-only focus/return; VoiceOver labels/values; no contacts/no results/no selection/no related states; email/profile presence; New/Edit/Cancel/save validation and store-failure recovery; related disclosure/Open; explicit Manage Link/Unlink; delete cancel/confirm; activity/audit evidence and relaunch persistence. Record screenshots/notes only after the owner review is requested by Delivery.

- [ ] **Step 4: Stop at the VD2-06 owner-acceptance boundary.**

  Delivery records no acceptance until the product owner explicitly accepts the signed build. Do not release VD2-07 and do not run the broad VD2-08 whole-app campaign; both require their own authorization and gates.

- [ ] **Step 5: Do not commit.**

## Plan Self-Review

- **Spec coverage:** Tasks 1–3 cover adaptive wide/compact composition, selection, read-first detail, New/Edit/Save/Cancel/Delete, disclosures, associations, canonical opening, truthful empty/error states, persistence, validation, activity, accessibility, and focused evidence. Task 4 places signed owner review after focused evidence and before any VD2-08 campaign.
- **Preservation:** Every mutation route names an existing `WorkspaceViewModel` command; no task changes schema, data fields, direct store ownership, contacts activity/association behavior, or opportunity route ownership.
- **Scope boundary:** The plan makes no Dashboard, roadmap, status, test-plan, unrelated project-configuration, VD2-07, or VD2-08 implementation change. The only project-file edit is the required `ContactsView.swift` source registration; evidence documentation is conditional on Delivery-authorized review/transition only.
- **Placeholder/type scan:** All produced view names, closure signatures, identifiers, commands, files, and commands are explicit. No placeholder markers, deferred implementation markers, or inconsistent method names remain.

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-07-31-vd206-contacts-master-detail.md`. Implementation must use a fresh implementer per released task, independent review/QA/architecture/security gates, and the signed owner-review boundary above. Do not execute VD2-06 until product-owner direction and the four pre-implementation approvals are recorded.
