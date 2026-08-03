# VD2-07x owner-feedback visual amendment

**Date:** 2026-08-01
**Status:** Approved owner correction; implementation must meet it before Task 2 visual acceptance.
**Scope:** Documentation amendment only. No source, tests, dashboard, roadmap,
fixture, behavior, or accessibility-deferral change is authorized by this
record.

## Controlling decision

The product owner identified two mismatches in the current visual output. This
record amends the controlling VD2-07x design, Task 2 brief, and implementation
plan so a fresh implementer and reviewers share one unambiguous target.

1. **Protected-export success dialog:** Match the supplied reference's centered,
   elevated dark panel and its hierarchy: emerald circular check; `Protected
   copy exported`; confirmation; a bordered, divided two-row facts group; the
   non-secret recovery-key reminder; and one full-width blue-to-violet `Done`
   action. The two facts are limited to `Exported file` / safe filename and
   `Saved to` / `Selected local folder`. Root ownership and real-success-only
   presentation are unchanged.
2. **Compact Settings selector:** The wide selector retains its reference cyan
   bottom rule. The compact vertical selector must not render that underline.
   Its selected complete row instead uses a restrained cyan-tinted rounded
   surface with cyan icon/text. The selectors retain their existing pointer,
   selected/non-selected, keyboard, and accessibility semantics.

## Required visual evidence

- Review a signed-host `VD2-07x-wide-recovery` capture against the wide
  reference.
- Review a named compact capture with a selected local-section row against the
  compact treatment; it must show the rounded cyan row and no detached
  underline.
- After a real successful export in the signed normal Debug app, review the
  success dialog against the reference hierarchy. It must show only the safe
  filename and `Selected local folder`.
- Every reviewed capture is limited to the app window. Do not include the
  desktop, Finder, another app, file chooser, recovery key, raw path, or
  document metadata.

## Artifact changes authorized by this amendment

- `docs/superpowers/specs/2026-08-01-vd207-reference-faithful-recovery-screen-design.md`
- `docs/delivery/task-briefs/VD2-07x-reference-faithful-settings.md`
- `docs/superpowers/plans/2026-08-01-vd207-reference-faithful-recovery-screen.md`

The VD2-08 accessibility deferral remains unchanged. This amendment neither
reclassifies its carried keyboard/AI assertions nor authorizes a product
Kanban/dashboard change.
