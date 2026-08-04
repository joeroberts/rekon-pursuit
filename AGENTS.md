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
2. Architect, TPM, QA, and Delivery Manager independently review the plan before the first task starts. For persistence, transaction, rollback, recovery, security, AI-provider, connected-provider, document, or research work, a Security/privacy verifier must also approve the plan before implementation.
3. The TPM/Delivery Manager releases only the next eligible dependency-safe task.
4. A fresh Implementer completes the task and targeted tests.
5. A separate Code Reviewer and QA verifier review it.
6. The Architect reviews architectural effects and approves any deviation through an ADR.
7. A fresh Security/privacy verifier independently reviews every high-risk implementation and its failure/recovery evidence before the task or milestone can be completed or any successor released; the delivery ledger records that evidence.
8. The TPM confirms technical readiness and dependency safety. The Delivery Manager records completion and may open only the next dependency-safe task. When a controlling roadmap, task brief, milestone, or owner handoff explicitly requires product-owner acceptance, every dependent successor remains blocked until that acceptance is recorded in the durable progress ledger.
9. At every milestone, run broad independent architecture/security/QA review before proceeding.

## Guardrails

- Hard prohibition: do not invoke, search for, inspect, install, mention as a dependency, or wait on `codex-governance` (the skill, CLI, configuration, or any `governance.yml` file). Maintain delivery records and perform repository checks only with this repository's ordinary files and tools.
- Never reuse an Implementer as the reviewer or verifier of its own work.
- Treat independent agents as ephemeral: after their requested output is received and recorded, terminate the agent immediately. Do not leave completed agents allocated while other work continues.
- For any owner-facing macOS app handoff, build with the configured Debug signing identity; never launch a `CODE_SIGNING_ALLOWED=NO` build when the workflow uses the Data Protection Keychain. The delivery ledger records the signing identity and verification evidence; when a task has no owner-facing handoff, it records that fact instead.
- Do not run parallel agents against the same subsystem or shared files without an explicit integration plan.
- After two unsuccessful remediation attempts or ten active minutes on a non-product blocker, stop the affected work and tell the product owner what failed, whether product behavior is affected, what is proven, the remaining risk, and the recommendation to continue, defer, or accept with a documented limitation. Record that evidence in the delivery ledger and do not resume the affected work without explicit direction; unrelated safe work may continue. Send one normal-priority notification only when a configured, authorized notification channel is available; otherwise record the sanitized in-task notice without retrying a failed notification.
- No feature UI is complete without persistence, activity/audit evidence, non-happy-path behavior, and acceptance tests.
- A documentation- or process-only change may use a scoped diff, formatting, and link audit instead of runtime tests when the delivery ledger records the omitted runtime verification and its rationale.
- Keep a durable progress ledger with completed tasks, reviews, test evidence, open risks, decisions, and gate status.
- Treat the approved PRD, UX review/mockups, TPM roadmap, architecture specification, and Codex handoff as controlling artifacts.

The detailed delivery package is in the product directory.

## Reasoning guidance

- Use the available model and reasoning effort proportionally: high effort for coordination and novel architecture, higher effort only for bounded persistence, transaction, rollback, recovery, security, or difficult root-cause work, and standard effort for delivery, TPM, roadmap, and documentation maintenance.
- Keep subagent briefs narrow, bounded, and task-specific. Do not increase model capability or reasoning effort merely because a task has a long history.
- If a required capability or reasoning tier is unavailable, select the nearest safe alternative and record the fallback in the task handoff before work begins. Do not silently downgrade recovery, transaction, or security work.
