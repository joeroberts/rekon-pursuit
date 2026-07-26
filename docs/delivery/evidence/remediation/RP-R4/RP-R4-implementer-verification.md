# RP-R4 implementer verification

Implemented local-only reconciliation in schema v19.

- v19 creates immutable reconciliation result history, one dedicated review task per opportunity, foreign keys, and the review-task index. Legacy posting checks migrate with their legacy IDs/statuses and map legacy `Closed` to unconfirmed `Closed suggested`.
- The store validates allowed local-review tuples and public HTTP(S) URLs without issuing a request. It rejects bracketed loopback, IPv4-mapped loopback, link-local, and ULA IPv6 literals. Rejected commands and injected activity failures remain transactional.
- Ordinary task completion and ordinary next-action edits cannot complete, rename, or delete the dedicated reconciliation review task. A malformed older record with a completed review task receives a fresh active review task on the next material reconciliation result.
- Explicit confirmation finds an unconfirmed `Closed suggested` result rather than assuming the newest history entry is a closure suggestion. It is the only reconciliation path that closes an opportunity, completes that dedicated task, writes stage history, and appends redacted local activity.
- The record view removes the retired unstructured posting-check controls. It states the R4 no-online-check boundary and provides local/offline recording, review-task opening, chronology with confidence/review/closure state, and a closure confirmation sheet with Keep active.
- The v19 fixture verifies lossless migration of all legacy posting statuses and the injected v19 failure preserves the v18 posting rows and verified snapshot.

Verification run:

- `xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -destination 'platform=macOS,arch=arm64' -only-testing:RekonPursuitTests/WorkspaceStoreTests` — succeeded.
- Focused re-run covered bracketed IPv6 rejection, review-task isolation and replacement, closure-suggestion selection, generic-stage rejection while a review is active, v18 migration provenance, and injected v19 migration rollback — succeeded.
- `xcodebuild build -project RekonPursuit.xcodeproj -scheme RekonPursuit -configuration Debug -destination 'platform=macOS,arch=arm64' -quiet` — succeeded.
- Scoped source and entitlement scan found no `URLSession`, `URLRequest`, `NWConnection`, `import Network`, or network-client entitlement in R4 sources.

Known follow-up for independent QA: exercise the requested full relaunch UI smoke using a fresh workspace; this implementation verification did not issue any network request.
