# M0-1 — Toolchain Selection Record and Local Evidence

- **Task:** `M0-1 — Compatibility and toolchain decision evidence`
- **Recorded:** 2026-07-24 (UTC)
- **Evidence IDs:** `M0-EVID-01` through `M0-EVID-05`
- **Scope:** Selection and non-project environment evidence only. No Xcode project, application code, CI workflow, app entitlement file, dependency source, archive, binary, signing identity, or secret was created or inspected.
- **Result:** **Ready for independent review.** Full Xcode is selected locally and provides non-project evidence that its bundled Swift compiler accepts explicit `macOS 14.0` targets for both required architectures. This is selection/feasibility evidence only: it does not prove a project setting, universal archive, app launch, entitlement allowlist, CI execution, or macOS 14 runtime behavior. Those remain M0-3 evidence.

## Test-first evidence checklist and rejection rules

Before making a selection, M0-1 requires the following records and rejects any option that violates one of these rules:

| Check | M0-1 requirement / rejection rule | Current result |
| --- | --- | --- |
| Deployment target | Require `macOS 14.0`; reject any tool, package, or API that raises the target. | Policy selected; project proof is M0-3. |
| Architectures | Require both `arm64` and `x86_64`; reject any dependency/helper that lacks either slice. | Policy selected; archive/slice proof is M0-3. |
| Xcode and Swift | Require a full Xcode version/build and its bundled Swift compiler; reject Command Line Tools as a replacement. | Selected locally; see `M0-EVID-01` and `M0-EVID-05`. |
| CI runner | Require an explicit macOS 14 baseline run plus Intel coverage; reject an unpinned `macos-latest` label. | Selected policy: pinned `macos-15-intel` build job and pinned `macos-14` arm64 clean-device smoke job; see `M0-EVID-01`. |
| Entitlements | Start deny-by-default; reject any M1 choice that adds network, helpers, shared containers, automation, accessibility, media, contacts, calendar, location, JIT, or debug exceptions. | Policy selected; binary inspection is M0-3. |
| Encryption | Require a maintained SQLite-at-rest encryption candidate with no helper, telemetry, dynamic download, or entitlement expansion; reject stock SQLite as the production encrypted store. | Candidate selected pending M0-3 validation. |
| Licensing/security | Require a pinned source/revision, compatible license, reviewed transitive dependencies, and a reproducible scan; reject an unreviewed package. | Candidate inventory recorded; pin/scan evidence is M0-3. |
| Reproducibility | Require clean-checkout unsigned and CI-signed archive commands; reject credentials, certificates, team IDs, recovery material, or absolute user paths in evidence. | Command design recorded; execution is M0-3/M5. |

## M0-EVID-01 — selected policy record

| Selection area | Selection or constrained candidate | Status / owner |
| --- | --- | --- |
| Minimum operating system | `macOS 14.0` deployment target. | Selected policy; Architect. |
| Architectures | `arm64` and `x86_64`; no helper binary is allowed in M1. | Selected policy; Architect + TPM. |
| Local toolchain | Xcode `26.6` (`17F113`), selected through the full Xcode developer directory. Its current macOS SDK is `26.5` (`25F70`). | Selected local evidence; Release engineer. |
| Swift language mode | The selected Xcode bundles Apple Swift `6.3.3` (`swiftlang-6.3.3.1.3`, clang `2100.1.1.101`). M0-3 must explicitly set language mode and strict-concurrency policy in project build settings. | Selected local evidence; Architect. |
| CI runner policy | Build/inspection job: GitHub-hosted `macos-15-intel` with Xcode `26.3` (`17C529`) selected through `DEVELOPER_DIR`; baseline smoke job: GitHub-hosted `macos-14` arm64, running the archived universal artifact. `macos-latest` is prohibited. M0-3 must capture the exact runner-image and Xcode outputs and fail if the CI Xcode major differs from 26. Local Xcode 26.6 versus CI Xcode 26.3 is an explicit minor-version skew requiring M0-3 clean-build and macOS-14 smoke validation; it is not permission to silently change the deployment target. | Selected policy; Release engineer + QA. |
| App identity convention | Proposed only: `com.rekonlabs.rekonpursuit`; the actual identifier must be confirmed as available under the owner’s Apple Developer team before project creation. No team identifier is recorded. | Pending owner confirmation; Release engineer. |
| Versioning convention | `CFBundleShortVersionString` uses SemVer; `CFBundleVersion` is a monotonically increasing CI build number. | Selected policy; Release engineer. |
| Local archive policy | M0-3 will define a non-interactive unsigned clean-checkout archive command. A separate signed archive command receives its identity solely through CI secrets; notarization/DMG evidence is M5 only. | Selected policy; Release engineer. |

