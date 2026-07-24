# Rekon Pursuit — M0 Test and Fixture Strategy

## Purpose and authority

This is the independent QA strategy for M0 readiness and M1 (Local record spine). It defines deterministic test data, controllable runtime seams, and evidence required before application implementation begins. It implements the verification requirements in the [architecture specification](../architecture/specification.md), [roadmap](roadmap.md), and [implementation handoff](../implementation-handoff.md); it does not choose a persistence or crypto library.

The strategy is deliberately **local-only**. No test may require a live Google account, cloud-model account, provider API, network connection, real user workspace, or production Keychain item. Later milestones must extend this catalog rather than replace its fixtures or bypass its seams.

## Approved lifecycle policy under test

The following decisions are testable acceptance constraints for M0/M1:

| Policy | Required observable behavior |
| --- | --- |
| Retention | Workspace data remains until the user deletes it; no age-based deletion job runs by default. |
| Deletion | A delete command hides content from normal views and search immediately, writes a tombstone/activity event, and retains only the recovery data permitted by backup/export policy. |
| Backup retention | Opt-in recoverable backups retain deleted content for 30 days by default. The app shows each backup's expiry. |
| Backup purge | `Purge deleted data from retained backups` is a deliberate destructive command with a warning and explicit confirmation; it removes eligible deleted content from retained backup copies. |
| Export | The user may create an unencrypted export only after a warning that it is outside app encryption and deletion controls, plus a destination/filename review. |
| Recovery authority | User-held recovery material has no support/reset bypass. A missing recovery secret produces recovery guidance, never an empty replacement workspace. |

Exact backup envelope, recovery-key, secure-delete, and clean-Mac restore contracts remain architecture-owned ADR subjects. This strategy requires fixtures and assertions for their chosen contract before M1 is released.

## Test harness rules

### Required test tiers

| Tier | Purpose | Allowed dependencies | Required outcome |
| --- | --- | --- | --- |
| Domain/unit | Pure commands, state transitions, ordering, serialization, and validation | In-memory fakes only | Fast, deterministic assertions with no disk, Keychain, or network access. |
| Repository/database | Schema, migrations, transactions, backup manifests, tombstones, and search indexes | Per-test temporary directory and fake Keychain | A test observes committed state through public repositories, not SQL implementation details alone. |
| Contract | Provider/runtime boundaries and XPC message contracts | Recorded fixture responses and deterministic fakes | Every success/failure response maps to a normalized result without a real transport. |
| App integration | SwiftUI command-to-persistence-to-activity path and recovery states | Isolated workspace fixture | One user action produces the intended persisted record and activity evidence atomically. |
| Release smoke | Signed app/install/relaunch and entitlement inspection | Clean macOS runner, synthetic workspace only | No production data or credentials; failures preserve diagnostics and recovery guidance. |

### Determinism contract

Every executable test must inject or fix the following values:

| Dependency | Required seam | Test behavior |
| --- | --- | --- |
| Clock | `Clock`/date provider protocol | Use named UTC instants; never assert the wall clock or relative strings without a fixed reference time. |
| UUID/randomness | UUID and random-byte provider protocol | Use fixture-specific fixed sequences. Tests must not depend on generated identifiers or random encryption salts. |
| Filesystem | File-store protocol rooted in a unique temporary directory | Deny accidental access outside the test root; inject disk-full, interruption, permission, and corruption faults. |
| Keychain | Keychain protocol with an in-memory fake plus a controlled unavailable/denied fake | Never use the developer's login Keychain in unit, database, or UI tests. |
| HTTP/network | HTTP transport protocol backed by fixture files | Fail the test if an unregistered request is attempted; default is offline. |
| XPC | Helper-client protocol with fake reply, timeout, crash, invalid identity, and relaunch states | No helper process is required for M0/M1; the interface must be contract-testable before document processing ships. |
| Process/app lifecycle | Launch/relaunch coordinator | Tests can terminate after a chosen transaction boundary and reopen the same fixture workspace. |
| Locale/time zone | Fixed `en_US_POSIX` locale and UTC unless a locale/time-zone fixture names another value | Avoid locale-dependent parsing/order surprises. |

Test setup must create a fresh workspace root, test Keychain namespace, fixture database, and correlation-ID sequence. Teardown must delete only that unique test root and must assert no request was made through the default-deny HTTP transport.

## Fixture catalog

