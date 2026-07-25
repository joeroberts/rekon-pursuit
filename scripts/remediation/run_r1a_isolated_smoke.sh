#!/usr/bin/env bash
# Builds and launches an ad-hoc-signed, sandboxed R1a smoke app. Its compiled
# bundle ID makes both its Keychain service and sandbox container distinct from
# the production app. It never reads or modifies production namespaces.
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
printf 'namespace=%s\n' "$smoke_id"
printf 'sandbox_entitlement=true\n'
printf 'temporary_container_present=%s\n' "$temporary_container_present"
printf 'temporary_artifacts_created=true\n'
