# VD2-07x Save-panel leaf authority — security/privacy re-gate

**Date:** 2026-08-01  
**Role:** Fresh independent security/privacy verifier  
**Verdict:** **ACCEPT** — pre-implementation release is security/privacy
appropriate for this exact bounded slice. This accepts the corrected scope and
required verification contract; it is not implementation or owner-smoke
acceptance.

## Scope and evidence reviewed

Read ADR-005, the current leaf-authority implementation plan and task brief,
the prior security/privacy gate, the protected-export feedback hunk-isolation
and Delivery completion records, the current protected-export worker and its
tests/seams, the inspection-only ViewModel boundary, and the declared signing
entitlements. No production or test source was changed and no test was run.

The prior security gate's two blockers are resolved in the controlling brief:

1. The obsolete parent-authority test cleanup is now explicitly confined to
   the released three-path boundary rather than requiring the invalid parent
   implementation to remain.
2. The signed owner smoke now requires effective-entitlement readback from the
   built application, with redacted evidence only.

## Re-gate assessment

| Security/privacy boundary | Evidence and required result | Disposition |
| --- | --- | --- |
| Exact atomic three-path cleanup | The task brief authorizes only `RekonPursuitCore/Workspace/ProtectedExportWorker.swift`, `RekonPursuitCoreTests/ProtectedExportTests.swift`, and the clean protected-export island at `RekonPursuitTests/WorkspaceViewModelTests.swift:706-860`. The current dirty-file diff has no hunk at that island. The scope-reconciliation/hunk-isolation records establish patch-only staging and keep `RekonPursuit/WorkspaceViewModel.swift` inspection-only. Within that one test island, deleting the two obsolete parent-review assertions and renaming/reasserting the pre-descriptor confirmation contract is acceptable. | **Accept.** The cleanup must be atomic with removal of every parent fault, parent expectation, and parent-authority branch from the three authorized paths. Any overlap with a pre-existing hunk, extra ViewModel test hunk, or source/UI/Store change returns the work to Delivery isolation review. |
| Least-privilege Save-panel authority | ADR-005 makes the exact transient leaf returned by `NSSavePanel` the sole external-write authority. Review derives the in-memory digest from the lexically standardized leaf URL and NFC filename without resolving, opening, statting, binding, or otherwise inspecting an ancestor. Confirmation recomputes that digest and its fingerprint before staging or final creation. | **Accept.** The fingerprint remains bound to protected-export type, fixed category, NFC filename, canonical leaf digest, and captured source revision. Locator, digest, or fingerprint substitution is `destinationChanged`; revision change remains `sourceChanged`; neither may create output or verified evidence. |
| Exclusive no-overwrite and truthful failure handling | The selected leaf alone is created with `O_RDWR | O_CREAT | O_EXCL | O_NOFOLLOW` and mode `0600`. Immediate `errno` capture preserves `EEXIST`, including a terminal symlink or occupied leaf, as no-overwrite. A non-`EEXIST` direct-leaf failure before descriptor assignment is unavailable-destination feedback; every failure after descriptor assignment is the conservative may-remain result. | **Accept.** The focused tests must preserve regular-file, terminal-symlink, and after-review sentinel bytes; prove no output/evidence for the pre-descriptor failure; and prove output-may-remain with zero verified evidence for a post-descriptor failure. There is no retry, overwrite, or selected-path deletion. Cleanup remains limited to the existing app-owned temporary package. |
| Encryption and evidence ordering | ADR-005 retains final-FD `fstat`, streaming, `fsync`, same-FD read-back, and encrypted-package verification before the single verified export/activity transaction. The task brief explicitly requires a default-`.none`, worker-local post-verification/pre-evidence fault. | **Accept.** That dedicated test must independently verify the retained output, then assert the conservative failure and zero `protected_export_events`/`protected_export_verified` activity. It is the required proof that verification alone cannot cause persisted success evidence. The plan's high-level success coverage is constrained by this more-specific brief requirement. |
| Privacy and persistence | The brief forbids bookmarks, persistent security-scope material, preferences, path persistence, raw-path activity/audit evidence, keys, export contents, schema changes, and new UI/Store/ViewModel APIs. Current protected-export evidence stores safe fixed metadata and the confirmation fingerprint, not the selected URL/path. | **Accept.** The selected URL and raw path, POSIX error, security-scope result, recovery key, key material, package data, and fault state must remain absent from persistence, activity/audit evidence, diagnostics, and owner-smoke records. No selected-destination pathname cleanup is permitted after final creation begins. |
| Entitlement and signed-artifact assurance | `RekonPursuit/RekonPursuit.entitlements` already declares App Sandbox and `com.apple.security.files.user-selected.read-write`; Debug and Release both point to that file. The brief prohibits entitlement/signing edits and requires a signed Debug build, strict signature verification, and `codesign -d --entitlements :-` on the built app. | **Accept.** Source inspection is not a substitute for effective-entitlement verification. The owner smoke must record only the redacted assertion that App Sandbox and the existing user-selected read/write authority are effective, with no task-related entitlement delta; it must not retain the entitlement dump, key, path, export, or database. |

## Required implementation and postimplementation evidence

- Preserve separate RED, GREEN, and regression result bundles. Each selected
  test must execute once with zero skips and expected failures; RED may fail
  only on the absent leaf-authority behavior.
- Perform the brief's signed owner-native smoke in a fresh local workspace and
  freshly created Documents child folder. It must demonstrate a selected new
  leaf reaches filename-only review and yields one nonempty verified export,
  without a parent-continuity claim or sensitive evidence disclosure.
- After implementation, retain independent code review, QA/test verification,
  architecture verification, this role's postimplementation verification, and
  Delivery completion review. No implementer may self-approve those gates.

## Residual limitation

As ADR-005 states, this one-step Save-panel design deliberately does not prove
parent-directory device/inode continuity between review and confirmation. A
parent replacement or permission loss can therefore make the selected leaf
unusable and must fail truthfully; it does not justify parent traversal,
folder-recursive authority, a bookmark, an entitlement change, or a pathname
cleanup fallback.

## Release disposition

**ACCEPT.** The corrected three-path test cleanup removes the prior
scope/security contradiction without expanding filesystem authority or
persistence. A fresh implementer may be released only under the task brief's
patch-isolation, TDD, redaction, signed-entitlement-readback, and owner-smoke
requirements. Any deviation requires a fresh Architecture and Security/privacy
review before implementation proceeds.
