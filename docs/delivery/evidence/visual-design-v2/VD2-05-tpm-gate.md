# VD2-05 — independent TPM pre-implementation gate

**Date:** 2026-07-30  
**Role:** Fresh TPM (planning gate)  
**Decision:** **SUPERSEDED — see the fresh re-review decision below.**

> This initial rejection remains as historical evidence. The planning package
> was amended before the fresh independent TPM re-review recorded at the end
> of this file. It does not authorize an implementation release.

## Evidence reviewed

- `docs/delivery/task-briefs/VD2-05-persisted-pipeline-stage-movement.md`
- `docs/superpowers/plans/2026-07-30-vd205-persisted-pipeline-stage-movement.md`
- `docs/delivery/evidence/visual-design-v2/VD2-05-planning-release-2026-07-30.md`
- `docs/delivery/dashboard-status.json`
- `docs/delivery/roadmap.md`
- the accepted VD2-04 owner handoff and fidelity records referenced by the
  planning release.

## Dependency and scope assessment

`VD2-04` is explicitly product-owner accepted. The dashboard correctly shows
`VD2-05` as `next_up`, with only planning and pre-implementation gates
authorized; `VD2-06`, `VD2-07`, and `VD2-08` remain Backlog. The brief and
plan otherwise contain the required workflow boundary: one local store writer,
transaction-derived projection, atomic audit/history evidence, accessible
alternative to drag/drop, test-only failure injection, encrypted fixture
isolation, and final independent/owner gates.

The planned exclusions are appropriate and must remain binding: no VD2-04
presentation redesign, schema migration, cloud/network work, new data,
bulk/undo, routes, CSV, Contacts, Settings, or VD2-06–08 work. The final
owner handoff must not be requested until the persistence, non-happy-path,
relaunch, audit, privacy, and visual evidence is independently accepted.

## Blocking sequencing ambiguity

The task brief calls the transactional result/failure-injection Core slice
**Task 1**, followed by the Board affordance slice as **Task 2**. The
implementation plan instead calls planning contracts **Task 1**, the
transactional Core slice **Task 2**, and the Board interaction slice
**Task 3**. It then says Delivery “releases Task 2 only.”

Those labels describe different work under the same names. A Delivery Manager
could therefore mistakenly release Board interaction before an accepted typed,
transactional persistence boundary, or allow an implementer to treat Core work
as planning-only. That violates the dependency rule that no card moves until
the local source of truth has committed stage, activity, history, and the
post-transition projection together.

## Required correction before re-review

Reconcile the brief and plan to one shared, explicit sequence and use it in
every future Delivery release:

1. **Pre-implementation contracts:** Architecture/QA/TPM/Delivery only; no
   product edit.
2. **Transactional Core + view-model result slice:** the sole implementation
   release immediately after those gates; no Board UI.
3. **Board interaction slice:** released only after fresh acceptance of the
   transactional slice.
4. **Independent proof and owner handoff:** released only after fresh
   acceptance of the Board slice; no new behavior.

The correction must replace ambiguous phrases such as “Task 2 only” with the
named slice above and explicitly state that the first implementation release
is the transactional Core + view-model result slice. It must preserve the
existing planning-release hold; no dashboard transition or implementation is
authorized by this rejected gate.

## TPM risk register

| Risk | Required control | Gate |
| --- | --- | --- |
| Committed stage is shown as failed after refresh | Return/apply a projection read inside the same store transaction; no best-effort refresh after write. | Architecture, Core tests, QA |
| Board runs ahead of persistence | Reconciled release sequence above; Core/VM gate before Board release. | Delivery, TPM |
| Drag is the only usable move path | Every card exposes identified keyboard/VoiceOver `Move to stage`; test exact labels and outcomes. | QA |
| Failure leaks data or fabricates success | ID-only payload, redacted status, no optimistic relocation, fixture-only failure injection. | Security/privacy, QA |
| Scope expands into later cards | Keep VD2-06–08 Backlog and exclude Contacts/Settings/final program acceptance from VD2-05 releases. | Delivery, TPM |

## Re-review condition

After the planning documents are synchronized, a fresh TPM gate may accept
the contract package. That acceptance is still not an implementation release:
Delivery must independently issue the bounded Core + view-model implementation
release only after all required pre-implementation gates accept.

