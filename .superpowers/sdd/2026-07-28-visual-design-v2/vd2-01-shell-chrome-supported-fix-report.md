# VD2-01 supported shell-chrome corrective fix

## Trigger

Independent re-review identified the prior divider-cover implementation as unsafe: it added a child view to an `NSSplitViewController`-managed `NSSplitView`.

## Root cause and supported contract

The macOS SDK's `NSSplitViewController.h` states that only a managed split view's `vertical`, `autosaveName`, and divider properties may be changed; manipulating its subviews can throw an exception. The previous cover view therefore risked an AppKit crash.

`NSSplitView.dividerStyle` is a supported divider property. The corrective implementation uses `.thick`, retaining AppKit's native resize hit area while using its documented clear thick-divider appearance. No split-view children are added, removed, or reordered.

## Change

- Removed the custom divider overlay, its layout observation, and all managed-split-view child mutation.
- Configured only `splitView.dividerStyle = .thick` through the existing window bridge.
- Added the supported SwiftUI window-toolbar visibility policy so fullscreen does not reintroduce toolbar material.
- Preserved traffic lights, `NavigationSplitView` ownership/resizing, and the existing custom keyboard focus treatment (`focusEffectDisabled(true)` plus the app's cyan focus ring).

## Test-first evidence

Before implementation, the focused test build failed because the new explicit policy members did not exist:

```text
RekonPursuitTests.swift: no member 'hidesWindowToolbar'
RekonPursuitTests.swift: no member 'splitViewDividerStyle'
```

## Automated verification

```sh
xcodebuild -project RekonPursuit.xcodeproj -scheme RekonPursuit -destination 'platform=macOS' \\
  -only-testing:RekonPursuitTests/RekonPursuitTests/testVisualFoundationKeepsWindowChromeNavyWithSupportedSplitViewConfiguration \\
  -only-testing:RekonPursuitTests/RekonPursuitTests/testWindowChromeConfiguratorAppliesNavyChromeWithoutAddingManagedSplitViewSubviews \\
  -derivedDataPath /tmp/rekon-vd2-supported-chrome-final test
```

Result: 2 tests executed, 0 failures (`TEST SUCCEEDED`).

```sh
xcodebuild -project RekonPursuit.xcodeproj -scheme RekonPursuit -destination 'platform=macOS' \\
  -derivedDataPath /tmp/rekon-vd2-supported-chrome-build build
codesign --verify --deep --strict \\
  /tmp/rekon-vd2-supported-chrome-build/Build/Products/Debug/RekonPursuit.app
git diff --check
```

Result: Debug build succeeded, the signed app passed codesign verification, and the working diff was whitespace-clean.

## Required hands-on smoke

Open the signed Debug app in both a normal window and fullscreen, then verify:

1. The title/toolbar region, sidebar top, detail canvas, and sidebar boundary do not show unintended gray material or a gray divider.
2. Traffic lights remain visible and the sidebar still resizes through the native split-view divider.
3. Keyboard navigation shows one cyan focus indicator per sidebar item; VoiceOver labels and navigation remain intact.
