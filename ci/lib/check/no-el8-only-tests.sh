#!/usr/bin/env bash
# ci/lib/check/no-el8-only-tests.sh
#
# Enforce the rule: every _el8 test job must have a _deb12 sibling.
# A deb12-only test is acceptable; an el8-only test is not.
#
# Requires: yq (Mike Farah Go version, available in alpine as yq-go)
# Usage: bash ci/lib/check/no-el8-only-tests.sh [path/to/.gitlab-ci.yml]
#
# Exits 0 if all _el8 jobs have a _deb12 sibling.
# Exits 1 and lists offenders if any _el8 job lacks a _deb12 sibling.

set -eu
set -o pipefail

CI_YAML="${1:-.gitlab-ci.yml}"

if [[ ! -f "$CI_YAML" ]]; then
  echo "ERROR: CI YAML not found: $CI_YAML" >&2
  exit 2
fi

# Extract all top-level keys from the CI YAML.
# yq (go) outputs one key per line with '| keys | .[]' on a mapping.
all_keys=$(yq 'keys | .[]' "$CI_YAML")

offenders=()

while IFS= read -r job; do
  # Match job names of the form: <name>_el8 or <name>_el8_branches
  if [[ "$job" =~ ^[a-z_]+_el8(_branches)?$ ]]; then
    # Derive the expected deb12 sibling: replace _el8 with _deb12
    sibling="${job/_el8/_deb12}"
    # Check that the sibling exists among the top-level keys
    if ! echo "$all_keys" | grep -qx "$sibling"; then
      offenders+=("$job (expected sibling: $sibling)")
    fi
  fi
done <<< "$all_keys"

if [[ ${#offenders[@]} -gt 0 ]]; then
  echo "FAIL: the following el8 test jobs have no deb12 sibling:" >&2
  for o in "${offenders[@]}"; do
    echo "  - $o" >&2
  done
  echo "" >&2
  echo "Policy: every _el8 test job must have a _deb12 sibling." >&2
  echo "Add the missing _deb12 job(s) to .gitlab-ci.yml to fix this." >&2
  exit 1
fi

echo "OK: no el8-only tests (all _el8 jobs have a _deb12 sibling)"
