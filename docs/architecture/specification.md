# Architecture Specification — Rekon Pursuit

**Status:** implementation-ready technical specification

## 1. Scope and architectural decisions

This application is a signed, sandboxed native macOS application with a single local user and no product-owned backend in the first release. It uses SwiftUI for the UI, Swift concurrency for background work, and SQLite as the authoritative store. A single application process owns the database; all mutations flow through a serialized write service. Files, OAuth secrets, and transient provider responses are never treated as the system of record unless imported into the local store.

The product is organized around four invariants:

1. **Local record first.** A user-visible action commits a local record and an immutable activity event in one database transaction.
2. **No implicit external effect.** Provider calls that create, modify, or send require an explicit confirmation state and an idempotency key.
3. **No implicit cloud AI.** Each AI run has an explicit local, sanitized-cloud, or full-cloud route. Failure of the selected route is a failure, never a fallback to another route.
4. **Evidence is retained separately from conclusions.** Reconciliation and research retain capture time, source, raw/derived evidence reference, classification, confidence, and the user decision.

### Assumptions

- **Minimum deployment target is macOS 14.0.** The supported baseline is a release gate, not an aspirational range: before implementation begins, the team records the Xcode/Swift toolchain, minimum macOS version, required App Sandbox/XPC entitlements, crypto primitive availability, and distribution/notarization constraints in the release compatibility matrix. A dependency or system API may be selected only after a reproducible clean macOS 14.0 build/test proves it supports that matrix, is maintained and license-approved, works in the sandbox/notarized DMG, and has no broader entitlement, helper privilege, network, or data-access requirement than the component it serves. Otherwise pin a compatible alternative or defer the feature; do not silently raise the deployment target.
- The desktop shell is SwiftUI. SQLite access uses a well-maintained Swift SQLite layer with parameterized statements and migration support. Database encryption uses SQLCipher, or an equivalent SQLite-at-rest encryption implementation validated before release.
- The app is distributed in a notarized DMG and does not expose a listening network service.
- One workspace is stored per macOS user. Multi-device sync, collaboration, server-side accounts, and automatic cloud backups are out of scope.
- Gmail, Calendar, model vendors, and research providers are adapter implementations behind stable local interfaces; exact client libraries and provider contracts are selected during implementation.

### Unresolved product decisions (must become settings/policy values before enabling the related feature)

- **Resolved by [ADR-001](adr/ADR-001-local-data-lifecycle.md) and the [lifecycle contract](local-data-lifecycle-contract.md):** active workspace data is retained indefinitely until user deletion; deletion is immediate logical deletion; recoverable backups expire 30 days after their creation; destructive purge is explicit; encrypted export is the default; and warned, reviewed unencrypted export is permitted. These rules are not implementation discretion.
- **Resolved by ADR-001:** portable/recoverable backup recovery is opt-in; the app never escrows, transmits, or resets a recovery secret, and it cannot create a recoverable backup until the user completes recovery-key setup and acknowledges that an unrecorded secret cannot be recovered.
- Gmail selection policy (explicit threads only, opt-in label, or both), OAuth scope set, and initial Calendar scope/conflict policy.
- Approved research providers, licenses, rate limits, response retention, and refresh cadence.
- Cloud model catalog, pricing source/version cadence, local-runtime distribution/update policy, and supported audio transcription models.
- Sanitization field set and whether users may add custom patterns; default is names, emails, phone numbers, street addresses, meeting URLs, account IDs, and employer/contact identifiers.
- Offer and coaching rubrics/weights. The engine must store versioned user inputs rather than embed product-defined values.

## 2. Runtime composition and boundaries

```text
SwiftUI windows / commands / accessibility layer
  └─ Presentation view models (read models + intent dispatch only)
       └─ Application services (transaction and policy boundary)
            ├─ WorkspaceRepository / SQLite write queue
            ├─ SearchIndex and NeedsAttentionQuery
            ├─ FileVault and DocumentPipeline
            ├─ ConsentCoordinator and ActionOutbox
            ├─ ModelRouter and AIExecutionService
            ├─ ReconciliationService / ResearchService
            └─ Provider adapters: Gmail, Google Calendar, model, web/data
                 └─ Keychain token store / HTTPS transport / local runtime
```

### Components

| Component | Responsibility | Must not do |
| --- | --- | --- |
| `WorkspaceStore` | migrations, transactions, encrypted SQLite access, backup/restore validation | issue network calls or render UI |
| `DomainRepository` | typed CRUD and query projections | decide confirmation policy |
| `ApplicationService` | validate commands, apply domain transitions, append activity/event rows atomically | access OAuth tokens directly |
| `ConsentCoordinator` | build disclosures, persist confirmation sessions, enforce state machines | perform domain edits outside service commands |
| `ActionOutbox` | durable pending external actions, idempotent execution and retry | silently retry a send or calendar mutation after user cancellation |
| `ProviderAdapter` | provider-specific request/response translation, auth refresh, normalized errors | mutate domain records directly |
| `ModelRouter` | selected route capability check, budget gate, sanitization preview and request dispatch | auto-select cloud on local failure |
| `DocumentPipeline` | immutable ingest, hashing, DOCX conversion/edit package, exports, secure deletion | overwrite originals or final versions |
| `ReconciliationService` | fetch/check permitted URLs, produce evidence and conservative classification | close an opportunity |
| `Scheduler` | local reminder notifications and explicitly enabled background refreshes | run work while workspace is locked or connection is revoked |
| `AuditService` | append-only activity, AI usage, consent, and provider-operation metadata | store raw sensitive prompts by default |

