#!/bin/bash
set -uo pipefail

#############################################################################
# job-completed.sh
#
# ACTIONS_RUNNER_HOOK_JOB_COMPLETED hook. The runner invokes it on the host, as
# the runner user, after every job on this machine -- container jobs included,
# which is the point: see reclaim-workspace-ownership.sh for what root leaves
# behind in the bind-mounted workspace.
#
# A non-zero exit from a job hook fails the job, so a cleanup problem is
# reported as a warning here and never as a build failure. The next job's
# checkout will say so loudly enough on its own.
#############################################################################

hook_dir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
helper="$hook_dir/reclaim-workspace-ownership.sh"

# sudo -n: the sudoers drop-in grants this one command password-less, and the
# hook must never block waiting on a prompt nobody can answer.
if ! output="$(sudo -n "$helper" 2>&1)"; then
    echo "::warning title=Runner workspace ownership::$helper failed, so root-owned files may still be in the workspace and a later job can fail with EACCES while cleaning it. Output: ${output:-<none>}"
    exit 0
fi

echo "$output"