Fixture IDs are stable references for task briefs, automated tests, and release evidence. Fixtures contain synthetic names, URLs, email addresses, and document text only. They must never be derived from a user's job-search data and must never contain database keys, OAuth tokens, recovery secrets, plaintext backup keys, or recovery material. Test-only recovery inputs are deterministically synthesized by an in-memory builder at test runtime from fixed non-secret test seed labels; they are neither persisted nor committed.

### Workspace, schema, and migration fixtures

| ID | Contents / setup | Assertions it enables |
| --- | --- | --- |
| `WS-EMPTY-001` | New encrypted workspace with schema version `N`, no records, fixed workspace ID and clock. | First launch, empty UI, schema creation, no background network activity. |
| `WS-CORE-001` | One employer, opportunity, task, contact link, and append-only activity event using fixed IDs/timestamps. | Repository reads, canonical record links, audit query ordering, relaunch persistence. |
| `WS-READONLY-001` | Valid workspace opened with a mutation-blocking storage/key state. | Read-only recovery UI; mutations are blocked without silently creating a new workspace. |
| `MIGRATE-NMINUS1-001` | Last supported schema fixture with core records and activity history. | Forward migration preserves IDs, timestamps, links, and events. |
| `MIGRATE-FAIL-001` | Pre-migration workspace plus injected transaction failure, disk interruption, relaunch/retry, and corrupt-rollback-snapshot variants at named steps. | Rollback and retained pre-migration recovery path through the ephemeral verified rollback snapshot; no independently restorable backup or empty replacement; actionable version/error state. |
| `DB-CORRUPT-001` | Workspace with an intentionally invalid database/page or manifest checksum. | Recovery mode, diagnostic guidance, verified restore/export offer; never automatic empty replacement. |

The architect must add one migration fixture for **every** supported prior schema before that migration is eligible for release. A fixture is immutable once released; a corrected historical fixture gets a new ID.

### Backup, restore, deletion, and export fixtures

| ID | Contents / setup | Assertions it enables |
| --- | --- | --- |
| `BACKUP-VALID-001` | `WS-CORE-001` backup metadata with manifest, blob inventory, fixed archive ID, authenticated-envelope metadata, and a runtime-builder recovery-input label (not recovery material). | Archive integrity, manifest binding, backup inventory, restore-to-new-workspace behavior. |
| `BACKUP-CORRUPT-001` | `BACKUP-VALID-001` with one modified archive/manifest/envelope byte, one variant per corruption class. | Authentication/checksum failure; no partial restore or overwritten active workspace. |
| `BACKUP-SWAP-001` | Two otherwise valid workspaces with exchanged archive, envelope, or verification material. | Detect swapped/bound-to-wrong-workspace recovery artifacts. |
| `RESTORE-KEYCHAIN-001` | Valid backup restored with the expected local Keychain recovery path available. | Restore/re-wrap behavior dictated by the ADR; restored data and activity evidence are complete. |
| `RESTORE-CLEANMAC-001` | Valid backup metadata and a runtime-builder recovery-input label with no prior workspace Keychain entries. | Portable recovery verification/re-wrap behavior dictated by ADR; no hidden dependency on prior Keychain state or committed secret. |
| `RECOVERY-ENROLL-001` | Fixed enrollment flow whose test-only input is generated in memory by the deterministic runtime builder; variants cover cancel, mismatch, Keychain locked/denied, and disk interruption. | No recovery archive/envelope on unsuccessful enrollment; no reset/escrow, file/clipboard write, secret log, plaintext fallback, or persisted/committed secret. |
| `RECOVERY-MISSING-001` | Backup metadata with the runtime builder withholding its recovery input in separate `locked`, `denied`, `missing`, and Keychain-cleanup-retry variants. | Exact unavailable state and guidance; never plaintext fallback or empty workspace creation; cleanup occurs only after dependent database/filesystem deletion succeeds. |
| `DELETE-LOGICAL-001` | `WS-CORE-001` after fixed-time deletion variants for every supported deletable entity. | Record disappears from normal views, FTS, cache keys, and active workflow projections; tombstone display equals `Deleted <entity-type> #<first-12-hex(SHA-256(workspaceID || subjectID))>` and contains no user-entered subject text; injected transaction fault yields all-old or all-new state. |
| `DELETE-QUEUED-WORK-001` | A deletion with queued AI, provider, and reconciliation work referencing the source. | Each queued operation is atomically cancelled or given durable visible `blocked_deleted_source`; no external call is made. |
| `BACKUP-RETENTION-001` | A recoverable backup created at fixed `T0`, containing data deleted at `T1 > T0`, inspected at `T1`, `T0 + 29 days`, and `T0 + 30 days`. | `expires_at = T0 + 30 days`; the deletion time never shifts expiry. UI exposes expiry and `expired_pending_removal` truthfully. |
| `BACKUP-PURGE-001` | Multiple retained backups containing deleted/non-deleted data, with confirm, cancellation-before-promotion, per-backup verify failure, predecessor-removal failure, interruption/relaunch, retry, and concurrent-backup-attempt variants. | Scope/cutoff blocks or queues mutation; predecessor survives until verified replacement; predecessor-removal failure is `incomplete_retryable` or `blocked`; durable per-backup progress is observable; no false completed result. |
| `EXPORT-ENCRYPTED-001` | Valid encrypted export fixture. | Export inventory, integrity, and no plaintext material in protected export path. |
| `EXPORT-UNENCRYPTED-001` | User-approved plaintext export with fixed type/categories/filename/destination and variants changing each reviewed field. | Exact warning and final review precede write; any reviewed-field change invalidates confirmation; event retains only safe metadata. |
| `EXPORT-CANCELLED-001` | User opens plaintext-export warning then cancels. | No file written, no export-completed activity event, workspace unchanged. |
| `LIFECYCLE-REDACTION-001` | Synthetic lifecycle operation corpus covering before/after audit patches, errors/diagnostics, backup manifests/envelopes, export ledger metadata, and delete/purge results. | Redaction scan proves no database key, OAuth token, recovery secret, plaintext backup key, raw deleted content, full local path, or raw export payload is retained; every tombstone display exactly equals `Deleted <entity-type> #<first-12-hex(SHA-256(workspaceID || subjectID))>` and contains no user-entered subject text. |

