#!/usr/bin/env bash
# Builds and launches an ad-hoc-signed, sandboxed R1a smoke app. Its compiled
# bundle ID makes both its Keychain service and sandbox container distinct from
# the production app. It never modifies production namespaces.
set -euo pipefail

if [[ $# -ne 1 ]]; then
  printf 'usage: %s <repository-root>\n' "${0##*/}" >&2
  exit 64
fi

repo_root="$(cd "$1" && pwd)"
smoke_suffix="$(uuidgen | tr -d '-' | cut -c1-12)"
smoke_id="com.rekonlabs.RekonPursuit.RPR1aSmoke${smoke_suffix}"
smoke_name="RekonPursuitRPR1aSmoke${smoke_suffix}"
smoke_root="$(mktemp -d "${TMPDIR:-/tmp}/rekon-r1a-smoke.XXXXXX")"
derived_data="$smoke_root/DerivedData"
production_id="com.rekonlabs.RekonPursuit"

# Fingerprints are intentionally one-way hashes of existence plus file content.
# The script never prints the production locations, their metadata, or their
# contents. There are two known historical locations: the sandboxed location
# and an earlier non-sandboxed location.
fingerprint_workspace() {
  local location="$1"
  if [[ ! -e "$location" ]]; then
    printf 'absent' | shasum -a 256 | awk '{print $1}'
    return
  fi
  {
    printf 'present:'
    shasum -a 256 "$location" | awk '{print $1}'
  } | shasum -a 256 | awk '{print $1}'
}

keychain_record_present() {
  local record_kind="$1"
  local production_service="${production_id}.workspace"
  local account=""
  case "$record_kind" in
    primary) account="primary-workspace-key" ;;
    pending) account="pending-workspace-key" ;;
    *) printf 'invalid keychain record kind\n' >&2; return 64 ;;
  esac
  if security find-generic-password -s "$production_service" -a "$account" >/dev/null 2>&1; then
    printf 'true'
  else
    printf 'false'
  fi
}

legacy_workspace="$HOME/Library/Application Support/RekonLabs/RekonPursuit/workspace.sqlite"
sandbox_workspace="$HOME/Library/Containers/$production_id/Data/Library/Application Support/RekonLabs/RekonPursuit/workspace.sqlite"
legacy_before="$(fingerprint_workspace "$legacy_workspace")"
sandbox_before="$(fingerprint_workspace "$sandbox_workspace")"
primary_before="$(keychain_record_present primary)"
pending_before="$(keychain_record_present pending)"

xcodebuild build \
  -project "$repo_root/RekonPursuit.xcodeproj" \
  -scheme RekonPursuit \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$derived_data" \
  PRODUCT_NAME="$smoke_name" \
  PRODUCT_BUNDLE_IDENTIFIER="$smoke_id" \
  CODE_SIGN_IDENTITY='-' \
  CODE_SIGNING_ALLOWED=YES \
  -quiet

smoke_app="$derived_data/Build/Products/Debug/$smoke_name.app"
compiled_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$smoke_app/Contents/Info.plist")"
if [[ "$compiled_id" != "$smoke_id" ]]; then
  printf 'ERROR: temporary app bundle ID was not compiled as expected\n' >&2
  exit 1
fi

if ! codesign -d --entitlements :- "$smoke_app" 2>&1 | grep -q 'com.apple.security.app-sandbox'; then
  printf 'ERROR: temporary app is not sandboxed\n' >&2
  exit 1
fi

# Launches only the uniquely named temporary process. The first-run screen is
# intentionally inspected by the operator; no production app or namespace is
# launched, read, or modified by this command.
open -n "$smoke_app"
sleep 2

temporary_container_present=false
if [[ -d "$HOME/Library/Containers/$smoke_id" ]]; then
  temporary_container_present=true
fi
if [[ "$temporary_container_present" != true ]]; then
  printf 'ERROR: temporary sandbox container was not created\n' >&2
  exit 1
fi
legacy_after="$(fingerprint_workspace "$legacy_workspace")"
sandbox_after="$(fingerprint_workspace "$sandbox_workspace")"
primary_after="$(keychain_record_present primary)"
pending_after="$(keychain_record_present pending)"
legacy_unchanged=false
sandbox_unchanged=false
primary_unchanged=false
pending_unchanged=false
[[ "$legacy_before" == "$legacy_after" ]] && legacy_unchanged=true
[[ "$sandbox_before" == "$sandbox_after" ]] && sandbox_unchanged=true
[[ "$primary_before" == "$primary_after" ]] && primary_unchanged=true
[[ "$pending_before" == "$pending_after" ]] && pending_unchanged=true

printf 'namespace=%s\n' "$smoke_id"
printf 'sandbox_entitlement=true\n'
printf 'temporary_container_present=%s\n' "$temporary_container_present"
printf 'production_legacy_workspace_unchanged=%s\n' "$legacy_unchanged"
printf 'production_sandbox_workspace_unchanged=%s\n' "$sandbox_unchanged"
printf 'production_primary_key_record_unchanged=%s\n' "$primary_unchanged"
printf 'production_pending_key_record_unchanged=%s\n' "$pending_unchanged"
printf 'temporary_artifacts_created=true\n'

if [[ "$legacy_unchanged" != true || "$sandbox_unchanged" != true || "$primary_unchanged" != true || "$pending_unchanged" != true ]]; then
  printf 'ERROR: a production namespace changed during isolated smoke\n' >&2
  exit 1
fi
