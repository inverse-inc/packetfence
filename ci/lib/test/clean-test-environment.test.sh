#!/bin/bash
# Regression tests for VM retention, exit status, and bounded log collection.
#
# Usage: clean-test-environment.test.sh [path-to-clean-test-environment.sh]
set -o nounset -o pipefail

SCRIPT_DIR=$(readlink -e "$(dirname "${BASH_SOURCE[0]}")")
TARGET="${1:-${SCRIPT_DIR}/clean-test-environment.sh}"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# Fake make records log collection/destruction without touching actual VMs.
mkdir -p "$WORK/bin"
cat > "$WORK/bin/make" <<'EOF'
#!/bin/bash
if [ "${MAKE_TARGET:-}" = "teardown" ]; then
    echo teardown >> "$CALL_LOG"
    sleep "${FAKE_TEARDOWN_SLEEP:-0}"
    exit "${FAKE_TEARDOWN_STATUS:-0}"
elif [ "${MAKE_TARGET:-}" = "clean" ]; then
    echo clean >> "$CALL_LOG"
    exit "${FAKE_CLEAN_STATUS:-0}"
fi
EOF
chmod +x "$WORK/bin/make"

run_case() {
    local name=$1 keep=$2 job_status=$3 expected_status=$4
    local teardown_sleep=${5:-0} clean_status=${6:-0} teardown_status=${7:-0}
    local test_only=${8-unit_tests_deb12} expected_keep=${9:-$keep}
    local test_only_env=()
    if [ "$test_only" != __UNSET__ ]; then
        test_only_env=("TEST_ONLY=$test_only")
    fi
    local log="$WORK/${name}.calls" output="$WORK/${name}.output" status=0
    local expected_calls=teardown
    [ "$expected_keep" = yes ] || expected_calls=$'teardown\nclean'

    # Outer timeout mirrors the CI wrapper. Slow log collection must be
    # bounded internally so cleanup still has time to run.
    timeout 4s \
        env -u TEST_ONLY "${test_only_env[@]}" PATH="$WORK/bin:$PATH" CALL_LOG="$log" \
            PIPELINE_TIMEOUT_TEARDOWN=1s PIPELINE_TIMEOUT_CLEAN=2s \
            FAKE_TEARDOWN_SLEEP="$teardown_sleep" \
            FAKE_CLEAN_STATUS="$clean_status" \
            FAKE_TEARDOWN_STATUS="$teardown_status" \
            JOB_STATUS="$job_status" CI_JOB_NAME=unit_tests_deb12 \
            KEEP_VMS="$keep" CI_PIPELINE_SOURCE=push \
            bash "$TARGET" >"$output" 2>&1 || status=$?

    if [ "$status" != "$expected_status" ] || \
       [ "$(cat "$log" 2>/dev/null)" != "$expected_calls" ]; then
        echo "FAIL: $name (exit $status, expected $expected_status)"
        cat "$output"
        return 1
    fi
    if [ "$keep" = yes ] && [ "$expected_keep" = no ]; then
        if ! grep -q 'KEEP_VMS=yes requires TEST_ONLY' "$output"; then
            echo "FAIL: $name did not explain why retention was disabled"
            cat "$output"
            return 1
        fi
    fi
    echo "PASS: $name"
}

run_case keep_success yes '' 0 || exit 1
run_case keep_explicit_success yes 0 0 || exit 1
run_case keep_failure yes 7 7 || exit 1
run_case clean_success no '' 0 || exit 1
run_case clean_failure no 7 7 || exit 1
run_case report_cleanup_failure no '' 9 0 9 || exit 1
run_case preserve_test_failure no 7 7 0 9 || exit 1
run_case keep_on_log_failure yes 7 7 0 0 3 || exit 1
run_case clean_after_log_timeout no 7 7 6 || exit 1
run_case keep_after_log_timeout yes 7 7 6 || exit 1
run_case keep_unset_filter_success yes '' 0 0 0 0 __UNSET__ no || exit 1
run_case keep_unset_filter_failure yes 7 7 0 0 0 __UNSET__ no || exit 1
run_case keep_empty_filter_success yes '' 0 0 0 0 '' no || exit 1
run_case keep_empty_filter_failure yes 7 7 0 0 0 '' no || exit 1
run_case keep_blank_filter yes 7 7 0 0 0 ' , ' no || exit 1
run_case keep_nonmatching_filter yes 7 7 0 0 0 mac_auth no || exit 1
run_case keep_invalid_filter yes 7 7 0 0 0 '[' no || exit 1
run_case keep_matching_list yes 7 7 0 0 0 'mac_auth,unit_tests' || exit 1
run_case keep_matching_regex yes 7 7 0 0 0 '^unit_tests_.*' || exit 1
