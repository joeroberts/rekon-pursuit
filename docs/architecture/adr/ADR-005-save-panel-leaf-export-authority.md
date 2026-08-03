# ADR-005: Save-panel leaf authority for protected exports

- **Status:** Accepted amendment
- **Date:** 2026-08-01
- **Decision owner:** Architect
- **Scope:** The signed macOS protected-export destination selected through `NSSavePanel`.
- **Amends:** The protected-export destination-binding paragraph in `docs/superpowers/specs/2026-07-27-r7a-encrypted-export-design.md`.

## Context

The protected-export UI uses `NSSavePanel` to obtain a new
`.rekonexport` file URL. In a signed sandboxed build, macOS grants authority
for that selected save target; it does not grant recursive authority for the
target's parent directory. The previous frozen implementation nevertheless
opened the parent directory, bound it by device/inode, and created the leaf
with `openat`. That mismatch rejects a valid native Save-panel selection before
the review step.

The existing `com.apple.security.files.user-selected.read-write` entitlement
is the intended least-privilege authority. This amendment does not add an
entitlement, persist a bookmark, expand to directory-recursive access, or
change the Save-panel workflow.

## Decision

Protected export uses the exact, transient file URL returned by
`NSSavePanel` as its sole external-write authority.

1. Review validates the NFC final filename and derives an in-memory
   canonical-leaf digest from the UTF-8 bytes of
   `RekonPursuit/export/leaf-destination/v2\0` followed by the lexically
   standardized, NFC selected-leaf path. That path includes the NFC filename;
   the filename is also bound separately by the confirmation fingerprint. It
   does not resolve or inspect ancestors.
2. The confirmation fingerprint continues to bind protected export type,
   fixed category, filename, canonical destination digest, and captured source
   revision. The selected URL and its raw path are never persisted or placed in
   activity/audit evidence.
3. Confirm recomputes the digest and fingerprint from the reviewed leaf URL
   before any final write. A changed reviewed locator/fingerprint requires a
   new review. Source-revision changes remain a separate pre-write rejection.
4. The final output is created only through the selected leaf path using
   `O_RDWR | O_CREAT | O_EXCL | O_NOFOLLOW` with mode `0600`. `EEXIST`,
   including an occupied or terminal-symlink leaf, remains a no-overwrite
   rejection. A direct selected-leaf failure before an output descriptor exists
   is unavailable-destination feedback; after one exists it remains the
   conservative potentially-unusable-output result.
5. Staging, final-FD `fstat`, streaming write, `fsync`, same-FD read-back,
   encrypted-package verification, and only-then verified export/activity
   evidence are unchanged. A later failure never retries, overwrites, or
   path-deletes the selected name.

## Non-goals and explicit limitation

This decision does not claim continuity of the selected parent directory's
device/inode between review and confirm. A one-step `NSSavePanel` selection
cannot prove that property. If a parent replacement or permission change makes
the selected leaf unusable, the operation fails truthfully before output
creation; if exclusive leaf creation succeeds, it proves only the selected
leaf was newly created at confirmation time.

A two-step folder chooser is not introduced. It would be required only to
restore parent-directory identity continuity by acquiring distinct folder
authority, which is a broader interaction and privacy-boundary decision.

## Consequences

- A native Save-panel choice in a normal user-selected Documents folder can
  proceed to review and confirmation without broader file access.
- The previous parent-device/inode review binding and `open(parent)` /
  `fstatat` / `openat` sequence are removed from this path rather than being
  represented as a capability the sandbox did not grant.
- Automated tests prove direct-leaf no-overwrite, terminal-symlink rejection,
  locator/fingerprint substitution rejection, source-revision rejection,
  post-create conservative handling, and verified-evidence ordering. A signed
  native Save-panel smoke is mandatory because unit tests cannot mint the
  operating system's Save-panel authorization.
