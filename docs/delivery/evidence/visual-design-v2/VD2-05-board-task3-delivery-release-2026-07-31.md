# VD2-05 — Original Task 3 Board implementation delivery release

**Date:** 2026-07-31  
**Role:** Fresh independent Delivery Manager  
**Decision:** **APPROVED — release only original plan Task 3, “Board
interaction and sealed UI-test scenarios.”**

## Dependency acceptance

Repair-plan Task 3 is complete and parent VD2-05 Task 2, “Transactional Core +
view-model result,” is accepted. The final repair gates are:

| Gate | Evidence | Decision |
| --- | --- | --- |
| Code Review | `.superpowers/sdd/2026-07-31-vd205-core-suite-evidence-repair/task-3-whole-suite-proof-code-review.md` | ACCEPT; no findings. |
| QA | `.superpowers/sdd/2026-07-31-vd205-core-suite-evidence-repair/task-3-whole-suite-proof-post-implementation-qa.md` | ACCEPT; independent complete Core 114/114 and ViewModel 91/91. |
| Architecture | `.superpowers/sdd/2026-07-31-vd205-core-suite-evidence-repair/task-3-whole-suite-proof-post-implementation-architecture.md` | ACCEPT; no ADR deviation. |
| Security/privacy | `.superpowers/sdd/2026-07-31-vd205-core-suite-evidence-repair/task-3-whole-suite-proof-post-implementation-security.md` | ACCEPT; no findings. |
| Final TPM | `.superpowers/sdd/2026-07-31-vd205-core-suite-evidence-repair/task-3-whole-suite-proof-final-tpm-gate.md` | ACCEPT repair Task 3 and parent Task 2; release Board only after the content-baseline conditions below. |

Those conditions are satisfied by this release. This decision accepts neither
the original Board implementation nor VD2-05 as a whole.

## Content-sensitive worktree boundary

The complete release-time tracked/untracked manifest is:

`.superpowers/sdd/2026-07-30-vd205-persisted-pipeline-stage-movement/task-3-board-dirty-worktree-content-manifest.md`

Its scope is every individual path returned by
`git status --porcelain=v1 -z --untracked-files=all` after this Delivery update
and dashboard render. Every manifest record contains the two-character status,
path, byte count, and file-content SHA-256; untracked directories are expanded
to files. The manifest also retains the canonical porcelain stream SHA-256 and
an aggregate SHA-256 over the canonical per-file records. Ignored internal SDD
records are outside Git's tracked/untracked status set and are not recursively
self-manifested.

No dirty path is accepted merely because it appears in the manifest. The
manifest is an attribution boundary for the one serial implementer and every
subsequent reviewer.

## Immutable Board target baselines

The four pre-existing Board targets were copied into Git's content-addressed
object database with `git hash-object -w`. Each blob was read back and its
SHA-256 reproduced. The new Board file is absent at release.

| Target | Bytes | Release SHA-256 | Immutable Git blob |
| --- | ---: | --- | --- |
| `RekonPursuit/PipelineView.swift` | 32999 | `38e7aea825f32e1916a3821f7ebbd4f4914b3b5e5826af397760ccd8a82b16fb` | `bbb82a06b01be0defd78ff960593d4bc283ff883` |
| `RekonPursuit/RekonVisualTheme.swift` | 75498 | `48a779b307a2f4f1bfa26214dc90b53ee5dac084abdc599be3f03b4acb005e4c` | `3478c18e7e25ee775ec0bf3022d2589865cd8847` |
| `RekonPursuitTests/RekonPursuitTests.swift` | 23576 | `41946f113ce091bc7cba0053f63cba94f749981c3996f55d357bc8eead48424b` | `284e9c2d54f822711d5872327b1c76eadafdc5e3` |
| `RekonPursuitUITests/RekonPursuitUITests.swift` | 72885 | `0f0a8dc205c64915e0210321162e31efbcf7c3fc41e3034e17337bf47ce7774f` | `c4e18ef61f287ddf232c9dc383aa89048d72d7fe` |
| `RekonPursuit/PipelineBoardView.swift` | — | **ABSENT** | New-file baseline; it must not exist before the implementer begins. |

If any existing target no longer matches both its SHA-256 and immutable blob,
or the new-file absence changes before implementation begins, stop. Delivery
must inspect the drift and issue a new baseline; the implementer may not merge
around it.

## Accepted Task 2 dependency binding

| Accepted dependency | SHA-256 |
| --- | --- |
| `RekonPursuitCore/Workspace/WorkspaceModels.swift` | `18675156d9e94477466da56d239a02e97fa45464fa5270d2612cd70e928a10e6` |
| `RekonPursuitCore/Workspace/WorkspaceStore.swift` | `676e669f614dc180cea8bd33742bb07d058d61945f653e43efacbbae9a0ee138` |
| `RekonPursuit/WorkspaceViewModel.swift` | `8e392c309fa2bab2218682ef297d071d66781e69453924846e94754c7ddef93a` |
| `RekonPursuitCoreTests/WorkspaceStoreTests.swift` | `83d61ea4769da4c44c8466b5af76415f7e9ecebf974295ba036a424921dc2162` |
| `RekonPursuitTests/WorkspaceViewModelTests.swift` | `dced4c9f2fef6b0acc671d03b7a148d831bd3b038e257d20413fe32d5053fcdd` |

