# VD2-07x — Protected-export dialog visual repair

**Status:** Planned repair brief. This is a new, bounded implementation slice;
it requires fresh independent Architecture, QA, Security/privacy, TPM, and
Delivery release decisions before a fresh implementer starts.

## Objective

Correct exactly the two confirmed P1 visual defects in the root-owned
protected-export success dialog:

1. its blue-to-violet `Done` action must visibly fill the dialog content
   width; and
2. its outlined dark panel must have one visible, restrained elevation shadow.

The target remains the approved owner amendment and supplied reference: a
centered elevated panel with emerald check, heading, confirmation, bordered
two-row safe facts group, recovery-key reminder, and a full-width primary
action.

## Controlling evidence

- `docs/delivery/task-briefs/VD2-07x-reference-faithful-settings.md`
- `docs/delivery/reviews/VD2-07x-owner-feedback-visual-amendment-2026-08-01.md`
- `docs/delivery/reviews/VD2-07x-task2-code-review-2026-08-01.md`
- `.superpowers/sdd/2026-08-01-vd207-reference-faithful-recovery-screen/task-2-report.md`

## Scope and boundaries

| Path | Authorized change |
| --- | --- |
| `RekonPursuit/SettingsView.swift` | Only `SettingsProtectedExportSuccessDialog`'s `Done` label sizing/order and panel elevation shadow. |
| `docs/delivery/reviews/` | Fresh review records only. |

Everything else is outside this repair: `ContentView`, `WorkspaceViewModel`,
the export worker/store, event/token lifecycle, file panel, fixtures, launch
arguments, app route, global rail, all four Settings sections, compact
selector, theme-wide `RekonPrimaryButtonStyle`, dashboard, roadmap, and VD2-08
accessibility work.

The current safe boundary is inviolable. The dialog continues to receive only
`displayFilename` and `dismiss`; it remains root-presented only after the
existing real successful protected-export event. It must never be a fixture,
launch argument, demo control, or test-only success path. `Done` must continue
to invoke only the existing root dismissal binding and leave the active
workspace unchanged.

## Test-first implementation contract

### 1. Establish the focused RED source-consumer check

Before changing the dialog, inspect only its declaration in
`RekonPursuit/SettingsView.swift`. The current implementation is RED because
it applies `RekonPrimaryButtonStyle` to `Button("Done", action: dismiss)` and
only then applies `.frame(maxWidth: .infinity)`, so the style paints the
intrinsic label rather than the available dialog-content width. It also has no
panel shadow.

The focused source-consumer check is satisfied only when the declaration has
all of the following, in this order:

```swift
Button(action: dismiss) {
    Text("Done")
        .frame(maxWidth: .infinity)
}
.buttonStyle(RekonPrimaryButtonStyle())
.accessibilityIdentifier("settings-protected-export-success-done")
```

The width is deliberately on `Text("Done")` *inside* the button label and
before the style. Do not change `RekonPrimaryButtonStyle` and do not rely on an
outer frame after the style to paint the gradient.

The dialog panel must also contain exactly one deliberate outer elevation
shadow after its dark rounded background/outline, for example:

```swift
.shadow(color: .black.opacity(0.42), radius: 24, x: 0, y: 12)
```

The implementation may tune only those shadow constants if the signed
app-window comparison shows the reference needs a less or more restrained
elevation. It must remain a single panel shadow; do not introduce a second
outline, glow, or a global theme change.

### 2. Make the minimum production change

Change only `SettingsProtectedExportSuccessDialog` as specified above. Retain
the existing identifier, gradient style, rounded-panel dimensions, safe facts,
and reminder copy. Do not change a test just to make a visual defect pass.

### 3. Run the minimum reproducible verification

Use the configured signed Debug identity. The focused UI checks confirm the
normal visual fixture does not invent success and that the Recovery surface
still composes correctly; they cannot manufacture a protected-export success.

```sh
xcodebuild build -project RekonPursuit.xcodeproj -scheme RekonPursuit \
  -configuration Debug -destination 'platform=macOS,arch=arm64'

xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207ReferenceRecoveryDashboardKeepsRailAndUsesCardComposition \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207ReferenceRecoveryDoesNotInventExportSuccess \
  -derivedDataPath /private/tmp/rekon-vd207x-dialog-visual-repair-dd \
  -resultBundlePath /private/tmp/rekon-vd207x-dialog-visual-repair.xcresult
```

The two tests must each execute once with zero skips and zero expected
failures. Review the declaration against the source-consumer contract above
after the build; it is the deterministic proof of modifier ordering that the
fixture cannot exercise without violating the real-success-only boundary.

### 4. Obtain the required real-success visual evidence

After the focused checks pass, a product-owner-controlled normal Debug session
must complete the existing export flow using an ordinary enrolled local
workspace, the owner's recovery-key entry, and a newly empty local destination.
The implementer must not create, request, retain, or record those credentials
or destination details.

Capture only the app window at:

```text
/private/tmp/rekon-vd207x-visual-evidence/VD2-07x-real-export-success.png
```

Compare it directly with the supplied dialog reference. Confirm the full-width
gradient `Done` action aligns to the facts-panel content width, the dialog has
one visible elevated-panel shadow, the safe filename and `Selected local
folder` are the only exported-location values shown, and `Done` dismisses the
dialog without changing the active workspace. Do not capture the desktop,
Finder, file chooser, raw path, recovery key, or document metadata.

## Acceptance criteria

- The primary action's painted gradient spans the full dialog content width;
  the width is proposed to the label before `RekonPrimaryButtonStyle` renders.
- The panel has one visible, restrained outer elevation shadow in the signed
  normal Debug capture.
- Existing real-success-only presentation, filename-only data boundary,
  root-only dismissal, and unchanged-workspace behavior remain intact.
- The two focused UI tests and signed Debug build pass as specified, with no
  introduced skip or expected failure.
- The normal-Debug real-export capture is reviewed, app-window-only, and safe.
- All three existing VD2-08 accessibility assertions remain unchanged and out
  of this repair.

## Release and handoff

The repair is not accepted merely because it compiles. A fresh code reviewer,
QA verifier, Architecture reviewer, Security/privacy verifier, TPM, and
Delivery manager must independently review the focused result, source-consumer
check, and owner-controlled capture before VD2-07x can advance. No dashboard
or roadmap transition is authorized by this brief.
