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
while IFS= read -r -d '' match_path; do
  # With -z, git grep writes the path as a NUL-delimited field, then a
  # line-number-and-content record. Read but never emit that content.
  if IFS= read -r match_record; then
    match_line="${match_record%%:*}"
    if [[ "${match_line}" =~ ^[0-9]+$ ]]; then
      printf \
        'ERROR: probable credential material (rule=credential-pattern): %s:%s\n' \
        "${match_path}" "${match_line}" >&2
    else
      printf \
        'ERROR: probable credential material (rule=credential-pattern): %s\n' \
        "${match_path}" >&2
    fi
    failures=1
  fi
done < <(
  git -C "${repo_root}" grep -I -n -z -E -- "${secret_pattern}" -- . \
    2>/dev/null || true
)

if [[ "${failures}" -ne 0 ]]; then
  exit 1
fi

printf 'Tracked-secret scan passed.\n'