The retained complete signed result bindings are:

| Suite | Passed | App host executable | XCTest executable | Result `Info.plist` |
| --- | ---: | --- | --- | --- |
| Core | 114/114 | `adc5db8380d3392f42fb833b1b900dcabd0f888acd98c0be325abe79f28c979e` | `516c7cccaae05018578e6331a36acab5af2b8e879ef0ab7de31c9a243f5ceede` | `d0cc1d0d9d712e7cd060787363ef78dac6bb79a9c3fe68a2fc2de40bd7f61c6b` |
| ViewModel | 91/91 | `2e914541445cbb62d3384c86ee313ff4d08084bba114ebd1f06e95d6e75387fb` | `a88e123b93348d83cb6b58acebf7e8523233be4e9bd2d839f9c490e1b47b1e86` | `1623dd7583e2eed981bdce819eeff2665d0f450cda806312fefee33665396d3a` |

Any dependency hash drift before or during Board work is a stop condition. Core,
schema, migrations, and the accepted transaction/ViewModel implementation are
read-only dependencies of this task.

## Serial ownership and integration plan

One fresh, bounded Implementer owns all Board target work from RED through
review handoff. No parallel worker may edit a Board target. The implementer
must:

1. read this release and its manifest; reproduce all target and dependency
   hashes and confirm `PipelineBoardView.swift` is absent before the first
   edit;
2. preserve all pre-existing target content and work serially: add pure/unit
   RED contracts, implement the focused Board view and narrow `PipelineView`
   delegation, then add only sealed test-host routing and UI scenarios;
3. keep every non-target dirty path byte-for-byte equal to the release
   manifest and keep every dependency at its accepted hash;
4. after implementation, compare each existing target directly to its
   immutable Git blob, justify every changed hunk against the Task 3 contract,
   and prove `PipelineBoardView.swift` is a newly created file;
5. hand the exact baseline-relative diffs and evidence package to fresh
   independent reviewers.

If a pre-existing change must be altered for work outside the exact release
boundary, stop and return to Delivery. There is no parallel integration lane.

## Exact released files

The implementer may change only:

- create `RekonPursuit/PipelineBoardView.swift`;
- narrowly delegate Board rendering from `RekonPursuit/PipelineView.swift`;
- add only sealed test-host scenario routing behind
  `#if REKON_UI_TEST_HOST` in `RekonPursuit/RekonVisualTheme.swift`;
- add pure and presentation tests in
  `RekonPursuitTests/RekonPursuitTests.swift`;
- add signed Board workflow/accessibility tests in
  `RekonPursuitUITests/RekonPursuitUITests.swift`.

Minimal Board focus and reduced-motion styling must remain inside these
authorized Board source files. No additional source or test file is released.

Core, schema, migrations, recovery, project/signing, entitlements, application
routes, Table/inspector redesign, dashboard, roadmap, status, ledgers,
delivery evidence, unrelated tests, and every other dirty path are
unauthorized.

## Test-first and evidence contract

Before implementation, preserve RED evidence for:

- pure ID-only drag payload serialization and rejection of empty, oversized,
  malformed, unknown, cancelled, and outside drops;
- pure result/presentation mapping, including Reduce Motion;
- source-card retention until persistence succeeds and target-only placement
  after the persisted result;
- keyboard-only movement to `Screening`;
- accessibility role, identifier, current state, all six canonical targets,
  and live outcome;
- persisted, precise no-op, blocked `Closed`, unavailable, both injected
  failure points, invalid, cancelled, closed-filter, relaunch, and History
  scenarios;
- exact success/relaunch/History evidence: one new activity and one matching
  stage-history record.

Then return fresh signed evidence for the pure/unit suite, wide and compact
native Board drag/drop, keyboard and VoiceOver semantics, accessibility
outcomes, filter behavior, Reduce Motion, failure stability, relaunch/History,
and all retained VD2-04 Table/Board regressions. Do not use unsigned-product
evidence.

Re-run the complete accepted Core 114-test and ViewModel 91-test selectors
against the post-Board tree. Inspect summary and detailed result inventories;
require every selected test passed with zero failures, skips, or expected
failures. Strictly verify the app, host, and nested XCTest signatures and
record source, executable, XCTest, and result hashes.

Before any acceptance:

- prove the five-file boundary against the immutable blobs and new-file
  baseline;
- prove every non-target dirty manifest entry and every dependency hash is
  unchanged;
- run `git diff --check`;
- obtain a fresh separate Code Review and independent QA verification;
- then obtain Architecture, TPM, Security/privacy, and Delivery acceptance.

## Holds

This release does not move a card, accept the Board implementation, accept
VD2-05, or authorize owner smoke. Owner handoff, `needsUserAction`, dashboard
status advancement, final VD2-05 acceptance, and VD2-06–08 remain blocked
until Board Task 3 passes every post-implementation gate.
