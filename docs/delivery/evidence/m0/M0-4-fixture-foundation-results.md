# M0-4 Deterministic Fixture Foundation Results

**State:** M0-4 accepted. This evidence releases `M0-GATE-01` for its final decision only; it does not release M1.

**Scope:** Test-target-only fixture catalog and fakes. No production persistence, crypto, network adapter, Keychain access, workspace, or feature behavior was added.

## Delivered foundation

- `RekonPursuitTests/Fixtures/fixture-manifest.json` is a version-1, synthetic-only catalog for all 22 M1-required fixture IDs. Each entry declares a stable ID, schema version, fixed clock/ID/random inputs, test-only fixture path, and expected result.
- `RekonPursuitTests/TestSupport.swift` provides a fixed clock, deterministic IDs/random bytes, unique temporary-root confinement, fault-mode declaration, fake Keychain states, recording default-deny HTTP, fake XPC, and a test-only lifecycle coordinator.
- Focused tests prove manifest completeness and rejection of duplicate/traversal metadata, default offline/no-XPC state, rejected HTTP recording, deterministic clock/IDs/random bytes, root confinement, callable filesystem-fault and Keychain-state seams, fixed locale/UTC, and teardown of only the harness root.

The manifest is a catalog/binding artifact, not an encryption, backup, recovery, migration, network, or database implementation. Runtime recovery inputs remain untracked and out of scope until their gated M1 work.

## Verification

| Check | Command | Result |
| --- | --- | --- |
| Focused test target | `xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -destination 'platform=macOS' -only-testing:RekonPursuitTests -derivedDataPath <unique-temp-root>` | Passed: 9 tests, 0 failures |
| Manifest shape/count | `jq -e '.schemaVersion == 1 and (.fixtures | length == 22) and ([.fixtures[].id] | unique | length == 22)' RekonPursuitTests/Fixtures/fixture-manifest.json` | Passed |
| Tracked-secret scan | `scripts/m0/check_tracked_secrets.sh .` | Passed |
| Diff whitespace | `git diff --check` | Passed |

## Acceptance record

QA/Test, Code Reviewer, Security/Privacy, Architect, TPM, and Delivery Manager independently accepted this test-only foundation. M1 remains blocked until `M0-GATE-01` is accepted.
