# VD2-07x Task 2 — TPM implementation release

**Date:** 2026-08-01
**Role:** Independent TPM
**Verdict:** **NEEDS CHANGE — hold the fresh Task 2 implementer until an independent QA planning-release acceptance and Delivery release are recorded.**

## Current delivery state

VD2-07x is **in progress**. VD2-08 remains blocked behind its full
acceptance. The product-owner decision in
`docs/delivery/task-briefs/VD2-07x-vd208-accessibility-deferral-addendum.md`
is controlling for this release decision: the exact local Settings
keyboard-focus / Tab / Space handoff observations and the AI informational
text role/label/value observation are VD2-08 work. They neither block the
approved VD2-07x visual implementation nor permit changes to, skips of, or
weakening of their existing tests.

## Gate assessment

| Gate | Evidence | TPM assessment |
| --- | --- | --- |
| Approved bounded design and task brief | `docs/superpowers/plans/2026-08-01-vd207-reference-faithful-recovery-screen.md` Task 2 and `docs/delivery/task-briefs/VD2-07x-reference-faithful-settings.md` specify the four Settings surfaces, root-owned filename-only success dialog, pointer-selection coverage, AI visual/content boundary check, visual evidence, and unchanged global rail. | Ready. |
| Architecture | `docs/delivery/reviews/VD2-07x-visual-architecture-release-2026-08-01.md` is **ACCEPT** for the constrained visual implementation. | Ready. |
| Security/privacy | `docs/delivery/reviews/VD2-07x-visual-security-privacy-release-2026-08-01.md` is **ACCEPT** for the constrained visual implementation. | Ready. |
| Task 1 contract consumed by Task 2 | The current seam is limited to a filename-only protected-export event, token/store lifetime checks, and root projection. The fixed archive instant remains `2025-05-06T12:00:00Z`. Final Task 1/Task 2 result and hunk-isolation evidence remains an acceptance gate. | Sufficient to define the bounded visual slice; still required for final acceptance. |
| Independent QA planning release | `docs/delivery/reviews/VD2-07x-visual-qa-release-2026-08-01.md` records **NEEDS CHANGE**. Its listed missing surfaces, dialog, focused tests, matrix, and screenshots are expected Task 2 implementation outputs, but the record is not an independent QA acceptance to release the plan. | **Open.** A fresh QA planning-release decision must verify that the test-first Task 2 brief can produce those outputs without changing the three deferred tests. |
| Delivery release | No independent Delivery decision releasing Task 2 is recorded. | **Open.** |

## Required correction before implementation starts

Record a fresh, independently authored QA **planning-release** decision that
reviews the Task 2 test-first scope rather than requiring Task 2's finished UI
as a precondition. It must retain these non-negotiable conditions:

1. The two compact-keyboard tests and the Document/AI accessibility test stay
   unchanged, run, and are reported as VD2-08 evidence only for their exact
   permitted semantic failures.
2. Task 2 adds separate compact pointer-selection coverage for all four local
   tabs and a focused AI visual/content-boundary test; neither relies on the
   carried accessibility observations.
3. Every other fixture date, export/root safety, rail/route, safe-content,
   aggregate/no-control/privacy, visual composition, and real-success-dialog
   failure remains a VD2-07x blocker.
4. A separate Delivery Manager then records the dependency-safe Task 2
   release for a fresh implementer.

No source, test, fixture, dashboard, index, or project-config change is
authorized by this TPM record.

## Downstream sequencing

Once the two open release gates are recorded, one fresh implementer may take
only Task 2. Task 3 remains held for the signed matrix classification, visual
attachments, ordinary real-export dialog evidence, signing verification,
isolated-diff review, independent post-implementation approvals, and
product-owner handoff. VD2-08 is not released by this decision.
