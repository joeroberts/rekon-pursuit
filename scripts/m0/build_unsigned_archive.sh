#!/usr/bin/env bash
# Produces the M0 bootstrap archive with Xcode signing disabled and without
# identities or profiles. Modern Apple linkers may still add an identity-free
# ad-hoc Mach-O signature.
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  printf 'usage: %s <repository-root> [artifact-root]\n' "${0##*/}" >&2
  exit 64
fi

repo_root="$(cd "$1" && pwd)"
if [[ $# -eq 2 ]]; then
  mkdir -p "$2"
  artifact_root="$(cd "$2" && pwd)"
else
  artifact_root="$(mktemp -d "${TMPDIR:-/tmp}/rekon-pursuit-m0-archive.XXXXXX")"
fi

case "${artifact_root}/" in
  "${repo_root}/"*)
    printf 'ERROR: archive output must be outside the repository: %s\n' \
      "${artifact_root}" >&2
    exit 64
    ;;
esac

archive_path="${artifact_root}/RekonPursuit.xcarchive"
derived_data_path="${artifact_root}/DerivedData"

xcodebuild archive \
  -project "${repo_root}/RekonPursuit.xcodeproj" \
  -scheme RekonPursuit \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "${archive_path}" \
  -derivedDataPath "${derived_data_path}" \
  -disableAutomaticPackageResolution \
  CODE_SIGNING_ALLOWED=NO \
  -quiet

archive_app="${archive_path}/Products/Applications/RekonPursuit.app"
archive_binary="${archive_app}/Contents/MacOS/RekonPursuit"
if [[ ! -x "${archive_binary}" ]]; then
  printf 'ERROR: unsigned archive did not produce %s\n' "${archive_binary}" >&2
  exit 1
fi

printf 'Identity-free archive created outside the repository with Xcode signing disabled.\n'
printf 'ARCHIVE_APP=%s\n' "${archive_app}"
