# RP-R5 — User-initiated public URL check

**State:** Next up — planning/privacy gate in progress  
**Depends on:** `RP-R4` accepted  
**Serial successor:** `RP-R6` remains unreleased until R5 is accepted; this does
not redefine R6's stored-data dependency contract.  
**Implementation release requires:** Planning, Architect, Security/Privacy, TPM,
QA, and Delivery approval of this brief.

## Outcome

For one active opportunity, the user may explicitly select **Check public URL**.
The app makes one bounded HTTPS request, stores only limited technical evidence,
and routes every ambiguous or unsafe result to a local manual-review task. It
never closes an opportunity automatically.

## Fixed product decisions

- Checks are manual, one-shot, and user-initiated. There is no polling,
  automatic retry, launch-time request, provider fallback, browser rendering,
  or background operation.
- HTTPS on port 443 is the only transport. Existing `http` URLs remain local
  records but result in manual review without a request; R5 adds no ATS
  exception. This is an explicit safety narrowing of the historical
  `http`/`https` local-record scope.
- Redirects are never followed. A `3xx` response or HTML meta-refresh is
  `Needs manual review / Ambiguous / Changed URL`; its safe, redacted target is
  evidence only.
- No result changes an opportunity stage. The existing explicit R4 closure
  confirmation remains the only operation that may close an opportunity.

## Boundaries

R5 adds one direct check path only. It does not add AI, Gmail, Calendar,
research providers, document handling, scripts, WebKit, crawling, login,
cookies, account credentials, uploads, external analytics, or scheduled work.
No raw HTML, arbitrary headers, resolved IP addresses, query values, or raw
transport errors are written to routine activity/diagnostic records.

## Request and public-destination contract

1. Re-validate the saved URL at tap time. Require absolute `https`, a DNS host,
   no userinfo/control characters/backslashes, no numeric-host ambiguity, and
   port 443. Reject hosts already forbidden by R4, `.local`, single-label hosts,
   literal non-public addresses, credential-like query keys (`password`,
   `token`, `auth`, `session`, `signature`, `key`, `code`, `credential`),
   LinkedIn, and Glassdoor. Preserve the saved URL unchanged; do not strip or
   rewrite it.
2. Resolve A/AAAA records immediately before transport. If any answer is
   loopback, private, link-local, CGNAT, ULA, multicast, documentation,
   benchmark, reserved, unspecified, or otherwise non-global, record manual
   review with no request.
3. `PublicURLTransport` uses one `NWConnection` to a selected validated IP
   address, with TLS SNI and an explicit `SecPolicyCreateSSL(true, hostname)`
   trust check for the original hostname. It verifies trust before sending HTTP
   bytes and sends the GET over that same connection. It does not fall back to
   `URLSession`. If peer binding or hostname trust cannot be proven, including
   because a system proxy intervenes, it fails closed to manual review.
4. Use exactly one bodyless `GET`: ephemeral configuration, no cache, cookie
   store, credential store, shared/background session, persistent transport
   data, request body, `Authorization`, `Proxy-Authorization`, `Cookie`,
   `Referer`, client certificate, or user-derived headers. Send only a generic
   product/version User-Agent, narrow HTML/XHTML/plain-text Accept values, and
   an optional bounded Range request.
5. Platform TLS trust and hostname validation are mandatory. Cancel all auth,
   proxy, and client-certificate challenges. Do not implement trust bypass,
   custom pinning, or an ATS exception.
6. The HTTP parser treats every `3xx` response as terminal. Resolve a relative
   `Location` only for local evidence display, validate it without connecting,
   and never open or fetch it from R5.
7. Use a 10-second request timeout, 15-second wall-clock deadline, 512 KiB
   decoded-body cap, two global concurrent checks, and no application retry.
   Stop/cancel if a server ignores Range and received bytes reach the cap.

## Durable state and lifecycle

- v20 creates `reconciliation_check_operations` with `id`, `opportunity_id`,
  `correlation_id`, `url_snapshot`, `state`, `started_at`, and `terminal_at`;
  `correlation_id` is unique. It adds non-null-or-null-as-applicable columns to
  `reconciliation_results`: `check_operation_id`, `method`, `checker_version`,
  `http_status`, `mime_type`, `declared_bytes`, `received_bytes`,
  `content_sha256`, `response_date`, `last_modified`, `etag`, `retry_after`,
  `redirect_target_redacted`, `evidence_excerpt`, and `redacted_error_code`.
  The migration is atomic, retains every v19 row unchanged with null v20 fields,
  and has injected-failure rollback evidence.
- Persist a local `started` operation with a correlation ID before transport;
  run DNS/network work outside `WorkspaceStore` locks and SQLite transactions.
- Allow one in-flight operation per opportunity and host. A repeat tap surfaces
  the active operation instead of sending another request.
- Terminal operation states are `completed`, `failed`, `cancelled`, and
  `interrupted`. On launch, abandoned `started` work becomes `interrupted`; it
  is never retried automatically.
