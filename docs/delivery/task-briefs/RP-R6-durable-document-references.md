# RP-R6 — Durable document references

**State:** In progress — released after independent pre-implementation gate  
**Depends on:** `UX-R2` accepted  
**Blocks:** `RP-R7a`, `RP-R8`, and `RP-R9`

## User-visible outcome

An opportunity can retain one or more local references to the user's PDF or DOCX
files. Rekon Pursuit can open each exact file after relaunch. If it has moved,
is unavailable, or access is denied, the reference is marked **Relink
required** and the user can choose a replacement. A replacement becomes the
same reference only when its SHA-256 and byte count match the original.

## Approved boundary

- Persist only opaque, security-scoped bookmark data, existing metadata, and a
  local availability state. The app does not persist a readable source path.
- On attach and relink, reject a file over 25 MB before creating a bookmark;
  scope access only long enough to validate type, size, hash, and byte count,
  then store the bookmark and release the temporary
  scope.
- Open is explicit user action. It resolves one bookmark, starts access, checks
  type/size/hash, opens the file through the workspace, and then closes access.
- A mismatch, stale bookmark, missing file, or unavailable access never opens a
  substitute and never changes the original hash. It records a redacted local
  state and prompts relink.
- Relink requires an exact content match. Replacing a document with a different
  résumé or cover letter is intentionally out of scope for this task; attach a
  new reference instead.
- An explicit **Remove reference** action clears its bookmark before removing
  the reference from active use. Logical opportunity deletion clears associated
  bookmark bytes as well.
- The existing encrypted-backup restore boundary must clear every restored
  bookmark and require relink in the staging database, checkpoint and close it,
  then swap it into place. On a scrub/checkpoint failure the staging copy is
  discarded and the prior workspace remains active. This applies even on the
  same Mac; no restored bookmark is trusted.
- No source-file deletion, copy, edit, parse, preview, text extraction, upload,
  cloud connection, or document version management is part of R6. Removing a
  local *reference* is required and never deletes its source file.

## Implementation shape

1. Add an additive migration for bookmark data and availability state on
   `document_references`; preserve every existing reference as
   `relinkRequired` rather than fabricating access.
2. Introduce a small injected bookmark service that owns bookmark creation,
   resolution, temporary scope leases, hash verification, and external-file
   opening. It must make path handling testable without touching a live user
   document.
3. Add store commands for attaching a bookmark, recording an availability
   transition, and marking restored references relink-required. Call that
   operation in the staged restore database before the restored workspace is
   made active. The scrub transaction must checkpoint and close successfully
   before the swap; failures discard staging. Activity events remain redacted:
   no source path or bookmark bytes.
4. Replace the compact Documents menu's metadata-only behavior with per-item
   status and explicit **Open** / **Relink** / **Remove** actions. The existing
   attach and final-sent action remain.
5. Add `ADR-004` and reconcile the compatibility matrix: R6 is read-only by
   operation policy, introduces no entitlement, and verifies the existing signed
   entitlement set rather than removing capabilities already required by R5 and
   export/backup workflows.

## Focused evidence

- PDF and DOCX attach persist a bookmark and reopen after store/app relaunch.
- A 25 MB + 1 byte file is rejected before bookmark creation or full file read.
- Allowed PDF/DOCX fixtures, a renamed/wrong-type input, and symlink or special
  file inputs are rejected or accepted deterministically before persistence.
- A missing, stale, denied, or moved source never opens and becomes relink
  required without replacing metadata.
- Relink accepts only the matching hash and byte count; a different document is
  rejected without mutation.
- Legacy rows and backup-restored rows are relink-required and cannot show or
  invoke Open before a matching relink.
- Restore failure injection proves the active workspace is never a restored
  database with a non-null bookmark.
- The open operation runs only while its lease is active and closes the lease on
  success and failure.
- Removing a reference and logically deleting its opportunity clear bookmark
  bytes; status/activity/error surfaces contain no path or bookmark bytes.
- Activity/audit output contains no external path or bookmark data.
- Debug macOS build and one product-owner hands-on test cover attach → relaunch
  → open, then moved-file → relink-required → matching relink.

## Release rule

Planning, Architect, TPM, QA, Delivery Manager, and Security/Privacy must
approve this brief, ADR-004, and the compatibility-matrix reconciliation before
the dashboard moves R6 from Next up to In progress.
After implementation, a fresh code reviewer, QA verifier, Architect, and
Security/Privacy verifier review the delivered slice before product-owner
hands-on acceptance. Only then may Delivery record acceptance and move a
successor. Do not release any recovery-key, export, AI-ledger, or Settings work.
