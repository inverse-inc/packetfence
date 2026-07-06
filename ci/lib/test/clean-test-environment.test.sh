#!/bin/bash
# Regression test for clean-test-environment.sh: a hung/slow log collection
# (teardown) must not prevent VM destruction (clean). Without an internal
# teardown bound, a hung fetch would run past the outer PIPELINE_TIMEOUT_CLEANUP
# and abort the job before clean; the fix keeps cleanup under that budget.
#
# Usage: clean-test-environment.test.sh [path-to-clean-test-environment.sh]
set -o nounset -o pipefail

SCRIPT_DIR=$(readlink -e "$(dirname "${BASH_SOURCE[0]}")")
TARGET="${1:-${SCRIPT_DIR}/clean-test-environment.sh}"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

export DESTROY_MARKER="$WORK/destroyed"

# Fake make on PATH: teardown hangs longer than the outer timeout, clean
# records that VM destruction ran.
mkdir -p "$WORK/bin"
cat > "$WORK/bin/make" <<'EOF'
#!/bin/bash
if [ "${MAKE_TARGET:-}" = "teardown" ]; then
    exec sleep "${FAKE_TEARDOWN_SLEEP:-6}"
elif [ "${MAKE_TARGET:-}" = "clean" ]; then
    : > "$DESTROY_MARKER"
fi
EOF
chmod +x "$WORK/bin/make"

# Outer timeout mirrors .gitlab-ci.yml's PIPELINE_TIMEOUT_CLEANUP wrapper.
# Without the internal bound the hung 6s fetch would exceed the 4s outer budget
# and abort before VM destroy. Bounding teardown (1s) + clean (2s) keeps cleanup
# under the outer budget, so it never fires and destroy still runs.
timeout 4s \
    env PATH="$WORK/bin:$PATH" \
        PIPELINE_TIMEOUT_TEARDOWN=1s \
        PIPELINE_TIMEOUT_CLEAN=2s \
        JOB_STATUS=1 \
        CI_JOB_NAME=unit_tests_deb12 \
        KEEP_VMS=no \
        CI_PIPELINE_SOURCE=push \
        bash "$TARGET" >/dev/null 2>&1 || true

if [ -f "$DESTROY_MARKER" ]; then
    echo "PASS: VM destroy ran despite log collection timing out"
    exit 0
fi
echo "FAIL: VM destroy did not run after log collection timed out"
exit 1
