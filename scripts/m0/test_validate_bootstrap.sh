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

task4_output="${fixture_root}/task4-workflow-policy.log"
if ! "${script_dir}/test_workflow_policy.sh" "${repo_root}" \
  >"${task4_output}" 2>&1; then
  printf 'FAIL: Task-4 workflow policy failed\n' >&2
  sed -n '1,120p' "${task4_output}" >&2
  failures=$((failures + 1))
else
  printf 'PASS: Task-4 workflow policy passed\n'
fi

# The universal-validation runner supplies the archive and its own identity
# evidence.  It cannot rely on the macOS 14 smoke job's capture, nor may an
# absent GitHub image value be silently written as "unknown".
universal_identity_fixture="${fixture_root}/missing-universal-runner-identity"
mkdir -p "${universal_identity_fixture}/.github/workflows" "${universal_identity_fixture}/scripts/m0"
cp "${repo_root}/.github/workflows/m0-bootstrap.yml" \
  "${universal_identity_fixture}/.github/workflows/m0-bootstrap.yml"
cp "${script_dir}/test_workflow_policy.sh" \
  "${universal_identity_fixture}/scripts/m0/"
sed -i '' \
  '/^  universal-validation:/,/^  macos-14-smoke:/ { s/: "${ImageOS:?ImageOS must be set by GitHub Actions}"/: # ImageOS check removed/; s/: "${ImageVersion:?ImageVersion must be set by GitHub Actions}"/: # ImageVersion check removed/; }' \
  "${universal_identity_fixture}/.github/workflows/m0-bootstrap.yml"
expect_failure_containing \
  "missing-universal-runner-identity" \
  "workflow must require universal-validation ImageOS to be non-empty" \
  "${universal_identity_fixture}/scripts/m0/test_workflow_policy.sh" \
  "${universal_identity_fixture}"

# The macOS 14 smoke runner is a distinct evidence environment.  Its runner
# image identity must be retained by that job, rather than being satisfied by
# the universal-validation job's artifact.
smoke_identity_fixture="${fixture_root}/missing-smoke-runner-identity"
mkdir -p "${smoke_identity_fixture}/.github/workflows" "${smoke_identity_fixture}/scripts/m0"
cp "${repo_root}/.github/workflows/m0-bootstrap.yml" \
  "${smoke_identity_fixture}/.github/workflows/m0-bootstrap.yml"
cp "${script_dir}/test_workflow_policy.sh" \
  "${smoke_identity_fixture}/scripts/m0/"
sed -i '' \
  '/^  macos-14-smoke:/,$ { /ImageOS=/d; /ImageVersion=/d; /m0-macos-14-runner-identity/d; }' \
  "${smoke_identity_fixture}/.github/workflows/m0-bootstrap.yml"
expect_failure_containing \
  "missing-smoke-runner-identity" \
  "workflow must retain macos-14 runner image identity evidence" \
  "${smoke_identity_fixture}/scripts/m0/test_workflow_policy.sh" \
  "${smoke_identity_fixture}"

# Each policy requirement must belong to its intended job.  These mutations
# preserve the required literals but move them into the other job, proving the
# policy test cannot pass on a workflow with swapped responsibilities.
universal_scope_fixture="${fixture_root}/misplaced-universal-requirements"
mkdir -p "${universal_scope_fixture}/.github/workflows" "${universal_scope_fixture}/scripts/m0"
cp "${repo_root}/.github/workflows/m0-bootstrap.yml" \
  "${universal_scope_fixture}/.github/workflows/m0-bootstrap.yml"
cp "${script_dir}/test_workflow_policy.sh" \
  "${universal_scope_fixture}/scripts/m0/"
sed -i '' \
  '/^  universal-validation:/,/^  macos-14-smoke:/ s/runs-on: macos-15-intel/runs-on: macos-14/' \
  "${universal_scope_fixture}/.github/workflows/m0-bootstrap.yml"
sed -i '' \
  '/^  macos-14-smoke:/,$ s/runs-on: macos-14/runs-on: macos-15-intel/' \
  "${universal_scope_fixture}/.github/workflows/m0-bootstrap.yml"
expect_failure_containing \
  "misplaced-universal-requirements" \
  "workflow must pin universal-validation to macos-15-intel" \
  "${universal_scope_fixture}/scripts/m0/test_workflow_policy.sh" \
  "${universal_scope_fixture}"

smoke_scope_fixture="${fixture_root}/misplaced-smoke-requirements"
mkdir -p "${smoke_scope_fixture}/.github/workflows" "${smoke_scope_fixture}/scripts/m0"
cp "${repo_root}/.github/workflows/m0-bootstrap.yml" \
  "${smoke_scope_fixture}/.github/workflows/m0-bootstrap.yml"
cp "${script_dir}/test_workflow_policy.sh" \
  "${smoke_scope_fixture}/scripts/m0/"
sed -i '' \
  '/^  universal-validation:/,/^  macos-14-smoke:/ s/name: Universal archive and local policy/name: Universal archive and local policy # needs: universal-validation/' \
  "${smoke_scope_fixture}/.github/workflows/m0-bootstrap.yml"
sed -i '' \
  '/^  macos-14-smoke:/,$ { s|needs: universal-validation|needs: bootstrap-only|; s|runs-on: macos-14|runs-on: macos-15-intel|; s|test "$(uname -m)" = "arm64"|test "$(uname -m)" = "x86_64"|; s|scripts/m0/validate_bootstrap.sh --static-only \.|true # validator moved|; s|actions/download-artifact@|actions/upload-artifact@|; s|shasum -a 256 -c RekonPursuit-unsigned.tar.gz.sha256|true # checksum moved|; s|"${smoke_binary}" >|true # launch moved|; }' \
  "${smoke_scope_fixture}/.github/workflows/m0-bootstrap.yml"
expect_failure_containing \
  "misplaced-smoke-requirements" \
  "workflow must make macos-14-smoke depend on universal-validation" \
  "${smoke_scope_fixture}/scripts/m0/test_workflow_policy.sh" \
  "${smoke_scope_fixture}"

task4_static_output="${fixture_root}/task4-static-validation.log"
if ! "${script_dir}/validate_bootstrap.sh" --static-only "${repo_root}" \
  >"${task4_static_output}" 2>&1; then
  printf 'FAIL: real-tree static validation failed after Task 4\n' >&2
  sed -n '1,120p' "${task4_static_output}" >&2
  failures=$((failures + 1))
else
  printf 'PASS: real-tree static validation passed after Task 4\n'
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
