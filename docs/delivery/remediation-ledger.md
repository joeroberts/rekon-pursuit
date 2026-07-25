# Rekon Pursuit — MVP remediation ledger

**Status:** `RP-R0`, `RP-R1a`, and `RP-R1b` are accepted. `RP-R2` is the sole released remediation task. `RP-R3`–`RP-R10` remain blocked by their stated dependencies and gates.

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
| `RP-R1a` | Typed workspace gate: visible create/open/recover/retry states for database artifacts × no key, primary only, pending only, and both keys. Ambiguous combinations are recovery-required: no overwrite, promotion, ignored key, or automatic key deletion. A non-secret durable creation journal records staging/pending-written/database-promoted/primary-promoted/cleanup-pending phases. Creation never deletes a committed database on an open error. | `RP-R0` | **Accepted** | State/failure tests, a macOS build, an isolated temporary-app smoke, and direct user observation of create workspace → native CSV dialog → fixture preview. The smoke record is manual UI evidence, not an automation claim. | All independent roles approved. The residual native-dialog observation risk is explicitly manual/user-observed. Release `RP-R1b` only. |
| `RP-R1b` | Reactive `NavigationSplitView` shell aligned with approved mockup structure and usable in a small window. | `RP-R1a` | **Accepted** | Debug build, focused navigation tests, isolated sandbox smoke, direct user 900×640 smoke, and all required independent approvals are recorded. | Delivery accepted R1b. Release `RP-R2` only. |
| `RP-R2` | Migration plus editable compensation, location, response state/history, and application/status dates. | `RP-R1b` | **Corrective pass required** | Existing-workspace migration and create/edit/relaunch activity evidence, plus the corrective clock/date, real-v15-fixture, atomic-rollback, and deterministic-history evidence. | `2851b84` is rejected pending the documented R2 corrective pass. `RP-R3`–`RP-R10` remain blocked. |
| `RP-R3` | Map → validate → row decision → import report; field-selected update-existing with no silent overwrite. | `RP-R2` | Blocked | Standard-header, nonstandard-header, invalid-row, duplicate, and reimport workflows. | Pending `RP-R2`; allowed-field policy in brief. |
| `RP-R4` | Reconciliation contract and local workflow states only: safe URL validation, classifications, evidence/error, confidence, retry de-duplication, closure confirmation; no request yet. | `RP-R1b` | Blocked | Deterministic fixtures and approved network/privacy contract. | Architect + Security/Privacy approval required. |
| `RP-R5` | User-initiated public-URL check: direct GET only, bounded/no-auth/no-script request, offline/manual-review handling, retry task, no auto-close. | `RP-R2`, `RP-R4` | Blocked | Online/offline/blocked/changed/failure/explicit-closure workflow evidence. | Architect + Security/Privacy approval of `RP-R4`. |
| `RP-R6` | Security-scoped document bookmark, open/verify/relink, hash revalidation, and relink-required after portable restore. No copy/edit/parse. | Serial after `RP-R2` | Blocked | PDF/DOCX attach, relaunch/open, moved-file relink, permission failure smoke. | `RP-R2` is the sole active task; release only in serial order after its acceptance. |
| `RP-R7a` | Recovery-key enrollment/verification, authenticated portable archive/export default, manifest, and restore-as-new-workspace. | Serial after `RP-R2` | Blocked | Recovery-key, portable restore, encrypted/default-export evidence. | `RP-R2` is the sole active task; later release also requires Architect + Security/Privacy approval. |
| `RP-R7b` | 30-day expiry display, deleted-data disclosure, and verified retained-backup purge/rebuild. | `RP-R7a` | Blocked | Expiry and purge success/failure evidence. | Architect + Security/Privacy approval required. |
| `RP-R8` | Empty read-only local AI ledger with time, feature, opportunity, route, model, completion, and cost filters. No AI/network/metrics execution. | Serial after `RP-R2` | Blocked | Every filter works at zero entries; no entry/network is produced. | `RP-R2` is the sole active task; release only in serial order after its acceptance. |
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
| TPM | Approved | The amended R1a scope is dependency-safe and remains limited to the non-destructive workspace gate and post-create CSV reachability. |
| Delivery Manager | Approved — released for implementation | R1a is the only active task; visual-shell alignment and every successor remain out of scope. |

### RP-R1a implementation verification record