Use commands for all writes: `CreateOpportunity`, `UpdateOpportunity`, `SetStage`, `CompleteTask`, `SnoozeTask`, `ResolveImportRow`, `ConfirmPostingClosure`, `CreateDocumentVariant`, `ConfirmExternalAction`, and `RecordAIExecution`. Commands carry an actor (`user`, `system`, `provider`), correlation ID, and optional idempotency key. UI reads projection queries and never writes SQL.

## 3. Local storage, encryption, and migrations

### Storage layout

- `Application Support/<bundle-id>/workspace.sqlite`: encrypted SQLite database, WAL mode, foreign keys enabled, busy timeout enabled.
- `Application Support/<bundle-id>/blobs/aa/bb/<sha256>`: encrypted immutable file/blob payloads; database stores hash, relative path, media type, byte count, and encryption version. Content-addressing deduplicates only identical plaintext **within this workspace**.
- `Application Support/<bundle-id>/backups/`: encrypted, versioned database-plus-manifest backups and authenticated recovery-key envelopes; never include Keychain secrets or plaintext recovery keys.
- Keychain: database-key wrapping key, OAuth refresh/access tokens, provider client state, and file-encryption root keys. Keychain access is scoped to this bundle/access group.
- `Caches/<bundle-id>/`: expirable provider responses, rendered previews, temporary document conversion and audio chunks. Caches contain no only copy of user data and are purged on logout/revocation/delete where applicable.

The database key is generated on first workspace creation, placed in Keychain, and used to open the encrypted database. Blob encryption uses authenticated encryption with a per-blob data-encryption key wrapped by the root key; include blob hash and workspace ID as associated data. Do not log keys, SQLCipher pragmas, OAuth authorization codes, access tokens, message bodies, transcript text, or model prompts.

### Backup recovery-key strategy

Portable/recoverable backups remain unavailable until the user opts in to recovery-key setup. During setup, the app generates a high-entropy, user-controlled recovery secret, shows it once for user-mediated offline recording and requires a re-entry verification before recoverable backup creation. This one-time reveal is **not an export**: the app does not write the secret to a file, password manager, clipboard, activity record, diagnostics, database, Keychain, or product-controlled service. The secret is never subsequently displayed or recoverable by RekonLabs. A user may choose a passphrase-derived recovery secret only if the KDF is Argon2id (or a platform-approved equivalent) with versioned, stored parameters and a calibrated work factor; the app must not silently weaken those parameters.

Each backup has a random backup-encryption key (BEK). The database/blob archive is encrypted with authenticated encryption using the BEK, with backup ID, workspace ID, manifest version, and encryption version as associated data. The BEK is wrapped twice: once by the current local Keychain root for same-Mac convenience, and once by a recovery-key encryption key derived from the user recovery secret. The recovery envelope records its KDF/wrapping algorithm/version, salt, nonce, authenticated ciphertext, backup/workspace IDs, and a manifest hash; its associated data binds all of those identifiers and the backup format version.

Portable verification has an explicit trust anchor that survives Keychain loss. At recovery-key enrollment, generate a per-workspace Ed25519 backup-signing keypair; retain its private key only in Keychain and place its public verification key, key ID, workspace ID, and format version in the recovery envelope. Derive a separate recovery trust-binding key from the recovery secret (domain-separated from the BEK-wrapping key) and store `HMAC(trustKey, workspaceID || verificationPublicKey || keyID || formatVersion)` in that envelope. Every manifest names that key ID and carries its Ed25519 signature over the canonical manifest, including archive and envelope hashes. On a clean Mac with no old Keychain, restore derives the trust key from the entered recovery secret, verifies this binding before trusting the envelope public key, then verifies the manifest signature and all existing archive/envelope bindings. When the old Keychain is available, its locally retained public-key fingerprint must match the envelope public key before use. Thus an attacker cannot substitute an archive, manifest, envelope, or self-chosen verification key merely by replacing portable files; a manifest signature alone is never treated as a portable trust root.

Restore creates a new workspace only after it verifies the manifest signature, recovery-secret trust binding, envelope binding, archive authentication, database/blob checksums, and compatibility. If the old Keychain is available, it may unwrap the local envelope; otherwise the user supplies the recovery secret and must re-enter it on failure. A successful recovery-secret restore immediately generates a fresh workspace root/database key **and a fresh backup-signing keypair**, then re-wraps all restored keys for the new workspace Keychain; it does not import old OAuth tokens or reuse the recovery secret as an operating key. The user is prompted to generate and verify a replacement recovery secret/envelope, including its new verification-key trust binding, before enabling subsequent recoverable backups. Changing, rotating, or disabling the recovery secret creates new envelopes for retained backups only after re-authentication; old envelopes are securely removed according to retention policy. If both the Keychain material and recovery secret are lost, backup data is intentionally unrecoverable: show clear loss guidance, allow deletion of inaccessible backups, and never offer a password-reset, support override, or empty-workspace replacement as recovery.

### Schema conventions

- UUIDv7 text primary keys generated by the application; all timestamps are UTC ISO-8601 milliseconds.
- Mutable entities have `created_at`, `updated_at`, `deleted_at` (nullable tombstone), and `version` for optimistic concurrency. UI sends expected `version`; conflicts return the current field values and require user resolution.
- Tables use `workspace_id` even though one workspace is expected, so export/import and future isolation are unambiguous.
- References use foreign keys. Immutable/audit tables never cascade-delete; they preserve a nullable/redacted subject reference and, on deletion, only the lifecycle contract's deterministic opaque display token: `Deleted <entity-type> #<first-12-hex(SHA-256(workspaceID || subjectID))>`. No user-entered subject text may be retained in an audit tombstone or its projection.
- User text is stored as UTF-8. Search uses FTS5 external-content tables for opportunity, employer, contact, interaction, task, document metadata, and research text. Exclude encrypted raw email bodies/transcripts unless the user has enabled local full-text indexing for that category.

