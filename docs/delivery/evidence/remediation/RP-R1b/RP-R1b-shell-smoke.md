# RP-R1b reactive shell — implementer evidence

**State:** Implementation verification complete; independent review remains
pending.

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

## 900 × 640 manual smoke

**Result: Completed by direct user observation on 2026-07-25.** In the
temporary app at 900 × 640, the user completed the required sequence: create
workspace, create and edit one synthetic opportunity, select Pipeline and
Activity & AI, then select Import CSV and preview the synthetic fixture in the
native chooser. This is manual evidence, not an automation claim.