| Role | Decision | Evidence |
| --- | --- | --- |
| Code Reviewer | Approved | Native single-file `NSOpenPanel`, read-only entitlement binding, one CSV security-scope owner, and manual-vs-automated smoke wording were reviewed at current implementation head. |
| QA | Approved | Focused workspace/view-model tests passed (22 tests, 0 failures); Debug macOS build and isolated smoke passed. The product owner directly confirmed the current temporary app’s workspace-create → Import CSV → Choose CSV file → synthetic-fixture preview sequence. |
| Architect | Approved | Workspace recovery and mutation boundaries remain non-destructive; the CSV picker is UI-only, sandbox-appropriate, and nonpersistent. No ADR deviation is required. |
| Security/Privacy | Approved after remediation | CSV access is single-file/read-only with balanced scoped-resource cleanup and no upload/bookmark. The temporary smoke is isolated from production data. A real local path was redacted from the handoff and reachable history; the rewritten history and current tree were rechecked. |
| TPM | Approved for final gate | R1a stayed within workspace initialization/recovery and CSV-picker reachability. R1b+ scope did not enter the slice; the native dialog check remains documented as direct manual evidence. |
| Delivery Manager | Approved — R1a accepted | Rechecked the final ledger, clean worktree, scoped implementation, isolated smoke, and user-observed native dialog. Released `RP-R1b` only. |

### RP-R1b plan approval record

| Role | Decision | Evidence |
| --- | --- | --- |
| Planning | Approved | [R1b shell brief](task-briefs/RP-R1b-reactive-application-shell.md) at `d9190a0`: reactive desktop shell only; existing isolated harness owns mutable smoke; R1a recovery tests remain authoritative. |
| Architect | Approved | Parent-owned file/modal intents, unchanged native CSV and workspace boundaries, no test-injection seam, and an enforceable compact-window limit. No ADR change required. |
| QA | Approved | Non-mutating UI checks plus the existing isolated temporary-app manual smoke cover 900×640 navigation/reactivity and the actual CSV preview without coverage or hosted-CI expansion. |
| TPM | Approved | R1b is the sole dependency-safe successor; no R2+ scope or successor release is implied. |
| Delivery Manager | Approved — released for implementation | Durable record rechecked; R1b was released as the sole successor. |

### RP-R1b implementation verification record

| Role | Decision | Evidence |
| --- | --- | --- |
| Code Reviewer | Approved | Navigation and workspace-gate tests assert real stable accessibility elements; focused UI suite passed. No persistence, file-access, or R2+ scope change was found. |
| QA | Approved | Focused UI/model checks, Debug build, and isolated harness passed. The 900×640 temporary-app sequence is recorded as direct user evidence, not automation. |
| Architect | Approved | The new shell preserves R1a workspace/recovery, native CSV ownership, local-only boundaries, and existing persistence; no ADR change is required. |
| TPM | Approved for acceptance | R1b stayed shell-only. Release exactly `RP-R2` next; later direct successors remain blocked to avoid shared persistence/UI work. |
| Product owner | Completed manual smoke | At 900×640 in the isolated temporary app: workspace create; synthetic record create/edit; Pipeline and Activity & AI navigation; native CSV chooser and fixture preview all passed. |
| Delivery Manager | Approved — R1b accepted | Final independent gate complete. Released `RP-R2` only; `RP-R3`–`RP-R10` remain blocked to avoid overlapping persistence/UI work. |

### RP-R2 plan approval record

| Role | Decision | Evidence |
| --- | --- | --- |
| Planning | Approved | [R2 opportunity-fields brief](task-briefs/RP-R2-opportunity-fields-and-migration.md) at `9502268`: migration, core fields, explicit response/stage-date semantics, and R3 mapping exclusion. |
| Architect | Approved | Coherent schema/default/migration contract; fixed work-arrangement values; stage and response audit semantics; existing CSV safe defaults without mapping scope. No ADR change required. |
| QA | Approved | Deterministic focused migration/create/edit/relaunch/history checks include history ordering and optional-date clearing; no coverage/CI expansion. |
| TPM | Approved | R2 is the sole released scope; all successors remain blocked. |
| Delivery Manager | Approved — released for implementation | Plan record is dependency-safe. R2 is the only implementation task; `RP-R3`–`RP-R10` remain blocked. |

### RP-R2 corrective-pass decision record

