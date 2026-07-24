# M0-3 Native Bootstrap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` to implement this plan task-by-task.

**Goal:** Build only the native macOS bootstrap and reproducible CI evidence required before M1.

**Architecture:** A minimal SwiftUI app and test targets provide a local-only status placeholder. Shell validation scripts inspect the project, archive, entitlements, architectures, dependencies, and tracked secrets; pinned CI invokes the same scripts. No tracker, persistence, integration, AI, or network implementation is in scope.

**Tech Stack:** SwiftUI, XCTest, Xcode 26.6 / Swift 6.3.3 locally; macOS 14.0; universal `arm64 x86_64`; CI Xcode 26.3 (`17C529`).

## Constraints

- App Sandbox and Hardened Runtime required; deny all network, helper, automation, accessibility, capture, location, and sharing entitlements.
- M5 exclusively owns signing, notarization, stapling, and DMG delivery.
- M0-4 and M1 remain blocked until M0-3 is accepted.

### Task 1: Failing bootstrap validation

**Create:** `scripts/m0/validate_bootstrap.sh`, `scripts/m0/test_validate_bootstrap.sh`, `docs/delivery/evidence/m0/M0-3-bootstrap-checklist.md`

1. Write the test wrapper calling `validate_bootstrap.sh .`.
2. Run it before the project exists; it must fail for missing Xcode project/workflow/settings.
3. Add an evidence checklist for macOS target, architectures, tests, unsigned archive, entitlement denylist, dependency and secret scan, and M5-only signing.
4. Commit as `test: add failing M0-3 bootstrap checks`.

### Task 2: Minimal native shell with test-first launch proof

**Create:** `RekonPursuit.xcodeproj/`, `RekonPursuit/BootstrapApp.swift`, `RekonPursuit/ContentView.swift`, `RekonPursuit/RekonPursuit.entitlements`, `RekonPursuitTests/RekonPursuitTests.swift`, `RekonPursuitUITests/RekonPursuitUITests.swift`

1. Write failing XCTest assertions for `BootstrapCopy.status == "Local-only foundation"` and visible accessibility identifier `bootstrap-status`.
2. Run `xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -destination 'platform=macOS'`; it must fail before project creation.
3. Implement only a SwiftUI status placeholder and targets. Set `MACOSX_DEPLOYMENT_TARGET = 14.0`, `ARCHS = arm64 x86_64`, explicit Swift language/concurrency settings, Sandbox and Hardened Runtime. Add no dependency or network code.
4. Re-run tests; commit as `build: add M0 native bootstrap shell`.

### Task 3: Local reproducibility and negative checks

**Create:** `scripts/m0/build_unsigned_archive.sh`, `scripts/m0/check_entitlements.sh`, `scripts/m0/check_tracked_secrets.sh`

1. Add temporary negative fixtures with an unsupported deployment target and a network entitlement; validation must reject both.
2. Implement project inspections via `xcodebuild -showBuildSettings`, `lipo -archs`, `codesign -d --entitlements :-`, `xcodebuild test`, and `xcodebuild archive CODE_SIGNING_ALLOWED=NO`.
3. Run both negative and real-tree checks. Build products are outside the repository. Commit as `test: add M0 bootstrap validation harness`.

### Task 4: Pinned CI and evidence

**Create:** `.github/workflows/m0-bootstrap.yml`, `docs/delivery/evidence/m0/M0-3-bootstrap-results.md`

1. Write a failing workflow-policy test that requires `macos-15-intel`, Xcode 26.3 (`17C529`), `macos-14` arm64 smoke, and no signing secrets.
2. Implement the workflow invoking the local validation scripts. It must not use `macos-latest`, sign, notarize, publish, or access user data.
3. Run local validation, capture command/output hashes, and mark actual remote GitHub evidence pending until it runs.
4. Commit as `ci: add pinned M0 bootstrap validation`.

### Task 5: Independent completion gate

Record independent Code Review, QA/Test, Architect, Security/Privacy, TPM, and Delivery Manager reviews in the ledger. Resolve all P0/P1 findings and re-run evidence. M0-4 may be released only after M0-3 is accepted.

## Self-review

This plan is test-first, contains no application feature work, preserves the macOS 14 and M5 signing boundaries, and holds M0-4/M1 behind their gates.
