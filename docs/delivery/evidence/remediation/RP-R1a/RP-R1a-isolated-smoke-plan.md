# RP-R1a isolated runtime smoke plan

**Status:** Prepared for independent QA execution; not yet run by the implementer.

## Isolation boundary

- Build a temporary app target with a distinct, compiled bundle identifier and a
  distinct, compiled Keychain-service constant before launch.
- Use a fresh temporary sandbox container and temporary workspace namespace.
- Verify the built app entitlement contains `com.apple.security.app-sandbox`.
- Record only the temporary namespace ID, App Sandbox result, and temporary
  container assertion. Do not read the production workspace or Keychain
  namespace; isolation follows from the compiled temporary bundle identity.

No absolute path, Keychain account metadata, key bytes, CSV contents, journal
attempt ID, or fixture content belongs in the smoke record.

## Steps and expected results

1. Launch the temporary app with no workspace artifacts or keys. The default
   page shows **Create local workspace** and explains that CSV import is not
   available yet.
2. Create the workspace. Without relaunch, the workspace gate disappears and
   the CSV page enables **Choose CSV file**.
3. Preview a synthetic CSV fixture. Confirm a preview is visible without
   importing it.
4. Repeat launch using fixture states representing no database/primary key,
   no database/pending key, database/no key, database/pending key, and
   database/both keys. Each state shows recovery-required and never offers
   replacement or automatically promotes/deletes a key.
5. Record the redacted before/after booleans and entitlement result. Remove
   only the temporary sandbox namespace after independent QA has accepted the
   evidence.

## Scope boundary

This smoke does not assess the later navigation-shell visual redesign, CSV
column mapping, lifecycle portability, or any user workspace.
