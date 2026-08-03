# VD2-07x baseline-repair prerequisite — Security/privacy review

**Date:** 2026-08-01  
**Role:** Independent security/privacy verifier  
**Verdict:** **ACCEPT** — the draft baseline-repair prerequisite is bounded to deterministic fixture time and Settings accessibility semantics. It neither changes the protected-export/recovery protocol nor expands the display or fixture data boundary.

## Scope and method

Reviewed:

- the approved reference-faithful Settings design;
- `docs/superpowers/plans/2026-08-01-vd207x-baseline-repair-prerequisite.md`;
- `docs/delivery/task-briefs/VD2-07x-baseline-repair-prerequisite.md`;
- the Task 1 implementation report and current protected-export/root-presentation source; and
- the fixture, Settings accessibility, and UI-test source named in the prerequisite allowlist.

This is a static pre-implementation gate. No source, test, fixture, project, signing, entitlement, index, or commit was changed, and no test was run by this reviewer.

## Security/privacy findings

| Boundary | Evidence | Disposition |
| --- | --- | --- |
| Fixture clock remains test-only and deterministic | `VisualFixtureLaunchConfiguration.fixedNow` is used only by the opt-in `-rekon-visual-fixture` launch configuration and fixture-host assertions. The current epoch decodes to `2025-05-01T00:00:00Z` despite a May 6 comment; the planned replacement `1_746_532_800` decodes to the required `2025-05-06T12:00:00Z`. The plan limits the change to that literal and its direct ISO-UTC regression assertion. | **Satisfied.** This changes only deterministic archive-fixture dates and the derived 30-day fixture expiry; it cannot affect a personal workspace, recovery key, destination, or export-success state. |
| Fixture isolation and no synthetic export success | `VisualFixtureLaunchConfiguration` is entered only by its explicit launch argument, and `VisualFixtureWorkspace` seeds its own temporary encrypted store rather than a user workspace. The plan expressly prohibits a fixture mode, launch argument, demo success, mock destination, test-only success control, or launch-parser change. The existing Task 1 contract still requires the default fixture success state to be absent. | **Satisfied.** The date correction does not make an export succeed, seed a protected-export event, or bypass review/confirmation/writing. |
| Protected-export/recovery safety contract stays unchanged | The current model publishes `ProtectedExportSuccess(displayFilename:)` only after the injected production-default writer returns and both the opaque operation token and store identity remain current. Its root projection contains only the filename, a boolean, and the fixed `Selected local folder` label; cancellation, failure, and workspace transitions clear the event. The repair allowlist excludes `WorkspaceViewModel`, `ContentView`, Core, persistence, export/review/write logic, and recovery behavior. | **Satisfied.** No repair hunk can expose the review URL, parent identity, receipt, bookmark, recovery key, key-derived data, archive fingerprint/checksum, or document data. The real-write-only success invariant remains a required green contract. |
| Settings focus changes remain semantic-only | The sole `sectionSelector(_:)` repair reuses the working `Button` focus modifiers: plain button style, native focus binding, Space handler, disabled native focus effect, label, existing identifier/value, and selected trait. It adds no data source, callback, persistence, route, file URL, or model reference. | **Satisfied.** Restoring keyboard-focus accessibility cannot disclose sensitive recovery/export/document data or mutate selection merely by focus. The plan retains pointer activation and requires exact selected/focused values. |
| AI accessibility repair preserves truthful unavailable copy | The only AI change removes a redundant explicit accessibility label from the existing unavailable `Text`, allowing it to remain a `StaticText`. It prohibits copy changes and controls, while the signed test continues to require `No AI requests`, `Gmail`, and `Calendar` and zero buttons, links, fields, switches, or checkboxes. | **Satisfied.** This restores role semantics without adding AI/cloud/Gmail/Calendar capability, network behavior, or data disclosure. |
| Document and archive privacy boundaries are retained | The brief prohibits document paths, names, bookmarks, hashes, MIME types, and controls; it leaves the Document section untouched. The fixture-date test asserts only UTC time, and archive verification retains safe date/lifecycle values rather than checksums, fingerprints, or paths. The plan also forbids recovery material, raw destination values, and result-bundle workarounds. | **Satisfied.** The repair has no permitted surface for document metadata, sensitive archive material, or absolute paths. |

## Required implementation evidence

This acceptance authorizes only the prerequisite's security/privacy planning gate; it does not accept an implementation or release Task 2. Before an implementation handoff is accepted, the independent verifier must confirm that the isolated diff contains only the four allowlisted repair hunks, the fixed-time and focused UI contracts are green with no skip/expected failure, and the full matrix contains no non-visual privacy/recovery/export failure or fixture-created success state. The existing runner-result-bundle finalization issue must remain reported as infrastructure evidence only, never masked through app or test behavior.

