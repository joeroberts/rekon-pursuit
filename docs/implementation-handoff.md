# Rekon Pursuit — Codex Implementation Handoff

## Authority and readiness

This package is ready to guide implementation planning. The approved product requirements remain authoritative; the roadmap governs delivery sequencing; the architecture specification governs technical boundaries and safety contracts; the UX review and flow mockups govern the required interaction behavior.

Repository-level multi-agent delivery governance is binding: [AGENTS.md](../AGENTS.md). It requires independent Planning, Architect, TPM, QA, Delivery Manager, Implementer, Reviewer, and high-risk Security/Privacy verification roles with task and milestone gates.

| Artifact | Role |
| --- | --- |
| [Product requirements](product/prd.md) | User outcomes, scope, invariants, and acceptance criteria |
| [UX design review](product/ux-design-review.md) | Interaction rules, accessibility, safe-state behavior |
| [UX mockups](../design/mockups/ux/) | Reference flows for the eight core workflows |
| [TPM roadmap](delivery/roadmap.md) | Milestones, vertical slices, gates, and test checkpoints |
| [Architecture specification](architecture/specification.md) | Native macOS design, local data model, privacy, integrations, and verification |

## Reconciled delivery approach

Implement vertical slices, not disconnected layers or screens. Each slice must persist real local state, use the shared command/activity-event path, expose recovery states, and pass its acceptance checks before the next gate.

### Canonical MVP milestone order

The roadmap's milestone IDs are authoritative. The current release sequence is:

| Milestone | Workstream(s) | Release boundary |
| --- | --- | --- |
| M1 | A + first B slice | Encrypted local record spine and safety controls |
| M2 | B | Complete offline opportunity workspace, pipeline, task/reminder model, and daily queue |
| M3 | C | Contacts, interactions, and relationship links |
| M4 | D | Local CSV import, duplicate decisions, import report, and batch traceability |
| M5 | E + F | Conservative posting reconciliation plus MVP hardening, lifecycle/export work, and release readiness |

M2 is accepted. M3 is the only active MVP feature milestone; M4 code/artifacts remain frozen and unreleased until M3 is accepted. Do not expose, extend, or claim M4 functionality as released while that dependency is open.

1. **Foundation (M1):** native SwiftUI shell, encrypted SQLite, migrations, Keychain abstraction, core entities, and append-only activity events.
2. **Daily tracker (M2, accepted):** the offline opportunity workspace, six fixed standard stages, tasks, pipeline/search, and deterministic Needs attention loop.
3. **Relationship memory (M3, released for completion and gate):** contact links and interaction history. It may not be claimed as accepted until its independent gate passes.
4. **Safe bulk capture (M4, frozen/unreleased):** local CSV map/validate/duplicate decisions, import report, and batch traceability. It may not be exposed or extended until M2 and M3 are accepted and M4 is explicitly released.
5. **Reconciliation and hardening (M5):** conservative posting reconciliation with explicit closure confirmation; manual local DOCX/PDF attachment links with source hashes; the empty/read-only local AI ledger; lifecycle/export work; and release readiness. Fully offline reconciliation makes no check, preserves the prior result, and creates retry/manual-review work. Signing, notarization, and DMG distribution remain M5 release work.
6. **Privacy and AI foundation (M6):** local/sanitized/full-cloud routing, sanitization/disclosure, consent/no-fallback tests, populated AI ledger/cost budgets, local runtime adapter, then cloud adapter only after consent tests pass. No AI feature ships earlier.
7. **Connected workflow (M7):** Gmail thread selection/matching, confidence-scored response classification with manual review for low-confidence cases, user-accepted follow-up task generation, draft/review/final-send confirmation, then Calendar availability and confirmed mutations.
8. **Document library and research (M8):** full document ingest/processing, immutable version links, final-file tracking, export/deletion controls, and permitted sourced research; these follow the privacy/AI and connected foundations.
9. **Decision support (M9):** interview prep/media, coaching, offer comparison, and negotiation.

## Non-negotiable implementation invariants

- Local record and activity event commit atomically for every material action.
- No import merge/overwrite happens without a row-level decision.
- No reconciliation result changes an opportunity stage; only explicit closure confirmation can do so.
- A fully offline reconciliation attempt makes no external request, retains the prior result, and creates retry/manual-review work; it never infers closure.
- No Gmail send, Calendar mutation, or other external write happens without an exact-payload review and final confirmation.
- Local, sanitized-cloud, and full-cloud AI are distinct routes. Selected-route failure never causes a cloud fallback.
- Gmail classification exposes confidence and thread evidence; low-confidence or ambiguous results require manual review, and no generated follow-up task exists until user acceptance.
- Source evidence remains distinct from conclusions; AI output stays editable and cannot silently overwrite source data.
- Status is not color-only, and core workflows include empty, loading, offline, permission-denied, failed, and recovery states.

## Decision gates that remain intentionally open

The local-data lifecycle gate is **resolved** by [ADR-001](architecture/adr/ADR-001-local-data-lifecycle.md) and the [M0-2 lifecycle contract](architecture/local-data-lifecycle-contract.md): its retention, deletion, backup/recovery, purge, and export rules are implementation requirements. All other decisions below are not implementation blockers for the local tracker foundation, but must be resolved before enabling their dependent capability.

| Gate | Resolve before | Decision |
| --- | --- | --- |
| Local data lifecycle | Resolved for M1 foundation and M5 lifecycle | ADR-001 plus M0-2 lifecycle contract: M1 migration snapshot/safe-open/logical deletion; M5 recovery-key strategy, authenticated backup envelope, restore/re-wrap, retention, purge, and export |
| Tracker semantics | M2 daily tracker | Initial stages, queue ordering, archive/delete rules |
| Import policy | M4 CSV completion | Duplicate signals, allowed update fields, undo scope |
| Reconciliation policy | M5 posting checks | Approved methods/providers, thresholds, retry cadence |
| AI routing and ledger policy | Privacy/AI foundation | Model catalog, pricing source, local-runtime policy, sanitization fields, full-cloud disclosure, ledger redaction/search, budgets |
| Integration consent | Gmail/Calendar after privacy/AI foundation | Gmail selection scope, classification confidence/manual-review thresholds, task-acceptance behavior, OAuth scopes, Calendar conflict rules |
| AI data/source policy | Documents/research after connected workflow | Approved provider/license list and user-provided evidence labeling |
| Decision rubrics | Interview/offer features | Versioned user weights and not-enough-evidence thresholds |

## Codex planning instruction

Before implementation, create a detailed, test-first plan from this package. Start at the Foundation and Local MVP tracker slices. Preserve the canonical order: manual attachment/hash support and empty/read-only local ledger in MVP; privacy/AI routing and populated-ledger foundation; Gmail/Calendar; then full document processing/versioning and research. Do not add an integration or AI feature merely because its UI is represented in a mockup; the corresponding architecture contract, decision gate, consent behavior, and acceptance tests must be completed first.
