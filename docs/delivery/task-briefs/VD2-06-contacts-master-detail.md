# VD2-06 — Contacts Master/Detail Task Brief

**Status:** Planning complete; not released for implementation.

**Controlling artifacts:**

- `docs/superpowers/specs/2026-07-31-vd206-contacts-master-detail-design.md`
- `docs/superpowers/specs/2026-07-28-visual-design-v2-design.md`
- `docs/superpowers/plans/2026-07-28-visual-design-v2.md`
- `docs/delivery/handoffs/VD2-05-to-VD2-06-codex-handoff-2026-07-31.md`
- `docs/superpowers/plans/2026-07-31-vd206-contacts-master-detail.md`

## Objective

Deliver a native macOS, read-first Contacts master/detail workspace: independently scrollable master list/detail at wide widths; compact list-to-detail replacement with **Back to Contacts**; read-first selection; same-region New/Edit/Save/Cancel; progressive notes and opportunities; explicit association management; and safe detail-only deletion.

## Release Gate and Dependencies

1. Product-owner direction starts VD2-06 planning/execution; the existing VD2-05 handoff alone does not release work.
2. Architecture, TPM, QA, and Delivery Manager independently approve the full plan and this brief.
3. Delivery Manager releases Task 1 only after those approvals are recorded. Each later task depends on the prior task's focused GREEN evidence and separate reviewer/QA checks.
4. VD2-07 remains blocked until a product owner accepts a normally signed Debug VD2-06 build and Delivery records that acceptance. VD2-08 broad whole-app acceptance is out of scope.

## Bounded Implementation Sequence

| Task | Deliverable | Exact files | Dependency / gate |
| --- | --- | --- | --- |
| 1 | Deterministic contact fixture inventory plus model/UI RED contracts | `RekonPursuitTests/WorkspaceViewModelTests.swift`; `RekonPursuitUITests/RekonPursuitUITests.swift`; fixture seam only if needed: `RekonPursuit/RekonVisualTheme.swift`, `RekonPursuitUITestHostTests/RekonPursuitUITestHostTests.swift` | Pre-implementation approvals |
| 2 | Extracted adaptive `ContactsView` presentation with read-first states and no ownership move | Create `RekonPursuit/ContactsView.swift`; modify `RekonPursuit/ContentView.swift` and only the required `ContactsView.swift` entries in `RekonPursuit.xcodeproj/project.pbxproj` | Task 1 RED fixture/UI contract |
| 3 | Focused GREEN regressions for cancel/validation/delete/association/routing/accessibility/relaunch | `RekonPursuitTests/WorkspaceViewModelTests.swift`; `RekonPursuitUITests/RekonPursuitUITests.swift`; minimal proved correction only in `RekonPursuit/ContactsView.swift` or `RekonPursuit/WorkspaceViewModel.swift` | Task 2 GREEN wide/compact contract |
| 4 | Signed build, manual owner path, independent review package | No source change absent a concrete defect; delivery evidence only after Delivery authorization | Task 3 GREEN and independent gates |

## Non-Negotiable Architecture and Preservation Rules

- `ContentView` is the sole `WorkspaceViewModel`, opportunity-route, and destructive-contact-confirmation owner. The extracted `ContactsView` receives `model`, `open: (Opportunity) -> Void`, and `delete: (Contact) -> Void` only.
- `ContactsView` owns only ephemeral selection, compact navigation, editor/disclosure/focus state. It does not create a model, call a store, own a route, or own an alert.
- Use the current validated draft and commands: `selectContact(_:)`, `beginNewContact()`, `createContact()`, `saveSelectedContact()`, `deleteContact(_:)`, `linkSelectedContact(to:)`, and `unlinkSelectedContact(from:)`.
- Preserve contact persistence/schema, email/profile validation warnings and errors, employer typeahead and canonical employer selection, employer-association restriction, interaction/activity/audit refresh, store failures, and relaunch behavior.
- Browsing related opportunities and **Open** are read-only and route through the canonical opportunity closure. Only explicit **Manage** Link/Unlink controls change associations.
- Delete is absent from master-list rows, exists only in a selected detail overflow, uses `ContentView`'s existing **Delete contact?** confirmation, and leaves selection untouched on cancellation.
- Use real persisted values; derive initials from name. Never add fictional data or fabricated relationship counts.

## Test-First Acceptance Contracts

**RED before implementation**

- Signed deterministic `contacts` fixture has at least two contacts with distinct employers, a linked opportunity, and a same-employer unlinked opportunity.
- Wide test requires concurrent `contacts-master-list` / `contacts-detail-region`, readable non-color selected-row state, and no row delete control.
- Compact test requires selection to replace—not stack under—the list and **Back to Contacts** to return predictably.
- Tests require identifiers: retained `contact-search`, `contact-name`, `contact-employer-search`, `save-contact`, `contact-save-error`, `manage-contact-opportunities`; new `contacts-new`, `contact-row-<id>`, `contacts-master-list`, `contacts-detail-region`, `contact-edit`, `contact-overflow`, `contact-related-opportunities`, `contact-manage-opportunities`.

**GREEN focused checks**

```bash
xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -configuration Debug -destination 'platform=macOS,arch=arm64' -only-testing:RekonPursuitTests/WorkspaceViewModelTests -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD206ContactsWideMasterDetailContract -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD206ContactsCompactDetailBackContract -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD206ContactsNewEditCancelValidationAndDeleteContract -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD206ContactsRelatedOpportunitiesOpenAndManageContract -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD206ContactsAccessibilityAndTruthfulEmptyStates

xcodebuild build -project RekonPursuit.xcodeproj -scheme RekonPursuit -configuration Debug -destination 'platform=macOS,arch=arm64'

git diff --check
```

Focused tests must demonstrate: selection is non-writing; edit/new Cancel leaves no write; invalid email/profile and store failure retain draft/error/recovery; valid save and Link/Unlink persist over relaunch; related disclosure/Open does not alter associations; deletion cancel/confirm is safe; no contacts/no results/no selection/no related states are truthful.

## Responsive, Accessibility, and Signed Owner Path

- Check wide/default/compact resizing and larger accessibility text. Master/detail must scroll independently at wide widths; compact detail never appears below the list; primary actions stay reachable by wrapping, truncation, or scrolling.
- Keyboard covers search, filter, row, Back, pencil, overflow/delete, disclosure, Manage, form fields, Cancel, and Save. Focus moves into detail/editor and returns to the originating row/control when it remains available.
- VoiceOver exposes row/selection state, button purpose, expanded/collapsed state, related count, warnings/errors, and non-color state semantics.
- After focused automation and independent code-review, QA/accessibility, architecture, and proportional security/privacy verification, build and launch the configured normally signed Debug app. Do not launch an unsigned `CODE_SIGNING_ALLOWED=NO` app.
- Owner manually checks real-safe Contacts data: layouts, search/filter, selection, New/Edit/Cancel/Save, validation/store failure recovery, disclosure/Open, explicit Manage association changes, delete cancellation/completion, activity/audit evidence, and relaunch persistence. Owner acceptance—not a passing test—closes VD2-06.

## Explicit Stop

This brief authorizes no dashboard/roadmap/status/evidence transition, VD2-07 implementation, or VD2-08 whole-app campaign. The only configuration edit permitted during implementation is registering the new `ContactsView.swift` source file; preserve all unrelated dirty project entries. Do not commit as part of this bounded work.
