# ADR-004: Durable document-reference bookmarks

- **Status:** Accepted — Architect and Security/Privacy approved for R6
- **Date:** 2026-07-27
- **Decision owner:** Product owner; Architect review required
- **Scope:** R6 local PDF/DOCX references only

## Decision

R6 may retain an opaque security-scoped bookmark in the encrypted local
workspace for a user-selected PDF or DOCX. The bookmark supports explicit
user-open and relink actions only; it is not a document copy or a general
filesystem grant. The app persists no readable source path, never parses or
uploads the file, and creates no new network capability.

Each reference carries an availability state. A file is verified immediately
before the system-open handoff through a temporary scope: it must be a regular,
non-symlink PDF/DOCX, no larger than 25 MB, with the saved SHA-256 and byte
count. A missing, stale, denied, or mismatched reference is relink-required;
the app must not hand it to the opener. The system opener remains outside the
app's control after handoff, so R6 guarantees verification immediately before
handoff rather than an impossible absolute identity guarantee after it.

Relink replaces the opaque bookmark only after the replacement exact-matches
the stored hash and byte count. A failed relink changes nothing. Existing
references created before R6, and all references in a restored backup, have
their bookmark bytes cleared and become relink-required before the workspace
is made active. Restore opens and scrubs the staging database in one SQLite
transaction, checkpoints and closes it successfully, then performs the active
workspace swap. If any staging scrub or checkpoint step fails, it discards that
staging copy and retains the prior active workspace.

Removing a reference clears its bookmark and records only redacted audit
metadata. Logical opportunity deletion must also clear every associated
bookmark; retained backup content is governed by ADR-001 and later R7 purge
work.

## Entitlement boundary

The existing app has `user-selected.read-write` and network-client
entitlements for already accepted workflows (export/backup and R5 public URL
checking). R6 does not expand them, request write access to document sources,
or use network. R6 file operations are read-only by policy and its Debug
acceptance evidence must inspect the signed entitlement set and prove no new
entitlement was introduced.

## Consequences

- A document source can be opened after relaunch without copying private files
  into the workspace.
- Restore and explicit removal revoke R6's stored access capability.
- Replacing a changed résumé is a new-reference workflow, not relink.
- Document editing, versioning, content extraction, preview, and external sync
  remain deferred.
