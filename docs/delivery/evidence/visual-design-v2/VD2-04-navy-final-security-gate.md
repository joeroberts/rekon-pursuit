# VD2-04 navy-surface correction — final security/privacy gate

**Date:** 2026-07-30  
**Role:** Independent security/privacy verifier  
**Verdict:** **Accepted, within the VD2-04 navy-surface correction boundary.**

## Scope and evidence

The reviewed correction boundary is the Pipeline-local presentation seam in
`RekonPursuit/RekonVisualTheme.swift` and its use in
`RekonPursuit/PipelineView.swift`, as constrained by
`VD2-04-pipeline-navy-surface-correction.md` and
`ADR-VD2-04-pipeline-navy-control-seam.md`.

The signed-Debug recovery result bundle
`/tmp/rekon-vd204-recovery-qa-20260730-1.xcresult` is present. Its
`xcresulttool` summary reports **Passed**, 7 total / 7 passed / 0 failed on
arm64 macOS. The exported attachment manifest is present and contains the
four required non-failure-associated Pipeline captures: wide Table, wide
Board, compact Table, and compact Board.

## High-risk boundary review

| Boundary | Finding |
| --- | --- |
| Local storage, recovery, Keychain, and preferences | No correction code calls a store/session, Keychain API, `UserDefaults`, bookmark/recovery API, or filesystem read/write operation. The control state is SwiftUI-local (`query`, `stage`, `includesClosed`, `selectedTableID`, and `showsBoard`) and the control coordinators only bind those values. |
| Network, AI, providers, Gmail, Calendar | No network client, URL request, provider/AI route, OAuth/credential, Gmail, or Calendar integration is added or reached by the control seam. |
| Documents and CSV/import processing | `PipelineView` retains an injected `importCSV` action and invokes it only from the existing button. The new style/representables neither choose files nor parse, read, write, or upload a document/CSV. |
| Activity/audit and opportunity mutation | The correction reads the existing in-memory `WorkspaceViewModel` projection and returns existing callbacks for open/delete/add/import. It adds no mutation, activity-event, route, or persistence call. |
| AppKit native-control seam | The new `NSTextField`, `NSPopUpButton`, `NSButton`, and `NSSegmentedControl` subclasses only draw Rekon colors, track pointer/focus/press state, and bind text or fixed-choice selection to local view state. Native controls remain the accessibility and keyboard owners. No hidden duplicate action, external payload handling, or persistence is introduced. |

## Scope control

The shared worktree is intentionally dirty with earlier delivery work,
including pre-existing changes in workspace/model/store files. Those files
are outside the navy-correction release boundary and this gate does **not**
re-approve them. No high-risk capability was added by the reviewed correction
files, and the delivery release correctly keeps VD2-04 in progress pending
the other independent gates and renewed product-owner acceptance.

## Residual risk

This is a native custom-drawing seam. Future edits must preserve the current
rule that coordinators bind only ephemeral Pipeline presentation state; adding
file selection, persistence, network work, or external option data to these
controls requires a new privacy/security review.
