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
# started from the worktree's code before the tests and stopped on exit, and its
# own /tmp/chi: the worktree's config is built by its own code and the
# pfconfig-test of /usr/local/pf is left alone.
#
# Must run as root. Example, from a worktree:
#   addons/dev-helpers/pf-wt-test.sh t/unittest/Switch.t
#

set -euo pipefail

PF=/usr/local/pf
PROG=$(basename "$0")
CODE_DIRS=(lib t html/pfappserver/lib html/captive-portal/lib)
OVERLAY_DIRS=(conf)
# Files that git ignores but the tests need: copied into the worktree if missing
IGNORED_NEEDED=(lib/fingerbank t/data/system_init_key)
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

for f in "${IGNORED_NEEDED[@]}"; do
    if [ ! -e "$WT/$f" ] && [ ! -L "$WT/$f" ] && { [ -e "$PF/$f" ] || [ -L "$PF/$f" ]; }; then
        cp -a "$PF/$f" "$WT/$f"
        echo "$PROG: copied $f (ignored by git) into the worktree" >&2
    fi
done

# Run from the same place inside the namespace
case $PWD/ in
    "$WT"/*) RUN_DIR=$PF${PWD#"$WT"} ;;
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
# with the namespace. /tmp/chi is removed only if this script created it.
CREATED_CHI=0
cleanup() {
    rm -rf --one-file-system "$NS_TMP"
    if [ "$CREATED_CHI" -eq 1 ]; then rmdir /tmp/chi 2>/dev/null || true; fi
}
trap cleanup EXIT
mkdir "$NS_TMP/real-run"
# Mount point of the private /tmp/chi
if [ "$SHARED_PFCONFIG" -eq 0 ] && [ ! -e /tmp/chi ]; then
    mkdir /tmp/chi
    CREATED_CHI=1
fi

export PF WT NS_TMP RUN_DIR SHARED_PFCONFIG
export PFCONFIG_TIMEOUT=${PF_WT_PFCONFIG_TIMEOUT:-300}
export PF_WT_DIRS="${DIRS[*]}" PF_WT_OVERLAY_DIRS="${OVERLAY_DIRS[*]}" PF_WT_PFCONFIG_FILES="${PFCONFIG_TEST_FILES[*]}"

unshare -m --propagation private bash -c '
set -euo pipefail

for d in $PF_WT_DIRS; do
    if [ -d "$WT/$d" ] && [ -d "$PF/$d" ]; then
        mount --bind "$WT/$d" "$PF/$d"
    fi
done

for d in $PF_WT_OVERLAY_DIRS; do
    if [ -d "$WT/$d" ] && [ -d "$PF/$d" ]; then
        layer=$NS_TMP/overlay/${d//\//_}
        mkdir -p "$layer/upper" "$layer/work"
        mount -t overlay pf-wt-overlay \
            -o "lowerdir=$WT/$d:$PF/$d,upperdir=$layer/upper,workdir=$layer/work" "$PF/$d"
    fi
done

if [ "$SHARED_PFCONFIG" -eq 0 ]; then
    # var/run on a tmpfs, every real entry bound back but the files of the
    # test pfconfig: the tests start their own one in the namespace.
    # (Sockets are not reachable through an overlayfs, hence the binds.)
    RUN=$PF/var/run
    mount --bind "$RUN" "$NS_TMP/real-run"
    mount -t tmpfs -o mode=0755 pf-wt-run "$RUN"
    shopt -s nullglob dotglob
    for e in "$NS_TMP"/real-run/*; do
        n=${e##*/}
        case " $PF_WT_PFCONFIG_FILES " in *" $n "*) continue ;; esac
        if [ -d "$e" ]; then mkdir "$RUN/$n"; else : > "$RUN/$n"; fi
        # An entry can vanish since the glob (a pid file of a service
        # stopping): skip it, fail on any other error
        if ! mount --bind "$e" "$RUN/$n" 2>/dev/null; then
            if [ -e "$e" ] || [ -L "$e" ]; then
                mount --bind "$e" "$RUN/$n"
            else
                # Empty mount point on the tmpfs, nothing mounted on it
                rmdir "$RUN/$n" 2>/dev/null || rm -f "$RUN/$n"
            fi
        fi
    done
    shopt -u nullglob dotglob
    chown --reference="$NS_TMP/real-run" "$RUN"
    mount -t tmpfs -o mode=1777 pf-wt-chi /tmp/chi
    # pfconfig empties var/control on start and the cache updates of the
    # tests touch it: keep the control files of $PF out of reach
    CONTROL=$PF/var/control
    control_owner=$(stat -c %u:%g "$CONTROL")
    mount -t tmpfs -o mode=0755 pf-wt-control "$CONTROL"
    chown "$control_owner" "$CONTROL"

    # Start the private pfconfig-test here, as t/pfconfig-test would, but in
    # the foreground of this shell: a failure is reported with its log instead
    # of the tests retrying its socket forever.
    PFCONFIG_LOG=$NS_TMP/pfconfig-test.log
    perl -I"$PF/t" -Mtest_paths "$PF/sbin/pfconfig" -n pfconfig-test \
        -s "$RUN/pfconfig-test.sock" -p "$RUN/pfconfig-test.pid" \
        -c "$PF/t/data/pfconfig.conf" > "$PFCONFIG_LOG" 2>&1 &
    PFCONFIG_PID=$!
    trap "kill $PFCONFIG_PID 2>/dev/null || true" EXIT
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
"$@"
' pf-wt-test "${ARGS[@]}"
