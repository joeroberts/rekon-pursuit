# VD2-07x — Pre-implementation QA command recheck

**Date:** 2026-08-01
**Role:** Fresh independent QA/test reviewer
**Verdict:** **NEEDS CHANGE**

## Scope and method

Independently rechecked the amended Task 1 brief, the amended reference-faithful
plan, and the prior QA recheck. Parsed the two literal matrices from the brief
and validated their shell syntax, selector parity, output paths, Xcode project
targets, and the stated RED/green rules. No source, test, fixture, project,
index, commit, or existing delivery artifact was changed.

## Passing matrix properties

- Both literal commands now begin with bare `xcodebuild`; `/usr/bin/xcodebuild`
  resolves and both multiline commands pass `zsh -n`. There is no leading diff
  marker.
- Each matrix has exactly 43 `-only-testing` selectors, all 43 unique. Their
  ordered lists are identical (SHA-256:
  `e3d632a6019b69ddcfdab55051954aabd40f4c988919feddbeab1d84bdf6c97d`).
  After normalizing only the task-specific DerivedData/result-bundle values,
  the commands are otherwise identical.
- The paths are unique and correctly separated:
  `/private/tmp/rekon-vd207x-task-1-red-dd` /
  `/private/tmp/rekon-vd207x-task-1-red.xcresult` for Task 1, and
  `/private/tmp/rekon-vd207x-task-2-green-dd` /
  `/private/tmp/rekon-vd207x-task-2-green.xcresult` for Task 2.
- The amended plan delegates to these exact brief matrices. It retains the
  Task-1 rule of zero skip/expected failure, with only the three declared
  visual-reference methods allowed to fail through the exact
  `VD2-07x RED: unrendered visual selector` activity/message; Task 2 requires
  zero failure, skip, and expected failure.

## Blocking correction

Both matrices contain seven selectors whose test-bundle prefix is
`RekonPursuitCoreTests` (the four `PortableArchiveTests` and three
`ProtectedExportTests` selectors). That is a project group, not an Xcode test
target: `xcodebuild -list` exposes `RekonPursuitTests`,
`RekonPursuitUITests`, and `RekonPursuitUITestHostTests`, while
`xcodebuild -showBuildSettings -target RekonPursuitCoreTests` fails with
“does not contain a target named `RekonPursuitCoreTests`.” The project builds
both Core test source files into `RekonPursuitTests.xctest`.

Replace only the prefix of those seven selectors in both matrices with
`RekonPursuitTests`, preserving the class and method portions. For example:

```
-only-testing:RekonPursuitTests/PortableArchiveTests/testExpiryAtBoundaryRemovesOnlyVerifiedMatchingRegularArchive
-only-testing:RekonPursuitTests/ProtectedExportTests/testReviewBindsDestinationParentIdentity
```

Then obtain a fresh QA command recheck. This correction must leave both
matrices at 43 identical selectors and change no value other than the seven
test-target prefixes and their already distinct output paths.

## Release decision

Do not release Task 1. Although the leading-marker issue is repaired and the
selector/RED policy is otherwise coherent, the seven invalid target identifiers
prevent either signed matrix from executing every required selector once.
