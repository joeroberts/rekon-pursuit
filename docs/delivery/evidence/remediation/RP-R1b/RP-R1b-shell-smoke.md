# RP-R1b reactive shell — implementer evidence

**State:** Implementation verification complete; independent review and the
required operator-facing smoke remain pending.

## Scope delivered

- Replaced the root segmented control with a native `NavigationSplitView`.
- Added a typed sidebar for the seven approved destinations and a persistent
  Rekon Pursuit toolbar/title treatment.
- Kept the workspace state as a persistent detail header. Its create, retry,
  and recovery actions remain owned by `ContentView` and retain their R1a
  behavior.
- Moved existing page content under a scrollable detail area. No local data,
  picker/modal ownership, entitlement, import behavior, or domain command was
  changed.

## Local verification

| Check | Command | Result |
| --- | --- | --- |
| Debug macOS build | `xcodebuild build -project RekonPursuit.xcodeproj -scheme RekonPursuit -destination 'platform=macOS,arch=arm64'` | Passed. |
| UI navigation checks | `xcodebuild test -quiet -project RekonPursuit.xcodeproj -scheme RekonPursuit -destination 'platform=macOS' -only-testing:RekonPursuitUITests` | Passed: default Needs Attention/sidebar/workspace-gate state and Contacts navigation. The test asserts the gate's visible `workspace-gate-status` static text; SwiftUI does not expose the `GroupBox` wrapper as the `Other` element previously queried. |
| Isolated harness preflight | `scripts/remediation/run_r1a_isolated_smoke.sh .` | Passed: temporary sandboxed app namespace and container were created. |

## Pending acceptance smoke

At a 900 × 640 window, an independent operator must still record the required
manual sequence in the temporary app: create workspace, create and edit one
synthetic opportunity, select Pipeline and Activity & AI, then select Import
CSV and preview the synthetic fixture in the native chooser. This document
does not claim that manual sequence was automated.
