# VD2-07x Save-panel leaf authority — Architecture gate

**Date:** 2026-08-01  
**Role:** Fresh independent Architect  
**Verdict:** **NEEDS CHANGE**

## Decision

ADR-005 supplies the correct authority boundary: a signed sandboxed export may
write only through the exact transient leaf URL returned by `NSSavePanel`; it
must not infer authority for, inspect, or bind the parent directory. The
proposed worker semantics preserve the encrypted, verified-write lifecycle and
the existing one-step Save-panel interaction.

This slice is not yet released because the implementation plan conflicts with
the controlling task brief in two bounded, test-execution-critical ways:

1. The plan permits a `WorkspaceViewModelTests.swift` change and selects that
   suite. The task brief makes `WorkspaceViewModel` inspection-only and
   expressly forbids editing its dirty test file. The plan must be amended to
   allow only `ProtectedExportWorker.swift` and
   `ProtectedExportTests.swift`, and to omit the ViewModel selector.
2. The plan names `RekonPursuitCoreTests/ProtectedExportTests`, but the current
   Xcode project has no `RekonPursuitCoreTests` test target. The source is
   compiled into the `RekonPursuitTests` target. Every RED, GREEN, and
   regression command in the plan must select
   `RekonPursuitTests/ProtectedExportTests` and retain the brief's separate
   result-bundle, resolved-test-list, zero-skip, and zero-expected-failure
   requirements.

These are documentation-only corrections. They do not authorize a fallback
test seam, a project-file edit, or a broader implementation scope. A fresh
architecture recheck is required after the plan has been corrected.

## Required leaf-authority contract after correction

| Boundary | Required implementation result |
| --- | --- |
| Save-panel authority | Keep the existing one-step native panel, `.rekonexport` filter, default filename, and directory-creation capability. Start and stop access only for the selected leaf URL; do not persist a bookmark or claim parent-directory authority. |
| Review | Validate the NFC final filename. Derive only an in-memory canonical destination digest from the lexically standardized selected leaf URL and NFC filename. Do not resolve, open, stat, bind, or otherwise inspect an ancestor. Remove the parent descriptor, device/inode, `fstatat`, parent comparison, and `openat` path from protected export. |
| Confirmation binding | Before staging or final creation, recompute the canonical leaf digest and confirmation fingerprint from the reviewed leaf URL. The fingerprint must bind protected-export type, fixed category, NFC filename, destination digest, and captured source revision. A locator/digest/fingerprint disagreement is `destinationChanged`; a revision disagreement is separately `sourceChanged`; neither creates output or verified evidence. |
| Final create and failures | Create only the selected leaf with `open(path, O_RDWR | O_CREAT | O_EXCL | O_NOFOLLOW, 0600)`. Capture `errno` immediately: `EEXIST`, including a terminal symlink or occupied leaf, is the unchanged no-overwrite result; another direct-leaf failure before descriptor assignment is the unchanged unavailable-destination result. After descriptor assignment, any later failure is the conservative may-remain result, with no retry, overwrite, or pathname deletion. |
| Verified-write chain | Preserve final-FD `fstat`, streaming, `fsync`, same-FD read-back, cryptographic verification, and then the single verified export/activity transaction. No verified event or `protected_export_verified` activity may precede successful read-back verification. |
| Redaction | The selected URL, raw path, POSIX error, security-scope outcome, recovery key, export payload, and key material remain absent from persistence, activity/audit evidence, diagnostics, and owner-facing copy. The event may retain only safe metadata already defined by the lifecycle contract, including the confirmation fingerprint and destination class. |

The existing worker is correctly identified as the source of the defect: it
currently opens and binds the parent, derives the digest from parent
device/inode plus filename, and uses `openat`. That implementation is not
approved to remain on the protected-export path once this slice is released.

## Entitlement and compatibility disposition

The current source entitlement file is unchanged in the working tree and
contains the existing sandbox plus
`com.apple.security.files.user-selected.read-write` entitlement. ADR-005,
the task brief, and the macOS compatibility matrix all require that exact
least-privilege entitlement to remain unchanged: no new entitlement, bookmark,
persistent security-scope material, preference, signing change, or project
change is authorized.

This static check is not a substitute for signed-artifact inspection. The
postimplementation gate must retain the required signed Debug build, strict
signature verification, and owner-native Save-panel smoke. The smoke may
record only redacted evidence and must prove a fresh selected Documents-child
leaf reaches review and produces a single nonempty verified export.

## ADR disposition

**No new ADR is required** for an implementation that conforms exactly to
ADR-005 and the corrected two-file task boundary.

A new ADR and fresh architecture review are required before any change that:

- restores a parent device/inode continuity claim or a parent-directory
  operation;
- adds a folder-picker/two-step interaction, directory-recursive authority,
  entitlement, bookmark, or persisted security-scope material;
- changes the canonicalization, digest/fingerprint inputs or binding, the
  direct-create flags/mode, no-overwrite semantics, or conservative
  post-descriptor result; or
- persists or displays a raw selected path, recovery material, export content,
  or other non-allowlisted evidence.

## Release condition

Do not dispatch an implementer on this gate. First correct the two plan
conflicts above, then obtain a fresh Architect recheck. Independent TPM, QA,
Security/privacy, and Delivery Manager releases remain required before a
fresh implementer may begin the bounded slice.
