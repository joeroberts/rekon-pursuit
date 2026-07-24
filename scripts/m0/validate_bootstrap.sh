#!/usr/bin/env bash
# Validates the M0-3 native shell without signing identities, live services,
# external dependencies, or repository-local build products.
set -euo pipefail

local_only=0
static_only=0
ci_only=0
while [[ $# -gt 1 ]]; do
  case "$1" in
    --local-only)
      local_only=1
      ;;
    --static-only)
      static_only=1
      ;;
    --ci)
      ci_only=1
      ;;
    *)
      printf 'usage: %s [--local-only] [--static-only] [--ci] <repository-root>\n' \
        "${0##*/}" >&2
      exit 64
      ;;
  esac
  shift
done

if [[ $# -ne 1 ]]; then
  printf 'usage: %s [--local-only] [--static-only] [--ci] <repository-root>\n' \
    "${0##*/}" >&2
  exit 64
fi

repo_root="$(cd "$1" && pwd)"
script_dir="${repo_root}/scripts/m0"
project_path="${repo_root}/RekonPursuit.xcodeproj"
project_file="${project_path}/project.pbxproj"
failures=0

record_missing() {
  printf 'MISSING: %s\n' "$1" >&2
  failures=1
}

record_error() {
  printf 'ERROR: %s\n' "$1" >&2
  failures=1
}

if [[ ! -d "${project_path}" ]]; then
  record_missing "Xcode project: RekonPursuit.xcodeproj"
fi
if [[ ! -f "${project_file}" ]]; then
  record_missing "project build settings: RekonPursuit.xcodeproj/project.pbxproj"
fi
if [[ "${local_only}" -eq 0 \
  && ! -f "${repo_root}/.github/workflows/m0-bootstrap.yml" ]]; then
  record_missing "CI workflow: .github/workflows/m0-bootstrap.yml"
fi

for required_script in \
  build_unsigned_archive.sh \
  check_entitlements.sh \
  check_tracked_secrets.sh \
  test_workflow_policy.sh; do
  if [[ ! -x "${script_dir}/${required_script}" ]]; then
    record_missing "executable validation script: scripts/m0/${required_script}"
  fi
done

if [[ -f "${project_file}" ]]; then
  if ! build_settings="$(
    xcodebuild -project "${project_path}" \
      -target RekonPursuit \
      -configuration Release \
      -showBuildSettings 2>&1
  )"; then
    printf '%s\n' "${build_settings}" >&2
    record_error "xcodebuild could not inspect Release build settings"
  else
    setting_value() {
      local setting_name="$1"
      sed -n \
        "s/^[[:space:]]*${setting_name} = //p" <<<"${build_settings}" \
        | head -n 1
    }

    deployment_target="$(setting_value MACOSX_DEPLOYMENT_TARGET)"
    if [[ "${deployment_target}" != "14.0" ]]; then
      record_error \
        "unsupported deployment target: expected 14.0, found ${deployment_target:-<unset>}"
    fi

    architectures="$(setting_value ARCHS)"
    for required_arch in arm64 x86_64; do
      if [[ " ${architectures} " != *" ${required_arch} "* ]]; then
        record_error \
          "required architecture is absent from ARCHS: ${required_arch}"
      fi
    done

    if [[ "$(setting_value SWIFT_VERSION)" != "6.0" ]]; then
      record_error "SWIFT_VERSION must be explicit and equal to 6.0"
    fi
    if [[ "$(setting_value SWIFT_STRICT_CONCURRENCY)" != "complete" ]]; then
      record_error "SWIFT_STRICT_CONCURRENCY must equal complete"
    fi
    if [[ "$(setting_value ENABLE_APP_SANDBOX)" != "YES" ]]; then
      record_error "ENABLE_APP_SANDBOX must equal YES"
    fi
    if [[ "$(setting_value ENABLE_HARDENED_RUNTIME)" != "YES" ]]; then
      record_error "ENABLE_HARDENED_RUNTIME must equal YES"
    fi
    if [[ "$(setting_value CODE_SIGN_ENTITLEMENTS)" \
      != "RekonPursuit/RekonPursuit.entitlements" ]]; then
      record_error "Release target must use the reviewed entitlement file"
    fi
    if [[ "$(setting_value CODE_SIGN_INJECT_BASE_ENTITLEMENTS)" != "NO" ]]; then
      record_error \
        "Release target must disable injected debug/base entitlements"
    fi
  fi

  if grep -Eq \
    'XCRemoteSwiftPackageReference|XCLocalSwiftPackageReference|repositoryURL[[:space:]]*=' \
    "${project_file}"; then
    record_error "unapproved Xcode package dependency is present"
  fi
  if grep -Eq 'DEVELOPMENT_TEAM[[:space:]]*=[[:space:]]*[^;[:space:]]+' \
    "${project_file}"; then
    record_error "a development-team identifier is tracked in project settings"
  fi
fi

dependency_manifest="$(
  find "${repo_root}" -maxdepth 4 -type f \
    \( -name Package.swift -o -name Package.resolved -o -name Podfile \
    -o -name Podfile.lock -o -name Cartfile -o -name Cartfile.resolved \) \
    -print -quit
)"
if [[ -n "${dependency_manifest}" ]]; then
  record_error \
    "unapproved dependency manifest is tracked: ${dependency_manifest#${repo_root}/}"
