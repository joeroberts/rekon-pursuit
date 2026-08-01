# VD2-06 — Contacts Master/Detail Task Brief

**Status:** Plan amended for QA pre-gate remediation; Task 1 may be released only after recorded Architecture, TPM, QA, and Delivery approval. Task 2 and all successor work remain blocked.

## Controlling Artifacts

- `docs/superpowers/specs/2026-07-31-vd206-contacts-master-detail-design.md`
- `docs/superpowers/specs/2026-07-28-visual-design-v2-design.md`
- `docs/superpowers/plans/2026-07-28-visual-design-v2.md`
- `docs/superpowers/plans/2026-07-31-vd206-contacts-master-detail.md`
- `.superpowers/sdd/2026-07-31-vd206-contacts-master-detail/preimplementation-qa-gate.md`
- `docs/delivery/handoffs/VD2-05-to-VD2-06-codex-handoff-2026-07-31.md`

## Objective

Deliver the approved native macOS read-first Contacts master/detail workspace while preserving current contact persistence, validation, employer association, activity/audit evidence, and canonical opportunity routing. First build and prove the signed test infrastructure that makes the presentation work testable.

## Release and Dependency Gates

1. Delivery may release **Task 1** after Architecture, TPM, QA, and Delivery independently approve this amended plan and brief. The fact that the required fixtures do not yet exist is not a release blocker: Task 1 creates them.
2. Task 1 must capture signed host inventory GREEN, low-layer test evidence, and signed UI RED that opens Contacts and fails only because VD2-06 presentation is absent.
3. **Task 2 remains blocked** until a fresh independent QA reviewer re-reviews that Task 1 evidence and source, confirms fixture isolation/inventory/relaunch plus focused low-layer no-write/failure/audit proof, and confirms the precise presentation-only RED. Architecture, TPM, and Delivery must then independently approve continuation.
4. Later tasks require prior focused GREEN evidence and independent review. VD2-07 remains blocked until explicit product-owner acceptance of a normally signed Debug VD2-06 build; VD2-08 broad whole-app acceptance is out of scope.

## Bounded Sequence

| Task | Deliverable | Exact files | Gate |
| --- | --- | --- | --- |
| 1 | Test foundation only: ready signed `contacts` and `contacts-empty` fixtures, stable-label inventory/relaunch proof, low-layer no-write/store-failure/relaunch/audit contracts, and signed Contacts-reaching UI RED | `RekonVisualTheme.swift`; `RekonPursuitUITestHostTests.swift`; `WorkspaceViewModelTests.swift`; `RekonPursuitUITests.swift` | Pre-implementation approvals; fixtures need not pre-exist |
| 2 | Extracted adaptive `ContactsView` presentation without ownership migration | Create `ContactsView.swift`; modify `ContentView.swift` and the required project-file registration only | Fresh QA accepts Task 1 evidence and Delivery releases |
| 3 | Focused deterministic UI GREEN for persistence, audit, errors, responsive/AX/keyboard, and destructive safety | Contacts unit/UI tests; smallest test-proven production correction only | Task 2 GREEN and Delivery release |
| 4 | Signed Debug verification and independent/owner review package | No source changes absent a concrete defect | Task 3 GREEN and independent gates |

## Task 1 Test-First Contract

- Add test-host-only `.contacts` and `.contactsEmpty = "contacts-empty"` to the existing `REKON_UI_TEST_HOST` fixture seam. Both are ready encrypted UUID-session workspaces and retain the host fixed clock/isolation/relaunch properties.
- Seed `contacts` with stable labels: `Contacts Primary`/Fixture North, `Contacts Secondary`/Fixture South, `Contacts Unlinked`/Fixture North, `Contacts Linked Opportunity`, and `Contacts Unlinked Opportunity`. Only Primary links to Linked Opportunity; the other Fixture North opportunity is unlinked and available only to explicit Manage. Seed ready `contacts-empty` with no contacts.
- Host inventory tests query labels and association matrix and prove relaunch determinism. Tests never use generated IDs or personal data.
- Do not add host-only store-failure scenarios, a larger-text launch mode, production preferences, schema/storage options, or direct database damage. Keep Task 1 proportional to the two missing fixtures and the focused Contacts contracts.
- Add lowest-layer coverage for non-writing selection and new draft, edit/new cancellation, invalid email/profile, explicit-only Link/Unlink, save/link/unlink/delete audit effects, fresh-model relaunch persistence, and deletion stale-selection/detail cleanup. Exercise create/update/link/unlink store failures by closing the test store before dispatch and reopening the unchanged encrypted test workspace; add no new failure hook. Existing correct behavior is recorded as GREEN baseline, never fabricated RED.
- Define the later UI failure surface: `contact-operation-error` is accessible and names the failed operation; create/update retain draft with Save/Cancel; Link/Unlink expose retry and Cancel/Close; no false success copy is shown. Use existing view-model error/status output or the smallest low-layer-proved error projection, never a new store failure framework.
- Add focused signed UI RED selectors, each using named identifiers/state waits: wide regions/independent scrolling/non-color selection; compact replacement/Back/focus return; truthful empty/no-result/no-selection/no-related states; and deterministic controls. The signed RED must reach Contacts. Fixture/signing/inventory/route defects are blockers, not RED evidence.

## Architecture, Safety, and Presentation Rules

- `ContentView` solely owns the model, route, and `Delete contact?` confirmation. `ContactsView(model:open:delete:)` owns ephemeral UI state only; it cannot instantiate a model, call a store, own a route, or directly delete.
- Preserve `selectContact(_:)`, `beginNewContact()`, `createContact()`, `saveSelectedContact()`, `deleteContact(_:)`, `linkSelectedContact(to:)`, and `unlinkSelectedContact(from:)`. No schema/data-field changes.
- Selection, disclosure, browse, canonical Open, edit Cancel, and new Cancel must not create contact/link/audit writes. Valid Save and explicit Link/Unlink must persist after relaunch with their expected audit evidence.
- Delete is detail-overflow-only. Cancel preserves row/detail/selection; confirm removes the row/links, leaves no stale selection/detail/related state, and proves the expected deletion audit. Each destructive flow has a separate UUID session.
- Keep accessibility deterministic and focused: individual tests for wide layout, compact Back/focus, AX labels/values/non-color cue, keyboard activation, and truthful states. No sleeps, coordinate-only menus, generated IDs, or monolithic catch-all test.
- Automated AX checks do not prove VoiceOver announcements or larger-text usability. Actual VoiceOver announcement/focus behavior and larger accessibility text are reserved for the signed manual QA/owner review.

## Required Signed Evidence Before Owner Review

Run only the focused Task 1 host/unit/UI selectors and affected Task 2/3 selectors, then the signed Debug build. Before independent owner review, capture:

- exact built app and host executable paths, scheme/configuration/destination, `.xcresult` paths, selectors, and fixture/session UUIDs;
- `codesign --verify --deep --strict` and `codesign -dvv` output for every launched product, including signing identity;
- app/host launch arguments and environment, including fixture and session;
- screenshots as supplemental evidence, not the sole oracle.

Never launch an unsigned `CODE_SIGNING_ALLOWED=NO` product.

## Explicit Stop

No commit, delivery evidence/status/dashboard/roadmap update, VD2-07 implementation, or broad VD2-08 campaign is authorized. After focused GREEN and independent Code Review, QA/accessibility, Architecture, and Security/Privacy approval, Delivery may request the signed owner review. Only explicit owner acceptance closes VD2-06.
