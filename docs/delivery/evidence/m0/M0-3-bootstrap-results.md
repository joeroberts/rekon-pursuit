# M0-3 Native Bootstrap Results

**State:** Ready for independent review; remote GitHub Actions evidence is **PENDING**. This record is not M0-3 acceptance and does not release M0-4, M1, or `M0-GATE-01`.

**Scope:** Native bootstrap, local validation, and pinned CI policy only. No tracker feature, persistence, integration, AI, network capability, user data, production credential, identity-based signing, notarization, stapling, DMG, or release publication is present.

**Evidence baseline:** `76a7a127fc8e9706bdf4f0832a7f10bb8be62c41` (`fix: redact tracked-secret diagnostics`). The Task 4 evidence commit is the commit containing this file and can be resolved with `git log -1 --format=%H -- docs/delivery/evidence/m0/M0-3-bootstrap-results.md`.

## Test-first workflow-policy evidence

The workflow-policy test was created and executed before the workflow existed.

| Phase | Command | Exit | Redacted result | SHA-256 |
| --- | --- | ---: | --- | --- |
| RED | `scripts/m0/test_workflow_policy.sh .` | `1` | `MISSING: workflow policy target: .github/workflows/m0-bootstrap.yml` | Command `747b84670d6483eee1810340589d6897fecd0a0f1c25921f99d5073ffed46739`; output `ebb3baf487b618c977d1871cca01671e5904abbb8623970c1b58f06d6dbd06c1` |
| GREEN | `scripts/m0/test_workflow_policy.sh .` | `0` | `M0 bootstrap workflow policy passed.` | Command `747b84670d6483eee1810340589d6897fecd0a0f1c25921f99d5073ffed46739`; output `700c99f35deec4b4eb46a03350847190efc68c9e00dc6c68720c83e6b2734253` |

The policy test requires:

- `macos-15-intel` for universal validation;
- `/Applications/Xcode_26.3.app/Contents/Developer`, Xcode `26.3`, and build `17C529`;
- static bootstrap checks in CI; the focused unit/UI checks remain local;
- `macos-14` with an explicit `arm64` assertion;
- a separate retained `m0-macos-14-runner-identity` artifact, created by the
  `macos-14-smoke` job itself, with its `ImageOS`, `ImageVersion`, OS, and
  architecture identity; and
- checksum-protected transfer and launch of the identity-free universal archive; and
- absence of `macos-latest`, explicit secret access, identity-based signing, notarization, stapling, release publication, and user-data integration configuration.

### Policy-scope remediation

The policy test now verifies that each required control is present in its
intended job, rather than accepting a matching literal elsewhere in the
workflow. In particular, `universal-validation` must own the pinned
`macos-15-intel` runner, exact Xcode path/version/build, policy regression,
and complete validator. `macos-14-smoke` must depend on that job and own the
`macos-14` runner, static validator, `arm64` assertion, archive download,
checksum, and archived-app launch. Comment-only lines are not accepted as
evidence.

The deterministic wrapper adds negative fixtures that swap the two runners
and separately move the smoke controls. Both must fail rather than passing
because the required text still appears in the other job.

| Check | Command | Exit | Output SHA-256 |
| --- | --- | ---: | --- |
| Job-scoped policy | `scripts/m0/test_workflow_policy.sh .` | `0` | `700c99f35deec4b4eb46a03350847190efc68c9e00dc6c68720c83e6b2734253` |
| Full deterministic wrapper, including the two swapped-job fixtures | `scripts/m0/test_validate_bootstrap.sh` | `0` | `5c34d27363a5e58a96e0b40993a99b995cd8b5992db5cfbd3f9d92808ffd93e6` |
| Complete local validator | `scripts/m0/validate_bootstrap.sh .` | `0` | Ephemeral raw output retained locally only; its final line was `Bootstrap local validation passed.` |

The wrapper output records both `misplaced-universal-requirements` and
`misplaced-smoke-requirements` as expected rejections. This is local evidence
only; it does not change the remote evidence state below.

The workflow uses read-only repository permission and disables persisted checkout credentials. Its cross-job artifact is the bootstrap app only, has one-day retention, contains no user data, and is not a release publication.

The two initial remote runs were cancelled before completion because their CI
configuration executed Xcode tests. The MVP CI gate is now deliberately
build-only: static configuration/secret/entitlement checks, an unsigned
universal archive, and the macOS 14 archive-launch smoke. Focused tests remain
local and do not create a hosted-CI coverage gate. A fresh remote run is
required before acceptance.

