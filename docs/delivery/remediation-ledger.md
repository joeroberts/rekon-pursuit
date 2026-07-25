# Rekon Pursuit — MVP remediation ledger

**Status:** `RP-R0` accepted after amended-gate review. `RP-R1a` is the sole released remediation implementation task; `RP-R1b`–`RP-R10` remain blocked by their stated dependencies and gates.

**Authority:** This is the canonical status record for the current MVP remediation. It supersedes “MVP shipped” language in the roadmap and candidate handoff. The PRD, architecture specification, ADR-001, and approved mockups remain controlling requirements.

## Verified gaps

| Requirement | Current verified state | Remediation task |
| --- | --- | --- |
| First-run workspace | Create action is hidden off the default page; a dangling-key/no-database state is currently reported as unavailable and has no recovery path. | `RP-R0`, `RP-R1a` |
| Usable layout/reactivity | Single segmented `VStack` does not implement the approved desktop shell and can appear inert. | `RP-R0`, `RP-R1b` |
| CSV selection/import | Picker is unreachable before workspace creation; importer requires literal `title` and `company` headers. | `RP-R1a`, `RP-R3` |
| Opportunity fields | Compensation, location, responses, and application/status dates are absent. | `RP-R2` |
| CSV mapping/update | No mapping or field-selected update-existing decision. | `RP-R3` |
| Reconciliation | Manual evidence log only; no direct check, outcome taxonomy, retry, or closure confirmation. | `RP-R4`, `RP-R5` |
| AI ledger | Static copy, not a searchable empty local ledger. | `RP-R8` |
| ADR-001 lifecycle | No portable recovery key/archive, encrypted-default export, expiry, or purge. | `RP-R7a`, `RP-R7b` |
| Document references | Metadata/hash only; no durable open/relink behavior. | `RP-R6` |
| Settings | Does not expose actual lifecycle/recovery/export state. | `RP-R9` |

## Controlled queue

| ID | Scope | Dependencies | State | Required evidence | Gate decision |
| --- | --- | --- | --- | --- | --- |
| `RP-R0` | Evidence-only baseline in a dedicated disposable test workspace/app-data location: first launch, default-page workspace access, pre-workspace CSV availability/explanation, page-state refresh, and mockup divergence. No behavior changes or modification of the user’s workspace/Keychain data. | None | **Accepted** | Redacted reproduction notes/screenshots, exact state transitions, build/OS/window details, and committed evidence path. | Amended boundary accepted. The evidence establishes the first-run/default-page, pre-workspace CSV guidance, page-refresh, and shell defects. Runtime create → CSV-preview/refresh is owned by `RP-R1a`. |
| `RP-R1a` | Typed workspace gate: visible create/open/recover/retry states for database artifacts × no key, primary only, pending only, and both keys. Ambiguous combinations are recovery-required: no overwrite, promotion, ignored key, or automatic key deletion. A non-secret durable creation journal records staging/pending-written/database-promoted/primary-promoted/cleanup-pending phases. Creation never deletes a committed database on an open error. | `RP-R0` | **Ready for Delivery release** | Focused failure injection covers staging close, pending write, database promotion, primary promotion, pending cleanup, and reopen; every ambiguous state preserves artifacts. Fresh-launch runtime smoke records only a temporary namespace ID and redacted before/after unchanged assertions; it never persists absolute paths, Keychain item/account metadata, keys, or fixture content. This task does not accept visual shell alignment. | Planning, Architect, QA, and Security/Privacy approved the amended brief. Await TPM and Delivery release decision; no successor is released. |
| `RP-R1b` | Reactive `NavigationSplitView` shell aligned with approved mockup structure and usable in a small window. | `RP-R1a` | Blocked | Before/after mockup comparison at the recorded window size plus manual create/edit/navigation refresh smoke. | Pending `RP-R1a`. |
| `RP-R2` | Migration plus editable compensation, location, response state/history, and application/status dates. | `RP-R1b` | Blocked | Existing-workspace migration and create/edit/relaunch activity evidence. | Pending `RP-R1b`. |
| `RP-R3` | Map → validate → row decision → import report; field-selected update-existing with no silent overwrite. | `RP-R2` | Blocked | Standard-header, nonstandard-header, invalid-row, duplicate, and reimport workflows. | Pending `RP-R2`; allowed-field policy in brief. |
| `RP-R4` | Reconciliation contract and local workflow states only: safe URL validation, classifications, evidence/error, confidence, retry de-duplication, closure confirmation; no request yet. | `RP-R1b` | Blocked | Deterministic fixtures and approved network/privacy contract. | Architect + Security/Privacy approval required. |
| `RP-R5` | User-initiated public-URL check: direct GET only, bounded/no-auth/no-script request, offline/manual-review handling, retry task, no auto-close. | `RP-R2`, `RP-R4` | Blocked | Online/offline/blocked/changed/failure/explicit-closure workflow evidence. | Architect + Security/Privacy approval of `RP-R4`. |
| `RP-R6` | Security-scoped document bookmark, open/verify/relink, hash revalidation, and relink-required after portable restore. No copy/edit/parse. | `RP-R1b` | Blocked | PDF/DOCX attach, relaunch/open, moved-file relink, permission failure smoke. | Pending `RP-R1b`. |
| `RP-R7a` | Recovery-key enrollment/verification, authenticated portable archive/export default, manifest, and restore-as-new-workspace. | `RP-R1b` | Blocked | Recovery-key, portable restore, encrypted/default-export evidence. | Architect + Security/Privacy approval required. |
| `RP-R7b` | 30-day expiry display, deleted-data disclosure, and verified retained-backup purge/rebuild. | `RP-R7a` | Blocked | Expiry and purge success/failure evidence. | Architect + Security/Privacy approval required. |
| `RP-R8` | Empty read-only local AI ledger with time, feature, opportunity, route, model, completion, and cost filters. No AI/network/metrics execution. | `RP-R1b` | Blocked | Every filter works at zero entries; no entry/network is produced. | Pending `RP-R1b`. |
| `RP-R9` | Settings exposes real recovery, expiry, deletion, export, document-reference, and ledger state; no fake integration controls. | `RP-R6`, `RP-R7b`, `RP-R8` | Blocked | Settings state matches stored state across relaunch. | Pending dependencies. |
| `RP-R10` | Clean-state, hands-on acceptance of all remediation tasks and candidate-package status reconciliation. | `RP-R1a`–`RP-R9` | Blocked | Full user workflow evidence and independent milestone reviews. | Pending every preceding task. |

