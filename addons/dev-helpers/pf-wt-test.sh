#!/bin/bash
#
# pf-wt-test.sh - run PacketFence perl tests against a git worktree
#
# The perl code and tests are hardcoded to /usr/local/pf. In a private mount
# namespace (unshare -m), the worktree's code directories are bind-mounted over
# /usr/local/pf, so the tests run the worktree's code while the rest of the
# installation (var, lib_perl, binaries, services) stays the real one.
# conf is an overlay: the worktree's files (the *.defaults of its branch) over
# the local ones of /usr/local/pf (pf.conf, ...); writes go to a throwaway layer.
# Nothing is mounted outside the namespace.
#
# By default the namespace also gets its own pfconfig-test (memory backend),
# started from the worktree's code before the tests, and its own var/run,
# var/control, var/cache/pfconfig and /tmp/chi: the worktree's config is built
# by its own code and the pfconfig-test of /usr/local/pf is left alone.
# The namespace has its own PIDs too (unshare -p): every process left in it,
# such as a pfconfig-test-serial a test started, is killed on exit.
#
# Must run as root. Example, from a worktree:
#   addons/dev-helpers/pf-wt-test.sh t/unittest/Switch.t
#

set -euo pipefail

PF=/usr/local/pf
PROG=$(basename "$0")
CODE_DIRS=(lib t html/pfappserver/lib html/captive-portal/lib)
# Single files, as their directory also holds binaries that git ignores
# (sbin/pfacct, ...): sbin/pfconfig is the daemon of the test pfconfigs
CODE_FILES=(sbin/pfconfig)
OVERLAY_DIRS=(conf)
# Files the tests need that a worktree can lack (lib/fingerbank is ignored by
# git): copied from $PF into the worktree if missing
NEEDED_FILES=(lib/fingerbank t/data/system_init_key)
# Runtime files of the test pfconfig, hidden from the namespace for a private one
PFCONFIG_TEST_FILES=(pfconfig-test.pid pfconfig-test.sock pfconfig-test-serial.pid pfconfig-test-serial.sock)

usage() {
    cat <<EOF
Usage: $PROG [options] [prove args...]
       $PROG [options] -e command [args...]

Run PacketFence perl tests with a worktree's code mounted over $PF.

Options:
  -w DIR   worktree to test (default: the git worktree of the current directory)
  -b DIR   also mount this directory of the worktree (relative to its root),
           can be repeated. Default: ${CODE_DIRS[*]}
  -o DIR   also mount this directory as an overlay: the worktree's files over
           the ones of $PF, writes discarded. Default: ${OVERLAY_DIRS[*]}
  -s       use the shared pfconfig-test of $PF instead of a private one
  -e       run a command instead of prove (e.g. -e perl t/unittest/Switch.t,
           -e bash for a shell in the namespace)
  -h       this help

Environment:
  PF_WT_PFCONFIG_TIMEOUT  seconds to wait for the private pfconfig-test (300)

Paths are relative to the current directory, mapped into $PF when it is inside
the worktree (cwd is $PF otherwise). Absolute paths into the worktree are
rewritten to $PF.

Examples:
  $PROG t/unittest/Switch.t t/unittest/dal/
  $PROG -v t/unittest/dal/node.t
  $PROG -w ~/pf-wt -e perl t/unittest/Switch.t
EOF
}

die() { echo "$PROG: $*" >&2; exit 1; }

WT=
EXTRA_DIRS=()
SHARED_PFCONFIG=0
EXEC=0
# Our options come first; the first other argument starts the prove args or,
# after -e, the command (so prove options such as -v pass through)
while [ $# -gt 0 ]; do
    case $1 in
        -w) [ $# -ge 2 ] || die "-w needs a directory"; WT=$2; shift 2 ;;
        -b) [ $# -ge 2 ] || die "-b needs a directory"; EXTRA_DIRS+=("$2"); shift 2 ;;
        -o) [ $# -ge 2 ] || die "-o needs a directory"; OVERLAY_DIRS+=("$2"); shift 2 ;;
        -s) SHARED_PFCONFIG=1; shift ;;
        -e) EXEC=1; shift; break ;;
        -h|--help) usage; exit 0 ;;
        --) shift; break ;;
        *) break ;;
    esac
done