### Core entity schema

| Table | Key columns and constraints |
| --- | --- |
| `opportunities` | `id`, `employer_id`, `title`, `stage_id`, `status`, `job_url`, normalized URL/title/employer keys, compensation JSON, location, description_blob_id, `next_action_at`, `closed_at`; unique partial index on normalized URL when non-null is advisory only, not automatic dedupe |
| `stages`, `opportunity_stage_history` | M2 persists the fixed ordered stages `Saved`, `Applied`, `Screening`, `Interviewing`, `Offer`, and `Closed`; history has from/to stage and timestamp. A later explicitly released milestone may introduce user-configured stage definitions, stable stage IDs, and ordering migration. |
| `employers`, `contacts`, `contact_employers`, `opportunity_contacts` | many-to-many contacts/opportunities, employer association history, relationship context and link source |
| `interactions`, `tasks`, `interviews`, `offers` | interactions may link contact/opportunity; task has status, due/snoozed timestamps, source and completion activity; interviews link events, prep, audio/transcript; offers store structured terms and a versioned comparison input snapshot |
| `documents`, `document_versions`, `document_links`, `experience_library_items` | document identity and immutable versions; base/version lineage; SHA-256 and blob references; `final_for_opportunity` link is immutable once marked sent except explicit correction event |
| `attachments`, `blobs` | source filename, MIME, provenance, encrypted blob metadata, secure-deletion status; no provider attachment is kept without a declared retention reason |
| `research_items`, `research_sources` | claim text, category (`verified_fact`, `anecdotal_signal`, `inference`), confidence, source URL/title/publisher/captured_at, evidence blob/snippet reference, model run if derived |
| `posting_checks` | opportunity, URL snapshot, started/completed timestamps, result (`still_open`, `possibly_closed`, `closed_suggested`, `ambiguous`, `failed`), evidence class, confidence, HTTP/provider metadata, evidence blob/error, user decision and activity IDs |
| `import_batches`, `import_rows`, `duplicate_candidates`, `import_decisions` | completed-report mapping JSON, row validation, candidate/rationale, decision (`create`, `update_selected_fields`, `keep_separate`, `skip`), result IDs; each row needs an explicit terminal decision before batch completion. Raw CSV retention, resumable batches, and undo ownership/revisions are deferred to `RP-R3a`. |
| `connections`, `external_resources`, `provider_operations`, `gmail_response_assessments`, `follow_up_proposals` | connection state/scope summary and token Keychain reference; normalized Gmail threads/messages/calendar events and match decisions; durable Gmail send protocol fields (`rfc822_message_id`, payload hash, reconciliation attempts/result); response assessment class/confidence/evidence/classifier version or AI-run ID, manual-review state, and separately accepted/rejected follow-up proposal; provider operations contain idempotency key, canonical-payload artifact ID and fingerprint, state and remote ID, never secret/raw payload inline |
| `external_mutation_payloads`, `consent_sessions`, `external_action_confirmations` | immutable encrypted canonical request artifacts/references for Gmail/Calendar mutations; immutable disclosure snapshot, selected route/data categories, user decision/time, exact reviewed payload fingerprint/artifact ID, expiration, state and final remote result |
| `activity_events`, `ai_usage_entries`, `audit_redactions`, `audit_search_tokens` | append-only local ledger, encrypted query projections/token index, and optional redaction overlay; see section 4 |
| `settings`, `pricing_versions`, `budgets`, `backup_runs`, `migration_history` | versioned JSON setting values, model price table snapshot, budget periods/alerts, backup verification metadata, applied migrations/checksums |

Normalize searchable values (`normalized_employer_name`, normalized title and canonicalized URL) in application code with a documented deterministic algorithm. Store the original values too. Compensation/offer terms use typed columns for comparison-critical fields plus versioned JSON for provider- or locale-specific additions; all money values include currency and period.

### Transaction rules

- A domain mutation, its `activity_events` row, related timeline projection, and outbox enqueue (if any) commit in one SQLite transaction.
- Network calls occur outside the transaction. Persist `provider_operations.state = queued` first; after execution, persist response/result and resulting domain mutation in a second transaction.
- The writer serializes operations. Reads use read-only connections; long export/report reads use a SQLite snapshot to avoid blocking changes.
- Every schema migration runs in an exclusive transaction, records its SHA-256/checksum in `migration_history`, and is idempotent. Migrations only move forward. A release must include a pre-migration **verified rollback snapshot** and a migration smoke test against the prior supported schema. The snapshot is the M0-2 contract's ephemeral transaction-scoped protection, not a retained/recoverable user backup: it is never independently restored/exported, is deleted after successful migration, and remains only long enough to preserve the recovery path after a failed migration.

### Backup, restore, and deletion

- M1 has no retained backup, restore, purge, or export command. It does include an ephemeral verified rollback snapshot within each migration transaction; it is destroyed on success or retained only long enough to preserve a failed migration's recovery path. It is not shown as a backup, cannot be independently restored/exported, and has no 30-day retention window.
- M5 implements the ADR-001 portable/recoverable encrypted backup, restore-to-new-workspace, retention/purge behavior, and encrypted/sanitized export. M5 export excludes OAuth tokens and database keys and requires the approved unencrypted-export warning/final destination review.
- M1 delete is a local confirmation flow: it marks the record logically deleted, removes active local projections/queued local work, and writes only the privacy-minimized tombstone/activity evidence. It does not offer backup, restore, purge, or export. M5 expands the confirmation to the ADR-001 backup/export disclosure and integration-revocation behavior. Secure-delete guarantees depend on APFS/SSD behavior and must be described as best-effort.

## 4. Activity, audit, and AI cost ledger