### CSV import fixtures

| ID | Rows / setup | Required outcomes |
| --- | --- | --- |
| `CSV-VALID-001` | Two valid new opportunities, canonical URLs, titles, employers, and dates. | Map → validate → commit; creates expected records and one material activity event per changed row. |
| `CSV-MIXED-001` | Valid rows plus missing required title/employer, invalid date, invalid URL scheme, overlong cell, and duplicate header. | Deterministic row-level errors; valid rows remain eligible; invalid rows are never silently committed. |
| `CSV-FORMULA-001` | Cells beginning `=`, `+`, `-`, and `@`; quoted delimiters and Unicode employer/title text. | Stored/displayed as untrusted text; export/spreadsheet-safe escaping policy; parser remains deterministic. |
| `CSV-DUP-URL-001` | Existing opportunity and row with same canonical URL but different title formatting. | Explainable duplicate candidate; no auto-merge; all four user choices are available. |
| `CSV-DUP-SIMILAR-001` | Existing opportunity and row matching employer/title/location/date but no URL. | Advisory similarity rationale and score; user decides create/update-selected-fields/keep-separate/skip. |
| `CSV-UPDATE-FIELDS-001` | Existing opportunity and duplicate row differing in allowed and disallowed fields. | Field-by-field diff; only user-selected permitted fields change; activity records the decision. |
| `CSV-REIMPORT-001` | Re-import of `CSV-VALID-001` after first batch commit. | Duplicate candidates reappear; no unintended duplicate or overwrite. |
| `CSV-UNDO-OWNED-001` | Imported rows untouched after commit. | Undo tombstones only batch-owned rows/revisions and creates a summary/activity event. |
| `CSV-UNDO-CONFLICT-001` | Imported row later edited by user or linked to a shared record. | Undo preserves later user edits/shared data and reports ineligible portions. |

### Reconciliation fixtures

All reconciliation fixtures use an allowlisted synthetic `https://jobs.fixture.rekon.test/...` URL, fixed response time, provider/parser version, and response headers/body snapshot. They are consumed only by the fake HTTP adapter.

| ID | Simulated outcome | Required outcome |
| --- | --- | --- |
| `RECON-OPEN-001` | HTTP 200 with a current posting and explicit application control. | `still_open` evidence with URL snapshot/time; stage unchanged. |
| `RECON-FILLED-001` | HTTP 200 with explicit position-filled language and configured threshold evidence. | Candidate closure evidence only; user confirmation is still required before a stage changes. |
| `RECON-AMBIGUOUS-001` | HTTP 200 changed text without conclusive closure evidence. | Manual review, retained evidence, no stage change. |
| `RECON-CHANGED-001` | Redirect/changed page or role mismatch. | Manual review with changed result; no inferred closure. |
| `RECON-DENIED-001` | HTTP 401/403 or access challenge. | Failed/blocked manual review; no retry storm, no stage change. |
| `RECON-TRANSIENT-001` | Timeout, HTTP 429, HTTP 503, and connection failure variants. | Retained error, deterministic retry/manual-review task, no stage change. |
| `RECON-MALFORMED-001` | Invalid content type/body or parser error. | Unsupported/failed result with provider/parser version and manual review. |
| `RECON-OFFLINE-001` | Default-deny HTTP transport; previous result exists. | Makes zero HTTP calls, retains prior result, displays `Offline — check not run`, creates retry/manual-review work. |

