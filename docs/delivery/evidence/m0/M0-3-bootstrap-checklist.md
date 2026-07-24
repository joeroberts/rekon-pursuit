# M0-3 Native Bootstrap Evidence Checklist

**Task status:** Evidence complete; independent acceptance pending. The project, app, CI workflow, and unsigned archive exist. Identity-based signing remains intentionally absent and M5-only.

**Scope boundary:** M0-3 may create only the native bootstrap, test targets, validation scripts, a pinned CI workflow, and redacted evidence. It must not add tracker functionality, persistence, integrations, AI, network behavior, user data, production credentials, signing, notarization, stapling, or DMG delivery. M0-4 and M1 stay blocked until M0-3 is independently accepted.

## Required evidence

| Check | Required result | Evidence command or artifact | State |
| --- | --- | --- | --- |
| Bootstrap artifact presence | `RekonPursuit.xcodeproj`, its build settings, and `.github/workflows/m0-bootstrap.yml` exist before the final M0-3 run. | `scripts/m0/test_validate_bootstrap.sh` | Verified |
| macOS target | `MACOSX_DEPLOYMENT_TARGET` is explicitly `14.0`; no bootstrap dependency requires a later minimum. | `xcodebuild -showBuildSettings` captured by the validation harness | Verified |
| Architectures | App archive contains both `arm64` and `x86_64`. | `lipo -archs` on the unsigned archive product | Verified |
| Local test proof | Unit and UI bootstrap assertions pass on the local accepted Xcode toolchain. | `xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -destination 'platform=macOS'` | Verified locally |
| Unsigned archive | A clean checkout produces an archive with `CODE_SIGNING_ALLOWED=NO`; no signing identity, certificate, profile, or private key is used. | `scripts/m0/build_unsigned_archive.sh` and redacted output | Verified |
| Entitlement denylist | App Sandbox and Hardened Runtime are present. Network client/server, app groups/shared containers, Apple Events/automation, accessibility, camera, microphone, contacts, calendars, reminders, location, privileged helpers, system extensions, JIT, unsigned executable memory, DYLD/debug exceptions, and Keychain Sharing are absent. | `scripts/m0/check_entitlements.sh` plus `codesign -d --entitlements :-` output | Verified |
| Dependency review | Bootstrap has no unapproved dependencies; any future package/source entry is identified for architecture, license, security, and minimum-OS review. | Validation harness dependency scan | Verified |
| Secret scan | No tracked secrets, recovery material, certificates, provisioning profiles, user data, or production credentials appear in the repository or CI configuration. | `scripts/m0/check_tracked_secrets.sh` | Verified |
| Pinned CI policy | Universal build/inspection uses `macos-15-intel` with Xcode `26.3` (`17C529`); baseline smoke uses `macos-14` arm64. The workflow must not use `macos-latest`. | `.github/workflows/m0-bootstrap.yml` and remote run evidence | Verified in run `30074424747` |
| M5 signing boundary | Signing, notarization, stapling, and DMG packaging are not performed or claimed by M0-3. They are M5-only release gates. | This checklist, CI policy review, and M5 release evidence | Required boundary |

## Task-1 expected-red evidence

Before Tasks 2–4 create the permitted artifacts, run:

```sh
scripts/m0/test_validate_bootstrap.sh
```

The command must exit nonzero and report all three absent prerequisites: the Xcode project, the CI workflow, and the project build-settings file. This expected failure proves the bootstrap validator is not silently treating an empty repository as ready; it is not acceptance evidence for M0-3.

## Completion record requirements

The final M0-3 results record must link the committed validation scripts and workflow, the exact commands and redacted outputs, local toolchain identity, CI run identifiers/image identity, archive architecture output, test result, entitlement/dependency/secret results, residual local/CI-version-skew risk, and independent Code Review, QA/Test, Architect, Security/Privacy, TPM, and Delivery Manager decisions. It must explicitly retain the M5-only signing boundary.