`activity_events` is append-only and contains: `id`, time, actor, event type, subject type/ID, opportunity/contact/document IDs where applicable, correlation ID, causation ID, summary, before/after JSON patch (redacted by field policy), evidence/confirmation reference, canonical-payload artifact reference where relevant, route, provider/model, and normalized searchable facets. Event types include imports, edits, stage changes, task actions, document versions, match decisions, reconciliation, provider connection lifecycle, AI request completion, and final confirmations.

`ai_usage_entries` is one row per attempted model request, created before dispatch and finalized regardless of result. It contains task/feature, related subject references, route, vendor/runtime, model, capability, execution state, started/completed timestamps, local runtime duration/compute metadata, input/output/cached tokens when available, currency, estimated cost, pricing version, redacted input fingerprint, output artifact references, failure class, and correlation ID. It does **not** contain raw prompt, email body, transcript, document text, or generated content by default. A separate user-controlled diagnostic capture may retain encrypted content for a limited period; it is off by default and has its own disclosure.

Cloud usage cost is computed from the immutable `pricing_versions` snapshot selected at dispatch. Unknown token counts or prices produce `cost_status = unavailable`, not zero. Local runs set `cloud_cost = null` and record runtime/compute fields separately. Budget evaluation includes queued/max-cost reservation when the provider supports it; otherwise it evaluates before dispatch using an upper bound and warns/blocks according to user policy. Daily/monthly totals, feature, opportunity, route, model, execution state, provider operation, confirmation, and correlation-ID views are SQL projections over the ledger.

Search is local-only and uses an encrypted FTS5 projection (or encrypted token index) over permitted ledger fields: event type, normalized summary tokens, actor, the opaque tombstone display token where applicable, provider/model, route, failure class, date, and stable IDs. It never indexes raw prompts, email/calendar bodies, unredacted before/after patches, recovery material, tokens, diagnostic captures, or user-entered deleted-subject text. `AuditService` exposes deterministic filters for date range, event type, actor, subject/opportunity, route, provider/model, execution/result state, confirmation ID, correlation ID, and a free-text query; result detail loads the authoritative event and applies `audit_redactions` at read time. Retention applies to the event, its query projection, and linked AI/output/payload references together: a redaction/deletion event removes searchable content and access to the encrypted artifact, while preserving the minimum permitted immutable tombstone (ID, time, type, redaction reason, and only `Deleted <entity-type> #<first-12-hex(SHA-256(workspaceID || subjectID))>`) for ledger integrity. Default retention and legal/user overrides are policy values; no payload artifact may outlive its declared retention reason.

## 5. AI routing, privacy controls, and execution lifecycle

### Route contract

Every AI-capable feature produces a `ModelExecutionRequest` with purpose, selected source artifacts, sensitivity tags, output schema, route choice, expected model, cost preview, and related local records. `ModelRouter` validates availability and policy before content is materialized.

### Foundation dependency gate

The privacy/AI foundation (route selection, source classification, sanitizer, exact outbound disclosure, consent binding, budget reservation, immutable AI ledger, failure/no-fallback behavior, and its tests) is a prerequisite for **every** AI-mediated capability: Gmail response classification or draft generation, document suggestions, research synthesis, transcription analysis, coaching, and offer support. No feature may instantiate a model adapter, persist an AI result, or expose an AI control before this gate is complete for its route. Manual document ingest, immutable storage, versioning, rendering, export, and user-authored editing are explicitly non-AI capabilities and may ship independently; they must not acquire a model dependency merely to satisfy this ordering.

| Route | Eligibility and behavior |
| --- | --- |
| `local` | Default for private categories. Content is passed only to the local runtime. If unavailable/too weak for the requested capability, show unavailable and let the user choose another route; do not fail over. |
| `sanitized_cloud` | User selects at the action point. Display categories/fields to be replaced and quality caveat. Sanitizer creates an in-memory transformed payload and a mapping held only for the running process unless user explicitly saves the result. Cloud receives only transformed data. |
| `full_cloud` | User selects and completes a distinct confirmation that names the vendor/model, exact content categories and records leaving the Mac, estimated cost, retention/link, and safer alternatives. Confirmation binds the request fingerprint and expires if payload, selected records, route, or model changes. |

Settings store defaults, capability preferences, fields to sanitize, budgets, and retention. Settings never pre-authorize `full_cloud`, never conceal an unavailable local runtime, and never enable cloud fallback. The execution sheet must offer Cancel, local where capable, sanitized-cloud where configured, and full-cloud as separate choices.

### Sanitization

Use deterministic field-level replacement first (`[PERSON_1]`, `[EMPLOYER_1]`) so prompts remain coherent, then configurable detectors for email, phone, address, meeting link, IDs, and custom user patterns. Preserve a local redaction report: detector/version, category counts, and mapping hash; do not store mapping values in the ledger. The preview shows the actual outbound transformed text or a clear per-field diff before execution. If a source cannot be safely sanitized (for example, audio), mark sanitized route unavailable rather than send it.

### AI lifecycle

`draft → route_selected → disclosure_required | budget_checked → queued → running → completed | failed | canceled | blocked_budget`.

Route and budget gates run before an execution is enqueued: route selection materializes a request fingerprint; sanitized/full-cloud disclosure must bind that fingerprint before `budget_checked`; budget evaluation/reservation then occurs immediately before `queued`. A route, source, model, payload, pricing version, or budget-policy change invalidates downstream approval/reservation and returns to the applicable earlier gate. `queued` means a durable ledger/outbox record exists and all required gates passed; it never means network dispatch has occurred. This timing is also the rule for all lifecycle diagrams and implementation slices.

