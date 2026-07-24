# Rekon Pursuit — M0/M1 Delivery Task Plan

> **For agentic workers:** Use the project delivery governance in [`AGENTS.md`](../../AGENTS.md). This is a task plan, not an implementation authorization. A fresh Implementer may begin a task only after the stated release gate passes.

**Goal:** Establish a reproducible, encrypted, auditable local record spine for Rekon Pursuit without enabling network, AI, Gmail, Calendar, document-processing, or research capabilities.

**Architecture:** M0 first converts the accepted lifecycle policy, compatibility constraints, and deterministic-fixture strategy into recorded, independently approved engineering evidence. M1 then delivers one vertical slice: a sandboxed SwiftUI app can create/open an encrypted workspace, migrate it, persist a minimal opportunity and its activity event atomically, relaunch successfully, and surface safe recovery states.

**Technology constraints:** Native SwiftUI macOS application; deployment target macOS 14.0; universal `arm64` and `x86_64` build; encrypted SQLite selected through the M0 gate; App Sandbox and Hardened Runtime; Keychain-backed key wrapping; local-only default-deny network; deterministic synthetic fixtures only.

## Global constraints

- The controlling artifacts are the [PRD](../product/prd.md), [architecture specification](../architecture/specification.md), [local-data lifecycle ADR](../architecture/adr/ADR-001-local-data-lifecycle.md), [compatibility matrix](../architecture/macos-compatibility-matrix.md), [fixture strategy](m0-test-fixture-strategy.md), and [roadmap](roadmap.md).
- M1 is local-only. It must have no Gmail, Calendar, AI, research, document-processing, telemetry, network-client entitlement, provider credentials, or live-service test dependency.
- All mutations must commit the domain change and an append-only activity event in the same SQLite transaction. A failed mutation must commit neither.
- Active data is retained until explicit deletion. Logical deletion immediately removes data from normal views and search; recovery backups are opt-in and retain deleted content for 30 days; unencrypted export requires warning and final filename/location confirmation.
- Tests use only synthetic fixtures, fixed UTC clocks, deterministic ID/randomness providers, unique temporary roots, fake Keychain, default-deny HTTP, and fake XPC. Tests must never touch a developer Keychain, user data, or the network.
- Never commit signing certificates, provisioning profiles, recovery secrets, database keys, OAuth tokens, production diagnostics, real job-search data, or personal contacts.
- A task is not complete because it compiles. It requires the exact evidence below, independent review, and an entry in `docs/delivery/m0-readiness-ledger.md`.

## Planned repository outputs

The following paths are implementation outputs, not files created by this planning task. Exact module and test-target names are intentionally selected in M0-3 only after the accepted toolchain record exists.

| Area | Required output | First task |
| --- | --- | --- |
| Release evidence | `docs/delivery/m0-readiness-ledger.md` and a redacted `docs/delivery/evidence/m0/` record set | M0-1 |
| Architecture decisions | lifecycle integration record and any narrowly scoped ADR amendment under `docs/architecture/adr/` | M0-2 |
| Native app and CI | Xcode project/workspace, app and test targets, build scripts, `.github/workflows/`, entitlement allowlist checks | M0-3 |
| Test inputs/harness | synthetic fixture catalog/builders, fakes, test-root controls, fixture provenance manifest | M0-4 |
| Local record spine | workspace/store/migration/keychain/audit interfaces, encrypted database implementation, minimal opportunity command/UI, migrations, recovery states, tests | M1-1 |

## Dependency graph and release rule

```text
M0-1 Compatibility/toolchain evidence
  → M0-2 Lifecycle-policy integration
  → M0-3 SwiftUI/Xcode bootstrap + CI
  → M0-4 Fixture/harness foundation
  → M0 gate review
  → M1-1 Encrypted local record spine
```

M0 tasks are released serially: M0-1, then M0-2, then M0-3, then M0-4. This ordering keeps one durable evidence path, prevents project-generated proof from being claimed before a project exists, and avoids shared configuration conflicts. M1-1 starts only after all four M0 tasks and the formal M0 gate are accepted.

