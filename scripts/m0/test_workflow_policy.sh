#!/usr/bin/env bash
# Enforces the M0-3 CI runner, toolchain, smoke, and no-release boundaries.
set -euo pipefail

if [[ $# -gt 1 ]]; then
  printf 'usage: %s [repository-root]\n' "${0##*/}" >&2
  exit 64
fi

if [[ $# -eq 1 ]]; then
  repo_root="$(cd "$1" && pwd)"
else
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  repo_root="$(cd "${script_dir}/../.." && pwd)"
fi

workflow_path="${repo_root}/.github/workflows/m0-bootstrap.yml"
failures=0

record_failure() {
  printf 'ERROR: %s\n' "$1" >&2
  failures=$((failures + 1))
}

require_literal() {
  local expected="$1"
  local description="$2"
  if ! grep -Fq -- "${expected}" "${workflow_path}"; then
    record_failure "workflow must ${description}"
  fi
}

require_job_literal() {
  local job_name="$1"
  local expected="$2"
  local description="$3"
  local job_body

  job_body="$(awk -v job="${job_name}" '
    $0 == "  " job ":" { in_job = 1; next }
    in_job && /^  [[:alnum:]_-]+:$/ { exit }
    in_job { print }
  ' "${workflow_path}")"

  if [[ -z "${job_body}" ]] || ! grep -Fq -- "${expected}" <<<"${job_body}"; then
    record_failure "workflow must ${description}"
  fi
}

forbid_job_literal() {
  local job_name="$1"
  local forbidden="$2"
  local description="$3"
  local job_body

  job_body="$(awk -v job="${job_name}" '
    $0 == "  " job ":" { in_job = 1; next }
    in_job && /^  [[:alnum:]_-]+:$/ { exit }
    in_job { print }
  ' "${workflow_path}")"

  if grep -Fq -- "${forbidden}" <<<"${job_body}"; then
    record_failure "workflow must not ${description}"
  fi
}

if [[ ! -f "${workflow_path}" ]]; then
  printf 'MISSING: workflow policy target: .github/workflows/m0-bootstrap.yml\n' >&2
  exit 1
fi

require_literal \
  'runs-on: macos-15-intel' \
  'pin universal validation to macos-15-intel'
require_literal \
  'DEVELOPER_DIR: /Applications/Xcode_26.3.app/Contents/Developer' \
  'select Xcode 26.3 by its exact installation path'
require_literal \
  'XCODE_VERSION: "26.3"' \
  'declare the exact CI Xcode version 26.3'
require_literal \
  'XCODE_BUILD: "17C529"' \
  'declare the exact CI Xcode build 17C529'
require_job_literal \
  'universal-validation' \
  'printf '\''%s\n'\'' "${version_output}"' \
  'emit the exact xcodebuild version output from universal-validation to the CI log'
require_job_literal \
  'universal-validation' \
  'tee "${RUNNER_TEMP}/m0-runner-toolchain-identity.txt"' \
  'write universal-validation runner and toolchain identity evidence'
require_job_literal \
  'universal-validation' \
  'name: m0-runner-toolchain-identity' \
  'retain universal-validation runner and toolchain identity evidence'
require_job_literal \
  'universal-validation' \
  ': "${ImageOS:?ImageOS must be set by GitHub Actions}"' \
  'require universal-validation ImageOS to be non-empty'
require_job_literal \
  'universal-validation' \
  ': "${ImageVersion:?ImageVersion must be set by GitHub Actions}"' \
  'require universal-validation ImageVersion to be non-empty'
require_job_literal \
  'universal-validation' \
  'printf '\''ImageOS=%s\n'\'' "${ImageOS}"' \
  'record universal-validation ImageOS evidence'
require_job_literal \
  'universal-validation' \
  'printf '\''ImageVersion=%s\n'\'' "${ImageVersion}"' \
  'record universal-validation ImageVersion evidence'
forbid_job_literal \
  'universal-validation' \
  '${ImageOS:-unknown}' \
  'silently fall back to unknown ImageOS evidence in universal-validation'
forbid_job_literal \
  'universal-validation' \
  '${ImageVersion:-unknown}' \
  'silently fall back to unknown ImageVersion evidence in universal-validation'
require_literal \
  'scripts/m0/test_workflow_policy.sh .' \
  'run this workflow-policy regression'
require_literal \
  'scripts/m0/validate_bootstrap.sh .' \
  'run the complete local bootstrap validator'
require_literal \
  'runs-on: macos-14' \
  'pin the baseline smoke job to macos-14'
require_job_literal \
  'macos-14-smoke' \
  ': "${ImageOS:?ImageOS must be set by GitHub Actions}"' \
  'require macos-14-smoke ImageOS to be non-empty'
require_job_literal \
  'macos-14-smoke' \
  ': "${ImageVersion:?ImageVersion must be set by GitHub Actions}"' \
  'require macos-14-smoke ImageVersion to be non-empty'
require_job_literal \
  'macos-14-smoke' \
  'printf '\''ImageOS=%s\n'\'' "${ImageOS}"' \
  'record macos-14 runner image identity evidence'
require_job_literal \
  'macos-14-smoke' \
  'printf '\''ImageVersion=%s\n'\'' "${ImageVersion}"' \
  'record macos-14 runner image version evidence'
forbid_job_literal \
  'macos-14-smoke' \
  '${ImageOS:-unknown}' \
  'silently fall back to unknown ImageOS evidence in macos-14-smoke'
forbid_job_literal \
  'macos-14-smoke' \
  '${ImageVersion:-unknown}' \
  'silently fall back to unknown ImageVersion evidence in macos-14-smoke'
require_job_literal \
  'macos-14-smoke' \
  'm0-macos-14-runner-identity.txt' \
  'write macos-14 runner identity evidence to a dedicated artifact file'
require_job_literal \
  'macos-14-smoke' \
  'name: m0-macos-14-runner-identity' \
  'retain macos-14 runner image identity evidence as a dedicated artifact'
require_literal \
  'test "$(uname -m)" = "arm64"' \
  'assert the macos-14 runner is arm64'
require_literal \
  'actions/upload-artifact@' \
  'transfer the identity-free universal archive to the smoke job'
require_literal \
  'actions/download-artifact@' \
  'retrieve the identity-free universal archive in the smoke job'
require_literal \
  '"${smoke_binary}" >' \
  'launch the archived universal app in the macos-14 smoke job'

forbidden_pattern='macos-latest|\$\{\{[[:space:]]*secrets\.|codesign([[:space:]]|$)|security[[:space:]]+import|notarytool|stapler|productbuild|create-dmg|gh[[:space:]]+release|CODE_SIGNING_ALLOWED[[:space:]]*=[[:space:]]*YES|CODE_SIGN_IDENTITY|DEVELOPMENT_TEAM|PROVISIONING_PROFILE|GMAIL|GOOGLE_CALENDAR|OPENAI_API_KEY'
if grep -Ein -- "${forbidden_pattern}" "${workflow_path}" >/dev/null; then
  record_failure \
    'workflow contains a floating runner, secret, signing, notarization, publishing, artifact-transfer, or user-data integration reference'
fi

if [[ "${failures}" -ne 0 ]]; then
  printf 'M0 bootstrap workflow policy failed: %d\n' "${failures}" >&2
  exit 1
fi

printf 'M0 bootstrap workflow policy passed.\n'
