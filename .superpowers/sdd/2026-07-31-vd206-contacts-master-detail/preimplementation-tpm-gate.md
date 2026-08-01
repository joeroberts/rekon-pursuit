# VD2-06 Pre-Implementation TPM Gate

## Verdicts

- **Plan/dependency readiness: ACCEPT.** The amended plan and brief at `4f065ebbf890549990e3fbc3be49fb72c801fbff` are bounded, dependency-safe, proportionately verified, and ready for Delivery to release Task 1 after all required pre-implementation gates are recorded.
- **Delivery release status: UNRELEASED.** This TPM acceptance is not an implementation release. VD2-06 remains Backlog until independent QA accepts the amended plan/brief and Delivery records the owner, Architecture, TPM, QA, and Delivery gates and releases Task 1 only.

## Controlling Evidence

- The product owner explicitly directed the team to move forward with VD2-06 on 2026-07-31, approved the adaptive read-first split and every design section, and approved the persisted design specification at `10abc664fdb76f6d4ea502a0e0b46a4afa083ed9`.
- The planning baseline was recorded at `d915e9d0b76cae3d68e3a8756c95f78512c57222`; commit `4f065ebbf890549990e3fbc3be49fb72c801fbff` amends only the VD2-06 plan and task brief to tighten the test foundation and gates.
- VD2-02, the recorded predecessor for VD2-06, is accepted. VD2-05 is accepted, but its handoff correctly does not release successor work.
- The roadmap and dashboard correctly remain unchanged during pre-gate review: VD2-06, VD2-07, and VD2-08 are Backlog, with no active or next-eligible task.

## Task and Dependency Assessment

### Task 1 — bounded test foundation

Task 1 is a coherent first releasable slice. It modifies only four named test/test-host files and creates exactly two test-only fixtures: `contacts` and `contacts-empty`. The fixtures retain the existing signed host's fixed clock, encrypted UUID-session root, Keychain isolation, and relaunch behavior. Stable labels replace generated record IDs, personal workspace data is prohibited, and no production failure hook, launch argument, schema option, direct database damage, or larger-text test infrastructure is introduced.

Verification is correctly layered:

- host inventory, isolation, encryption, association matrix, and relaunch selectors must be GREEN;
- focused low-layer selection/draft/no-write, validation, closed-store failure recovery, audit, deletion cleanup, and relaunch contracts run before presentation work, recording existing correct behavior as GREEN rather than fabricating RED;
- signed UI selectors must reach Contacts and be RED only for missing VD2-06 presentation identifiers or states.

Signing, fixture inventory, route-to-Contacts, host launch, or failure-seam problems are blockers, not acceptable RED evidence. The exact selectors, result bundles, session UUIDs, launch environment, executable paths, and signing verification are required evidence. This is proportional to the two-fixture foundation and does not expand into a broad regression campaign.

### Task 2 — non-circular evidence gate

Task 2 is correctly blocked on evidence that Task 1 first produces. A fresh QA reviewer must inspect Task 1 source and evidence and accept fixture isolation/inventory/relaunch, low-layer no-write/failure/audit proof, and the signed Contacts-reaching presentation-only RED. Architecture, TPM, and Delivery then independently decide continuation. The missing fixtures are therefore Task 1 deliverables, not preconditions to Task 1, and the Task 2 gate is post-evidence rather than circular.

### Tasks 3 and 4 — proportional completion path

Task 3 stays focused on deterministic Contacts behavior: isolated persistence/audit/destructive sessions, lowest-practical-layer store-failure proof, semantic UI waits, accessibility values, keyboard behavior, and responsive states. It explicitly reserves actual VoiceOver announcement and larger-text usability claims for signed manual review. Task 4 reruns the focused selectors, builds and verifies normally signed Debug artifacts, obtains fresh Code Review, QA, Architecture, and Security/Privacy acceptance, and then permits only a Delivery-authorized owner review.

Automated success cannot close VD2-06. Explicit product-owner acceptance of the signed Debug build is required, followed by Delivery's recorded acceptance.

## Escalation and Stop Boundaries

- Before Task 1 release: missing independent pre-implementation approval or Delivery aggregation stops implementation.
- During Task 1: host launch/signing, inventory, isolation, route-to-Contacts, or failure-seam defects stop the task and cannot be reported as valid UI RED.
- Before Task 2: QA rejection or incomplete Task 1 evidence returns the work to bounded Task 1 remediation; presentation implementation does not start.
- During Tasks 2–3: a changed fixture/inventory/signature failure returns to Task 1 remediation; an unstable selector is diagnosed in isolation; a model change is allowed only after focused low-layer evidence proves the existing public contract insufficient.
- Before owner review: any failed focused selector, signing verification, or independent final gate stops the handoff. Delivery alone authorizes the signed owner path.
- No task authorizes commits, dashboard/roadmap/status/evidence updates, unrelated source/configuration changes, or broad VD2-08 testing.
- VD2-07 remains blocked until explicit owner acceptance of the signed VD2-06 build and Delivery's recorded acceptance. VD2-08 remains outside this card and requires VD2-03 through VD2-07 accepted plus its own release.

## Required Actions Before Delivery Release

No plan or dependency correction is required.

1. Record independent QA ACCEPT for the amended plan and brief and any other required pre-implementation gate not yet recorded.
2. Delivery records the complete owner, Architecture, TPM, QA, and Delivery gate set.
3. Delivery releases **Task 1 only**. Tasks 2–4, VD2-07, and VD2-08 remain blocked by their stated successor gates.

## Exact Release Condition

Delivery may transition VD2-06 from Backlog and release only Task 1 after the approved owner direction/design and recorded independent Architecture, TPM, QA, and Delivery approvals for the amended plan and brief at `4f065ebbf890549990e3fbc3be49fb72c801fbff` are all present. Task 2 requires fresh independent QA acceptance of Task 1 source and the complete signed host-GREEN, focused low-layer, and Contacts-reaching presentation-only UI-RED evidence, followed by Architecture, TPM, and Delivery continuation approval. Task 3 requires Task 2 GREEN and Delivery release. Task 4 requires Task 3 GREEN plus independent reviewer, QA, Architecture, and Security/Privacy acceptance. VD2-06 closes only after explicit product-owner acceptance of the normally signed Debug build and Delivery's recorded acceptance; only then may VD2-07 be considered for a separate release, while VD2-08 remains separately gated.