Only `completed` outputs may be attached as a draft artifact. Outputs are always editable and label their route/model/run, sources, generated time, and evidence class. Structured generation validates against the feature schema; invalid output is retained only as a failed diagnostic reference if diagnostic retention was enabled, then offers retry/edit locally. No AI output overwrites source text, opportunity fields, document versions, or scores without a normal user command and activity event.

## 6. OAuth, Gmail, Calendar, and external confirmation state machines

### Connection lifecycle

Gmail and Calendar have independent `connections` rows, Keychain token entries, scopes, and revocation controls:

`disconnected → authorizing → connected → refresh_required | permission_denied | revoked | disconnected`.

OAuth uses Authorization Code with PKCE in the system browser/ASWebAuthenticationSession, strict redirect/state/nonce validation, and provider-recommended token handling. Request the least scopes separately: Gmail read/matching, Gmail draft creation, Gmail send; Calendar availability read, Calendar event write. Scope escalation is a new consent operation. Disconnect immediately stops jobs, deletes tokens from Keychain, marks cached remote references disconnected, and offers separate deletion of retained imported content.

### Gmail selection/matching

1. User selects explicit threads or an enabled label/query scope; sync stores only permitted metadata/content under the selected retention policy.
2. Matcher proposes a link using deterministic signals (selected thread, sender/contact email, normalized employer/title, quoted application ID, calendar linkage) and stores rationale/confidence.
3. User accepts, rejects, or leaves pending. Rejection creates a durable suppression keyed by thread/opportunity and matcher evidence version; it cannot be proposed again unless materially new evidence changes the fingerprint and the UI says why.
4. A draft/reply may be generated or created as a Gmail draft after user review. Local draft and provider draft operations are auditable.

### Gmail response classification and follow-up contract

For each newly retained inbound Gmail message, the Gmail adapter may emit a `GmailResponseAssessment`, never a direct stage change or task. Its immutable input binding is the Gmail account, thread/message IDs, Gmail history/version marker, retained-message hash, and classifier version; its output is one of `interview_request`, `recruiter_question`, `offer`, `rejection`, `application_acknowledgement`, `status_update`, `no_action`, or `ambiguous`, plus calibrated confidence, bounded evidence spans/normalized signals, rationale code, and an optional structured follow-up recommendation (kind, due-time basis, suggested due time, priority, and linked opportunity). An AI-produced assessment also stores its `ai_usage_entries`/output-artifact reference and is permitted only after the foundation dependency gate; a deterministic classifier uses the same output contract.

Assessments and `follow_up_proposals` are durable, versioned local rows linked to the message hash and correlation ID. Any unsupported output, source-version mismatch, conflicting signals, or confidence below the release-configured threshold is `manual_review`; it creates no follow-up proposal that can be auto-accepted and never changes an opportunity. Even at or above the threshold, the app creates a visible `proposed` follow-up only; the user must explicitly accept it to issue `CreateTask`, or reject/dismiss it with an activity event. Reclassification after a message changes creates a new assessment/proposal and supersedes, rather than mutates, the old one. The UI shows class, confidence, evidence/rationale, classifier route/version, and “Needs manual review” where applicable.

### Canonical external-mutation artifacts

Before a Gmail send or Calendar create/update/delete can enter its reviewed state, the application serializes the exact provider request into a deterministic, versioned canonical form (including operation kind, account/calendar or thread identifiers, normalized recipients/attendees, body representation, attachment/blob hashes, changed-field set, remote etag when required, and adapter/canonicalization version). A Gmail send additionally includes its preallocated RFC 5322 `Message-ID`; it is part of the reviewed payload and fingerprint, never an adapter-added value. The app stores that form as an encrypted immutable blob and creates an `external_mutation_payloads` row with artifact hash, canonical-payload fingerprint, workspace/connection/subject IDs, retention reason/expiry, and creation activity ID. The blob's authenticated-encryption associated data binds its artifact ID, hash, workspace ID, provider, operation kind, and canonicalization version. Sensitive values stay only inside this encrypted artifact; display-safe metadata is separately redacted.

The review UI renders from this canonical artifact, not a mutable draft projection. `external_action_confirmations`, `provider_operations`, and the final activity event must all reference the same artifact ID and fingerprint. Confirmation is valid only when the reviewed artifact hash/fingerprint, account, target, operation kind, and (for update/delete) etag still match. The adapter transmits a request reconstructed from that artifact; it must reject any mismatch rather than reading mutable UI/domain fields. A post-confirmation edit, regenerated draft, changed attachment, account/target/etag change, expiration, or failed revalidation supersedes the artifact and invalidates both review and confirmation before a new canonical artifact is generated.

Canonical payload artifacts are retained only for the declared audit/reconciliation period (a release policy setting, with a user-visible default) and are included in encrypted backups under the same retention policy. Deletion/redaction securely removes the artifact and its searchable projection where possible, changes linked references to an immutable redaction tombstone containing only non-sensitive integrity metadata, and appends a deletion event. A provider operation needed to resolve an ambiguous outcome may retain its artifact until that outcome is resolved; it must then follow the same retention/deletion rule. Export includes these artifacts only when the user explicitly selects encrypted audit evidence export.

### Email send state machine

`drafting → ready_for_review → reviewed_exact_payload → final_confirmation_required → queued → sending → sent | send_failed | send_outcome_unknown | canceled | expired`.

At the `ready_for_review → reviewed_exact_payload` transition, the app preallocates a cryptographically random RFC 5322 `Message-ID` and a dormant local Gmail send-operation ID, then creates the canonical external-mutation artifact containing both. The final confirmation view renders that artifact's exact To/Cc/Bcc, subject, HTML/plain text body, attachments and hashes, linked Gmail thread, selected model route (if generated), and provider account. `reviewed_exact_payload` stores the artifact ID and canonical payload fingerprint; `final_confirmation_required` records the user-visible confirmation session bound to both. Editing any message field, attachment, recipient, thread, or account invalidates review/confirmation and returns to `ready_for_review`.