## Required seams and contract tests

The implementation plan must create these dependency interfaces before the first feature makes direct use of their platform implementation. Names may vary, but responsibilities may not be collapsed into unmockable globals.

| Boundary | Required methods/capabilities | Minimum contract evidence |
| --- | --- | --- |
| Workspace store | Open/create, transaction, migration version, query, backup snapshot, restore prepare/commit, close. | Atomic record-plus-event commit; rollback on injected error; migration/relaunch tests. |
| Crypto/recovery service | Create/open workspace keys, protect/unprotect backup material, verify binding, rotate/re-wrap as ADR requires. | `BACKUP-VALID`, corrupt/swap, Keychain, clean-Mac, and missing-recovery fixtures. |
| File store | Read/write/rename/unlink/list/atomic replace, fault injection, root confinement. | No writes outside test root; disk-full/interruption leaves no promoted partial artifact. |
| Keychain | Read/write/delete/status (available, locked, denied, missing). | Locked/denied state blocks dependent actions with recovery guidance and no plaintext fallback. |
| Clock/ID/random | Current time, elapsed time, UUID, secure random bytes. | Identical test run produces identical ordering, IDs, and serialized fixture output except designated encrypted ciphertext. |
| HTTP transport | Execute normalized request; expose request capture; offline/default-deny mode. | Each reconciliation fixture maps to exact request/result; unregistered request fails test. |
| Provider adapter | Normalize provider results/errors and retain version/evidence metadata. | Reconciliation outcome taxonomy and offline no-request proof. |
| XPC helper client | Submit bounded job; cancel; validate helper identity; observe timeout/crash/invalid reply. | Fake-driven contract tests for document-processing future slice; M0/M1 app makes no XPC call. |
| Activity/audit writer | Append atomically with command transaction; query redacted projection. | Every M1 mutation produces exactly one required event and a failed transaction produces none. |

## M0 readiness evidence

M0 is not an application feature release. The following evidence must be committed and independently reviewed before M1 implementation begins:

| Evidence ID | Required proof | Owner | Independent approver |
| --- | --- | --- |
| `M0-QA-01` | This fixture catalog is mapped to planned files/test targets and every fixture has synthetic provenance. | QA/test agent | Delivery Manager |
| `M0-QA-02` | Test-harness decision records fixed clock, deterministic IDs/randomness, temp-root filesystem, fake Keychain, default-deny HTTP, and fake XPC seams. | Architect | QA/test agent |
| `M0-QA-03` | ADR-001 plus the accepted lifecycle contract resolve backup taxonomy/envelope, recovery trust/enrollment/restore/re-wrap, tombstone/search/queued-work behavior, creation-time 30-day retention, purge concurrency/interruption/retry semantics, redaction, and unencrypted-export warning/review invalidation. | Architect | Security/privacy verifier and QA/test agent |
| `M0-QA-04` | Compatibility/release matrix names supported macOS/Xcode/Swift baseline, signing/notarization, Sandbox/entitlement strategy, dependency policy, and CI runner. | Architect / TPM | QA/test agent |
| `M0-QA-05` | M1 task brief lists each acceptance test first, fixture IDs, seams, failure modes, and release evidence; no live credentials or network dependency. | Planning agent | QA/test agent and TPM |
| `M0-QA-06` | Fixture security review confirms no real credentials, PII, private emails, or executable/malicious payloads outside intentionally bounded test samples. | Security/privacy verifier | Delivery Manager |

M0 pass condition: all `M0-QA-01` through `M0-QA-06` are approved, no unresolved lifecycle behavior affects a fixture assertion, and the Delivery Manager records the gate in the progress ledger. A missing implementation choice is a blocked gate, not permission for an implementer to improvise.

## M1 test evidence expectations

M1 is acceptable only when the local record spine passes the following independent evidence bundle:

