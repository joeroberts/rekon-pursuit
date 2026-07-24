# Rekon Pursuit — Delivery Governance

This project uses independent subagents as its default delivery model. The primary agent coordinates integration; it does not replace the independent planning, architecture, TPM, QA, or delivery-management roles.

## Required independent roles

| Role | Responsibility |
| --- | --- |
| Planning agent | Converts approved product/architecture artifacts into granular, test-first task briefs with explicit dependencies. |
| Architect agent | Owns architecture decisions, data/security contracts, interfaces, and ADRs. It does not approve its own implementation. |
| TPM agent | Owns roadmap sequencing, dependency gates, risks, milestone readiness, and scope control. |
| QA/test agent | Defines fixture/test strategy before implementation and independently verifies every slice and milestone against acceptance criteria. |
| Delivery manager agent | Maintains the progress ledger, opens only dependency-safe work, records decisions, and escalates blockers. |
| Implementer agent | Delivers one bounded vertical slice. |
| Code reviewer agent | Independently reviews one implementation task for specification compliance and code quality. |
| Security/privacy verifier | Independently verifies high-risk capabilities: local storage/recovery, AI routing, Gmail/Calendar, documents, and research providers. |

## Execution gates

1. A Planning agent produces task briefs before implementation.
2. Architect, TPM, QA, and Delivery Manager independently review the plan before the first task starts.
3. The TPM/Delivery Manager releases only the next eligible dependency-safe task.
4. A fresh Implementer completes the task and targeted tests.
5. A separate Code Reviewer and QA verifier review it.
6. The Architect reviews architectural effects and approves any deviation through an ADR.
7. The TPM/Delivery Manager records completion and opens the next task.
8. At every milestone, run broad independent architecture/security/QA review before proceeding.

## Guardrails

- Never reuse an Implementer as the reviewer or verifier of its own work.
- Do not run parallel agents against the same subsystem or shared files without an explicit integration plan.
- No feature UI is complete without persistence, activity/audit evidence, non-happy-path behavior, and acceptance tests.
- Keep a durable progress ledger with completed tasks, reviews, test evidence, open risks, decisions, and gate status.
- Treat the approved PRD, UX review/mockups, TPM roadmap, architecture specification, and Codex handoff as controlling artifacts.

The detailed delivery package is in the product directory.
