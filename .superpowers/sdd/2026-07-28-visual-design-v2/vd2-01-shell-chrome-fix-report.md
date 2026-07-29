# VD2-01 shell-chrome corrective pass

## Scope

Address the remaining shared-shell regressions reported from the native app:

- graphite/gray system material visible above the sidebar and detail canvas in a standard window;
- a full-width graphite strip reappearing when the window enters full screen;
- two simultaneous focus treatments on sidebar destinations.

This pass is intentionally limited to shared window chrome and sidebar focus
presentation. It does not change routes, keyboard navigation semantics,
VoiceOver labels, workflow behavior, persistence, minimum window size, or the
traffic-light controls.

## Root cause and design decision

SwiftUI background modifiers cannot consistently paint the AppKit-owned window
and toolbar material on the macOS 14 deployment target. The earlier root-canvas
background therefore left the system graphite material visible in title/toolbar
regions, especially after entering full screen.

`containerBackground(_:for: .window)` was considered, but it is macOS 15+.
Instead, a zero-content `NSViewRepresentable` configures the hosting `NSWindow`
with the existing Rekon navy token and transparent titlebar. The shell also
hides its window toolbar background using the macOS 14-supported SwiftUI API.
This retains the native window controls rather than replacing the titlebar or
changing the window style mask.

Sidebar destinations already render the approved custom cyan focus ring. The
platform focus effect was additionally drawing an inset rectangle around the
icon and label. The shared sidebar button now explicitly suppresses only that
duplicated platform focus visual while retaining keyboard focus state and
VoiceOver behavior.

## Delivered change

- Extended `RekonWindowCanvasPolicy` with explicit window-container and
  toolbar-material requirements.
- Added `RekonWindowChromeConfigurator`, which updates the attached AppKit
  window on creation, update, and window attachment.
- Applied the configurator and hidden toolbar material at `AppShellView`.
- Added a testable `RekonSidebarFocusPolicy` and applied
  `focusEffectDisabled(true)` only because the custom focus ring remains the
  visible keyboard focus indicator.
- Added a focused policy regression test.

## TDD and verification evidence

### Red

The new focused test was first run before the window/focus-policy API existed.
It failed with missing `RekonSidebarFocusPolicy` and missing window-policy
members, as expected.

### Green

```text
xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit \
  -destination 'platform=macOS' \
  -only-testing:RekonPursuitTests/RekonPursuitTests/testVisualFoundationKeepsWindowChromeNavyAndUsesOneSidebarFocusTreatment \
  -derivedDataPath /tmp/rekon-vd2-shell-chrome-green

Test Suite 'Selected tests' passed: 1 test, 0 failures.
** TEST SUCCEEDED **
```

```text
xcodebuild build -project RekonPursuit.xcodeproj -scheme RekonPursuit \
  -configuration Debug \
  -derivedDataPath /tmp/rekon-vd2-shell-chrome-build

codesign --verify --deep --strict \
  /tmp/rekon-vd2-shell-chrome-build/Build/Products/Debug/RekonPursuit.app

** BUILD SUCCEEDED **
```

The explicit `codesign` verification exited successfully with no output.
No UI-test runner was launched in this corrective pass.

## Required independent visual smoke

Open the signed Debug app at:

`/tmp/rekon-vd2-shell-chrome-build/Build/Products/Debug/RekonPursuit.app`

Verify the following before accepting this corrective pass:

1. In a normal-size window, the area above the sidebar and detail canvas is
   Rekon navy rather than graphite gray; traffic lights remain present.
2. Enter and exit full screen. The top edge remains navy—there is no full-width
   graphite toolbar strip—and the sidebar divider reads as the intended subtle
   dark-navy separation rather than a gray border.
3. Navigate to each sidebar destination by keyboard. A focused destination has
   one visible outer cyan focus treatment, not a second inner rectangle around
   its icon/text. Activation and VoiceOver labels remain intact.

## Remaining gate

The compiler, targeted regression test, and code-sign verification are green.
Independent code review, QA verification, and the live visual smoke above are
still required; this report does not mark VD2-01 accepted.
