# Legacy Keychain Migration Design

**Status:** Product owner approved; Architect and Security/Privacy reviewed.

## Goal

Allow the signed, sandboxed Rekon Pursuit app to reopen the user's existing
encrypted workspace whose database key was created by an earlier identity-free,
non-sandboxed development build. This is a one-time corrective migration under
`UX-R1`, not a general recovery, export, backup, or workspace-reset feature.

## Chosen approach

Use a temporary, non-shipped migration build of the **same** Rekon Pursuit app
bundle ID (`com.rekonlabs.RekonPursuit`) and Personal Team (`2UA854NLX4`). It
has a compile-time-only migration entry point and no sandbox entitlement. The
ordinary product build stays sandboxed.

The migration build performs this bounded sequence in memory:

1. Read only the fixed legacy generic-password item using the existing service
   and primary account, without `kSecUseDataProtectionKeychain`.
2. Open the existing `workspace.sqlite` read-only with that key. A failed open
   stops the migration before any destination key is created.
3. Add a distinct data-protection Keychain item with the same service/account
   and `kSecUseDataProtectionKeychain = true`. It never updates an existing
   destination item.
4. Re-read the destination item through the data-protection query and reopen
   the same database read-only.
5. Exit with a redacted result. The user then launches the normal sandboxed
   app, which uses data-protection Keychain queries going forward.

The migration build and normal app must first prove the same app-identity
Keychain group in their signed entitlements. If that proof is absent, the
migration does not run. The fallback is an explicit separate architecture
decision about a shared Keychain group; it is not a reason to disable the
product sandbox.

## Invariants

- No key value enters a file, log, argument, clipboard, UI, activity event,
  backup, export, or diagnostic.
- The workspace database, WAL/SHM sidecars, and legacy Keychain item are never
  moved, overwritten, or deleted.
- Existing destination data-protection key material is never overwritten.
- Database verification is read-only: no schema migration, activity event,
  workspace creation, restore, or record mutation may occur.
- A failed preflight, missing legacy key, key/database mismatch, target-write
  failure, or failed target re-open aborts safely and retains all artifacts.
- The migration utility is not shipped and cannot be reached by the normal app
  UI or normal build configuration.

## Acceptance evidence

1. A disposable synthetic legacy-key workspace proves the signed sandboxed app
   cannot open it before migration and opens the same encrypted database after
   migration.
2. Focused negative tests prove every abort path leaves source key, target key,
   and database unchanged.
3. On the user workspace, the migration verifies the original database before
   target-key creation and the signed sandboxed app subsequently displays the
   existing opportunities without a recovery screen.
4. The user confirms the existing workspace appears correctly. The legacy
   Keychain item remains retained until an explicitly approved future cleanup;
   this task has no cleanup command.

## Out of scope

Portable recovery keys, backup/restore, data export, automatic cleanup,
multi-workspace support, Keychain Sharing for shipped components, schema/data
migration, and all UX-R2/RP-R6 work remain out of scope.
