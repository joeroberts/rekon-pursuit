# VD2-05 — Core/VM contract-evidence repair delivery release

**Date:** 2026-07-31  
**Role:** Fresh independent Delivery Manager  
**Decision:** **REJECT the Core + view-model slice as incomplete; release one
test/evidence-only repair. Board interaction remains withheld.**

## Evidence assessed

| Independent role | Decision | Delivery interpretation |
| --- | --- | --- |
| Security/privacy | Accept | The transaction-only production boundary introduces no new network, entitlement, fixture-routing, or persistence exposure. This decision does not substitute for behavioral test evidence. |
| Code review | Reject | The existing Core tests do not bind the committed activity to the moved subject and exact `from`/`to` stage; they also do not prove every required encrypted-store reopen baseline. The VM tests do not cover each result copy/count/attention requirement or nonselected history preservation precisely enough. |
| QA/test | Reject | Required Task 2 contracts remain incomplete: exact audit/history identity, complete no-write baselines after reopen, result-specific ViewModel state/copy, and signed Debug evidence. |

The rejection is limited to contract and evidence completeness. It does **not**
accept the Core/VM slice, release Board interaction, alter the existing signed
production implementation, or advance VD2-05 toward owner handoff.

## Authorized repair boundary

A fresh implementer may make **test and evidence changes only** in these files:

1. `RekonPursuitCoreTests/WorkspaceStoreTests.swift`
2. `RekonPursuitTests/WorkspaceViewModelTests.swift`
3. `docs/delivery/evidence/visual-design-v2/VD2-05-core-contract-repair-verification-2026-07-31.md`

No production source, project/signing configuration, UI/Board source, fixture
routing, database schema, dashboard renderer, or Board test may change under
this release.

### Required repair contracts

The repair must add or strengthen named tests so the exact facts are proven:

1. **Committed audit/history identity.** A persisted move asserts exactly one
   newly-added `opportunity_stage_changed` activity for the subject opportunity
   and one newly-added history entry for the same subject, with the exact
   `Saved` → `Screening` transition. It must not accept another opportunity's
   activity or fixture creation history as proof.
2. **Encrypted reopen baselines.** Same-stage (including Closed), deleted or
   missing/unavailable, and reconciliation-blocked Close retain the complete
   pre-command baseline of opportunities, activities, subject history, and
   relevant needs-attention tasks after closing and reopening the encrypted
   store. Both injected failure points retain that same baseline after reopen.
3. **View-model result completeness.** The five public results prove their
   exact redacted copy and state effects: persisted updates opportunities,
   activity/attention arrays and all three counts; no-op, unavailable, blocked,
   and failed retain projection, selected ID, selected detail, selected history,
   needs-attention array, and counts. No-op/unavailable copy must be asserted
   explicitly.
4. **Selection locality.** A persisted move of an opportunity that is *not*
   selected updates the returned list/counts but does not replace the selected
   opportunity's stage-history cache.
5. **Signing evidence.** The verification record must cite freshly produced
   signed Debug Core and ViewModel `.xcresult` bundles and record a successful
   signature check for the product/test host/test bundle used by the command.
   Disabled signing is not evidence.

## Non-authorizations and holds

- `WorkspaceStore.swift`, `WorkspaceModels.swift`, `WorkspaceViewModel.swift`,
  all Board/Pipeline/UI source, drag/drop, keyboard controls, activity copy in
  the product, screen captures, test-host fixture routing, and project files
  are specifically **not** authorized.
- The repair cannot weaken an assertion, replace a reopen check with an
  in-memory check, use broad `refreshCounts()`, or accept a skipped/build/cache/
  signing failure as test evidence.
- Board interaction, card relocation, owner handoff, VD2-06, VD2-07, and
  VD2-08 remain **withheld**.

## Return gate

The repair implementer returns the exact test diff and the signed result
bundles/verification record. A **fresh** Code Reviewer and QA verifier must
accept that evidence. Architecture, TPM, and Delivery then re-evaluate the
Core/VM slice before any Board work can be released. Security's current accept
is recorded but does not waive those independent gates.

## Superseding test-target correction

The physical source path named above is compiled in the `RekonPursuitTests`
test target. The narrow follow-up
[test-target identity repair release](VD2-05-core-contract-test-identity-repair-delivery-release-2026-07-31.md)
corrects the focused selector to
`RekonPursuitTests/WorkspaceStoreTests`, authorizes only the missing
`@MainActor` test-helper annotation, and retains every production/UI/Board
hold in this release.

## Delivery state

- `VD2-05`: **In progress — Core/VM slice rejected pending test/evidence repair.**
- `VD2-06`, `VD2-07`, `VD2-08`: **Backlog.**
- `DESIGN-V2`: **Backlog.**
