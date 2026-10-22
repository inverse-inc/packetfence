#!/bin/bash
set -euo pipefail

#############################################################################
# reclaim-workspace-ownership.sh
#
# Give every file under a self-hosted runner's _work tree back to the user the
# runner service runs as.
#
# Container jobs execute as root inside the container, and $GITHUB_WORKSPACE
# (/__w/<repo>/<repo>) is a bind mount of the host workspace. Anything such a
# job writes there -- actions/checkout's .git, build products, the dotfiles
# that land in the runner-forced HOME=/github/home -- stays owned by root once
# the container is gone. The next job to land on that runner runs as the
# unprivileged runner user and its checkout cannot clean the leftovers:
#
#   File was unable to be removed
#   Error: EACCES: permission denied, unlink
#     '.../.git/logs/refs/heads/<branch>'
#
# Run as root from the runner's ACTIONS_RUNNER_HOOK_JOB_COMPLETED hook; see
# README.md for the install and sudoers bits.
#
# It takes no arguments on purpose. The tree it touches is derived from its own
# location, so the unprivileged caller cannot aim a root-owned recursive chown
# at a directory of its choosing.
#############################################################################

prog="$(basename "$0")"

if [[ $# -ne 0 ]]; then
    echo "$prog: takes no arguments" >&2
    exit 2
fi

# Installed as <runner-root>/hooks/<this script>, so the work tree and the
# ownership to restore both come from <runner-root>.
self="$(readlink -f "$0")"
runner_root="$(dirname "$(dirname "$self")")"
work_root="$runner_root/_work"

# A typo'd install path must never become `chown -R` over / or /home: require a
# work tree at least three components deep.
IFS=/ read -ra components <<< "${work_root#/}"
if (( ${#components[@]} < 3 )); then
    echo "$prog: refusing to touch a tree this shallow: $work_root" >&2
    exit 1
fi

if [[ ! -d "$work_root" ]]; then
    echo "$prog: no runner work tree at $work_root, nothing to do"
    exit 0
fi

# The runner root holds config.sh/.runner/.env, all written by the runner user,
# so it is the authoritative source for the ownership jobs should leave behind.
uid="$(stat -c '%u' "$runner_root")"
gid="$(stat -c '%g' "$runner_root")"

if (( uid == 0 )); then
    echo "$prog: $runner_root is root-owned; refusing to guess a runner user" >&2
    exit 1
fi

# -h so a stray symlink is retargeted rather than followed, -xdev so a mount
# someone parked under _work is left alone.
mapfile -d '' stray < <(find "$work_root" -xdev \( ! -uid "$uid" -o ! -gid "$gid" \) -print0)

if (( ${#stray[@]} == 0 )); then
    echo "$prog: $work_root is already owned by ${uid}:${gid}"
    exit 0
fi

printf '%s\0' "${stray[@]}" | xargs -0 chown -h "${uid}:${gid}"
echo "$prog: reclaimed ${#stray[@]} path(s) under $work_root for ${uid}:${gid}"