[ $# -gt 0 ] || { usage >&2; exit 1; }
[ "$(id -u)" -eq 0 ] || die "must run as root (unshare -m and mount)"

if [ -z "$WT" ]; then
    WT=$(git rev-parse --show-toplevel 2>/dev/null) || die "not in a git worktree, use -w"
fi
WT=$(realpath "$WT")
[ "$WT" != "$(realpath $PF)" ] || die "$WT is $PF itself, run the tests directly"
[ -d "$WT/lib/pf" ] && [ -d "$WT/t" ] || die "$WT is not a PacketFence tree"

# Normalize a directory relative to the worktree root and reject one that
# escapes it (.., absolute path) or is the root itself: it is also the mount
# target under $PF. Symlinks are not followed (lib/fingerbank is one).
rel_dir() {
    local r
    r=$(realpath -m -s --relative-to="$WT" "$WT/$1")
    case $r in
        .|..|../*|/*) die "$1 is not a directory below the worktree root" ;;
    esac
    [ -d "$WT/$r" ] || die "$WT/$r is not a directory"
    echo "$r"
}
for i in "${!EXTRA_DIRS[@]}"; do EXTRA_DIRS[i]=$(rel_dir "${EXTRA_DIRS[i]}"); done
for i in "${!OVERLAY_DIRS[@]}"; do OVERLAY_DIRS[i]=$(rel_dir "${OVERLAY_DIRS[i]}"); done
DIRS=("${CODE_DIRS[@]}" "${EXTRA_DIRS[@]}")

for f in "${NEEDED_FILES[@]}"; do
    if [ ! -e "$WT/$f" ] && [ ! -L "$WT/$f" ] && { [ -e "$PF/$f" ] || [ -L "$PF/$f" ]; }; then
        cp -a "$PF/$f" "$WT/$f"
        echo "$PROG: copied $f from $PF into the worktree" >&2
    fi
done

# Run from the same place inside the namespace. The physical path, as $WT is
# resolved: a cwd reached through a symlink still matches.
CWD=$(pwd -P)
case $CWD/ in
    "$WT"/*) RUN_DIR=$PF${CWD#"$WT"} ;;
    *) RUN_DIR=$PF ;;
esac

ARGS=()
for a in "$@"; do
    case $a in
        "$WT"|"$WT"/*) ARGS+=("$PF${a#"$WT"}") ;;
        *) ARGS+=("$a") ;;
    esac
done
[ $EXEC -eq 1 ] || ARGS=(prove "${ARGS[@]}")

# Mount points of the namespace (only used inside it)
NS_TMP=$(mktemp -d /tmp/pf-wt-test.XXXXXX)
# Only empty mount points and the discarded overlay layers: the mounts are gone
# with the namespace
trap 'rm -rf --one-file-system "$NS_TMP"' EXIT
mkdir "$NS_TMP/real-run"
# Mount point of the private /tmp/chi. It is left in place: removing it would
# also unmount the /tmp/chi of a concurrent run.
[ "$SHARED_PFCONFIG" -ne 0 ] || mkdir -p /tmp/chi

export PF WT NS_TMP RUN_DIR SHARED_PFCONFIG
export PFCONFIG_TIMEOUT=${PF_WT_PFCONFIG_TIMEOUT:-300}
[[ $PFCONFIG_TIMEOUT =~ ^[0-9]+$ ]] || die "PF_WT_PFCONFIG_TIMEOUT must be a number of seconds"
export PF_WT_DIRS="${DIRS[*]}" PF_WT_FILES="${CODE_FILES[*]}" PF_WT_OVERLAY_DIRS="${OVERLAY_DIRS[*]}" PF_WT_PFCONFIG_FILES="${PFCONFIG_TEST_FILES[*]}"

# Private mount and PID namespaces: the inner bash is PID 1 of the namespace and
# the kernel kills every process left in it when it exits. --kill-child kills
# it if unshare itself is killed, and --pdeathsig kills unshare if this script
# is (a SIGTERM or SIGHUP to it alone, a closed terminal): bash runs its own
# traps only once the foreground command is done, so it can't forward them.
setpriv --pdeathsig TERM \
    unshare -m -p -f --kill-child --mount-proc --propagation private bash -c '
set -euo pipefail
# PID 1 of a namespace only gets the signals it handles
trap "exit 130" INT
trap "exit 143" TERM HUP

skip() { echo "pf-wt-test: $1 not in the worktree or $PF, the one of $PF is used" >&2; }

for d in $PF_WT_DIRS; do
    if [ -d "$WT/$d" ] && [ -d "$PF/$d" ]; then
        mount --bind "$WT/$d" "$PF/$d"
    else
        skip "$d"
    fi
done

for f in $PF_WT_FILES; do
    if [ -f "$WT/$f" ] && [ -f "$PF/$f" ]; then
        mount --bind "$WT/$f" "$PF/$f"
    else
        skip "$f"
    fi
done

for d in $PF_WT_OVERLAY_DIRS; do
    if [ -d "$WT/$d" ] && [ -d "$PF/$d" ]; then
        layer=$NS_TMP/overlay/${d//\//_}
        mkdir -p "$layer/upper" "$layer/work"
        mount -t overlay pf-wt-overlay \
            -o "lowerdir=$WT/$d:$PF/$d,upperdir=$layer/upper,workdir=$layer/work" "$PF/$d"
    else
        skip "$d"
    fi
done

if [ "$SHARED_PFCONFIG" -eq 0 ]; then
    # var/run on a tmpfs, every real entry bound back but the files of the
    # test pfconfig: the tests start their own one in the namespace.
    # (Sockets are not reachable through an overlayfs, hence the binds.)
    RUN=$PF/var/run
    run_perms=$(stat -c "%a %u:%g" "$RUN")
    mount --bind "$RUN" "$NS_TMP/real-run"
    mount -t tmpfs -o "mode=${run_perms%% *}" pf-wt-run "$RUN"
    chown "${run_perms#* }" "$RUN"
    shopt -s nullglob dotglob
    for e in "$NS_TMP"/real-run/*; do
        n=${e##*/}
        case " $PF_WT_PFCONFIG_FILES " in *" $n "*) continue ;; esac
        # Nothing to bind for a dangling symlink
        [ -e "$e" ] || continue
        if [ -d "$e" ]; then mkdir "$RUN/$n"; else : > "$RUN/$n"; fi
        # An entry can vanish since the glob (a pid file of a service
        # stopping): skip it, fail on any other error
        if ! mount --bind "$e" "$RUN/$n" 2>/dev/null; then
            if [ -e "$e" ]; then
                mount --bind "$e" "$RUN/$n"
            else
                # Empty mount point on the tmpfs, nothing mounted on it
                rmdir "$RUN/$n" 2>/dev/null || rm -f "$RUN/$n"
            fi
        fi
    done
    shopt -u nullglob dotglob
    mount -t tmpfs -o mode=1777 pf-wt-chi /tmp/chi
    # Private, empty state of the test pfconfigs, same owner and mode:
    # - var/control: pfconfig empties it on start, the tests touch its files
    # - var/cache/pfconfig: the BDB cache of pfconfig-test-serial, which the
    #   one of $PF holds open
    for d in var/control var/cache/pfconfig; do
        [ -d "$PF/$d" ] || continue
        perms=$(stat -c "%a %u:%g" "$PF/$d")
        mount -t tmpfs -o "mode=${perms%% *}" pf-wt-state "$PF/$d"
        chown "${perms#* }" "$PF/$d"
    done

    # Start the private pfconfig-test here, as t/pfconfig-test would, but in
    # the foreground of this shell: a failure is reported with its log instead
    # of the tests retrying its socket forever.
    PFCONFIG_LOG=$NS_TMP/pfconfig-test.log
    perl -I"$PF/t" -Mtest_paths "$PF/sbin/pfconfig" -n pfconfig-test \
        -s "$RUN/pfconfig-test.sock" -p "$RUN/pfconfig-test.pid" \
        -c "$PF/t/data/pfconfig.conf" > "$PFCONFIG_LOG" 2>&1 &
    PFCONFIG_PID=$!
    # Stopped gracefully first, for 10s at most (it only handles TERM once
    # preloaded); whatever is left is killed with the namespace
    stop_pfconfig() {
        kill "$PFCONFIG_PID" 2>/dev/null || return 0
        local i
        for i in $(seq 10); do
            kill -0 "$PFCONFIG_PID" 2>/dev/null || return 0
            sleep 1
        done
    }
    trap stop_pfconfig EXIT
    echo "pf-wt-test: starting a private pfconfig-test (log: $PFCONFIG_LOG)" >&2
    waited=0
    until [ -S "$RUN/pfconfig-test.sock" ]; do
        if ! kill -0 "$PFCONFIG_PID" 2>/dev/null || [ "$waited" -ge "$PFCONFIG_TIMEOUT" ]; then
            echo "pf-wt-test: pfconfig-test did not start, end of its log:" >&2
            grep -v " INFO: \|^Preloading " "$PFCONFIG_LOG" | tail -20 >&2
            exit 1
        fi
        sleep 1
        waited=$((waited + 1))
    done
    echo "pf-wt-test: pfconfig-test ready after ${waited}s" >&2
fi

cd "$RUN_DIR"
# Not the last command, so that bash never execs it as PID 1
rc=0
"$@" || rc=$?
exit "$rc"
' pf-wt-test "${ARGS[@]}"