GitHub’s current hosted-runner reference identifies `macos-14` as arm64 and `macos-15-intel` as Intel. The current runner-image inventories show an Xcode 26 series installation on the macOS 15 Intel image, while the macOS 14 image provides the required baseline runtime. Source checked 2026-07-24: [GitHub-hosted runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners) and [runner-image inventories](https://github.com/actions/runner-images/tree/main/images/macos). The macOS 14 image is scheduled for deprecation, so M0-3 must record the image version and escalate a replacement baseline plan before the announced retirement date; it may not silently substitute a later runtime.

## M0-EVID-02 — macOS 14 and universal-build feasibility assessment

The selected Xcode 26.6 includes the macOS 26.5 SDK/platform and its bundled Swift compiler accepts both `arm64-apple-macosx14.0` and `x86_64-apple-macosx14.0` target triples. That directly disproves the earlier concern that the compiler's *default* host target (`arm64-apple-macosx26.0`) would silently raise the approved deployment baseline: the target is explicit and accepted for both slices.

The evidence boundary remains explicit:

- This is compiler/SDK feasibility, not a claim that the app will run correctly on macOS 14.0.
- M0-3 must set `MACOSX_DEPLOYMENT_TARGET=14.0`, build and inspect a universal archive, run the macOS 14 arm64 clean-device smoke, and inspect all generated entitlements.
- M0-1 cannot claim an archive, executable slice, project build-setting result, signed output, or CI execution result.

## M0-EVID-03 — dependency and encryption decision inventory

| Area | Candidate / decision | Version or revision | Source and license | Entitlement / dependency impact | Required M0-3 validation before acceptance |
| --- | --- | --- | --- | --- | --- |
| SQLite API boundary | Internal, narrow Swift adapter over the SQLite C API exposed by the selected SQLCipher build; parameterized SQL only. No ORM or third-party Swift wrapper is approved. | No source added in M0-1. | Adapter is Rekon Pursuit code; SQLCipher supplies the SQLite-compatible C API. | No network, helper, telemetry, or entitlement impact. | Deterministic transaction, migration, foreign-key, WAL, FTS5, and fault-injection tests. |
| Encrypted SQLite | **Selected candidate:** SQLCipher Community Edition `v4.17.0` at release commit `810db22`, built as a signed universal component linked with Apple CommonCrypto/Security.framework. The exact immutable source hash, build recipe, and binary provenance must be captured before the dependency is added. | `v4.17.0` / `810db22` (candidate; not yet integrated). | <https://github.com/sqlcipher/sqlcipher>; BSD-3-Clause. Release record checked 2026-07-24: <https://github.com/sqlcipher/sqlcipher/releases>. | No additional app entitlement or helper is permitted. The component must be static/signed and must not download executable code. | Build/inspect both architectures; stock SQLite fails to read database; correct key opens; wrong/missing key fails; WAL, migration, FTS5, backup/restore, corruption, and clean uninstall/reinstall tests. |
| Cryptographic provider | Apple CommonCrypto/Security.framework is the only proposed provider for the SQLCipher build. Do not introduce OpenSSL or a custom crypto implementation without an ADR and dependency review. | Platform-provided; exact SDK evidence blocked on full Xcode. | Apple platform framework; no third-party crypto dependency selected. | No entitlement impact. | Build/link proof with selected Xcode, SQLCipher configuration review, tamper/redaction/recovery contract tests. |
| Test framework | XCTest/XCUITest supplied by the accepted Xcode; no external test framework selected. | Blocked on exact Xcode. | Apple platform tooling. | No entitlement impact. | M0-3 placeholder test target and deterministic fake seams. |
| Linting / formatting / scans | No formatter, linter, dependency scanner, or secret scanner is selected in M0-1 because the local host lacks the required tools and no CI workflow exists. M0-3 must obtain Architect and Security/Privacy approval for version-pinned tools and record their licenses, hashes, transitive dependencies, and false-positive handling before enabling them. | Not selected. | Not applicable. | Must not require privileged helper, network client entitlement, or runtime telemetry. | CI execution and redacted reports in M0-3. |

Why SQLCipher remains conditional: its official repository describes a SQLite fork with full-database encryption, requires codec/temp-store configuration and a supported cryptographic provider, and states that platform-specific verification is still necessary. This record selects the candidate and a validation plan; it does **not** assert encryption implementation evidence.

## M0-EVID-04 — M1 entitlement and CI evidence policy

M1 must have exactly this deny-by-default policy:

- Required later in M1 and subject to M0-3 archive inspection: App Sandbox and Hardened Runtime; `get-task-allow=false` in release configuration.
- Prohibited in M1: network client/server, app groups/shared containers, Apple Events/automation, accessibility, camera, microphone, contacts, calendars, reminders, location, privileged helpers, system extensions, JIT, unsigned executable memory, DYLD/debug exceptions, and Keychain Sharing.
- No external service, package download at runtime, telemetry, or production credential is permitted in M1.
- M0-3 CI design must perform a clean-checkout build from empty derived data; deterministic tests with default-deny HTTP and a fake Keychain; binary/entitlement inspection; dependency and secret scans; redacted retained diagnostics; and a macOS 14.0 clean-device smoke. Signed/notarized DMG work remains M5 only.

## M0-EVID-05 — redacted local command record

The following is the complete relevant local evidence captured on 2026-07-24 after full Xcode was installed and selected. User paths, identifiers, credentials, certificates, and secrets are omitted. The earlier Command Line Tools blocker record is superseded by this record.

```text
Host OS: macOS 26.5.2 (build 25F84)
Host CPU: arm64
Active developer directory: <XcodeDeveloperDir>

$ xcodebuild -version
Xcode 26.6
Build version 17F113

$ xcrun swift --version
swift-driver version: 1.148.6
Apple Swift version 6.3.3 (swiftlang-6.3.3.1.3 clang-2100.1.1.101)
Target: arm64-apple-macosx26.0

$ xcodebuild -showsdks
macOS SDKs:
    macOS 26.5    -sdk macosx26.5

$ xcrun --sdk macosx --show-sdk-platform-version
26.5

$ xcrun --sdk macosx --show-sdk-version
26.5

$ xcrun swiftc -target arm64-apple-macosx14.0 -print-target-info
target.triple: arm64-apple-macosx14.0
target.arch: arm64

$ xcrun swiftc -target x86_64-apple-macosx14.0 -print-target-info
target.triple: x86_64-apple-macosx14.0
target.arch: x86_64

$ printf 'import Foundation\n' | xcrun swiftc -target <each-required-triple> -typecheck -
exit status: 0 for arm64-apple-macosx14.0 and x86_64-apple-macosx14.0

$ xcrun clang -arch <each-required-architecture> -mmacosx-version-min=14.0 -x c -fsyntax-only -
exit status: 0 for arm64 and x86_64
```

This evidence is reproducible with the commands listed in the task plan. The `swift --version` default target is informative only: it reflects the host SDK default and does not change the required `macOS 14.0` deployment target. The explicit-target commands above are the relevant feasibility evidence.

## Blocker, completion condition, and follow-up

**Evidence commits:** baseline repository commit is `ebe521237813fe94df4c38b643de052bd308c799` (`docs: establish M0 readiness package`); this M0-1 evidence record is committed as `04129c234d8410b118fa37375256fc94cd19f8a9` (`docs: pin M0 toolchain evidence`); its traceability correction is `632dd18` (`docs: reconcile M0 evidence traceability`). All later evidence and reviews must identify their commit SHA relative to this baseline.

**Open evidence limitations:** The owner has not yet confirmed the proposed bundle identifier under an Apple Developer team. CI-runner image version/Xcode build output is selected for capture but cannot exist until M0-3 creates the permitted CI workflow. Neither limitation authorizes an M0-1 scope expansion.

**M0-1 completion condition:** independent Architect, QA/Test, Security/Privacy, TPM, and Delivery Manager reviewers must accept this updated evidence record and selected policy. M0-2 may be considered only after that acceptance. Do not create an Xcode project, CI workflow, or application code as part of M0-1; those are M0-3 work.