Confirm durably queues the preallocated Gmail send operation before transport, binding its Gmail account and target thread, RFC 5322 `Message-ID` in the outbound raw MIME, and canonical payload/body-and-attachment hash. The adapter sends that exact raw message through Gmail and stores the returned Gmail message/thread IDs when available. Gmail does not supply a general send idempotency key, so a local idempotency key alone never authorizes replay. On timeout, connection loss, process crash, or any response that cannot prove the send result, atomically enter `send_outcome_unknown` and retain the operation/artifact. On launch and user-requested reconciliation, query Gmail for the exact `rfc822msgid:<generated-message-id>` in the sending account, fetch each candidate, and require matching account, normalized Message-ID, recipients/subject/thread constraints, and canonical payload hash before marking `sent`. A definitive Gmail rejection marks `send_failed`. Missing, delayed, inaccessible, or non-matching search results remain `send_outcome_unknown`; they are not proof of absence and do not permit replay. Only a fresh, explicitly re-reviewed/confirmed send operation with a new Message-ID may send again, while the original remains visibly unresolved. Every transition and reconciliation attempt is durable and audited.

### Calendar mutation state machine

`draft_event → availability_checked → conflict_review_required | ready_for_review → confirmed → queued → creating_or_updating → completed | failed | canceled | expired`.

Availability is read-only and is not an authorization to create an event. On entering `ready_for_review` (or `conflict_review_required` after the user resolves a proposal), the app creates the canonical external-mutation artifact. Review shows that artifact's calendar/account, create/update/delete operation, all changed fields, attendees, conferencing link, reminders, linked opportunity/interview, and detected conflicts. `confirmed` binds its confirmation session to the artifact/fingerprint; any changed reviewed field invalidates confirmation and creates a new review artifact. A remote version/etag is required for update/delete; a conflict produces `failed_conflict` with options to reload, save as a new proposal, or cancel. The app never resolves attendee/calendar conflicts automatically.

All confirmation sessions expire after a short configurable local interval and on application restart if the payload cannot be revalidated. Confirmation UI explicitly identifies the record, irreversible effect, and safer alternative.

## 7. Document and media pipeline

1. **Ingest:** user chooses a file via picker; obtain security-scoped access, stream-copy to encrypted blob storage, calculate SHA-256, detect MIME safely, capture provenance, and release access. Never retain an external path as the only copy.
2. **Classify:** originals are immutable. `DOCX` is the editable first-class source; PDF is reference/export in the initial connected release. Store parser/converter version and extraction warnings.
3. **Extract/render:** DOCX/PDF parsing and rendering run only in a separately signed embedded XPC helper, not an in-process queue. The helper has a distinct least-privilege sandbox profile: no network client/server entitlement, no Keychain access group, no SQLite/blob-store access, no security-scoped bookmark handling, and no general filesystem entitlement. The app, after validating size/type and decrypting only into a short-lived protected staging file, passes a read-only file descriptor plus bounded parsing options over XPC; it passes app-created write-only output descriptors (or receives bounded XPC result data) for text/preview artifacts. The helper receives neither workspace paths nor encryption keys and cannot persist outputs. The app validates helper audit identity/signature, validates all returned structured data and output limits, encrypts/commits successful artifacts, then closes/unlinks staging and output files. Per-job wall-clock and resource limits cancel and invalidate the XPC connection; helper crash, invalid reply, timeout, or relaunch recovery records a durable failed/`needs_user_action` job with redacted diagnostics, cleans temporary handoffs, and never promotes partial output. Malformed/encrypted/unreadable files retain the original and enter the same recoverable state.
4. **Variant:** create a new `document_versions` row with parent/base version and a complete change-set or generated suggestion artifact. Suggested changes require review; accepting them writes another immutable version. Users can export a selected version but exports do not alter lineage.
5. **Final tracking:** when attached/sent for an opportunity, record the exact version hash, attachment hash, timestamp, and external message ID if applicable. Replacing it creates a new link/event rather than mutating history.
6. **Audio/transcript:** recording starts only after an affirmative consent attestation per recording. Keep audio and transcript as independently deletable blobs; deleting either preserves an activity tombstone and interview metadata but removes access to content. AI analysis references the selected remaining artifact and route disclosure.

## 8. Import, task, reconciliation, and research behavior

### CSV import

The MVP remediation import wizard follows the UX flow exactly: `map_columns → validate_rows → decide_duplicates → commit → report`. Validation is deterministic/offline and reports row-level errors. Duplicate candidates are advisory, scored with an explainable local rule set (canonical URL, employer/title similarity, and optional date/location); no candidate is auto-merged. The core flow retains a completed report but does not retain raw CSV content or resumable in-progress batches.

Every duplicate row requires `create`, `update_selected_fields` (show field-by-field diff), `keep_separate`, or `skip`; the user must select exact fields for an update. Batch commit creates records, decisions, one activity event per materially changed row, and a batch summary atomically. `RP-R3a` owns the later reversible-import design: an `Undo import` command may tombstone only rows/field revisions still owned solely by that batch; it never deletes later user edits or shared linked records. The R3 report displays created, updated, skipped, errors, and duplicate rationale; undo eligibility is R3a work.

### Needs attention

`NeedsAttentionQuery` is a deterministic read model. It includes overdue tasks, upcoming tasks within the configured horizon, preparation due, follow-ups, reconciliation manual reviews, and offer deadlines. Order by priority class, due/snoozed time, opportunity created time, then UUID; labels expose both absolute and relative time. Complete/snooze/reschedule/open operations produce activity events; snooze/reschedule retain prior due time and are reversible through an explicit command. Notifications are local-only unless the user later enables a separate system service.