## Common review protocol

For every task below:

1. The TPM and Delivery Manager confirm dependencies are accepted and release the task in the progress ledger.
2. A fresh Implementer performs the bounded task and attaches the specified evidence.
3. A separate Code Reviewer checks scope, artifact quality, and specification compliance.
4. A separate QA/Test verifier checks the stated tests and fixture evidence.
5. The Architect reviews architectural effects; the Security/Privacy verifier also reviews M0-2 and M1-1.
6. The TPM and Delivery Manager record the result, residual risks, and next eligible task. A rejection returns only the affected task to the Implementer.

## M0-1 — Compatibility and toolchain decision evidence

**M0-1 evidence IDs:** `M0-EVID-01` toolchain/SDK/runner selection; `M0-EVID-02` universal/macOS-14 feasibility; `M0-EVID-03` dependency and encryption-candidate decision inventory; `M0-EVID-04` entitlement and CI policy; `M0-EVID-05` redacted selection-command record. The readiness ledger records each ID with its owner, reviewer, result, and artifact link.

| Evidence ID | Compatibility-matrix rows it satisfies | Required M0-1 artifact |
| --- | --- | --- |
| `M0-EVID-01` | §1: Xcode selection, Swift selection; §2: Xcode/Swift/runner selection records | Toolchain, SDK, and CI-runner selection record |
| `M0-EVID-02` | §1: minimum operating system and processor support | macOS-14 and universal-build feasibility assessment |
| `M0-EVID-03` | §4: Swift packages/build tools, SQLite access layer, SQLCipher-or-equivalent candidate | Dependency/encryption decision inventory and future validation plan |
| `M0-EVID-04` | §3: deny-by-default entitlement inventory; §6: dependency/secret scanning and CI evidence policy | Entitlement allowlist and CI/scan policy record |
| `M0-EVID-05` | §2: toolchain-validation gate record | Redacted command-output record for Xcode, Swift, SDK, and runner selection |

**Objective:** Turn the approved compatibility constraints into a reproducible selected-toolchain record. This task selects evidence-backed versions; it must not guess or silently raise the macOS deployment target.

**Dependencies:** None. The compatibility matrix and architecture specification are controlling inputs.

**Permitted scope:** `docs/delivery/evidence/m0/`, `docs/delivery/m0-readiness-ledger.md`, and status/evidence references in `docs/architecture/macos-compatibility-matrix.md`. It must not create feature code or change product requirements.

### Test-first work order

- [ ] Define an evidence checklist before selecting anything: macOS 14.0 deployment target, `arm64` + `x86_64`, exact Xcode and bundled Swift versions, macOS CI runner identity, build settings for language mode and strict concurrency, bundle/signing-identity source, reproducible unsigned and signed archive commands, entitlement allowlist, SQLite access layer, database-encryption candidate, crypto primitive availability, dependency license/security posture, and CI checks.
- [ ] Define negative acceptance checks first: reject a toolchain/dependency that requires macOS later than 14.0, lacks either architecture, expands privileges, requires a helper/daemon/network capability, has an unapproved license/security posture, or cannot build under App Sandbox/Hardened Runtime/notarization constraints.
- [ ] Capture non-project toolchain evidence only: `xcodebuild -version`, `swift --version`, available SDK identifiers, CI-runner identity, and documented macOS-14 universal-build feasibility. Project build settings, archive, binary architecture, entitlement inspection, and CI execution evidence are explicitly deferred to M0-3.
- [ ] Select a candidate SQLite/encryption approach and record a feasibility test plan that will prove correct/wrong-key behavior, stock-SQLite unreadability, WAL, migration, FTS5, backup/restore, and corruption handling after M0-3 creates the test targets. This is not encryption implementation evidence.
- [ ] Record the deny-by-default entitlement policy for M1: App Sandbox and Hardened Runtime are required; network client/server, app groups/shared containers, automation/Apple Events, accessibility control, camera, microphone, contacts, calendars, reminders, location, privileged helpers, system extensions, JIT, and debug exceptions are prohibited. Machine inspection evidence is explicitly deferred to M0-3.

