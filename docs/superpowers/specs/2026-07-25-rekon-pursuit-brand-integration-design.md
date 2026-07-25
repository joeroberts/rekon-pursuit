# Rekon Pursuit brand integration design

## Purpose

Give the native macOS app a recognizable Rekon Pursuit identity without
changing any job-tracker workflow, local-data behavior, or pending R2 work.

## Approved direction

Use the existing Rekon Pursuit artwork in `design/assets/` as the source of
truth. Do not create a second logo or introduce a letter-mark.

### macOS app icon

- Derive a square icon from the existing left-side target-and-arrow emblem.
- Keep the blue, cyan, and violet gradient and a near-black/navy background.
- Remove the horizontal wordmark, divider, and `Pursuit` lettering.
- Simplify loose pixel fragments only where needed for legibility at small
  Finder/Dock sizes.
- Produce a macOS `AppIcon` asset catalog with the required raster sizes from
  one 1024-pixel master.

### In-app brand treatment

- Display the existing full horizontal Rekon Pursuit logo in the expanded
  sidebar header.
- Use the compact emblem only where the full mark cannot fit.
- Preserve the current shell structure, navigation, and content. This is a
  brand pass, not a UX redesign.

## Boundaries

- No data model, migration, importer, workspace, entitlement, network, or
  activity-event changes.
- No new product capability and no revision to the approved mockup flows.
- Do not begin implementation until the active R2 corrective pass is accepted
  and the remediation ledger explicitly releases this separate brand task.

## Acceptance

- The app uses the new AppIcon in Dock/Finder builds.
- The sidebar uses the full brand mark without clipping at the supported
  compact desktop size.
- The compact emblem remains recognizable at small UI sizes.
- Existing R2 and earlier focused checks remain unaffected.