### Job posting reconciliation

Eligible active opportunities with a user-saved URL are checked only through approved methods/providers. Each check creates a `posting_checks` row before transport and always stores URL snapshot, time, response class, evidence/error, provider/parser version, and confidence.

Classification rules: clear active evidence → `still_open`; explicit source text that the position is filled/closed → `closed_suggested`; stale/partial/mismatched content → `possibly_closed` or `ambiguous`; authentication block, robots restriction, changed URL, rate limit, network/parse failure → `failed`/`ambiguous` and **Needs manual review**. No check mutates opportunity stage. Only `ConfirmPostingClosure` may transition an opportunity to Closed, and it must display evidence, captured time, alternative Keep active, and record both the decision and history event. Retry occurs only on user request or separately enabled schedule; retries have backoff and provider limits but never transform failure into closure.

### Research

Research adapters accept only permitted/approved sources plus user-provided excerpts/links. Each source record has license/provenance, fetch/capture time, canonical URL, content hash, and retention policy. The synthesis writer must attach source IDs and label every assertion `verified_fact`, `anecdotal_signal`, or `inference`, with confidence and date. Missing evidence yields `not_enough_evidence`, never an invented conclusion. Disallowed domains are blocked before fetch; no automated Glassdoor or LinkedIn scraping is implemented.

## 9. Provider adapter contract

All adapters implement a local protocol with normalized error types and test doubles:

```swift
protocol ProviderAdapter {
  var providerID: String { get }
  func capabilityStatus(_ capability: Capability) async -> CapabilityStatus
  func execute(_ operation: ProviderOperation) async throws -> ProviderResult
}
```

`ProviderOperation` has immutable local ID, idempotency key, account/connection ID, capability, canonical request fingerprint, redacted request metadata, expiration, and correlation ID. `ProviderResult` includes remote IDs, remote version/etag where available, normalized result, redacted metadata, and retry classification. Adapters classify errors as `offline`, `auth_required`, `permission_denied`, `rate_limited`, `provider_transient`, `conflict`, `invalid_request`, `unsupported`, or `unknown`; only safe read/refresh operations may be automatically retried with bounded exponential backoff and jitter. External mutation retries always return to the user after an ambiguous or failed outcome.

## 10. Security and privacy controls

- Enforce App Transport Security/TLS certificate validation; no custom trust bypass in production. Pinning is not assumed unless a provider requires and supports an operational rotation plan.
- Use parameterized SQL, allowlisted sort/filter fields, strict URL scheme/domain validation, HTML sanitization for mail/web rendering, and no execution of document macros/embedded scripts.
- Treat provider text, CSV cells, web pages, document content, transcripts, and AI output as untrusted. Prompt construction clearly separates instructions from source content; tools/actions receive structured, allowlisted data and never execute model-produced commands.
- Limit document/media sizes, decompression ratios, parser runtime, concurrent jobs, provider response size, and redirect depth. Quarantine invalid artifacts with a safe error state.
- Keychain and encrypted storage protect tokens/content at rest; lock/unavailable Keychain makes dependent features unavailable with recovery guidance, never falls back to plaintext.
- Provide per-connection revoke/delete, data-category retention controls, local export, AI routing history, budget controls, and clear content-outbound disclosures. Telemetry is off by default unless separately opted in; crash reports must scrub paths/content/tokens.
- Logging is structured and redacted by default. Use local correlation IDs; production diagnostics retain operation class and error code, not source payloads.

## 11. Observability and recovery

The app keeps a local diagnostics journal with correlation IDs across command, event, outbox, provider operation, and AI ledger entries. It records timing, queue length, retry class, schema/app/adapter versions, and redacted error context. A user can export a sanitized diagnostics bundle after preview; it excludes blobs, prompt/content text, tokens, OAuth material, and local paths by default.

| Failure | Required user-visible result and recovery |
| --- | --- |
| Database/key unavailable or corruption | Open read-only recovery mode if possible; block mutations; offer verified backup restore/export and diagnostic bundle. Never create a replacement empty workspace silently. |
| Migration failure | Roll back transaction; preserve the verified transaction-scoped rollback snapshot required for retry/recovery; show version/error and offer retry/keep-current-workspace. Offer portable-backup restore only if the user separately has an enrolled recoverable backup. |
| Disk full/blob write interruption | Preserve source document where possible, mark ingest failed, release temporary files, show space/retry guidance; do not create a partial version. |
| App crash during mutation | SQLite atomic transaction leaves old or new state; on launch resume only idempotent local jobs and reconcile queued provider operations by operation state. |
| Offline/provider outage | Persist local draft/command and provider operation state; show Offline/Retry when connection returns. Never represent queued external work as completed. |
| OAuth expiry/revocation | Mark connection action-required, stop sync/mutations, retain local records, offer reconnect or disconnect/delete. |
| Gmail send timeout/crash | Persist `send_outcome_unknown`; on relaunch reconcile only with the durable Gmail Message-ID search-and-full-payload proof. Keep unknown when proof is absent or delayed; never replay that operation. A new send requires fresh review/confirmation and a new Message-ID. |
| Calendar timeout | Query remote result before permitting a retry; show unknown outcome until resolved to avoid duplicate side effects. |
| AI local runtime unavailable | Show capability/status and route choices; do not invoke cloud without a new explicit selection/disclosure. |
| Cloud AI failure/budget block | Finalize ledger with failure/blocked state, preserve inputs locally, offer retry or another route as a new run. |
| Reconciliation ambiguity/failure | Retain evidence/error; queue Needs manual review; do not change opportunity state. |
| Provider schema/content change | Mark adapter/parser result unsupported/failed with captured version, keep evidence, and require manual review or adapter update. |