### Exact outputs and evidence

- [ ] A versioned toolchain-selection record with exact Xcode build, Swift build, SDK, CI image/runner, bundle identifier convention, versioning convention, deployment target, and universal architecture requirement.
- [ ] A dependency decision inventory for the SQLite layer, encryption implementation, and test/lint tooling: version/revision, source, license, maintenance/security review date, transitive dependencies, entitlement impact, architecture result, and decision owner.
- [ ] Redacted non-project command logs for Xcode, Swift, SDK, and CI-runner selection; no certificate, team identifier, local path, credential, or recovery secret may appear.
- [ ] A CI evidence design showing PR checks: clean checkout build, deterministic unit/database/contract tests, entitlement/binary inspection, dependency scan, secret scan, and macOS-14.0 clean-device smoke. Signed/notarized DMG remains explicitly deferred to M5.
- [ ] Compatibility-matrix rows updated only with evidence-backed status and links. Any failed row remains `Required for M1 — pending` and blocks M1.

### Definition of done

- Every selection-only M0-1 row has selected values and attached non-project evidence, or the task is recorded blocked with a specific unresolved row. Project-generated validation rows remain pending and are explicitly assigned to M0-3.
- The selection record requires macOS 14.0 and universal architectures; no prohibited entitlement is proposed for M1.
- The delivery ledger records evidence IDs, commit SHA, owners, reviewers, toolchain/runner details, pass/fail result, and residual risks.
- Architect, TPM, QA/Test, Delivery Manager, and Security/Privacy verifier independently accept the evidence required by their roles.

**Required gates:** Architect owns architecture/toolchain selection; Release Engineer provides non-project command evidence; QA/Test verifies evidence reproducibility; Security/Privacy verifies dependency/entitlement policy; TPM verifies milestone fit; Delivery Manager records acceptance. M0-3 cannot begin until this task is accepted.

## M0-2 — Local-data lifecycle policy integration

**Objective:** Convert ADR-001 into implementation-ready, testable contracts for workspace creation, key custody, logical deletion, audit tombstones, backup retention/purge, restore, and export without weakening the accepted privacy model.

**Dependencies:** ADR-001 and M0-1 are accepted. This task must use the selected dependency/encryption decision record and must not choose a conflicting implementation.

**Permitted scope:** Lifecycle-contract and traceability documents under `docs/architecture/` and `docs/architecture/adr/`; M0 evidence, fixture strategy, task plan, roadmap, and readiness ledger under `docs/delivery/`; and only the lifecycle-decision cross-references in `docs/product/prd.md` and `docs/implementation-handoff.md`. It must not implement storage, write backup code, or change accepted product behavior.

### Test-first work order

- [ ] Write a lifecycle traceability matrix before changing any decision text. Map every ADR acceptance criterion to fixture IDs and evidence: `WS-EMPTY-001`, `WS-READONLY-001`, `MIGRATE-*`, `BACKUP-*`, `RESTORE-*`, `RECOVERY-ENROLL-001`, `RECOVERY-MISSING-001`, `DELETE-LOGICAL-001`, `DELETE-QUEUED-WORK-001`, `BACKUP-RETENTION-001`, `BACKUP-PURGE-001`, `EXPORT-ENCRYPTED-001`, `EXPORT-UNENCRYPTED-001`, `EXPORT-CANCELLED-001`, and `LIFECYCLE-REDACTION-001`.
- [ ] Define testable interface contracts for: workspace open/create/close; transaction/migration; Keychain status; recovery-key enrollment and re-entry verification; backup manifest/envelope verification; restore-to-new-workspace; logical deletion/tombstone/index invalidation; purge progress/result; and export warning/review/confirmation. Each contract must define success, cancellation, tamper/corruption, Keychain unavailable, missing recovery material, disk interruption, and retry behavior.
- [ ] Define the atomicity assertions first: a delete commits deletion state, tombstone/activity event, search/index invalidation, and blocked queued-work state together or commits none; a failed migration rolls back and preserves the pre-migration recovery path; a purge never removes predecessor artifacts before a verified replacement exists.
- [ ] Define the sensitive-data assertions first: database keys, OAuth tokens, recovery secrets, plaintext backup keys, raw deleted content, full export paths, and raw payloads are excluded from backups/exports/ledger/diagnostics as the ADR requires.
- [ ] Reconcile the contracts against the architecture specification's recovery trust-binding and clean-Mac restore model. If wording is ambiguous or contradictory, create a narrowly scoped ADR amendment that resolves it; do not defer ambiguity to an implementer.