The macOS 14 runtime runner uses Xcode 15.4, which cannot open the
Xcode-26-authored project format. Project/entitlement configuration is therefore
validated on the pinned build runner; the macOS 14 runner validates its actual
compatibility responsibility by downloading and launching the built universal
archive.

## Local verification

Local verification ran from the staged Task 4 tree so the tracked-secret scan included the proposed workflow and policy test.

### Toolchain

Command output SHA-256: `107efc1aff1211e6ea3fb0299dce377ab9d32c23027c2956ae1b0b310643abd9`

```text
Xcode 26.6
Build version 17F113
SDK 26.5
Apple Swift version 6.3.3 (swiftlang-6.3.3.1.3 clang-2100.1.1.101)
Target: arm64-apple-macosx26.0
```

This identifies the local host toolchain. The project and archive checks independently enforce a macOS `14.0` minimum and both `arm64` and `x86_64` slices; the host target shown by `swift --version` is not used as deployment-target evidence.

### Complete validator

- Command: `scripts/m0/validate_bootstrap.sh .`
- Command SHA-256: `64f37c5d21f55f2f8354e3226f4462334af8e22b6caed9d83fcff2620e7e229d`
- Exit: `0`
- Redacted output SHA-256: `cfb577e3b847e5d47d3e89c8f2cce71d8c40edfbcd1ff4daffd84eecfb4e0773`

```text
Entitlement allowlist and runtime checks passed.
Tracked-secret scan passed.
M0 bootstrap workflow policy passed.
Entitlement allowlist and runtime checks passed.
Identity-free archive created outside the repository with Xcode signing disabled.
ARCHIVE_APP=<ephemeral-output-outside-repository>
Bootstrap local validation passed.
```

The redaction removed only ephemeral local paths, host identifiers, timestamps, and Xcode diagnostic timing. The underlying command also passed unit/UI tests, Release build, App Sandbox/Hardened Runtime inspection, the entitlement denylist, dependency and tracked-secret scans, identity-free archive checks, `arm64`/`x86_64` slice inspection, per-slice macOS `14.0` minimum inspection, and non-system dynamic-dependency rejection.

### Negative and regression wrapper

- Command: `scripts/m0/test_validate_bootstrap.sh`
- Command SHA-256: `3d6f7f7b81e7e4730a4db3916222e1273a219aeeae153d8de8b31488efc7bc01`
- Exit: `0`
- Output SHA-256: `d93084560ab8f4d91b6c1d87cc8f46ec8dd19bb1c39b84c8aa3e869913a75617`

```text
PASS: tracked-secret scanner reports only safe match metadata
PASS: unsupported-target rejected with the expected diagnostic
PASS: network-entitlement rejected with the expected diagnostic
PASS: Task-4 workflow policy passed
PASS: real-tree static validation passed after Task 4
PASS: real-tree local validation passed
M0 bootstrap validation tests passed.
```

## Remote GitHub Actions evidence

GitHub Actions run [`30074424747`](https://github.com/joeroberts/rekon-pursuit/actions/runs/30074424747) passed on commit `c73c744`. It is build-only: it does not run a hosted test suite.

| Required remote evidence | Result |
| --- | --- |
| Pinned universal build | Passed on `macos-15-intel`; Xcode `26.3`, build `17C529`; image `macos15` / `20260715.0340.1`; `x86_64` runner. |
| Static project/security checks | Passed. |
| Identity-free universal archive | Passed; retained archive SHA-256 `1149b038ec7404e7d2566d9f43876e12bacef748309b9c3b43267bae3dfd9309`. |
| macOS 14 runtime smoke | Passed on image `macos14` / `20260629.0180.1`, `arm64` runner. The downloaded archive checksum, universal-slice verification, and launch smoke all passed. |

The local Xcode `26.6` / CI Xcode `26.3` minor-version skew is now evidenced by the pinned remote build, and the macOS 14 archived-app launch has passed. A missing or mismatched runner image/toolchain remains a failed gate, not permission to float to `macos-latest` or change the macOS `14.0` deployment target.

## Boundaries and next gate

- Developer ID signing, notarization, stapling, DMG construction, and distribution remain M5-only.
- No signing certificate, provisioning profile, private key, secret expression, recovery material, or personal content is referenced by the workflow.
- Independent Code Review, QA/Test, Architect, Security/Privacy, TPM, and Delivery Manager decisions are still required.
- M0-3 is ready for its consolidated independent acceptance decision; M0-4, M1, and `M0-GATE-01` remain blocked until that decision is recorded.
