# VD2-06 pre-implementation architecture gate

**Date:** 2026-07-31
**Role:** Independent Architecture re-review
**Reviewed amendment:** `4f065ebbf890549990e3fbc3be49fb72c801fbff`
**Verdict:** **ACCEPT**

## Materials reviewed

- Committed `docs/superpowers/plans/2026-07-31-vd206-contacts-master-detail.md` at `4f065eb`.
- Committed `docs/delivery/task-briefs/VD2-06-contacts-master-detail.md` at `4f065eb`.
- `docs/superpowers/specs/2026-07-31-vd206-contacts-master-detail-design.md`.
- Visual Design v2 master design and implementation plan.
- Current `RekonPursuit/ContentView.swift`, `RekonPursuit/WorkspaceViewModel.swift`, `RekonPursuit/RekonVisualTheme.swift`, and `WorkspaceStore.close()` boundaries.

## Amendment assessment

The amendment resolves the earlier test-foundation ambiguity and narrows Task 1 to a safe, test-only slice:

- exactly two ready Contacts fixtures, `contacts` and `contacts-empty`, in the existing signed host seam;
- host inventory/isolation/relaunch proof;
- focused view-model no-write, closed-store failure, relaunch, and audit proof; and
- signed UI RED that must reach Contacts and fail only on absent VD2-06 presentation.

It expressly prohibits a new failure framework, larger-text launch framework, production preference or launch argument, schema/storage option, direct database damage or mutation, personal-workspace access, broad regression work, and presentation implementation in Task 1. The missing fixtures are Task 1 deliverables, not pre-release evidence.

## Architecture evidence

### Container, route, and delete ownership

- `ContentView` remains the sole `@StateObject` owner of `WorkspaceViewModel`, the sole `OpportunityRoute` owner, and the sole `pendingContactDeletion` / `Delete contact?` confirmation owner (`ContentView.swift:21-47`, `:91-99`).
- The later `ContactsView(model:open:delete:)` retains the current observed-model and closure boundary (`ContentView.swift:157`, current private Contacts declaration at `:742-743`). It may own only row selection, compact navigation, editor/disclosure, and focus presentation state. It cannot instantiate a model or store, own a route or alert, or delete directly.
- Related-opportunity Open still invokes the supplied closure, reaching `ContentView.openOpportunity(_:)` and the guarded canonical overview route (`ContentView.swift:175-178`). No alternate opportunity editor or route is introduced.

### Draft, command, persistence, and audit boundaries

- Selection and new-draft setup continue through `selectContact(_:)` and `beginNewContact()`. Those operations load or clear in-memory draft/relationship projections without writing (`WorkspaceViewModel.swift:951-970`, `:1988-2032`).
- Contact writes remain exclusively `createContact()`, `saveSelectedContact()`, and the confirmed `deleteContact(_:)`; association writes remain exclusively `linkSelectedContact(to:)` and `unlinkSelectedContact(from:)` (`WorkspaceViewModel.swift:932-1077`). The amendment adds tests around these commands rather than a second writer.
- The closed-store failure proof uses the existing `WorkspaceStore.close()` boundary, then dispatches the normal view-model command and reopens the unchanged encrypted test workspace. It adds no injection hook, transaction mode, direct SQL/database mutation, schema change, or production recovery path.
- Task 2 may add a narrowly scoped view-model contact-operation error projection only if Task 1 low-layer evidence proves that the existing `contactSaveError` / operation-specific `statusMessage` surface is ambiguous. Such a projection may report existing command outcomes only; it cannot own persistence, retry automatically, or create a new failure mechanism.

### Fixture isolation

- The existing fixture implementation is compiled under `#if REKON_UI_TEST_HOST` (`RekonVisualTheme.swift:1229-2094`), so the two new fixture IDs and seeding remain unavailable to the production app target.
- The existing launch configuration uses a fixed clock, a sanitized explicit session, a session/fixture-specific temporary root, and a session/fixture-specific Keychain namespace (`RekonVisualTheme.swift:1341-1398`).
- The existing fixture workspace opens or creates a real encrypted workspace, retains it across explicit relaunch, uses isolated bookmark/separate-workspace dependencies, and guards cleanup against paths outside its owned non-symlinked fixture root (`RekonVisualTheme.swift:1648-1875`).
- The amendment requires stable labels rather than generated IDs, separate UUID sessions for destructive cases, host proof of encryption/root ownership/link inventory/relaunch, and no personal workspace access. This preserves the established isolation contract.

## Risks that remain implementation checks

- `contacts-empty` must create a ready encrypted workspace with zero contacts; it must not fall through to an uninitialized or onboarding state.
- The fixture seeder must use existing public store commands for contacts, opportunities, and links and must not reuse the prior stage-move hook/scenario machinery.
- Closed-store tests must create a fresh model/store for the reopen assertion and prove unchanged durable state; an error from a second close or teardown is not the required operation-failure proof.
- Link and Unlink currently report failures through operation-specific status text, while create/update also expose `contactSaveError`. Task 1 must establish whether that surface is unambiguous before Task 2 may add any projection.
- Confirmed deletion must reconcile local presentation selection with the model's cleared selected-contact draft and related caches. The amended low-layer and later isolated UI contracts explicitly cover this stale-state risk.

## ADR and high-risk gate classification

No new ADR is required. The amendment stays within the existing Visual Design v2 ownership and navigation decisions: it does not change a data contract, storage schema, transaction/rollback design, recovery architecture, route boundary, or model ownership.

No additional high-risk Security/Privacy pre-implementation gate is required for Task 1. Its encrypted-workspace activity is bounded test setup and observation through existing public/store-close seams, with no production persistence or recovery behavior change. This does not waive the program's proportional independent Security/Privacy review of the implemented VD2-06 slice before owner review. Any implementation that introduces a production failure hook, schema/storage change, direct database mutation, new recovery behavior, or broader test-host capability is outside this ACCEPT and must stop for fresh Architecture and Security/Privacy pre-gates.

## Required corrections

None. The committed amendment already states the ownership, isolation, persistence, failure-proof, scope, and successor gates needed for safe execution.

## Exact release condition

This ACCEPT does not itself release implementation. Delivery may release **VD2-06 Task 1 only** after this Architecture re-approval of commit `4f065eb`, independent TPM and QA approval of that same committed plan/brief, the Delivery Manager's independent approval, and the Delivery Manager's explicit dependency-safe Task 1 release are all recorded. The two Contacts fixtures do not need to exist before Task 1 release because creating and proving them is Task 1.

**Task 2 remains blocked** until Task 1 has produced: signed-host inventory/isolation/relaunch GREEN for both fixtures; focused low-layer no-write, closed-store failure, relaunch, deletion-cleanup, and audit GREEN; and signed UI RED that reaches Contacts and fails only on missing VD2-06 presentation contracts. A fresh independent QA reviewer must accept Task 1 source and evidence, after which Architecture, TPM, and Delivery must independently approve continuation and Delivery must explicitly release Task 2. VD2-07 remains blocked until explicit product-owner acceptance of the normally signed Debug VD2-06 build is recorded.
