#!/usr/bin/env bash
# Enforces the bootstrap's exact entitlement allowlist and, when supplied,
# inspects the entitlements and Hardened Runtime flag on an ad-hoc app.
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  printf 'usage: %s <repository-root> [signed-app]\n' "${0##*/}" >&2
  exit 64
fi

repo_root="$(cd "$1" && pwd)"
declared_plist="${repo_root}/RekonPursuit/RekonPursuit.entitlements"

if [[ ! -f "${declared_plist}" ]]; then
  printf 'MISSING: entitlement declaration: RekonPursuit/RekonPursuit.entitlements\n' >&2
  exit 1
fi

prohibited_entitlements=(
  com.apple.security.network.client
  com.apple.security.network.server
  com.apple.security.application-groups
  com.apple.security.temporary-exception.apple-events
  com.apple.security.automation.apple-events
  com.apple.security.accessibility
  com.apple.security.device.camera
  com.apple.security.device.audio-input
  com.apple.security.personal-information.addressbook
  com.apple.security.personal-information.calendars
  com.apple.security.personal-information.location
  com.apple.security.privileged-helper
  com.apple.developer.system-extension.install
  com.apple.security.cs.allow-jit
  com.apple.security.cs.allow-unsigned-executable-memory
  com.apple.security.cs.disable-library-validation
  com.apple.security.cs.allow-dyld-environment-variables
  com.apple.security.get-task-allow
  keychain-access-groups
)

is_prohibited() {
  local candidate="$1"
  local denied
  for denied in "${prohibited_entitlements[@]}"; do
    if [[ "${candidate}" == "${denied}" ]]; then
      return 0
    fi
  done
  return 1
}

check_plist_allowlist() {
  local plist_path="$1"
  local label="$2"
  local keys
  local key
  local failures=0

  if ! plutil -lint "${plist_path}" >/dev/null; then
    printf 'ERROR: invalid entitlement plist: %s\n' "${label}" >&2
    return 1
  fi

  keys="$(plutil -p "${plist_path}" | awk -F'"' '/=>/{print $2}')"
  while IFS= read -r key; do
    [[ -z "${key}" ]] && continue
    if [[ "${key}" == "com.apple.security.app-sandbox" ]]; then
      continue
    fi
    if is_prohibited "${key}"; then
      printf 'ERROR: prohibited entitlement: %s\n' "${key}" >&2
    else
      printf 'ERROR: entitlement is outside the M0 allowlist: %s\n' "${key}" >&2
    fi
    failures=1
  done <<<"${keys}"

  if ! /usr/libexec/PlistBuddy \
    -c 'Print :com.apple.security.app-sandbox' "${plist_path}" 2>/dev/null \
    | grep -Fxq 'true'; then
    printf 'ERROR: App Sandbox entitlement is missing or false: %s\n' \
      "${label}" >&2
    failures=1
  fi

  return "${failures}"
}

check_plist_allowlist "${declared_plist}" "declared entitlements"

if [[ $# -eq 2 ]]; then
  signed_app="$2"
  if [[ ! -d "${signed_app}" ]]; then
    printf 'MISSING: signed app for entitlement inspection: %s\n' \
      "${signed_app}" >&2
    exit 1
  fi

  codesign --verify --strict "${signed_app}"
  signature_details="$(codesign -dvv "${signed_app}" 2>&1)"
  if ! grep -Eq 'flags=.*runtime' <<<"${signature_details}"; then
    printf 'ERROR: Hardened Runtime flag is absent from the ad-hoc app\n' >&2
    exit 1
  fi
  if ! grep -Fxq 'Signature=adhoc' <<<"${signature_details}"; then
    printf 'ERROR: local validation app must use an ad-hoc signature\n' >&2
    exit 1
  fi
  if ! grep -Fxq 'TeamIdentifier=not set' <<<"${signature_details}"; then
    printf 'ERROR: local validation app unexpectedly uses a team identity\n' >&2
    exit 1
  fi

  entitlement_output="$(codesign -d --entitlements :- "${signed_app}" 2>&1)"
  if [[ "${entitlement_output}" != *"<?xml"* ]]; then
    printf 'ERROR: codesign did not return machine-readable entitlements\n' >&2
    exit 1
  fi

  signed_plist="$(mktemp "${TMPDIR:-/tmp}/rekon-pursuit-entitlements.XXXXXX")"
  trap 'unlink "${signed_plist}" 2>/dev/null || true' EXIT
  printf '<?xml%s\n' "${entitlement_output#*<?xml}" >"${signed_plist}"
  check_plist_allowlist "${signed_plist}" "signed app entitlements"
fi

printf 'Entitlement allowlist and runtime checks passed.\n'
