#!/bin/bash
# Decide whether $CI_JOB_NAME is selected by the $TEST_ONLY filter.
# exit 0 = run, exit 1 = skip, exit 2 = invalid TEST_ONLY.
set -o nounset -o pipefail

test_only="${TEST_ONLY:-}"
[ -z "${test_only}" ] && exit 0

# Reject newline or single quote (basic injection guard).
if printf '%s' "${test_only}" | grep -qP "[\n']"; then
    echo "Error: TEST_ONLY contains invalid characters (newline or single quote)." >&2
    exit 2
fi

# Comma-separated list -> regex alternation; drop empty items so a stray
# comma (e.g. "auth,") can't collapse into a match-everything pattern.
pattern=$(printf '%s' "${test_only}" | tr ',' '\n' | grep -v '^[[:space:]]*$' | tr '\n' '|' | sed 's/|$//')
if [ -z "${pattern}" ]; then
    echo "Error: TEST_ONLY contains no valid test names (only commas/whitespace)." >&2
    exit 2
fi

echo "${CI_JOB_NAME}" | grep -qE -- "${pattern}"