- Exact durable-header allowlist is `Date`, `Last-Modified`, `ETag`,
  `Retry-After`, and redirect `Location` only. The redirect field retains at
  most normalized scheme, host, and a 256-character path after removing
  userinfo/query/fragment. It never retains raw page content, cookies,
  arbitrary headers, subresources, resolved IPs, or query values.
- A valid URL that fails HTTPS eligibility, prohibited-source, DNS, or
  peer-proof preflight writes a terminal failed/offline result and one
  deduplicated review task. A malformed URL rejected before operation creation
  writes nothing. Cancellation/interruption writes terminal operation evidence
  and manual review for an active opportunity. Deleted/stale work writes only a
  redacted operation tombstone and never an active result/task.
- Before completion commits, revalidate operation identity, URL snapshot,
  active opportunity, and deletion state. Opportunity deletion cancels active
  transport and preserves only permitted redacted operation/tombstone evidence.

## Result mapping

| Condition | Stored result |
| --- | --- |
| Known offline before dispatch | `Needs manual review / Offline unchecked / Offline — check not run`; no request. |
| Unsafe URL/DNS/public-peer proof unavailable | `Needs manual review / Failed / Source failed`; no request. |
| `3xx` or meta refresh | `Needs manual review / Ambiguous / Changed URL`; record redacted target; never follow or open it. |
| `401`, `403`, `407`, `429`, `451`, login/captcha/WAF/robots | `Needs manual review / Failed or Ambiguous / Access blocked`. |
| `404`, `410` | `Possibly closed / Ambiguous`; never infer closure from status alone. |
| `5xx`, TLS/DNS error, timeout, malformed/oversized/unsupported response, parse failure | `Needs manual review / Failed / Source failed`. |
| `2xx` with the exact active marker contract below | `Still open / Confirmed`. |
| `2xx` with the exact closure marker contract below | `Closed suggested`; explicit R4 confirmation still required. |
| Any other `2xx` | `Needs manual review / Ambiguous`; `200 OK` alone is not proof. |

### Version 1 classifier contract

The bounded in-memory parser accepts UTF-8 HTML/XHTML/plain text only, strips
markup without executing it, collapses Unicode whitespace, and evaluates at
most 512 KiB. `Still open` or `Closed suggested` requires exact normalized
opportunity-title identity or a saved stable requisition ID in visible text;
otherwise the result is Ambiguous. A title identity plus one of these active
markers is `Still open`: `apply now`, `apply for this job`, `submit
application`, `submit your application`. A title identity plus one of these
closure markers is `Closed suggested`: `this job is no longer available`,
`position has been filled`, `job has expired`, `applications are no longer
being accepted`. Both marker classes, more than one incompatible title, a
truncated body, a script/JSON-only match, or any unmatched marker is
Ambiguous/manual review. Persist at most the 512-character normalized visible
text window centered on the matching marker and its SHA-256; no body is stored.
An HTML meta refresh is recognized only by a literal `meta` refresh directive
in the parsed initial markup and is always Changed URL.

## User flow

- The selected opportunity shows **Check public URL** only for an active record
  with a R4-valid saved URL. While active, it shows Checking and allows Cancel.
- The result panel makes clear what was checked, what was not checked, status,
  timestamp, limited evidence, confidence, and linked review task. The existing
  R4 **Open job posting** action remains the only browser handoff.
- Retry is a new explicit tap. A confirmed Still open result may resolve the
  outstanding reconciliation review task; all ambiguous/failed/offline paths
  retain or create one active manual-review task.

## Focused verification

Use deterministic resolver and transport fixtures only; no live internet
request is an acceptance test. Prove:

1. Explicit public HTTPS active evidence records Still open without stage
   mutation.
2. Explicit closure wording produces Closed suggested and requires existing
   explicit confirmation.
3. Redirect cancellation makes exactly one request, stores redacted target,
   and creates manual review.
4. Offline, unsafe DNS, auth/access, rate limit, 404/410, `5xx`, TLS/DNS,
   timeout, oversized/unsupported response, cancellation, interruption,
   URL change, and logical deletion map as specified with no unintended task or
   stage mutation.
5. No cookies, credentials, auth challenge, script, automatic redirect, or
   request occurs where forbidden; response persistence/diagnostics are
   allowlisted and redacted.
6. Relaunch retains terminal evidence/outcome/task state, while startup remains
   responsive with a pending fixture transport.
7. Build inspection proves only the app network-client entitlement is added,
   with no ATS exception, server/local-network, or helper entitlement.
8. Product-owner smoke: explicit check → evidence/history → manual review or
   Still open → optional explicit closure confirmation.

## Release rule

R5 remains **Next up** until Architect and Security/Privacy approve the
resolver/transport feasibility and privacy boundary, QA accepts the fixture
strategy, TPM confirms scope/order, and Delivery records release. Only then may
the dashboard transition `RP-R5: Next up → In progress` and implementation
begin. R6 and all other successors remain unreleased.