## Review record

| Role | Decision | Findings that changed the plan |
| --- | --- | --- |
| Planning | Approved `RP-R0` brief | Established `RP-R0` through `RP-R10`; lifecycle was later split. |
| Architect | Approved `RP-R0` release | Required isolated baseline evidence; accepted the `R1a`/`R1b`, `R4`/`R5`, and `R7a`/`R7b` boundaries. |
| QA | Approved `RP-R0` release | Confirmed reproducible first-run/CSV/reactivity/layout evidence requirements without a coverage or CI expansion. |
| TPM | Approved `RP-R0` release | Confirmed no Phase 2 scope and no remaining product decision. |
| Delivery Manager | Approved `RP-R0` release | Confirmed this ledger/brief are canonical and only `RP-R0` may proceed. |

### RP-R1a amended-brief review record

| Role | Decision | Evidence |
| --- | --- | --- |
| Planning | Approved | The non-destructive workspace-state and phase boundaries are dependency-safe; recovery copy must not promise recovery without a database. |
| Architect | Approved | The complete database/key matrix, durable non-secret journal, recovery-required handling, and injected-failure boundaries resolve the interrupted-creation ambiguity. |
| QA | Approved | Focused local state fixtures and one isolated runtime smoke cover preservation without a coverage/CI expansion. |
| Security/Privacy | Approved | The compiled immutable Keychain namespace, non-destructive key handling, and redacted evidence rules prohibit paths, Keychain metadata, keys, and fixture content. |
| TPM | Pending final release review | Review must follow this recorded approval set. |
| Delivery Manager | Pending final release decision | Review must follow TPM approval. |

## Release log

| Date | Task | Delivery decision | Scope boundary |
| --- | --- | --- | --- |
| 2026-07-25 | `RP-R0` | **Approved — released** | It may create only redacted baseline evidence under `docs/delivery/evidence/remediation/RP-R0/` using a dedicated disposable test workspace and app-data location. It must not change production behavior, the user’s workspace, or Keychain data. `RP-R1a`–`RP-R10` remain blocked pending their stated dependencies and gates. |
| 2026-07-25 | `RP-R0` | **Accepted — amended gate** | Evidence boundary approved; runtime create/CSV-preview/refresh transferred to `RP-R1a`. |
| 2026-07-25 | `RP-R1a` | **Approved — released** | Only active implementation task; isolated smoke is a release condition. |

## Risks and decisions

| ID | Decision / risk | Owner | State |
| --- | --- | --- | --- |
| `RP-D1` | Reconciliation may perform a user-initiated direct public-URL request. It never auto-closes an opportunity. | Product owner | Accepted 2026-07-25 |
| `RP-RISK-1` | Direct URL requests can reach private/internal endpoints without explicit validation. `RP-R4` must reject non-http(s), credential-bearing, localhost, private, and link-local destinations. | Architect + Security/Privacy | Open |
| `RP-RISK-2` | Portable recovery/export/purge can cause data loss or false recovery claims. `RP-R7a/b` requires separate high-risk approval and restore-as-new-workspace. | Architect + Security/Privacy | Open |
| `RP-RISK-3` | The current candidate’s status claims obscured required work. This ledger is controlling until `RP-R10` is accepted. | Delivery Manager | Mitigated |