### Exact outputs and evidence

- [ ] A lifecycle traceability matrix with ADR rule, architecture rule, interface contract, fixture ID, expected observable state, failure state, and named verifier.
- [ ] A schema/command contract document or ADR amendment that specifies only: deletion fields and tombstone minimum metadata; event redaction; FTS/index invalidation requirement; backup metadata and 30-day expiry calculation; purge durable state and all-or-nothing user-visible completion; export confirmation fingerprint behavior; and Keychain cleanup ordering.
- [ ] Recovery contract evidence that explicitly covers both same-Mac Keychain recovery and clean-Mac recovery-secret verification/re-wrap, including rejection of corrupt/swapped archive, envelope, manifest, or verification-key substitution.
- [ ] UX-copy acceptance references for deletion disclosure, backup expiry, destructive purge, missing-recovery guidance, encrypted-export default, and unencrypted-export warning plus final destination/filename review.
- [ ] `M0-QA-03` evidence mapped to the fixture strategy and logged with the ADR revision/version it verified.

### Definition of done

- No M1 implementer must infer retention, deletion, backup, restore, purge, Keychain, or export behavior.
- The 30-day backup-retention default, explicit destructive purge, indefinite active-data retention, logical deletion, and unencrypted-export confirmation are represented as deterministic assertions.
- The contract guarantees no plaintext/key fallback and no silent empty-workspace replacement in unavailable/corrupt/recovery-secret-missing states.
- Architect accepts the contract; QA/Test and Security/Privacy independently accept fixture mapping and sensitive-data controls; TPM and Delivery Manager record the accepted decision and open risks.

**Required gates:** Architect owns the ADR/contract; Security/Privacy verifier must approve recovery/key/deletion/export controls; QA/Test verifies fixtures cover every lifecycle branch; TPM confirms no scope expansion; Delivery Manager records the decision. M1-1 cannot begin until this task is accepted.

## M0-3 — SwiftUI/Xcode bootstrap and CI evidence foundation

**Objective:** Create the smallest signed-build-capable native macOS project and CI evidence path necessary to prove the M1 local-only boundary. This is scaffolding, not a tracker feature.

**Dependencies:** M0-1 and M0-2 accepted. The TPM/Delivery Manager must release this task only after the selected Xcode/Swift/CI runner and dependency policy are recorded and the accepted lifecycle contract has been mapped to M1 test requirements.

**Permitted scope:** Xcode project/workspace, app/test target configuration, build/release scripts, `.github/workflows/`, entitlement/configuration files, CI documentation/evidence, and `docs/delivery/m0-readiness-ledger.md`. It must not add opportunity UI, persistence behavior, integrations, AI, or network code.

### Test-first work order

- [ ] Add a failing clean-checkout CI job specification before project scaffolding. Its required checks are: resolve only pinned approved dependencies; build universal app from empty derived data; inspect architecture and entitlement allowlist; run dependency and secret scans; preserve redacted diagnostics/evidence on failure; and launch the archive on macOS 14. Focused tests remain local MVP evidence, not a hosted-CI coverage gate.
- [ ] Add a failing local reproducibility command specification before project files. It must create an unsigned test archive non-interactively from a clean checkout; the separate signed command must require externally supplied CI secrets and must not run from developer fixtures.
- [ ] Define entitlement-negative tests before creating entitlements. They must fail if App Sandbox/Hardened Runtime are missing or if network client/server, app groups/shared containers, privileged helper/system extension, automation/Apple Events, accessibility control, camera, microphone, contacts, calendars, reminders, location, JIT, debug exception, or Keychain Sharing appears.
- [ ] Create the minimum SwiftUI shell and test targets needed to make these checks pass, with macOS 14.0, explicit Swift language mode/strict-concurrency setting, universal architectures, App Sandbox, Hardened Runtime, and default team-scoped Keychain access only.
- [ ] Run a clean build, test, architecture inspection, entitlement inspection, secret scan, and default-deny-network smoke. Attach output with the selected toolchain identity.

