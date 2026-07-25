# RP-R1a isolated runtime smoke — implementer evidence

**Status:** Complete — isolation preflight and the required visible UI workflow
passed.

## Superseded evidence

The prior pass claims were unsupported and are superseded. No prior claim is
used as evidence for workspace creation, CSV reachability, or CSV preview.

## 2026-07-25 isolated preflight

**Temporary namespace:** `com.rekonlabs.RekonPursuit.RPR1aSmoke`

| Check | Result |
| --- | --- |
| Temporary app compiled with its distinct namespace | Pass |
| App sandbox entitlement present | Pass |
| Fresh temporary sandbox container present | Pass |
| Temporary app uses a compiled namespace distinct from production | Pass |
| Harness reads or modifies production workspace/Keychain namespaces | No |

The harness records no production file, Keychain, path, fingerprint, account,
key, or fixture-content data. Isolation follows from the distinct compiled
bundle identity, derived Keychain service, and App Sandbox container.

## Required UI workflow

**Result: Passed by direct user observation on 2026-07-25.** Desktop Computer
Use repeatedly failed to read the isolated temporary app after launch, so it
did not provide the observation. The product owner completed the visible
sequence in the current native-picker temporary app and confirmed the import
preview:

1. On the default workspace gate, select **Create local workspace**.
2. **Import CSV** → **Choose CSV file…**.
3. Select the synthetic `r1a-smoke-import.csv` fixture bundled with the repository.
4. Observe the import preview.

No screenshot or filesystem/Keychain identifier is retained from this manual
observation. The preflight's redacted isolation checks passed before launch;
the smoke is user-observed evidence, not an automation claim.
