# VD2-05 — Core/VM test-target identity repair delivery release

**Date:** 2026-07-31  
**Role:** Fresh independent Delivery Manager  
**Decision:** **Release a source-target terminology correction, one
test-helper actor annotation, and fresh signed evidence only. Board interaction
remains withheld.**

## Diagnosis

`RekonPursuitCoreTests/WorkspaceStoreTests.swift` is the physical source
group, but Xcode compiles and runs it in the `RekonPursuitTests` test target.
Earlier VD2-05 evidence used the physical-group name as a `-only-testing`
target selector, which cannot select the compiled test. The correct focused
Core selector is therefore:

```text
-only-testing:RekonPursuitTests/WorkspaceStoreTests
```

The ViewModel focused selector remains:

```text
-only-testing:RekonPursuitTests/WorkspaceViewModelTests
```

After that selector correction reached compilation, Swift concurrency checking
identified a test-only isolation mismatch: the `StageMoveModelBaseline` helper
is constructed from the `@MainActor` `WorkspaceViewModelTests` fixture and
must itself be `@MainActor`.

## Authorized changes

1. Correct the current VD2-05 plan terminology so it names the physical source
   path and its actual `RekonPursuitTests` execution target separately.
2. Add `@MainActor` to `StageMoveModelBaseline` in
   `RekonPursuitTests/WorkspaceViewModelTests.swift`.
3. Produce a fresh verification record with isolated, signed Debug result
   bundles for both focused selectors and signature checks for the app/test
   host/test bundle actually exercised.
4. Update the delivery dashboard to point to this repair release while keeping
   VD2-05 in progress and every successor withheld.

## Explicit non-authorizations

No production source, project or signing configuration, fixture routing,
database schema, Board/Pipeline/UI source, drag/drop, keyboard control,
activity copy, or selector assertion may change. This release neither accepts
the Core/VM slice nor releases Board interaction, owner handoff, VD2-06,
VD2-07, or VD2-08.

## Required fresh evidence

The repair returns both exact selectors above with unique isolated
`-derivedDataPath` and `-resultBundlePath` output, signed Debug binaries, and
the prior contract matrix intact. A build/cache/signing failure, skipped test,
or broad replacement suite is not acceptance evidence.

## Delivery state

- `VD2-05`: **In progress — Core/VM evidence repair only.**
- Board interaction and card relocation: **withheld.**
- `VD2-06`, `VD2-07`, `VD2-08`: **Backlog.**
