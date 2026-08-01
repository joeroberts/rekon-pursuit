# VD2-06 pre-implementation QA/accessibility gate — amended-plan re-review

**Verdict: ACCEPT for release of Task 1 only.**

This accepts the committed amended plan `4f065eb`, not an implementation and
not release of Task 2, VD2-07, or VD2-08. The contacts fixtures are correctly
defined as Task 1 deliverables rather than a circular precondition.

## Evidence reviewed

- Approved design: `docs/superpowers/specs/2026-07-31-vd206-contacts-master-detail-design.md`.
- Amended plan and task brief in full:
  `docs/superpowers/plans/2026-07-31-vd206-contacts-master-detail.md` and
  `docs/delivery/task-briefs/VD2-06-contacts-master-detail.md`.
- Current fixture seam: `RekonVisualTheme.swift:1230-1239`, `1669-1770`, and
  `1875-1999`; current host tests; and UI launcher
  `RekonPursuitUITests.swift:1-35,340-380`.
- Current contact model/store behavior: `WorkspaceViewModel.swift:932-1076`,
  `1984-2032`; `WorkspaceStore.swift:488-549`; and closed-database behavior
  in `EncryptedDatabase.swift:81-102,178-189`.
- The shared `RekonPursuit` scheme. Its TestAction includes
  `RekonPursuitTests`, `RekonPursuitUITests`, and
  `RekonPursuitUITestHostTests`; the latter has
  `RekonPursuitUITestHost` as its test target. `xcodebuild -list` confirms the
  project targets and this shared scheme.

## Basis for acceptance

1. **Task ordering is now valid.** The actual host deliberately has no
   `contacts`/`contacts-empty` fixture today: `VisualFixtureID` contains only
   the existing fixtures, and existing seeding creates no contacts. The
   amended Task 1 now creates, inventories, isolates, and relaunch-proves the
   two missing ready encrypted fixtures before asking the UI RED contracts to
   run. Task 2 is explicitly blocked behind a fresh QA re-review of those
   results.

2. **The fixture evidence is sufficient and bounded.** The existing host
   already owns a fixed clock, UUID-qualified temporary root, dedicated
   Keychain namespace, cleanup guards, and relaunch retention. The planned
   labels and link matrix let tests select durable fixture semantics without
   relying on generated IDs or personal data. A ready `contacts-empty` fixture
   correctly distinguishes an empty Contacts UI from the current onboarding
   `empty` fixture.

3. **The proposed store-failure layer is feasible and proportionate.** A
   closed `WorkspaceStore` produces a deterministic `Database is closed`
   failure. `createContact` and `saveSelectedContact` retain their draft and
   set `contactSaveError`; Link/Unlink retain the association and set truthful
   `statusMessage` failure text. The store operations are transactional, and a
   newly opened `WorkspaceSession` can reopen the unchanged encrypted database
   to prove no mutation. This proves real command-boundary failure behavior
   without adding a VD2-06-only production option, failure hook, schema
   variant, or destructive database manipulation. Validation UI evidence then
   exercises the same scoped accessible error rendering surface, while source
   review and the signed manual matrix cover the status-backed association
   path.

4. **The responsive/accessibility evidence is now focused.** Separate wide,
   compact/focus-return, AX-label/value, keyboard, and truthful-state contracts
   avoid a slow all-in-one AppKit test. Reserving larger accessibility text and
   actual VoiceOver announcements for signed manual QA/owner review is correct:
   AX automation can assert elements, values, focus, and reachability, but
   cannot prove spoken VoiceOver announcements. The plan still requires those
   manual checks before owner acceptance.

5. **The selectors and commands are feasible.** The named future test methods
   can be addressed through the single shared `RekonPursuit` scheme because it
   includes all three test bundles and builds the UI test host dependency. The
   commands use supported macOS/arm64 destinations and avoid an unsigned app
   launch. Fixture labels, semantic menu discovery, test-owned UUID sessions,
   and named-state waits are appropriate controls against flake.

## Residual risks and mandatory Task 1 evidence discipline

- Closing a store proves an unavailable connection, not every possible I/O or
  mid-transaction fault. This is acceptable for this presentation slice only
  because the store methods already transact and Task 1 must reopen a fresh
  encrypted workspace and compare persisted contacts, links, and audit events.
- A closed store instance cannot be used for the post-failure read assertion.
  Each low-layer test must capture its baseline, close the original store,
  dispatch exactly one command, then create a **fresh** store/model against the
  same encrypted workspace for no-write/relaunch assertions. It must not read
  through the old closed model/store cache.
- UI validation proves the shared error view is accessible, but not that a UI
  test can inject every persistence failure. Before Task 2 is accepted, QA and
  code review must trace `contact-operation-error` to both the
  `contactSaveError` create/update path and the `statusMessage` Link/Unlink
  path, and Task 4's signed manual matrix must retain the corresponding
  recovery/association checks.
- Task 1 must retain its precise RED/green distinction: host inventory and
  low-layer selectors are GREEN; UI selectors may be RED only after the signed
  host launches, Contacts is reached, and the reported failure is a missing
  VD2-06 presentation state or identifier. Fixture, signature, route, parser,
  or inventory failure is a blocker, not RED evidence.

## Exact Task 1 release condition

Delivery may release **only Task 1** when all of the following are recorded:

1. Product-owner-approved design plus the amended plan/brief are the
   controlling artifacts, and independent Architecture, TPM, QA (this gate),
   and Delivery approvals are recorded.
2. The released file scope is limited to the four Task 1 files named in the
   plan. No `ContactsView`, `ContentView`, schema, production launch option,
   persistence-failure hook, delivery-status artifact, VD2-07, or VD2-08 work
   is included.
3. The implementer follows the exact Task 1 selectors and preserves signed
   Debug evidence: host inventory/relaunch and low-layer contracts GREEN; UI
   RED reaches Contacts and is presentation-only; fixture/session UUIDs,
   result bundles, built paths, and `codesign` verification are retained for
   the next gate.
4. **Task 2 remains blocked** until a fresh independent QA reviewer reviews
   Task 1 source and evidence, confirms the fixture inventory/isolation/
   relaunch and closed-store no-write/audit proof, confirms the precise signed
   Contacts-reaching UI RED, and Architecture, TPM, and Delivery separately
   authorize continuation.

No acceptance of a signed build, successor work, or broad campaign follows
from this pre-implementation decision.
