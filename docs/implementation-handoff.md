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

1. **Foundation:** native SwiftUI shell, encrypted SQLite, migrations/backups, Keychain abstraction, core entities, append-only activity events, and a deterministic Needs attention query.
2. **Local MVP tracker:** opportunity workspace, stages, tasks, pipeline/search, contact links, CSV map/validate/duplicate decisions, reversible import batches, conservative reconciliation with explicit closure confirmation, manual local DOCX/PDF attachment links with source hashes, and an empty/read-only locally searchable AI ledger. Fully offline reconciliation makes no check, preserves the prior result, and creates retry/manual-review work.
3. **Privacy and AI foundation:** local/sanitized/full-cloud routing, sanitization/disclosure, consent/no-fallback tests, populated AI ledger/cost budgets, local runtime adapter, then cloud adapter only after consent tests pass. No AI feature ships earlier.
4. **Connected workflow:** Gmail thread selection/matching, confidence-scored response classification with manual review for low-confidence cases, user-accepted follow-up task generation, draft/review/final-send confirmation, then Calendar availability and confirmed mutations.
5. **Document library and research:** full document ingest/processing, immutable version links, final-file tracking, export/deletion controls, and permitted sourced research; these follow the privacy/AI and connected foundations.
6. **Decision support:** interview prep/media, coaching, offer comparison, and negotiation.

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
| Tracker semantics | Daily tracker | Initial stages, queue ordering, archive/delete rules |
| Import policy | CSV completion | Duplicate signals, allowed update fields, undo scope |
| Reconciliation policy | Posting checks | Approved methods/providers, thresholds, retry cadence |
| AI routing and ledger policy | Privacy/AI foundation | Model catalog, pricing source, local-runtime policy, sanitization fields, full-cloud disclosure, ledger redaction/search, budgets |
| Integration consent | Gmail/Calendar after privacy/AI foundation | Gmail selection scope, classification confidence/manual-review thresholds, task-acceptance behavior, OAuth scopes, Calendar conflict rules |
| AI data/source policy | Documents/research after connected workflow | Approved provider/license list and user-provided evidence labeling |
| Decision rubrics | Interview/offer features | Versioned user weights and not-enough-evidence thresholds |

## Codex planning instruction

Before implementation, create a detailed, test-first plan from this package. Start at the Foundation and Local MVP tracker slices. Preserve the canonical order: manual attachment/hash support and empty/read-only local ledger in MVP; privacy/AI routing and populated-ledger foundation; Gmail/Calendar; then full document processing/versioning and research. Do not add an integration or AI feature merely because its UI is represented in a mockup; the corresponding architecture contract, decision gate, consent behavior, and acceptance tests must be completed first.