### Exact outputs and evidence

- [ ] A native Xcode project/workspace with a minimal SwiftUI macOS app target and distinct unit, database/repository, contract, and UI/integration test targets, using the M0-1 accepted versions and settings.
- [ ] Build settings proving `MACOSX_DEPLOYMENT_TARGET = 14.0`, `arm64` plus `x86_64`, explicit Swift language/concurrency modes, App Sandbox, and Hardened Runtime. The M1 entitlement set contains no network client/server entitlement.
- [ ] Non-interactive local build/test/archive scripts or documented commands; CI workflows that run the M0-1 required checks on pull requests and record artifacts needed by the ledger.
- [ ] An entitlement allowlist and a machine-verifiable inspection result for the main app; a dependency lock/inventory; configuration that prevents credentials/secrets from entering source control or test fixtures.
- [ ] `M0-QA-04` CI/toolchain evidence and a ledger entry linked to the clean command output and repository commit.

### Definition of done

- A clean checkout can build and run the focused local test target with no live network, credentials, signing identity, or user workspace.
- CI fails deterministically for a prohibited entitlement, unsupported architecture/deployment target, unpinned/unapproved dependency, or tracked secret. Hosted CI is build/archive/smoke-only for the MVP.
- The project supplies no feature-facing tracker screen beyond a minimal boot/recovery placeholder and makes no persistence claim yet.
- Architect approves build configuration; QA/Test independently validates clean CI and local commands; Security/Privacy verifies the entitlement/secret posture; Code Reviewer verifies no feature scope leaked into scaffolding; TPM/Delivery Manager record acceptance.

**Required gates:** Architect, Release Engineer, QA/Test, Security/Privacy verifier, Code Reviewer, TPM, and Delivery Manager. M0-4 begins only after M0-3 is accepted. M1-1 cannot begin until this task is accepted.

## M0-4 — Deterministic fixture and harness foundation

**Objective:** Materialize the QA-owned synthetic fixtures and controllable runtime seams needed to prevent live-data, live-network, nondeterministic, and unrecoverable-state regressions in M1.

**Dependencies:** The fixture strategy is controlling input. M0-2 must be accepted before lifecycle fixture assertions are finalized. M0-3 must be accepted before fixture paths and test-target binding are finalized.

**Permitted scope:** fixture directories/builders, test-only harness/fakes, fixture provenance manifest, test-target configuration, `docs/delivery/evidence/m0/`, and `docs/delivery/m0-readiness-ledger.md`. It must not implement production persistence/crypto behavior or connect to external services.

### Test-first work order

- [ ] Create a failing fixture-validation specification that rejects any fixture without stable ID, schema/version, synthetic provenance, fixed clock/ID/randomness input, allowed path, and declared expected result.
- [ ] Create a failing harness-isolation specification: every test receives a unique temporary workspace root and Keychain namespace; no writes escape it; default-deny HTTP fails unregistered requests; fake XPC records no launch; teardown proves no request occurred and deletes only the unique test root.
- [ ] Add deterministic fakes before production adapters: clock, UUID/secure-randomness provider, filesystem with disk-full/interruption/permission/corruption faults, Keychain with available/locked/denied/missing states, HTTP transport, XPC client, and lifecycle/relaunch coordinator.
- [ ] Add the M1 fixture set and builders first: `WS-EMPTY-001`, `WS-CORE-001`, `WS-READONLY-001`, `MIGRATE-NMINUS1-001`, `MIGRATE-FAIL-001`, `DB-CORRUPT-001`, all `BACKUP-*`, all `RESTORE-*`, `RECOVERY-ENROLL-001`, `RECOVERY-MISSING-001`, `DELETE-LOGICAL-001`, `DELETE-QUEUED-WORK-001`, `BACKUP-RETENTION-001`, `BACKUP-PURGE-001`, `EXPORT-ENCRYPTED-001`, `EXPORT-UNENCRYPTED-001`, `EXPORT-CANCELLED-001`, `LIFECYCLE-REDACTION-001`, and `RECON-OFFLINE-001`.
- [ ] Run fixture validation, isolation tests, default-deny transport tests, and security scan. Reject any non-synthetic PII, credential, key, or executable/malicious payload outside deliberately bounded test data.

