# VD2-04 scope decision — Closed visibility

**Date:** 2026-07-30  
**Decision owner:** Product owner  
**Status:** Approved before VD2-04 implementation

## Decision

VD2-04 is authorized to remove the obsolete global **Show closed
opportunities** Settings control and its `UserDefaults`-backed model state.
Pipeline will instead own the sole Closed-record visibility control as local,
ephemeral session state. No other Settings redesign is approved by this
decision.

## Rationale and boundary

The architect's state-boundary contract requires Pipeline filters to be local
presentation state. Retaining a persisted global preference either creates a
misleading Settings control with no effect or reintroduces a hidden global
input to Pipeline. Retiring that one obsolete control leaves one truthful
source of visibility state.

This authorization is expressly limited to the control, its backing
preference/state, and direct supporting tests/copy. VD2-07 exclusively owns
all other Settings information architecture, grouping, controls, and visual
redesign. It does not authorize a schema migration, new preference, unrelated
Settings change, or a broader behavioral redesign.

## Delivery effect

The decision resolves VD2-04's product-scope gate but does not release
implementation. Planning, architecture, TPM, QA, and Delivery Manager gates
remain required before a fresh implementer starts the serial card.