| Evidence ID | Fixture(s) | Required proof | Owner / verifier |
| --- | --- | --- | --- |
| `M1-QA-01` | `WS-EMPTY-001`, `WS-CORE-001` | Fresh workspace opens offline; create minimal opportunity; quit/relaunch; same stable ID, timestamps, links, and activity event are observable. | Implementer / QA verifier |
| `M1-QA-02` | `WS-CORE-001`, injected write failure | Opportunity mutation and required activity event commit in one transaction; failure leaves neither partial record nor orphan event. | Implementer / QA verifier |
| `M1-QA-03` | `MIGRATE-NMINUS1-001`, `MIGRATE-FAIL-001` | Every supported migration preserves data; injected failure rolls back and retains pre-migration recovery path. | Implementer / QA verifier |
| `M1-QA-04` | `WS-READONLY-001`, `DB-CORRUPT-001`, `RECOVERY-ENROLL-001`, `RECOVERY-MISSING-001` | Read-only/corrupt/key-unavailable states block mutations, show recovery guidance, and never replace the workspace with a blank one. | Implementer / QA verifier + Security/privacy verifier |
| `M1-QA-05` | `BACKUP-VALID-001`, `BACKUP-CORRUPT-001`, `BACKUP-SWAP-001`, `RESTORE-KEYCHAIN-001`, `RESTORE-CLEANMAC-001` | Chosen lifecycle ADR is exercised end-to-end: successful verified backup/restore, tamper/swap rejection, both approved recovery paths, and no partial overwrite. | Implementer / QA verifier + Security/privacy verifier |
| `M1-QA-06` | `DELETE-LOGICAL-001`, `DELETE-QUEUED-WORK-001`, `BACKUP-RETENTION-001`, `BACKUP-PURGE-001`, `EXPORT-ENCRYPTED-001`, `EXPORT-UNENCRYPTED-001`, `EXPORT-CANCELLED-001`, `LIFECYCLE-REDACTION-001` | Approved deletion, retention, purge, redaction, encrypted-default export, and unencrypted-export warning semantics are exact and deterministic. | Implementer / QA verifier + Security/privacy verifier |
| `M1-QA-07` | `RECON-OFFLINE-001` | Default offline setup records zero transport requests. This guards the local-first boundary before reconciliation is implemented. | Implementer / QA verifier |
| `M1-QA-08` | Synthetic clean workspace | Accessibility smoke: keyboard reaches visible create/validation/recovery actions; status is not color-only; identifiers support later UI automation. | Implementer / QA verifier |
| `M1-QA-09` | Full M1 suite | Formatter/linter, unit/database/contract tests, migration compatibility, dependency scan, and clean-macOS unsigned-build/launch smoke pass; results and environment versions are attached to the ledger. Developer ID signing, notarization, and DMG smoke are M5 evidence only. | TPM / QA verifier |

No M1 test may be waived because a UI is not yet built. If the command exists, its persistence, event, validation, recovery, and accessibility state must be evidenced at the lowest practical layer plus app integration where surfaced.

## Fixture maintenance and ownership

| Activity | Accountable role | Required control |
| --- | --- | --- |
| Create/curate fixture files and test data builders | QA/test agent | Stable ID, synthetic provenance, documented schema/version, and review for secrets/PII. |
| Approve cryptographic/recovery fixture shape | Architect | ADR reference, tamper/binding cases, both recovery paths where supported. |
| Verify sensitive fixture handling | Security/privacy verifier | No secrets, no production keys, bounded malicious samples, no plaintext leaks in logs. |
| Release task only after test prerequisites exist | TPM and Delivery Manager | Fixture IDs and expected evidence are attached to the task ledger entry. |
| Run feature tests and attach raw results | Implementer | May not mark its own verification complete. |
| Independently assess results and regressions | QA/test agent | Re-runs targeted tests from a clean workspace; records pass/fail and deviations. |
| Approve architecture deviations | Architect | ADR required before changing a seam, data-lifecycle rule, or fixture contract. |

Fixture changes require review like production changes. Do not update a fixture merely to make a failing test pass: preserve the original, add a new versioned fixture if the approved contract changed, and link the change to an ADR or product decision.

## Exit checklist

- [ ] All M0 evidence IDs are approved and recorded in the delivery ledger.
- [ ] M1 task briefs name their fixture IDs, deterministic seams, and failure/recovery assertions.
- [ ] Test configuration blocks live HTTP and production Keychain access by default.
- [ ] Test artifacts contain no actual personal/job-search data, tokens, or private documents.
- [ ] Backup/recovery/deletion/export contract tests match the approved lifecycle ADR exactly.
- [ ] A QA verifier distinct from the implementer can run the M1 suite from a clean checkout and obtain the recorded result.