### Exact outputs and evidence

- [ ] Versioned synthetic fixture files/builders with immutable stable IDs and a provenance manifest mapping every fixture to the fixture strategy.
- [ ] Test-only seam interfaces/fakes for clock, IDs/randomness, filesystem, Keychain, HTTP, XPC, process lifecycle, locale, and time zone, with explicit fault modes listed in the fixture strategy.
- [ ] Test reports proving root confinement, Keychain isolation, no default-network request, fixed-time ordering, deterministic IDs, and teardown behavior.
- [ ] A fixture-security review report proving no real credentials, PII, private email, recovery secret, production database, or unsafe executable payload is tracked.
- [ ] `M0-QA-01`, `M0-QA-02`, and `M0-QA-06` evidence attached to the delivery ledger.

### Definition of done

- An M1 implementer can write tests against every named fixture/fake without a live service, personal Keychain, user workspace, or wall-clock assertion.
- Lifecycle fixtures exactly reflect the M0-2 accepted contract; any changed lifecycle decision requires a new fixture ID rather than mutation of a released fixture.
- Default local-only execution proves zero HTTP/XPC requests and leaves no artifacts outside the test root.
- QA/Test owns and accepts fixture integrity; Security/Privacy independently accepts fixture safety; Architect accepts interface responsibilities; Code Reviewer verifies test-only seams do not become production globals; TPM/Delivery Manager record acceptance.

**Required gates:** QA/Test is accountable; Architect, Security/Privacy verifier, Code Reviewer, TPM, and Delivery Manager independently approve. M1-1 cannot begin until this task is accepted.

## M1-1 — Encrypted workspace, migrations, audit command vertical slice

> **Superseded MVP scope correction (2026-07-24):** The original brief remains the long-term lifecycle contract, but is too broad for the approved MVP. The controlling execution brief is [M1 Foundation Completion](../superpowers/plans/2026-07-24-m1-foundation-completion.md). M1 must now complete migration safety, safe-open guidance, redacted activity visibility, and logical deletion. Recovery-key backup/restore, retention/purge, and all export behavior—including the required unencrypted-export warning—are M5 work. Pipeline, contacts, CSV, and interactions already committed in the repository are unreleased M2/M3 work and must not be extended or accepted before the corrected M1 gate. **The original M1 test-work-order backup/recovery/restore/purge/export requirements and the legacy backup/export portions of `M1-QA-05`/`M1-QA-06` are superseded for M1; they are M5-L acceptance requirements. The remaining M1 migration, safe-open, create/audit, logical-deletion/tombstone-redaction (`M1-QA-10`), offline, accessibility, and build evidence requirements continue to apply.**

**Objective:** Deliver the first real Rekon Pursuit vertical slice: a sandboxed local workspace can be created/opened with encrypted SQLite, run versioned migrations, create one minimal opportunity through a command, append its activity event atomically, survive quit/relaunch, and handle key/storage/migration recovery failures without data loss or network activity.

**Dependencies:** M0-1, M0-2, M0-3, M0-4, and the formal M0 gate all accepted. TPM/Delivery Manager must explicitly release this task. No later M1/M2 tracker capabilities may be added.

**Permitted scope:** The bounded native app, workspace/storage/keychain/migration/audit modules, one minimal opportunity command/UI surface, deterministic test targets/fixtures, local diagnostics/ledger records, and required documentation/evidence. It must not add contacts, tasks, pipeline, search UI beyond the deletion/index proof, CSV import, reconciliation, backups UI beyond contract-testable behavior, AI, Gmail, Calendar, research, document processing, or a network entitlement.