fi

scope_matches="$(
  git -C "${repo_root}" grep -I -nE \
    '(^|[[:space:]])import[[:space:]]+(Network|CoreData|SwiftData)|URLSession|NWConnection|@Model|sqlite3_' \
    -- '*.swift' 2>/dev/null || true
)"
if [[ -n "${scope_matches}" ]]; then
  printf '%s\n' "${scope_matches}" >&2
  record_error "feature, persistence, or network code leaked into the bootstrap"
fi

if [[ -x "${script_dir}/check_entitlements.sh" ]]; then
  if ! "${script_dir}/check_entitlements.sh" "${repo_root}"; then
    failures=1
  fi
fi

if [[ -x "${script_dir}/check_tracked_secrets.sh" ]]; then
  if ! "${script_dir}/check_tracked_secrets.sh" "${repo_root}"; then
    failures=1
  fi
fi

if [[ "${local_only}" -eq 0 \
  && -f "${repo_root}/.github/workflows/m0-bootstrap.yml" \
  && -x "${script_dir}/test_workflow_policy.sh" ]]; then
  if ! "${script_dir}/test_workflow_policy.sh" "${repo_root}"; then
    failures=1
  fi
fi

if [[ "${static_only}" -eq 1 ]]; then
  if [[ "${failures}" -ne 0 ]]; then
    exit 1
  fi
  printf 'Bootstrap static validation passed.\n'
  exit 0
fi

if [[ "${failures}" -ne 0 ]]; then
  exit 1
fi

artifact_root="$(mktemp -d "${TMPDIR:-/tmp}/rekon-pursuit-m0-validation.XXXXXX")"
cleanup() {
  find "${artifact_root}" -depth -delete
}
trap cleanup EXIT

test_derived_data="${artifact_root}/TestDerivedData"
test_arguments=(
  -project "${project_path}"
  -scheme RekonPursuit
  -destination 'platform=macOS'
  -derivedDataPath "${test_derived_data}"
  -disableAutomaticPackageResolution
)
if [[ "${ci_only}" -eq 1 ]]; then
  # Hosted CI validates the unit-level bootstrap contract. The cosmetic UI
  # assertion remains a local check so it cannot block the compatibility gate.
  test_arguments+=( -only-testing:RekonPursuitTests )
fi
xcodebuild test "${test_arguments[@]}" -quiet

release_derived_data="${artifact_root}/ReleaseDerivedData"
xcodebuild build \
  -project "${project_path}" \
  -scheme RekonPursuit \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "${release_derived_data}" \
  -disableAutomaticPackageResolution \
  -quiet

signed_app="${release_derived_data}/Build/Products/Release/RekonPursuit.app"
"${script_dir}/check_entitlements.sh" "${repo_root}" "${signed_app}"

archive_root="${artifact_root}/UnsignedArchive"
"${script_dir}/build_unsigned_archive.sh" "${repo_root}" "${archive_root}"
archive_app="${archive_root}/RekonPursuit.xcarchive/Products/Applications/RekonPursuit.app"
archive_binary="${archive_app}/Contents/MacOS/RekonPursuit"

archive_signature="$(codesign -dvv "${archive_app}" 2>&1 || true)"
if [[ -n "${archive_signature}" ]]; then
  if ! grep -Fxq 'Signature=adhoc' <<<"${archive_signature}" \
    || ! grep -Fxq 'TeamIdentifier=not set' <<<"${archive_signature}" \
    || ! grep -Eq 'flags=.*linker-signed' <<<"${archive_signature}"; then
    printf '%s\n' "${archive_signature}" >&2
    record_error \
      "archive contains a signature other than the permitted identity-free linker signature"
  fi
fi
if [[ -d "${archive_app}/Contents/_CodeSignature" \
  || -f "${archive_app}/Contents/embedded.provisionprofile" ]]; then
  record_error "archive contains signing resources or a provisioning profile"
fi

archive_architectures="$(lipo -archs "${archive_binary}")"
for required_arch in arm64 x86_64; do
  if [[ " ${archive_architectures} " != *" ${required_arch} "* ]]; then
    record_error \
      "unsigned archive is missing architecture ${required_arch}: ${archive_architectures}"
  fi

  build_metadata="$(xcrun vtool -show-build -arch "${required_arch}" "${archive_binary}")"
  minimum_os="$(
    sed -n 's/^[[:space:]]*minos[[:space:]]*//p' <<<"${build_metadata}" \
      | head -n 1
  )"
  if [[ "${minimum_os}" != "14.0" ]]; then
    record_error \
      "archive ${required_arch} slice has minimum macOS ${minimum_os:-<unset>}, expected 14.0"
  fi
done

non_system_dependencies="$(
  otool -L "${archive_binary}" \
    | awk '/^[[:space:]]+/{print $1}' \
    | grep -Ev '^(/System/Library/|/usr/lib/)' \
    || true
)"
if [[ -n "${non_system_dependencies}" ]]; then
  printf '%s\n' "${non_system_dependencies}" >&2
  record_error "archive links an unapproved non-system dependency"
fi

if [[ "${failures}" -ne 0 ]]; then
  exit 1
fi

printf 'Bootstrap local validation passed.\n'
