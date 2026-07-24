#!/usr/bin/env bash
# M0-3 bootstrap validation entry point. It intentionally propagates validation
# failures while the required native project and CI artifacts do not yet exist.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../.." && pwd)"

cd "${repo_root}"
exec "${script_dir}/validate_bootstrap.sh" .