### Test-first work order

- [ ] Write failing domain and repository tests for `WS-EMPTY-001` and `WS-CORE-001`: create/open an encrypted workspace offline; submit one `CreateOpportunity` command with fixed actor/correlation ID; observe one opportunity plus exactly one append-only activity event; quit/relaunch; observe the same stable identifiers, timestamps, and event ordering.
- [ ] Write failing transaction tests before persistence code: inject a write failure after domain mutation/before event append and after event staging/before commit; both must leave neither a partial opportunity nor orphan activity event. Prove the writer serializes mutations and UI/database reads use the approved boundary.
- [ ] Write failing encrypted-storage tests before the selected encryption integration: correct key opens; wrong/missing key rejects; closed database cannot be read with stock SQLite; keys/SQLCipher parameters never appear in logs; Keychain locked/denied/missing states show recovery guidance and never create plaintext or blank replacement workspaces.
- [ ] Write failing migration tests with `MIGRATE-NMINUS1-001` and `MIGRATE-FAIL-001`: forward migration preserves IDs/timestamps/links/events; injected failure rolls back and retains the pre-migration recovery path; migrations are forward-only, exclusive, checksummed, idempotent, and recorded in `migration_history`.
- [ ] Write failing lifecycle/recovery tests with `WS-READONLY-001`, `DB-CORRUPT-001`, `RECOVERY-ENROLL-001`, `RECOVERY-MISSING-001`, `BACKUP-VALID-001`, `BACKUP-CORRUPT-001`, `BACKUP-SWAP-001`, `RESTORE-KEYCHAIN-001`, `RESTORE-CLEANMAC-001`, `DELETE-LOGICAL-001`, `DELETE-QUEUED-WORK-001`, `BACKUP-RETENTION-001`, `BACKUP-PURGE-001`, `EXPORT-ENCRYPTED-001`, `EXPORT-UNENCRYPTED-001`, `EXPORT-CANCELLED-001`, and `LIFECYCLE-REDACTION-001`. Tests must reflect the M0-2 contract exactly, including encrypted-default export, restore to a new workspace, and no partial overwrite.
- [ ] Write failing local-boundary/accessibility tests: `RECON-OFFLINE-001` proves zero transport requests; keyboard reaches visible create, validation, and recovery actions; status is not color-only; no test requires live Keychain/network.
- [ ] Implement the minimal code necessary to pass the preceding tests, then run the full deterministic M1 suite, clean checkout build, architecture/entitlement inspection, dependency/secret scan, and macOS-14.0 clean-device smoke.

### Exact outputs and evidence

- [ ] An encrypted, versioned workspace store using the M0-1 accepted SQLite/encryption implementation, with serialized writes, read-only queries, foreign keys/WAL settings, keyed open/create/close, and no plaintext fallback.
- [ ] Versioned schema/migration framework with `migration_history`, pre-migration verified transaction-scoped rollback snapshot/recovery path (not a retained/recoverable backup), checksums, idempotent forward migrations, and deterministic migration fixtures.
- [ ] A Keychain abstraction that wraps workspace keys and returns available/locked/denied/missing state without logging secrets. The default access group is team-scoped and Keychain Sharing remains absent.
- [ ] One minimal `CreateOpportunity` command carrying actor and correlation ID; it persists the record and exactly one redacted append-only activity event in the same transaction. A compact local UI exposes create, validation, success, read-only/corrupt/key-unavailable/migration-failure recovery states, and relaunch evidence.
- [ ] M1 lifecycle integration proving logical deletion/tombstone/index removal, queued-local-work suppression, and redaction through the M0-2 contracts. Portable-backup expiry/purge and encrypted/unencrypted export confirmation are `M5-L` contract tests, not an M1 output.
- [ ] Evidence bundle `M1-QA-01`–`M1-QA-04`, `M1-QA-07`–`M1-QA-10`: test reports, fixture IDs, clean toolchain/CI logs, entitlement/architecture inspection, dependency/secret scan, macOS-14.0 clean-device smoke, and redacted recovery/diagnostic output. Legacy backup/export portions of `M1-QA-05`/`M1-QA-06` are `M5-L-QA-01` and `M5-L-QA-02`.

