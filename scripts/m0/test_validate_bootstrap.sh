#!/usr/bin/env bash
# Exercises the M0-3 bootstrap validator against controlled negative fixtures,
# the real local tree, and the intentionally unreleased Task-4 workflow gate.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../.." && pwd)"
fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/rekon-pursuit-m0-tests.XXXXXX")"

cleanup() {
  find "${fixture_root}" -depth -delete
}
trap cleanup EXIT

failures=0

expect_failure_containing() {
  local name="$1"
  local expected="$2"
  shift 2
  local output_file="${fixture_root}/${name}.log"

  if "$@" >"${output_file}" 2>&1; then
    printf 'FAIL: %s unexpectedly passed\n' "${name}" >&2
    failures=$((failures + 1))
  elif ! grep -Fq -- "${expected}" "${output_file}"; then
    printf 'FAIL: %s did not report %q\n' "${name}" "${expected}" >&2
    sed -n '1,120p' "${output_file}" >&2
    failures=$((failures + 1))
  else
    printf 'PASS: %s rejected with the expected diagnostic\n' "${name}"
  fi
}

copy_static_fixture() {
  local destination="$1"
  mkdir -p "${destination}/RekonPursuit" "${destination}/scripts/m0"
  cp -R "${repo_root}/RekonPursuit.xcodeproj" "${destination}/"
  cp "${repo_root}/RekonPursuit/RekonPursuit.entitlements" \
    "${destination}/RekonPursuit/"
  cp "${script_dir}"/*.sh "${destination}/scripts/m0/"
  git -C "${destination}" init -q
  git -C "${destination}" add .
}

secret_fixture="${fixture_root}/tracked-secret"
mkdir -p "${secret_fixture}"
git -C "${secret_fixture}" init -q
synthetic_secret="sk-REKON_""PURSUIT_SYNTHETIC_TOKEN_1234567890"
printf '%s\n' "${synthetic_secret}" >"${secret_fixture}/fixture.txt"
git -C "${secret_fixture}" add fixture.txt
secret_output="${fixture_root}/tracked-secret.log"
if "${script_dir}/check_tracked_secrets.sh" "${secret_fixture}" \
  >"${secret_output}" 2>&1; then
  printf 'FAIL: tracked-secret scanner unexpectedly passed a synthetic secret\n' >&2
  failures=$((failures + 1))
elif grep -Fq -- "${synthetic_secret}" "${secret_output}"; then
  printf 'FAIL: tracked-secret scanner leaked synthetic secret content\n' >&2
  failures=$((failures + 1))
elif ! grep -Fq \
  'ERROR: probable credential material (rule=credential-pattern): fixture.txt:1' \
  "${secret_output}"; then
  printf 'FAIL: tracked-secret scanner did not report safe match metadata\n' >&2
  failures=$((failures + 1))
else
  printf 'PASS: tracked-secret scanner reports only safe match metadata\n'
fi

unsupported_target_fixture="${fixture_root}/unsupported-target"
copy_static_fixture "${unsupported_target_fixture}"
sed -i '' \
  's/MACOSX_DEPLOYMENT_TARGET = 14\.0;/MACOSX_DEPLOYMENT_TARGET = 15.0;/g' \
  "${unsupported_target_fixture}/RekonPursuit.xcodeproj/project.pbxproj"
expect_failure_containing \
  "unsupported-target" \
  "ERROR: unsupported deployment target: expected 14.0, found 15.0" \
  "${unsupported_target_fixture}/scripts/m0/validate_bootstrap.sh" \
  --static-only "${unsupported_target_fixture}"

network_entitlement_fixture="${fixture_root}/network-entitlement"
copy_static_fixture "${network_entitlement_fixture}"
/usr/libexec/PlistBuddy \
  -c "Add :com.apple.security.network.client bool true" \
  "${network_entitlement_fixture}/RekonPursuit/RekonPursuit.entitlements"
expect_failure_containing \
  "network-entitlement" \
  "ERROR: prohibited entitlement: com.apple.security.network.client" \
  "${network_entitlement_fixture}/scripts/m0/validate_bootstrap.sh" \
  --static-only "${network_entitlement_fixture}"

task4_output="${fixture_root}/task4-workflow-gate.log"
if "${script_dir}/validate_bootstrap.sh" --static-only "${repo_root}" \
  >"${task4_output}" 2>&1; then
  printf 'FAIL: the unreleased Task-4 workflow gate unexpectedly passed\n' >&2
  failures=$((failures + 1))
elif ! grep -Fq \
  "MISSING: CI workflow: .github/workflows/m0-bootstrap.yml" \
  "${task4_output}"; then
  printf 'FAIL: Task-4 gate did not report the missing workflow\n' >&2
  sed -n '1,120p' "${task4_output}" >&2
  failures=$((failures + 1))
else
  unexpected_task4_failures="$(
    grep -E '^(ERROR|MISSING):' "${task4_output}" \
      | grep -Fv 'MISSING: CI workflow: .github/workflows/m0-bootstrap.yml' \
      || true
  )"
  if [[ -n "${unexpected_task4_failures}" ]]; then
    printf 'FAIL: Task-4 gate has unexpected failures:\n%s\n' \
      "${unexpected_task4_failures}" >&2
    failures=$((failures + 1))
  else
    printf 'PASS: Task-4 workflow remains the only static readiness gate\n'
  fi
fi

local_output="${fixture_root}/local-validation.log"
if ! "${script_dir}/validate_bootstrap.sh" --local-only "${repo_root}" \
  >"${local_output}" 2>&1; then
  printf 'FAIL: real-tree local validation failed\n' >&2
  sed -n '1,200p' "${local_output}" >&2
  failures=$((failures + 1))
else
  printf 'PASS: real-tree local validation passed\n'
fi

if [[ "${failures}" -ne 0 ]]; then
  printf 'M0 bootstrap validation tests failed: %d\n' "${failures}" >&2
  exit 1
fi

printf 'M0 bootstrap validation tests passed.\n'
