# RP-R7a-1 — Recovery setup and legacy-flow containment

**State:** Proposed — not released for implementation  
**Depends on:** `RP-R6` accepted and the R7a recovery-design gate  
**Blocks:** Portable archive, restore, encrypted export, and warned unencrypted export work

## User-visible outcome

Settings has a truthful **Recovery & export** state. A user can set up a
user-held recovery key, understand that it cannot be reset, and see that
portable recovery has not yet created any backup. The app no longer presents
the old same-Mac backup, replace-in-place restore, or direct CSV-export routes
as usable recovery/export commands.

## Approved boundary

- Generate one 256-bit recovery key with platform cryptographic randomness.
  Show grouped Base32 plus checksum exactly once; do not write it to the
  clipboard, a file, activity, diagnostics, fixtures, database, or Keychain.
- Require complete re-entry before enrollment. Store only a versioned,
  one-way enrollment fingerprint in the encrypted workspace store and
  non-secret enrollment state. Cancel, mismatch, malformed input, invalid
  checksum, or persistence failure creates no partial or replacement record:
  it leaves a previously unenrolled workspace disabled and a prior enrollment
  unchanged.
- Key material exists only in operation memory. Creating a later archive or
  encrypted export will require a fresh key entry; neither operation is part
  of this task.
- Withdraw or disable reachable UI actions for current same-Mac backup,
  replace-active-workspace restore, and direct unencrypted CSV export. Preserve
  existing files, database data, and legacy backup material. Do not invoke,
  migrate, remove, or overwrite them.
- Settings must state that portable recovery has been set up but no portable
  backup exists. It must never imply that enrollment itself created a backup,
  export, restore point, expiry record, or recovery guarantee.
- Operate only on a ready active workspace. A preserved legacy recovery folder
  is not opened, selected, copied, changed, or otherwise accessed by this
  task.
- Record only redacted local outcome metadata (enrollment enabled/failed and
  reason category). It must contain no recovery key, fingerprint, raw path, or
  user-entered content.

## Explicitly excluded

- Archive, catalogue, manifest, envelope, restore, workspace switch, expiry
  display, deletion disclosure, purge, encrypted-export file, and unencrypted
  export file creation.
- Any Keychain/database-key export, cloud recovery, reset/escrow path, or
  access to the preserved legacy workspace.

## Interface contract reserved for the next slice

The later archive/envelope task must use a canonical header commitment that
includes archive ID, format version, **per-archive salt**, manifest hash,
signing-public-key fingerprint, archive checksum, and fixed header fields. It
excludes envelope and signature fields to avoid circular encoding. That
commitment is authenticated associated data for recovery-key envelope unwrap;
the later signature preimage covers the finalized envelope and all canonical
header fields except its own signature. This task does not create it or any
archive.

## Focused acceptance evidence

- Recovery setup succeeds only after generated-key re-entry and remains enabled
  after relaunch without retaining the raw key.
- Cancellation, mismatch, malformed/checksum-invalid re-entry, and injected
  persistence failure create no newly enabled or partial/replacement record;
  an existing enrollment remains enabled and unchanged.
- The encrypted workspace store may retain only the opaque versioned
  enrollment fingerprint. Activity, diagnostics, fixtures, UI copy,
  clipboard/files, manifests, and exports contain neither that fingerprint nor
  any raw key/Base32 display value; no surface contains a path.
- The old same-Mac backup, replace-in-place restore, and direct CSV-export
  controls are unreachable from the active UI; existing local material remains
  untouched.
- The task neither writes an archive/export nor changes the active workspace.
- A focused macOS build and product-owner smoke cover Settings → set up key →
  re-enter → relaunch → Recovery & export state.

## Release rule

Planning, Architect/Security, TPM, QA, and Delivery Manager must approve this
brief before it moves from Next up to In progress. A fresh implementer delivers
only this boundary. Code review, QA, Architect/Security, and product-owner
hands-on acceptance are required before the next R7a archive task can be
released.