### Definition of done

- A fresh macOS-14.0 sandboxed app, with no network entitlement, creates a workspace, creates a minimal opportunity, writes one matching activity event atomically, quits, relaunches, and reads the same state.
- Wrong/missing/locked/denied Keychain, corrupt workspace, failed migration, and offline execution each produce the approved safe state and recovery guidance—never plaintext fallback, silent loss, automatic external request, partial overwrite, or empty replacement workspace. Missing recovery secret, tampered/swap backup, interrupted purge, and canceled export are M5-L evidence.
- Tests prove closed-database at-rest protection, transaction atomicity, migration preservation/rollback, redacted event data, no default-network traffic, deterministic fixtures, and keyboard/non-color accessibility smoke.
- A separate Code Reviewer, QA/Test verifier, Architect, and Security/Privacy verifier all approve. TPM/Delivery Manager record `M1` acceptance only after `M1-QA-01`–`M1-QA-04`, `M1-QA-07`–`M1-QA-10` evidence is present and no P0/P1 trust, loss, audit, accessibility, or compatibility defect remains.

**Required gates:** Fresh Implementer; independent Code Reviewer; independent QA/Test verifier; Architect; Security/Privacy verifier; TPM; Delivery Manager. Completion opens only the next roadmap-eligible local tracker task after the milestone gate, not AI or connected workflows.

## M0 milestone review checklist

Before M1-1 may be released, the Delivery Manager must obtain independent written acceptance of the following:

- [ ] **Planning:** this task plan is dependency-safe, test-first, bounded, and maps the M0/M1 requirements to evidence.
- [ ] **Architect:** compatibility/toolchain, encrypted-storage, recovery, migration, audit, and interface decisions are internally consistent and accepted.
- [ ] **TPM:** scope is limited to M0/M1, dependencies are sequenced, risks have owners, and M1 has no blocked prerequisite.
- [ ] **QA/Test:** `M0-QA-01` through `M0-QA-05` are complete, fixtures/harness are deterministic, and M1 acceptance tests are actionable without live services.
- [ ] **Security/Privacy:** `M0-QA-03` and `M0-QA-06` are complete; secrets/keys/recovery/export/deletion/entitlement controls have no unresolved P0/P1 gap.
- [ ] **Delivery Manager:** all evidence links, review decisions, rejected-item remediation, toolchain records, and residual risks are in the progress ledger; the M0 gate is recorded `Accepted`.

## Out-of-scope enforcement

The following remain blocked until their roadmap gates: CSV import/reconciliation beyond `RECON-OFFLINE-001` fixture protection (M3/M4); documents/attachments (M5/Phase 2c); AI route selection, cloud/local inference, AI cost entries, and budgets (M6); Gmail/Calendar OAuth and mutations (M7); employer research and document processing (M8); interview and offer decision support (M9). A task that adds any of these must be rejected or returned to its roadmap gate.

## Planning self-review

| Requirement | Task coverage |
| --- | --- |
| M0-1 compatibility/toolchain evidence | M0-1 |
| M0-2 lifecycle-policy integration | M0-2 |
| M0-3 SwiftUI/Xcode bootstrap and CI | M0-3 |
| M0-4 fixture/harness foundation | M0-4 |
| M1 encrypted workspace, migrations, audit command vertical slice | M1-1 |
| Test-first, deterministic fixtures, no live dependencies | Global constraints; M0-4; M1-1 |
| Independent Architect, TPM, QA, Delivery Manager gates | Common review protocol; M0 milestone review checklist |
| No code implementation in this planning task | Scope statement and all task definitions |

No placeholder tasks, unowned decisions, or implicit cross-task dependencies remain in this plan. Any new architecture decision, dependency, entitlement, fixture, or M1 scope expansion requires an ADR/ledger update and a fresh review before implementation.
