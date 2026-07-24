#!/usr/bin/env bash
# Scans only Git-tracked content for credential material and unsafe filenames.
set -euo pipefail

if [[ $# -ne 1 ]]; then
  printf 'usage: %s <repository-root>\n' "${0##*/}" >&2
  exit 64
fi

repo_root="$(cd "$1" && pwd)"
if [[ "$(git -C "${repo_root}" rev-parse --is-inside-work-tree 2>/dev/null)" != "true" ]]; then
  printf 'ERROR: secret scan requires a Git worktree: %s\n' "${repo_root}" >&2
  exit 64
fi

failures=0
while IFS= read -r -d '' tracked_path; do
  case "${tracked_path}" in
    .env|*/.env|*.p12|*.pfx|*.cer|*.key|*.pem|*.mobileprovision|\
    *.provisionprofile|*Credentials.plist|*credentials.json|\
    *secrets.yml|*secrets.yaml)
      printf 'ERROR: prohibited tracked credential/secret file: %s\n' \
        "${tracked_path}" >&2
      failures=1
      ;;
  esac
done < <(git -C "${repo_root}" ls-files -z)

secret_pattern='-----BEGIN ([A-Z0-9]+ )*PRIVATE KEY-----|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{30,}|gh[pousr]_[0-9A-Za-z]{20,}|xox[baprs]-[0-9A-Za-z-]{10,}|sk-[0-9A-Za-z_-]{20,}'
secret_matches="$(
  git -C "${repo_root}" grep -I -nE -- "${secret_pattern}" -- . 2>/dev/null \
    || true
)"
if [[ -n "${secret_matches}" ]]; then
  printf 'ERROR: probable credential material in tracked content:\n%s\n' \
    "${secret_matches}" >&2
  failures=1
fi

if [[ "${failures}" -ne 0 ]]; then
  exit 1
fi

printf 'Tracked-secret scan passed.\n'