| Role | Decision | Evidence / boundary |
| --- | --- | --- |
| Planning | Correction brief issued | Independent Architect and QA review of `2851b84` found stale initialization-time audit timestamps, new-form date carryover, an invalid version-16 failure setup, and missing R2 edge-case coverage. The R2 brief now requires a per-command injected clock, explicit date validation, fresh new-form defaults, a real v15 fixture, atomic update rollback, and deterministic history ordering. |
| QA failure classification | Stage-history ordering: R2-caused; import-report equality: not R2-caused | A selected effective stage date makes `ORDER BY occurred_at, rowid` nondeterministic/semantically wrong for R2; the correction fixes it with `occurred_at ASC, id ASC` and tie tests. The import-report equality precision failure predates R2’s report contract and is explicitly deferred without an R2 code change. |
| Release state | **No corrective implementation released by this record** | TPM/Delivery must independently release this bounded corrective pass before a fresh implementer changes code. `RP-R3`–`RP-R10` remain blocked. |

## Release log

| Date | Task | Delivery decision | Scope boundary |
| --- | --- | --- | --- |
| 2026-07-25 | `RP-R0` | **Approved — released** | It may create only redacted baseline evidence under `docs/delivery/evidence/remediation/RP-R0/` using a dedicated disposable test workspace and app-data location. It must not change production behavior, the user’s workspace, or Keychain data. `RP-R1a`–`RP-R10` remain blocked pending their stated dependencies and gates. |
| 2026-07-25 | `RP-R0` | **Accepted — amended gate** | Evidence boundary approved; runtime create/CSV-preview/refresh transferred to `RP-R1a`. |
| 2026-07-25 | `RP-R1a` | **Provisional release superseded** | The original release was withdrawn while the non-destructive workspace-state amendment was reviewed. The amended brief is ready for final TPM and Delivery release; no implementation began. |
| 2026-07-25 | `RP-R1a` | **Released for implementation** | Implement the approved non-destructive workspace-session gate and focused local verification in an isolated temporary namespace. Do not inspect, modify, delete, reset, or recover the user’s workspace or production Keychain material. `RP-R1b`–`RP-R10` remain blocked. |
| 2026-07-25 | `RP-R1a` | **Ready for final Delivery acceptance** | All independent implementation reviewers approve. The only remaining decision is Delivery Manager acceptance and, if accepted, release of `RP-R1b` only. |
| 2026-07-25 | `RP-R1a` | **Accepted — `RP-R1b` released** | Delivery Manager rechecked final evidence and approvals. The native picker’s dialog/preview remains direct user-observed evidence. `RP-R2`–`RP-R10` remain blocked. |
| 2026-07-25 | `RP-R1b` | **Accepted — `RP-R2` released** | Delivery Manager accepted the completed shell slice after independent Code Review, QA, Architect, TPM, and direct user 900×640 evidence. `RP-R3`–`RP-R10` remain blocked. |
| 2026-07-25 | `RP-R2` | **Released for implementation** | Delivery Manager approved the migration-and-core-fields brief. No successor is released; `RP-R3`–`RP-R10` remain blocked. |
| 2026-07-25 | `RP-R2` | **Implementation rejected — corrective pass planned** | Independent Architect and QA findings are reconciled in the R2 brief. This is not acceptance and does not release corrective code or any successor. |

## Risks and decisions

| ID | Decision / risk | Owner | State |
| --- | --- | --- | --- |
| `RP-D1` | Reconciliation may perform a user-initiated direct public-URL request. It never auto-closes an opportunity. | Product owner | Accepted 2026-07-25 |
| `RP-RISK-1` | Direct URL requests can reach private/internal endpoints without explicit validation. `RP-R4` must reject non-http(s), credential-bearing, localhost, private, and link-local destinations. | Architect + Security/Privacy | Open |
| `RP-RISK-2` | Portable recovery/export/purge can cause data loss or false recovery claims. `RP-R7a/b` requires separate high-risk approval and restore-as-new-workspace. | Architect + Security/Privacy | Open |
| `RP-RISK-3` | The current candidate’s status claims obscured required work. This ledger is controlling until `RP-R10` is accepted. | Delivery Manager | Mitigated |
| `RP-RISK-4` | A store-wide initialization timestamp can make later audit events untruthful, while optional form dates can silently reuse a prior draft. | Architect + QA | Open — RP-R2 corrective pass |
| `RP-RISK-5` | The existing import-report equality test compares a precision-sensitive timestamp but is unrelated to R2’s report contract. | QA | Deferred — separate test-hygiene release required; no R2 scope expansion |
