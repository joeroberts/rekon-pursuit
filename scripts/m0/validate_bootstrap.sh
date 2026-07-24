#!/usr/bin/env bash
# Validates that the M0-3 native-bootstrap artifacts exist. Later M0-3 tasks
# extend this script with build, archive, entitlement, dependency, and secret
# checks once those artifacts are permitted to exist.
set -euo pipefail

if [[ $# -ne 1 ]]; then
  printf 'usage: %s <repository-root>\n' "${0##*/}" >&2
  exit 64
fi

repo_root="$1"
if [[ ! -d "${repo_root}" ]]; then
  printf 'ERROR: repository root does not exist: %s\n' "${repo_root}" >&2
  exit 64
fi

missing=0

if [[ ! -d "${repo_root}/RekonPursuit.xcodeproj" ]]; then
  printf 'MISSING: Xcode project: RekonPursuit.xcodeproj\n' >&2
  missing=1
fi

if [[ ! -f "${repo_root}/.github/workflows/m0-bootstrap.yml" ]]; then
  printf 'MISSING: CI workflow: .github/workflows/m0-bootstrap.yml\n' >&2
  missing=1
fi

if [[ ! -f "${repo_root}/RekonPursuit.xcodeproj/project.pbxproj" ]]; then
  printf 'MISSING: project build settings: RekonPursuit.xcodeproj/project.pbxproj\n' >&2
  missing=1
fi

if [[ "${missing}" -ne 0 ]]; then
  exit 1
fi

printf 'Bootstrap artifact presence check passed.\n'