All non-happy states use visible label/icon/text, focused recovery actions, accessible descriptions, and Escape cancellation where a modal operation is cancellable.

## 12. Testing and release verification

| Layer | Required coverage |
| --- | --- |
| Domain/unit | stage/task transitions; duplicate rule explanations; import decisions; route/budget gate timing and proof that no AI-mediated feature runs before the foundation gate; sanitizer determinism; ledger cost math; offer/coach `not_enough_evidence`; reconciliation classification; Gmail response-classification schema/confidence thresholds/manual-review and accept/reject-only task creation; event append rules; canonicalization determinism and confirmation-fingerprint invalidation |
| Database | fresh install; each migration from every supported prior schema; rollback on injected failure; FK/index/FTS integrity; transaction atomicity; optimistic-concurrency conflict; backup/restore checksum and blob inventory; recovery-envelope authentication/binding including recovery-secret trust binding to the portable verification public key; artifact/ledger retention-redaction and query-index removal |
| Adapter contract | Gmail/Calendar/model/research fixtures for success, expired auth, denied scope, rate limit, malformed response, timeout, version conflict, and pagination; prove Gmail/Calendar mutation requests are reconstructed from the confirmed canonical artifact and reject mismatched/missing artifacts; Gmail send timeout/crash/relaunch reconciliation searches the durable RFC 5322 Message-ID and requires full payload proof, preserves unknown when proof is absent, and never replays; no live credentials in tests |
| State-machine | exhaustive valid/invalid transitions for OAuth, Gmail response assessment/proposal, email send including `send_outcome_unknown`, calendar mutation, AI execution, import, closure confirmation, and deletion; route/budget checks must precede enqueue; any payload/account/target/etag change invalidates confirmation and requires a new canonical artifact |
| Document/security | malicious CSV/formulas, malformed/zip-bomb DOCX, oversized PDF/audio, unsafe HTML, redirect loops, encrypted/unreadable document, prompt injection text, secret-redaction/log assertions; XPC helper signature/audit-identity validation, denied network/Keychain/database/path access, descriptor-only handoff, output validation, timeout cancellation, helper crash, and app-relaunch cleanup/recovery |
| UI/accessibility | default Needs attention order; keyboard-only complete/snooze/reschedule/cancel; labels not color-only; disclosure text; exact-payload send review; conflict/manual-review/error/offline/empty states; VoiceOver identifiers |
| Audit/search | query by date, type, actor, subject, route, provider/model, execution state, confirmation, correlation ID, and permitted free text; verify deterministic ordering/pagination, redaction at read time, no raw sensitive content is indexed, and AI/provider mutations are discoverable through their shared correlation/fingerprint references |
| End-to-end | local-only daily loop; re-import with row decisions; confirmed closure; Gmail selected-thread accept/reject suppression; high/low-confidence Gmail response assessment with manual review and explicit follow-up acceptance; email draft then exact confirmation plus timeout/crash/relaunch unknown-outcome reconciliation; Calendar conflict review; each AI route and no-fallback proof; export/restore with local-Keychain envelope and a clean-Mac/no-prior-Keychain recovery-secret restore that verifies the recovery-bound public key, re-wraps keys, and rejects corrupted/swapped archive, envelope, manifest, or verification-key substitution; unrecoverable-loss guidance |

Use deterministic clocks, random seeds, fixture provider responses, and an injectable filesystem/Keychain/HTTP/XPC layer. The MVP has a rough 50% automated-coverage planning target: do not pursue broad percentage gains as a release goal, but do retain focused tests for primary flows and material failure, privacy, data-loss, and irreversible-effect boundaries. CI runs formatter/linter, the applicable unit/database/contract tests, security dependency scan, migration compatibility tests, clean-macOS-14.0 build/launch smoke tests, and helper-entitlement inspection. Developer ID signing, notarization, stapling, and DMG smoke tests are M5 release-gate evidence. A release gate requires encrypted backup/restore smoke tests for both available recovery paths (including clean-Mac portable trust verification), no unresolved migration or baseline/dependency-matrix checks, and manual verification that full-cloud and external mutations cannot execute without their confirmation sheets or their authenticated canonical payload artifacts.

## 13. Initial implementation slices

1. Workspace bootstrap: encrypted SQLite, migration/backup framework, Keychain abstraction, event ledger, core opportunity/contact/task schema, and Needs attention query.
2. Local tracker: working record, stage/task/activity commands, search, CSV decision workflow, reversible batch behavior, and conservative reconciliation evidence/closure confirmation.
3. Privacy/AI foundation: settings, model router, sanitizer/disclosure/ledger/budget state machines, local runtime adapter, then cloud adapter only after consent tests pass.
4. Connections: independent OAuth lifecycle, selected Gmail matching/drafts/send confirmation, then Calendar availability/mutation confirmation. Gmail response classification/draft generation remains unavailable until slice 3's AI foundation gate is complete. This slice uses the already-required encrypted generic blob/attachment storage and canonical-payload artifacts; it does not depend on DOCX/PDF conversion, document versioning, or the full document library.
5. Document library: manual immutable ingest/blob handling, document links/versions, XPC-isolated DOCX/PDF safe pipeline, final-file tracking, export and deletion controls. This deliberately follows Connections to match the delivery roadmap; no technical blocker requires manual document processing before Gmail/Calendar. Any AI suggestion capability remains gated by slice 3.
6. Intelligence/decision support: permitted research, interview media/consent, prep/coaching, offer comparison and negotiation drafts; all are enabled only on the completed privacy/AI foundation.

Each slice is shippable with all unsupported controls visibly unavailable rather than simulated. The local daily-tracker slice is the MVP; integrations and cloud processing remain disabled until their adapter, confirmation, and recovery tests are complete.