---

# VD2-05 — independent TPM re-review of amended planning package

**Date:** 2026-07-30  
**Role:** Fresh independent TPM (re-review)  
**Decision:** **ACCEPT — planning package is dependency-safe; implementation
remains withheld pending the separate Delivery release.**

## Evidence re-reviewed

- `docs/delivery/task-briefs/VD2-05-persisted-pipeline-stage-movement.md`
- `docs/superpowers/plans/2026-07-30-vd205-persisted-pipeline-stage-movement.md`
- `docs/delivery/architecture/ADR-VD2-05-stage-move-transaction.md`
- `docs/delivery/evidence/visual-design-v2/VD2-05-qa-strategy.md`
- `docs/delivery/evidence/visual-design-v2/VD2-05-architecture-gate.md`
- `docs/delivery/evidence/visual-design-v2/VD2-05-planning-release-2026-07-30.md`
- `docs/delivery/dashboard-status.json` and `docs/delivery/roadmap.md`

## Sequencing decision

The amended brief and plan now use one unambiguous dependency chain:

1. **Contracts** — Planning, Architecture, QA, TPM, and Delivery gates only;
   no source, test, or dashboard implementation release.
2. **Transactional Core + view-model result** — the first and only initial
   implementation release. It creates the typed, atomic persistence boundary
   and contains no Board interaction.
3. **Board interaction** — may be released only after a fresh independent
   acceptance of the Core + view-model slice. It consumes the accepted
   `StageMoveResult` command and has no alternate writer or optimistic move.
4. **Independent proof and owner handoff** — may be released only after fresh
   acceptance of Board interaction. It adds no workflow behavior and cannot
   mark VD2-05 accepted without explicit product-owner acceptance.

This resolves the earlier conflicting task-label risk. Future Delivery records
must use these names verbatim; a bare task number alone is not a valid release
description.

## Dependency, risk, and scope assessment

`VD2-04` is accepted and is the satisfied predecessor. The current dashboard
correctly keeps `VD2-05` as the next eligible planning item and retains
`VD2-06`, `VD2-07`, and `VD2-08` as Backlog. Neither the brief nor the plan
opens later work, Contacts, Settings, routes, CSV, cloud/network, migration,
bulk move, undo, fabricated data, or a VD2-04 presentation redesign.

| Delivery risk | Required control | Release gate |
| --- | --- | --- |
| A stage mutation commits but UI reports failure after a broad refresh | Core returns an in-transaction committed projection; VM applies it once and does no post-commit throwing refresh. | Architecture, Core/VM tests, QA |
| Board UI advances ahead of persistence truth | Board interaction cannot start until fresh acceptance of the Transactional Core + view-model result slice. | Delivery, TPM |
| Failure or stale input relocates a card | Only `.persisted` applies the projection; all other outcomes retain arrays, selection, and source lane. | Core/VM/Board tests, QA |
| Native drag excludes keyboard or VoiceOver users | ID-only drag is additive to an identified Move to stage control, exact targets, AX/current-state checks, and manual VoiceOver proof. | Board QA |
| Fixture/secrets/error state escapes the test host | Sealed `REKON_UI_TEST_HOST` scenarios, UUID encrypted sessions, no arbitrary launch data, redacted outcome text, signed builds. | Security/privacy, QA |
| Close behavior silently changes the local filter | Dedicated closed-filter-locality contracts and Include closed preconditions for Close proof. | Board QA |
| VD2-06–08 accidentally start | Delivery leaves all three Backlog through every VD2-05 transition; only VD2-05 may move to in progress after the next release. | Delivery, TPM |

## Conditions on the next release

This acceptance approves only the amended **planning contract package**. It is
not an implementation authorization. Before a fresh implementer may touch
source, Delivery must record that Planning, Architecture, QA, TPM, and Delivery
have accepted and must release **Transactional Core + view-model result only**.
That release must enumerate its allowed files and retain the Board hold.

After that slice, fresh Code Review, QA, Architecture, TPM, and Delivery
acceptance is required before the **Board interaction** release. Delivery must
update the dashboard/roadmap only at those real transitions, retain VD2-06–08
as Backlog, and request owner acceptance only after the independent proof and
security/privacy gates are accepted.
