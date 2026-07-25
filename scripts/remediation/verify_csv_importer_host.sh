#!/usr/bin/env bash
# Confirms the CSV picker is attached to its triggering control. Keeping the
# presentation host local prevents it from competing with the backup and
# document importers attached to the root view.
set -euo pipefail

if [[ $# -ne 1 ]]; then
  printf 'usage: %s <ContentView.swift>\n' "${0##*/}" >&2
  exit 64
fi

source_file="$1"
button_line="$(rg -n -F 'Button("Choose CSV file…")' "$source_file" | cut -d: -f1)"

if [[ -z "$button_line" ]]; then
  printf 'CSV chooser button was not found\n' >&2
  exit 1
fi

if ! sed -n "${button_line},$((button_line + 14))p" "$source_file" | rg -q -F '.fileImporter('; then
  printf 'CSV importer must be attached directly to the CSV chooser button\n' >&2
  exit 1
fi
