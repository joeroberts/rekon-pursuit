# VD2-07x dialog build verification

**Date:** 2026-08-01  
**Verifier:** Fresh independent build verifier  
**Scope:** Reproduce the reported ordinary/default-DerivedData signed Debug
build failure once, inspect only its relevant `cstemp` artifact/error, then
perform and verify an isolated signed Debug build. No source, test, dashboard,
DerivedData cleanup, or signing-setting change was made.

## Inputs reviewed

Read `.superpowers/sdd/2026-08-01-vd207-reference-faithful-recovery-screen/dialog-repair-report.md`.
The project configuration currently uses automatic signing and contains the
configured development team (`2UA854NLX4`); this verification did not alter
that configuration.

## Default DerivedData reproduction

Command (run once, with no `-derivedDataPath`):

```sh
xcodebuild build -project RekonPursuit.xcodeproj -scheme RekonPursuit \
  -configuration Debug -destination 'platform=macOS,arch=arm64'
```

Factual result: exit status `65`; the build failed at the app `CodeSign` step.
Relevant output:

```text
Signing Identity:     "Apple Development: jaroberts4@gmail.com (PT7GS96H3L)"
Provisioning Profile: "Mac Team Provisioning Profile: com.rekonlabs.RekonPursuit"
RekonPursuit.app: invalid or unsupported format for signature
In subcomponent: .../RekonPursuit.app/Contents/MacOS/RekonPursuit.cstemp
Command CodeSign failed with a nonzero exit code
** BUILD FAILED **
```

Only the identified `cstemp` artifact was inspected. It is a `60304` byte
`Mach-O 64-bit executable arm64`, modified at `2026-08-01T07:13:44Z`, with
mode `-rwxr-xr-x` and no filesystem flags. Direct inspection reported:

```text
RekonPursuit.cstemp: code object is not signed at all
```

No default DerivedData content was deleted or modified.

## Isolated signed Debug build and signature verification

The following previously non-existent DerivedData path was used:
`/private/tmp/rekon-vd207x-dialog-build-verifier-dd`.

```sh
xcodebuild build -project RekonPursuit.xcodeproj -scheme RekonPursuit \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /private/tmp/rekon-vd207x-dialog-build-verifier-dd
```

Factual result: exit status `0` and `** BUILD SUCCEEDED **`. The app was signed
using the same Apple Development identity and provisioning profile named in the
default-path command.

App signature verification command:

```sh
codesign --verify --deep --strict --verbose=4 \
  /private/tmp/rekon-vd207x-dialog-build-verifier-dd/Build/Products/Debug/RekonPursuit.app
```

Factual result: exit status `0`:

```text
RekonPursuit.app: valid on disk
RekonPursuit.app: satisfies its Designated Requirement
```

`codesign --display --verbose=4` further reported:

```text
Identifier=com.rekonlabs.RekonPursuit
Format=app bundle with Mach-O thin (arm64)
Authority=Apple Development: jaroberts4@gmail.com (PT7GS96H3L)
TeamIdentifier=2UA854NLX4
```

## Verdict

The failure is confined to corrupted or stale content in the default
DerivedData product path, specifically the unsigned
`RekonPursuit.cstemp` subcomponent. It is not reproduced by an isolated signed
Debug build of the same source and build configuration, whose resulting app
passes strict deep signature verification. This evidence does not implicate
the source or current signing/build configuration.
