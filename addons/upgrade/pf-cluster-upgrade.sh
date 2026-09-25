#!/bin/bash
#
# pf-cluster-upgrade.sh
#
# Automates "Performing an upgrade on a cluster" (Clustering Guide 12.4) for a
# 3-node cluster. Runs on one node and drives all three over SSH; the per-node
# version upgrade itself stays with do-upgrade.sh (Upgrade Guide 5.1).
#
# Roles A, B, C follow cluster.conf order; C is detached and upgraded first.
# Phases: see --help.
#
# Deliberately does not source addons/functions/helpers.functions: this script
# runs across a package change and must not depend on a library that is being
# upgraded underneath it.
#
# Exit: 0 ok | 1 hard failure | 2 usage error | 3 aborted by user
#
# Copyright (C) 2005-2026 Inverse inc.
#
# Author: Inverse inc. <info@inverse.ca>
#
# Licensed under the GPL
#

set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"
SCRIPT_VERSION="2.2.2"

# --- Configuration (overridable by file or CLI) -------------------------------
# Next to the other PacketFence configuration; pfcmd fixpermissions does not
# descend into conf/, so mode 600 survives.
CONFIG_FILE="/usr/local/pf/conf/pf-cluster-upgrade.conf"

NODES=()                  # empty => order from cluster.conf (A B C)
PIONEER=""                # empty => last node in cluster.conf (= C)
SSH_USER="root"
# A hostname, not a master/slave flag - so one config file is valid on every
# node and can be distributed via git. Empty = no restriction (warns once).
MASTER_NODE=""

# This node's private key for reaching the others. Empty means "not set up";
# nothing is guessed or searched for, preflight asks instead.
SSH_IDENTITY=""
# Path preflight offers for a new key. Own name so an existing default key is
# never overwritten.
SSH_IDENTITY_NEW="/root/.ssh/id_pf_cluster"
SSH_CONNECT_TIMEOUT=10
SSH_ALIVE_INTERVAL=15     # keepalive interval; detects dead connections
SSH_ALIVE_COUNT=4         # ssh aborts after INTERVAL*COUNT seconds
RETRY_COUNT=5             # retries for pure connection failures
RETRY_DELAY=15            # seconds between attempts
DETACH_TIMEOUT=14400      # max runtime of a detached operation (4h)
INTERACTIVE_UPGRADE=0     # 1 = bind do-upgrade.sh to the terminal
POLL_SECS=15              # interval between status queries in the wait loops.
                          # 0 is allowed (tests): poll_step still advances the
                          # counter, otherwise the loop would never end.

# Target version, passed to do-upgrade.sh as UPGRADE_TO. Without it
# run-upgrade.sh would prompt (set_upgrade_to) and hang while detached.
TARGET_VERSION=""

# Passed to do-upgrade.sh as INCLUDE_OS_UPDATE; without a value run-upgrade.sh
# prompts. "no" because phase 'patch' already updated the OS.
INCLUDE_OS_UPDATE=no
SSH_EXTRA_OPTS=""

PF_ROOT="/usr/local/pf"
PFCMD="/usr/local/pf/bin/pfcmd"
CLUSTER_NODE_CMD="/usr/local/pf/bin/cluster/node"
CLUSTER_SYNC_CMD="/usr/local/pf/bin/cluster/sync"
DO_UPGRADE="/usr/local/pf/addons/upgrade/do-upgrade.sh"

LOG_DIR="/usr/local/pf/logs"    # next to the other PacketFence logs
STATE_FILE="/root/.pf-cluster-upgrade.state"
LOCK_FILE="/var/lock/pf-cluster-upgrade.lock"

WS_USER=""                # webservices user for cluster/sync
WS_PASS=""                # empty => read from pf.conf, otherwise prompt

MIN_FREE_MB_MYSQL=10240   # /var/lib/mysql - A and B resync from scratch
MIN_FREE_MB_ROOT=8192      # full backup by run-upgrade.sh + new container images
MIN_FREE_MB_APTCACHE=2048  # downloaded packages
SERVICE_WAIT_TIMEOUT=600  # not wall clock: a round costs more than POLL_SECS
                          # ('pfcmd service pf status' ~8s), so 600 is ~13 min
SERVICE_OK_POLLS=2        # green polls in a row before a node counts healthy.
                          # Units use Restart=on-failure, so one green poll can
                          # catch a service that crashes right after.
GALERA_WAIT_TIMEOUT=3600  # a full sync of A and B can take up to 1h per the guide
DB_WAIT_TIMEOUT=180       # how long to wait for the database after a start
CONFIG_SETTLE_SECS=20     # pause between 'configreload hard' and starting
                          # the services - see RS_PREP_CONFIG.
SERVICE_REVIVE=1          # 1 = poke units stuck in the start limit once
SERVICE_REVIVE_AFTER=60   # ... no earlier than this many wait seconds
VERIFY_RETRIES=6          # retry effect checks this often before they
VERIFY_RETRY_SECS=5       # ... count as failed
MARIADB_STOP_TIMEOUT=600  # time limit for the shutdown marker in the journal
MARIADB_STOP_GRACE=60     # grace period after it, before SIGKILL helps
VIP_WAIT_TIMEOUT=180      # how long to wait for the VIP after keepalived starts
CLUSTER_VIP=""            # empty = management_ip of [CLUSTER] in cluster.conf

ASSUME_YES=0
KEEP_STATE=0        # 1 = keep the state file after 'finish'
DRY_RUN=0
RESUME=0
REBASELINE=0        # re-record the service baseline
NO_COLOR=0
PHASE=""

# Services that 12.4.4 requires to be restarted on A and B after C has been
# disabled - in the order given by the guide.
DETACH_RESTART_SERVICES=(radiusd pfdhcplistener haproxy-admin haproxy-db
                         proxysql haproxy-portal keepalived)


# --- Runtime ------------------------------------------------------------------
RUN_ID="$(date +%Y%m%d-%H%M%S)"
RUN_LOG=""
LOCK_HELD=0
# Phase named in the resume hint. During a full run that is "run", not the
# sub-phase currently executing.
RESUME_PHASE=""
NO_RESUME_HINT=0          # 1 = name no resume command on abort
RSTEP_OUT=""              # output of the last rstep, for effect checks
SELF_HOST=""
NODE_A=""; NODE_B=""; NODE_C=""
declare -a FAIL_LIST=()
declare -a WARN_LIST=()
declare -A NI=()
# Outages last determined by services_healthy, for the error message.
SERVICES_DOWN_LAST=""
# Services that must not count as an outage while they are deliberately held
# back - see start_pf_vip_last.
declare -a SERVICES_IGNORE=()
# Node whose keepalived is masked right now, so cleanup can release it even
# when the run dies in between.
KEEPALIVED_MASKED_NODE=""
# 1 = preflight found the target version already in place on every node.
SAME_VERSION=0
# Node name -> SSH target, filled from management_ip in cluster.conf.
declare -A NODE_SSH=()

C_RST=""; C_RED=""; C_GRN=""; C_YEL=""; C_BLU=""; C_BLD=""; C_DIM=""

setup_colors() {
    if [[ $NO_COLOR -eq 1 || ! -t 1 ]]; then
        C_RST=""; C_RED=""; C_GRN=""; C_YEL=""; C_BLU=""; C_BLD=""; C_DIM=""
    else
        C_RST=$'\033[0m'; C_RED=$'\033[31m'; C_GRN=$'\033[32m'
        C_YEL=$'\033[33m'; C_BLU=$'\033[36m'; C_BLD=$'\033[1m'; C_DIM=$'\033[2m'
    fi
}

# --- Output -------------------------------------------------------------------
_ts() { date '+%Y-%m-%d %H:%M:%S'; }

say() {
    printf '%s\n' "$1"
    [[ -n "$RUN_LOG" ]] && printf '%s %s\n' "$(_ts)" \
        "$(sed 's/\x1b\[[0-9;]*m//g' <<<"$1")" >>"$RUN_LOG"
    return 0
}

# Same as say(), but to stderr. For helpers whose stdout the caller captures:
# a progress line inside "$(...)" is parsed as remote output, not shown.
say_err() {
    printf '%s\n' "$1" >&2
    [[ -n "$RUN_LOG" ]] && printf '%s %s\n' "$(_ts)" \
        "$(sed 's/\x1b\[[0-9;]*m//g' <<<"$1")" >>"$RUN_LOG"
    return 0
}
log_warn_err() { say_err "${C_YEL}[WARN]${C_RST} $*"; }
log_dim_err()  { say_err "${C_DIM}    $*${C_RST}"; }

log_head() { say ""; say "${C_BLD}${C_BLU}=== $* ===${C_RST}"; }
log_step() { say "${C_BLU}--> ${C_RST}$*"; }
log_info() { say "    $*"; }
log_dim()  { say "${C_DIM}    $*${C_RST}"; }
log_ok()   { say "${C_GRN}[ OK ]${C_RST} $*"; }
log_warn() { say "${C_YEL}[WARN]${C_RST} $*"; WARN_LIST+=("$*"); }
log_fail() { say "${C_RED}[FAIL]${C_RST} $*"; FAIL_LIST+=("$*"); }

die() {
    local msg="$1"; shift || true
    say ""
    say "${C_RED}${C_BLD}ABORT:${C_RST} ${msg}"
    local h; for h in "$@"; do say "${C_YEL}  hint:${C_RST} ${h}"; done
    say ""
    say "Log: ${RUN_LOG:-<none>}"
    # Resuming makes no sense after some aborts (wrong node).
    [[ ${NO_RESUME_HINT:-0} -eq 0 && -n "${RESUME_PHASE:-$PHASE}" ]] \
        && say "Resume after fixing: ${SCRIPT_NAME} ${RESUME_PHASE:-$PHASE} --resume"
    exit 1
}

on_err() {
    local rc=$? line=$1 cmd=$2
    say ""
    say "${C_RED}${C_BLD}UNEXPECTED ERROR${C_RST} (rc=${rc}) on line ${line}:"
    say "${C_DIM}  ${cmd}${C_RST}"
    say "Aborting so as not to leave a half-finished state behind."
    say "Log: ${RUN_LOG:-<none>}"
    exit 1
}
trap 'on_err ${LINENO} "$BASH_COMMAND"' ERR

cleanup() {
    # A masked keepalived would leave the cluster without a VIP. Whatever
    # killed the run, this has to come off again - best effort, and loudly.
    if [[ -n "$KEEPALIVED_MASKED_NODE" ]]; then
        local kn="$KEEPALIVED_MASKED_NODE"; KEEPALIVED_MASKED_NODE=""
        say "${C_YEL}[WARN]${C_RST} releasing keepalived on ${kn} again"
        rexec "$kn" "$RS_KEEPALIVED_START" >/dev/null 2>&1 \
            || say "${C_RED}[FAIL]${C_RST} ${kn}: keepalived stayed masked - systemctl unmask packetfence-keepalived"
    fi
    [[ $LOCK_HELD -eq 1 && -e "$LOCK_FILE" ]] && rm -f "$LOCK_FILE" 2>/dev/null || true
    return 0
}
trap cleanup EXIT

# Discard whatever was typed during a long wait: an impatient Enter from 20
# minutes ago must not answer the next question.
tty_flush() {
    [[ -r /dev/tty ]] || return 0
    local junk
    # The variable is the discard bucket - draining the buffer is the point.
    # shellcheck disable=SC2034
    read -r -t 0.1 -N 10000 junk </dev/tty 2>/dev/null || true
    return 0
}

# Answer of the last tty_ask. Kept apart from the return code - they mean
# different things.
TTY_ANSWER=""

# tty_ask <prompt> -> answer in TTY_ANSWER
#   rc 0 = something was read (an empty line counts)
#   rc 1 = EOF or no usable /dev/tty
# Without that distinction EOF looks like a pressed Enter - both would abort.
tty_ask() {
    local rc=0
    TTY_ANSWER=""
    [[ -r /dev/tty ]] || return 1
    tty_flush
    printf '%s' "$1"
    read -r TTY_ANSWER </dev/tty || rc=$?
    return $rc
}

# Records what was asked and answered, with a reason instead of just "<empty>".
ask_log() {
    [[ -n "$RUN_LOG" ]] || return 0
    printf '%s QUESTION: %s -> %s\n' "$(_ts)" "$1" "$2" >>"$RUN_LOG"
    return 0
}

# Like confirm(), but returns 1 on "no" instead of aborting.
# For offers that may be declined.
ask_yes_no() {
    [[ $DRY_RUN -eq 1 ]] && return 1
    [[ -t 0 ]] || return 1
    tty_ask "${C_YEL}$1 [yes/NO]: ${C_RST}" || { ask_log "$1" "<EOF>"; return 1; }
    ask_log "$1" "${TTY_ANSWER:-<empty>}"
    case "${TTY_ANSWER,,}" in yes|y) return 0 ;; *) return 1 ;; esac
}

# Creates this node's key pair, distributes it and records the path in the
# config file. ssh-copy-id asks for the password itself - never this script.
ssh_identity_setup() {
    local -a peers=("$@")
    local n tgt

    command -v ssh-copy-id >/dev/null 2>&1 \
        || { log_fail "ssh-copy-id is not available"; return 1; }

    if [[ -f "$SSH_IDENTITY_NEW" ]]; then
        log_info "${SSH_IDENTITY_NEW} already exists - reusing it, not overwriting."
    else
        mkdir -p "$(dirname "$SSH_IDENTITY_NEW")" && chmod 700 "$(dirname "$SSH_IDENTITY_NEW")"
        # No passphrase: BatchMode cannot supply one, and the script opens
        # hundreds of short connections over its lifetime.
        ssh-keygen -t ed25519 -N "" -f "$SSH_IDENTITY_NEW" -C "pf-cluster-upgrade@$(hostname -s)" \
            >/dev/null 2>&1 || { log_fail "ssh-keygen failed"; return 1; }
        chmod 600 "$SSH_IDENTITY_NEW"
        log_ok "Key pair created: ${SSH_IDENTITY_NEW}"
    fi

    for n in "${peers[@]}"; do
        tgt="$(ssh_target "$n")"
        log_step "${n}: copying the public key to ${SSH_USER}@${tgt}"
        log_info "  ssh-copy-id will now ask for the password of ${SSH_USER}@${tgt}."
        ssh-copy-id -i "${SSH_IDENTITY_NEW}.pub" -o StrictHostKeyChecking=accept-new \
            "${SSH_USER}@${tgt}" </dev/tty \
            || { log_fail "${n}: ssh-copy-id failed"; return 1; }
    done

    SSH_IDENTITY="$SSH_IDENTITY_NEW"; ssh_opts_init
    config_set_identity || return 1

    for n in "${peers[@]}"; do
        rexec "$n" 'true' >/dev/null 2>&1 \
            || { log_fail "${n}: login with the new key still does not work"; return 1; }
    done
    log_ok "Key set up and recorded in ${CONFIG_FILE}"
    return 0
}

# Writes SSH_IDENTITY to the config file, creating it if needed.
config_set_identity() {
    local tmp
    if [[ ! -f "$CONFIG_FILE" ]]; then
        printf '# Created by pf-cluster-upgrade.sh.\n' > "$CONFIG_FILE" || return 1
    fi
    # The temp file holds the whole configuration, WS_PASS included, and 'mv'
    # passes ITS mode on to the config file - so it must be 600 from the start,
    # not only after the move.
    tmp=$(mktemp "${CONFIG_FILE}.XXXXXX") || return 1
    chmod 600 "$tmp"
    grep -v '^[[:space:]]*SSH_IDENTITY=' "$CONFIG_FILE" >> "$tmp" 2>/dev/null || true
    printf 'SSH_IDENTITY=%s\n' "$SSH_IDENTITY" >> "$tmp" || { rm -f "$tmp"; return 1; }
    mv "$tmp" "$CONFIG_FILE" || { rm -f "$tmp"; return 1; }
    # May contain credentials (WS_PASS) - not world-readable.
    chmod 600 "$CONFIG_FILE"
    return 0
}

# Prints what to do by hand. Always shown when setup is not automatic, with the
# config file path and the required permissions.
ssh_identity_hint() {
    local n
    say ""
    say "${C_BLD}Manual setup:${C_RST}"
    say "  1. Create this node's key (no passphrase):"
    say "     ssh-keygen -t ed25519 -N '' -f ${SSH_IDENTITY_NEW}"
    say "     chmod 600 ${SSH_IDENTITY_NEW}"
    say "  2. Distribute it to the other nodes:"
    for n in "${NODES[@]}"; do
        is_self "$n" && continue
        say "     ssh-copy-id -i ${SSH_IDENTITY_NEW}.pub ${SSH_USER}@$(ssh_target "$n")"
    done
    say "  3. Record it in the configuration file:"
    say "     ${C_BLD}${CONFIG_FILE}${C_RST}"
    say "     SSH_IDENTITY=${SSH_IDENTITY_NEW}"
    say "     chmod 600 ${CONFIG_FILE}"
    say ""
    say "  Permissions: private key ${C_BLD}600${C_RST} (ssh rejects anything wider),"
    say "  configuration file ${C_BLD}600${C_RST} (may hold the webservices password)."
    say ""
}

# EOF is not a user abort but a usage error: the question was never asked.
# Hence exit 2 and a message that says what to do.
die_no_input() {
    say ""
    say "${C_RED}${C_BLD}ABORT:${C_RST} No input possible - the question went unanswered."
    say "${C_YEL}  hint:${C_RST} /dev/tty returns EOF. This is NOT a user abort."
    say "${C_YEL}  hint:${C_RST} Start it in an interactive session (e.g. tmux),"
    say "${C_YEL}  hint:${C_RST} or run it unattended with --yes."
    say ""
    say "Log: ${RUN_LOG:-<none>}"
    [[ ${NO_RESUME_HINT:-0} -eq 0 && -n "${RESUME_PHASE:-$PHASE}" ]] \
        && say "Resume: ${SCRIPT_NAME} ${RESUME_PHASE:-$PHASE} --resume"
    exit 2
}

confirm() {
    [[ $ASSUME_YES -eq 1 ]] && { log_dim "(auto-confirmed: $1)"; return 0; }
    [[ $DRY_RUN -eq 1 ]] && { log_dim "(dry-run: $1)"; return 0; }
    local try
    for (( try = 1; try <= 3; try++ )); do
        tty_ask "${C_YEL}$1 [yes/NO]: ${C_RST}" || { ask_log "$1" "<EOF>"; die_no_input; }
        case "${TTY_ANSWER,,}" in
            yes|y)
                ask_log "$1" "$TTY_ANSWER"; return 0 ;;
            "")
                # An empty line no longer kills a running upgrade.
                ask_log "$1" "<empty, attempt ${try}/3>"
                say "${C_YEL}Please answer 'yes' or 'no'.${C_RST}" ;;
            *)
                ask_log "$1" "$TTY_ANSWER"
                say "${C_YEL}Aborted by user.${C_RST}"; exit 3 ;;
        esac
    done
    say "${C_YEL}Three times no answer - aborting.${C_RST}"
    exit 3
}

# confirm_typed <question> <word> - for destructive steps
confirm_typed() {
    [[ $DRY_RUN -eq 1 ]] && { log_dim "(dry-run: $1)"; return 0; }
    if [[ $ASSUME_YES -eq 1 ]]; then log_dim "(auto-confirmed: $1)"; return 0; fi
    say "${C_RED}${C_BLD}$1${C_RST}"
    local try
    for (( try = 1; try <= 3; try++ )); do
        tty_ask "${C_YEL}Type '$2' to continue: ${C_RST}" \
            || { ask_log "$1" "<EOF>"; die_no_input; }
        [[ "$TTY_ANSWER" == "$2" ]] && { ask_log "$1" "$TTY_ANSWER"; return 0; }
        # Only an empty line gets another try: anything else typed means the
        # step was declined.
        [[ -n "$TTY_ANSWER" ]] && {
            ask_log "$1" "$TTY_ANSWER"
            say "${C_YEL}Aborted by user.${C_RST}"; exit 3
        }
        ask_log "$1" "<empty, attempt ${try}/3>"
        say "${C_YEL}Type '$2' or abort with Ctrl-C.${C_RST}"
    done
    say "${C_YEL}Three times no answer - aborting.${C_RST}"
    exit 3
}

# --- State (for --resume) -----------------------------------------------------

# Read-modify-write of the state file: drop every line matching <regex>, then
# optionally append <line>, then replace the file.
#
# Two things this has to survive, both of them real:
#   - A SECOND INSTANCE. 'status' and 'preflight' also write here (roles,
#     baselines), and the script itself tells the operator to run 'status' in
#     another terminal while an upgrade is going on. A fixed temp name plus an
#     unsynchronised read-modify-write would let one process publish a state
#     without the markers the other just wrote - and --resume would then repeat
#     a step like the wipe of /var/lib/mysql. Hence flock plus mktemp.
#   - A FULL /root. run-upgrade.sh puts a whole backup there, which is why
#     MIN_FREE_MB_ROOT exists. A short write must leave the old file alone
#     instead of replacing it with a truncated one.
state_rewrite() {
    local drop="$1" add="${2-}" tmp rc=0
    exec 9>>"${STATE_FILE}.lock" || return 1
    chmod 600 "${STATE_FILE}.lock" 2>/dev/null || true
    flock -w 30 9 || { exec 9>&-; return 1; }
    tmp=$(mktemp "${STATE_FILE}.XXXXXX") || { exec 9>&-; return 1; }
    chmod 600 "$tmp"
    if [[ -f "$STATE_FILE" ]]; then
        grep -vE "$drop" "$STATE_FILE" >>"$tmp" || rc=$?
        # 1 = every line dropped, that is normal. 2 = read or WRITE error.
        [[ $rc -le 1 ]] || { rm -f "$tmp"; exec 9>&-; return 1; }
    fi
    if [[ -n "$add" ]]; then
        printf '%s\n' "$add" >>"$tmp" || { rm -f "$tmp"; exec 9>&-; return 1; }
    fi
    mv "$tmp" "$STATE_FILE" || { rm -f "$tmp"; exec 9>&-; return 1; }
    exec 9>&-
    return 0
}

state_set() {
    [[ $DRY_RUN -eq 1 ]] && return 0
    state_rewrite "^${1//./\\.}=" "$(printf '%s=%s' "$1" "$2")" \
        || die "Could not write the state file ${STATE_FILE}." \
               "Check the free space under $(dirname "$STATE_FILE") and the permissions." \
               "Without it --resume loses track of what has already been done."
    return 0
}
# Prints the value and ALWAYS returns 0: a missing value is normal on the first
# run. A trailing '[[ -n "$v" ]] &&' would return 1 and 'set -e' would then
# abort the whole phase.
state_get() {
    [[ -f "$STATE_FILE" ]] || return 0
    local v; v=$(grep "^${1}=" "$STATE_FILE" 2>/dev/null | tail -n1 | cut -d= -f2-) || true
    [[ -n "$v" ]] && printf '%s' "$v"
    return 0
}
# Is the key recorded at all? Not the same as having a value: an empty service
# baseline means "everything runs" and must not count as "nothing recorded yet".
state_has() {
    [[ -f "$STATE_FILE" ]] || return 1
    grep -q "^${1}=" "$STATE_FILE" 2>/dev/null
}
mark_done() { state_set "done.$1" "1"; }
# Drops every key with this prefix. A phase that undoes another one must also
# drop its step markers, or --resume would skip steps that no longer happened.
state_unset_prefix() {
    [[ $DRY_RUN -eq 1 ]] && return 0
    [[ -f "$STATE_FILE" ]] || return 0
    state_rewrite "^${1//./\\.}" \
        || die "Could not write the state file ${STATE_FILE}." \
               "The markers of the undone phase are still in there - remove them" \
               "by hand before the next --resume."
    return 0
}
# done_skip <key> -> 0 if the step should be skipped
done_skip() {
    [[ $RESUME -eq 1 ]] || return 1
    [[ "$(state_get "done.$1" || true)" == "1" ]] || return 1
    log_dim "skipped (already done): $1"
    return 0
}

# --- Execution on the nodes ---------------------------------------------------
# No next-phase hint during a full run - it continues on its own.
next_hint() {
    [[ "$RESUME_PHASE" == "run" ]] && return 0
    say "${C_BLD}Next step:${C_RST} ${SCRIPT_NAME} $1"
}

# verify <node> <description> <remote test> [error text ...]
# Checks the EFFECT of a step, not just its return code. A command can return 0
# and still have done nothing - in a cluster that only surfaces phases later.
verify() {
    local node="$1" desc="$2" test="$3"; shift 3
    [[ $DRY_RUN -eq 1 ]] && { log_dim "[dry-run] check skipped: ${desc}"; return 0; }
    # Retry instead of judging once: some steps do not take effect immediately
    # (services linger in 'deactivating'). The good case hits on the first try.
    local try
    for (( try = 1; try <= VERIFY_RETRIES; try++ )); do
        if rexec_retry "$node" "$test" 2>/dev/null | grep -q '^VERIFY_OK$'; then
            [[ $try -gt 1 ]] && log_ok "  verified: ${desc} (after ${try} attempts)" \
                             || log_ok "  verified: ${desc}"
            return 0
        fi
        (( try < VERIFY_RETRIES )) && sleep "$VERIFY_RETRY_SECS"
    done
    log_fail "${node}: check failed - ${desc} (${VERIFY_RETRIES} attempts)"
    die "${node}: the step had no effect: ${desc}" "$@"
}

# verify_node_disabled <on_node> <disabled_node>
# The node name is escaped before it goes into the test: it comes from
# cluster.conf or --nodes, and verify() hands this text to a shell on the far
# side. Two callers in 12.4.4, from both directions.
verify_node_disabled() {
    local on_node="$1" disabled_node="$2" q
    q="$(printf '%q' "${disabled_node}")"
    verify "$on_node" "${disabled_node} is disabled on ${on_node}" \
        "test -f ${PF_ROOT}/var/run/${q}-cluster-disabled && echo VERIFY_OK" \
        "bin/cluster/node creates ${PF_ROOT}/var/run/<host>-cluster-disabled for this."
}

# Is the procedure already running? Once 'prepare' is done the cluster has left
# its initial state, and preflight must no longer demand it.
procedure_started() {
    local k
    for k in prepared migrated_to_c ab_upgraded reintegrated; do
        [[ "$(state_get "$k")" == "1" ]] && return 0
    done
    return 1
}

# Returns 1 when POLL_SECS is 0, so a wait loop still advances its counter
# and terminates - the tests run with POLL_SECS=0.
poll_step() { (( POLL_SECS > 0 )) && printf '%s' "$POLL_SECS" || printf '1'; }

ssh_opts_init() {
    SSH_OPTS=(-o BatchMode=yes
              -o "ConnectTimeout=${SSH_CONNECT_TIMEOUT}"
              # ConnectTimeout covers only the handshake; without ServerAlive
              # a half-open connection would block the script forever.
              -o "ServerAliveInterval=${SSH_ALIVE_INTERVAL}"
              -o "ServerAliveCountMax=${SSH_ALIVE_COUNT}"
              -o TCPKeepAlive=yes
              -o StrictHostKeyChecking=accept-new
              -o LogLevel=ERROR)
    # No '&&' as the function's last statement: a false condition returns 1,
    # and under 'set -e' the ERR trap fires before any phase even starts.
    if [[ -n "$SSH_IDENTITY" ]]; then
        # Without IdentitiesOnly ssh also offers every default key and
        # exhausts MaxAuthTries (sshd default 6) - the login then fails even
        # though a valid key was among them.
        SSH_OPTS+=(-i "$SSH_IDENTITY" -o IdentitiesOnly=yes)
    fi
    if [[ -n "$SSH_EXTRA_OPTS" ]]; then
        # shellcheck disable=SC2206
        SSH_OPTS+=($SSH_EXTRA_OPTS)
    fi
}

# The master is the node whose short name matches MASTER_NODE. Unset, every
# node counts as master and require_master warns once.
is_master() {
    [[ -z "$MASTER_NODE" ]] && return 0
    [[ "${MASTER_NODE%%.*}" == "${SELF_HOST%%.*}" ]]
}

# Refuses the changing phases on a non-master - otherwise two nodes could run
# the procedure at once from the same distributed config.
require_master() {
    if [[ -z "$MASTER_NODE" ]]; then
        log_warn "No MASTER_NODE set in ${CONFIG_FILE}."
        log_info "  Without it any node may start the procedure. With a config"
        log_info "  distributed via git, name the driving node there."
        return 0
    fi
    is_master && return 0
    NO_RESUME_HINT=1
    die "This node (${SELF_HOST}) is not the master." \
        "The procedure is driven from ${MASTER_NODE} only - start it there." \
        "Only the read-only phases are available here: status, preflight." \
        "To drive from this node, change MASTER_NODE in ${CONFIG_FILE}."
}

is_self() {
    [[ "${1%%.*}" == "${SELF_HOST%%.*}" ]]
}

# The cluster.conf section name is the node's identity (bin/cluster/node knows
# it only that way), but works as an address only if it resolves - so the
# management_ip from cluster.conf takes precedence.
ssh_target() {
    printf '%s' "${NODE_SSH[$1]:-$1}"
}

# Fills NODE_SSH. Falls back to the name when no management_ip is recorded -
# e.g. for a list passed via --nodes.
resolve_ssh_targets() {
    local n ip
    for n in "${NODES[@]}"; do
        ip="$(node_mgmt_ip "$n" 2>/dev/null || true)"
        if [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            NODE_SSH["$n"]="$ip"
        else
            NODE_SSH["$n"]="$n"
        fi
    done
}

# rexec <node> <script> - quiet, returns stdout+stderr, rc as return code
rexec() {
    local node="$1" script="$2"; shift 2
    local rc=0 out=""
    script="$(printf 'PF_ROOT=%q\nPFCMD=%q\n%s' "$PF_ROOT" "$PFCMD" "$script")"
    if is_self "$node"; then
        out=$(LC_ALL=C bash -s -- "$@" <<<"$script" 2>&1) || rc=$?
    else
        local qa=""; [[ $# -gt 0 ]] && qa="$(printf '%q ' "$@")"
        out=$(LC_ALL=C ssh "${SSH_OPTS[@]}" "${SSH_USER}@$(ssh_target "$node")" \
              "LC_ALL=C bash -s -- ${qa}" <<<"$script" 2>&1) || rc=$?
    fi
    printf '%s' "$out"
    return $rc
}

# rstep <node> <description> <script> - honours --dry-run and does NOT abort on
# failure itself; the caller decides (usually with die()).
rstep() {
    local node="$1" desc="$2" script="$3"; shift 3
    if [[ $DRY_RUN -eq 1 ]]; then
        log_dim "[dry-run] ${node}: ${desc}"
        return 0
    fi
    log_step "${node}: ${desc}"
    local out rc=0
    out=$(rexec "$node" "$script" "$@") || rc=$?
    RSTEP_OUT="$out"   # so the caller can inspect the output
    if [[ -n "$out" && -n "$RUN_LOG" ]]; then
        { echo "--- ${node}: ${desc} ---"; echo "$out"; echo "--- end ---"; } >>"$RUN_LOG"
    fi
    if [[ $rc -ne 0 ]]; then
        say "${C_RED}    Output:${C_RST}"
        tail -n 30 <<<"$out" | sed 's/^/      /' | while IFS= read -r l; do say "$l"; done
    fi
    return $rc
}

# rtty <node> <description> <command line>
# For interactive runs (do-upgrade.sh may prompt): output streams live and stdin
# stays the terminal.
rtty() {
    local node="$1" desc="$2" cmd="$3"
    if [[ $DRY_RUN -eq 1 ]]; then
        log_dim "[dry-run] ${node}: ${desc}"
        log_dim "[dry-run]   ${cmd}"
        return 0
    fi
    log_step "${node}: ${desc}"
    say "${C_DIM}    Command: ${cmd}${C_RST}"
    say "${C_DIM}    Output streams live; prompts can be answered here.${C_RST}"
    say ""
    local rc=0
    if is_self "$node"; then
        bash -c "$cmd" 2>&1 | tee -a "$RUN_LOG" || rc=${PIPESTATUS[0]}
    else
        ssh -tt "${SSH_OPTS[@]}" "${SSH_USER}@$(ssh_target "$node")" "$cmd" 2>&1 | tee -a "$RUN_LOG" || rc=${PIPESTATUS[0]}
    fi
    say ""
    return $rc
}

# rexec_retry <node> <script> [args...]
# Like rexec, but retries pure connection failures (ssh returns 255). Use ONLY
# for read-only or idempotent calls - after an abort a changing command may
# already have run.
rexec_retry() {
    local node="$1"; shift
    local try=1 rc=0 out=""
    while :; do
        rc=0; out=$(rexec "$node" "$@") || rc=$?
        [[ $rc -ne 255 ]] && break
        # 255 only means "ssh itself failed". An unknown host or a rejected
        # login will not improve - do not hit that wall RETRY_COUNT times.
        if grep -qiE 'could not resolve|name or service not known|permission denied|no route to host' <<<"$out"; then
            break
        fi
        # To stderr: every caller of rexec_retry captures stdout. WARN_LIST
        # would be lost in the subshell anyway, so the caller reports the
        # failure - here we only keep the operator informed while it waits.
        if (( try >= RETRY_COUNT )); then
            log_warn_err "${node}: connection not restored after ${RETRY_COUNT} attempts"
            break
        fi
        log_dim_err "${node}: connection error - attempt ${try}/${RETRY_COUNT}, retrying in ${RETRY_DELAY}s"
        sleep "$RETRY_DELAY"; try=$((try+1))
    done
    printf '%s' "$out"
    return $rc
}

# rdetach <node> <unit> <description> <script>
#
# A long task inside the SSH session dies on SIGHUP when the connection drops -
# the worst possible moment during 'apt upgrade' or do-upgrade.sh. As a
# transient systemd unit it no longer hangs off the terminal; progress is
# followed through short, repeated queries.
rdetach() {
    local node="$1" unit="$2" desc="$3" script="$4"
    if [[ $DRY_RUN -eq 1 ]]; then
        log_dim "[dry-run] ${node}: ${desc} (detached as ${unit})"
        return 0
    fi

    local logf="${LOG_DIR}/${unit}.log"
    log_step "${node}: ${desc}"
    log_dim  "runs as systemd unit ${unit}; a dropped connection does not interrupt it"

    local out rc=0
    out=$(rexec "$node" "$RS_DETACH_START" "$unit" "$logf" "$script") || rc=$?
    if [[ $rc -ne 0 ]]; then
        say "${C_RED}    ${out}${C_RST}"
        return $rc
    fi
    if grep -q 'ALREADY_RUNNING' <<<"$out"; then
        log_info "  already running there - only following its progress"
    elif grep -q '^ALREADY_DONE:' <<<"$out"; then
        # The log shown below is from the EARLIER run - say so, or the next
        # person debugs the wrong one.
        local drc; drc=$(sed -n 's/^ALREADY_DONE://p' <<<"$out" | head -n1)
        log_warn "  ${unit} already left a result on ${node} (rc=${drc})"
        log_info "  So it ran through earlier, probably after a dropped connection."
        log_info "  It is NOT started again; the output below comes from that run."
        log_info "  To start over: delete /run/${unit}.rc on the node."
    elif ! grep -q 'STARTED' <<<"$out"; then
        say "${C_RED}    unexpected reply on start: ${out}${C_RST}"
        return 1
    fi

    # Each query is its own short connection; a failed one is retried without
    # disturbing the operation.
    local offset=0 waited=0 state="" urc="" size="" body=""
    while (( waited < DETACH_TIMEOUT )); do
        rc=0
        out=$(rexec_retry "$node" "$RS_DETACH_POLL" "$unit" "$logf" "$offset") || rc=$?
        if [[ $rc -ne 0 ]]; then
            log_warn "${node}: status not queryable - the operation keeps running there"
            sleep "$RETRY_DELAY"; waited=$((waited+RETRY_DELAY)); continue
        fi
        state=$(sed -n 's/^STATE://p' <<<"$out" | head -n1)
        urc=$(sed -n 's/^RC://p' <<<"$out" | head -n1)
        size=$(sed -n 's/^SIZE://p' <<<"$out" | head -n1)
        body=$(sed -n '/^---LOG---$/,$p' <<<"$out" | tail -n +2)
        if [[ -n "$body" ]]; then
            while IFS= read -r l; do [[ -n "$l" ]] && log_dim "  | $l"; done <<<"$body"
            [[ -n "$RUN_LOG" ]] && printf '%s\n' "$body" >>"$RUN_LOG"
        fi
        [[ "$size" =~ ^[0-9]+$ ]] && offset="$size"

        case "$state" in
            done)
                # Clean up as soon as the result was read: a leftover .rc
                # file makes the next run adopt it and replay the old log.
                # Cleanup precedes the message, so an abort leaves nothing.
                rexec "$node" "$RS_DETACH_CLEAN" "$unit" "$logf" "$RUN_ID" \
                    >/dev/null 2>&1 || true
                log_dim "  log on the node: ${logf%.log}-${RUN_ID}.log"
                if [[ "$urc" == "0" ]]; then
                    log_ok "${node}: ${desc} completed"
                    return 0
                fi
                log_fail "${node}: ${desc} ended with return code ${urc}"
                return "${urc:-1}"
                ;;
            running) : ;;
            gone)
                rexec "$node" "$RS_DETACH_CLEAN" "$unit" >/dev/null 2>&1 || true
                log_fail "${node}: ${unit} is gone but left no result"
                log_info "  Probably stopped from outside. Log on the node: ${logf}"
                return 1
                ;;
        esac
        sleep "$POLL_SECS"; waited=$((waited+$(poll_step)))
    done
    log_fail "${node}: ${desc} has run for ${DETACH_TIMEOUT}s - time limit reached"
    log_info "  The operation keeps running on the node. Inspect it with:"
    log_info "    ssh ${SSH_USER}@$(ssh_target "$node") 'systemctl status ${unit}; tail -f ${logf}'"
    log_info "  Then resume with: ${SCRIPT_NAME} ${PHASE} --resume"
    return 1
}

ni_set() { NI["$1|$2"]="$3"; }
ni_get() { printf '%s' "${NI["$1|$2"]:-}"; }

# --- Remote building blocks ---------------------------------------------------

# Starts a detached operation. $1=unit, $2=log file, $3=script.
read -r -d '' RS_DETACH_START <<'REMOTE' || true
set -u
unit="$1"; logf="$2"; script="$3"
mkdir -p "$(dirname "$logf")"
# Still running (resume after a dropped connection)? Then do not start it
# again, just report.
if systemctl is-active --quiet "$unit" 2>/dev/null; then echo ALREADY_RUNNING; exit 0; fi
# A unit from an earlier run that finished while nobody was watching (dropped
# connection, Ctrl-C). Its result counts - but it is reported, not adopted
# silently. An already EVALUATED result is gone: rdetach() removes it on read.
if [ -s "/run/${unit}.rc" ]; then
  echo "ALREADY_DONE:$(tr -dc '0-9' < "/run/${unit}.rc")"
  exit 0
fi
systemctl reset-failed "$unit" >/dev/null 2>&1 || true
printf '%s\n' "$script" > "/run/${unit}.sh"
chmod 600 "/run/${unit}.sh"
rm -f "/run/${unit}.rc"
: > "$logf"
# 'bash <file>' instead of executing the file: /run is mounted noexec on many
# systems, where a direct call fails with 126. Reading is
# still allowed. IgnoreOnIsolate is mandatory, not a nicety: the packetfence
# preinst runs 'systemctl isolate packetfence-base.target' (line 124), which
# would otherwise stop our unit mid dpkg transaction.
systemd-run --unit="$unit" --collect --quiet \
  --property=IgnoreOnIsolate=yes \
  /bin/bash -c "bash '/run/${unit}.sh' >> '${logf}' 2>&1; echo \$? > '/run/${unit}.rc'" || exit 1
echo STARTED
REMOTE

# Queries the state of a detached operation. $1=unit, $2=log, $3=offset.
read -r -d '' RS_DETACH_POLL <<'REMOTE' || true
set -u
unit="$1"; logf="$2"; off="$3"
if [ -s "/run/${unit}.rc" ]; then
  echo "STATE:done"; echo "RC:$(tr -dc '0-9' < "/run/${unit}.rc")"
elif systemctl is-active --quiet "$unit" 2>/dev/null; then
  echo "STATE:running"; echo "RC:"
else
  echo "STATE:gone"; echo "RC:"
fi
size=$(stat -c %s "$logf" 2>/dev/null || echo 0)
echo "SIZE:${size}"
echo "---LOG---"
if [ "$size" -gt "$off" ]; then tail -c "+$((off+1))" "$logf" 2>/dev/null; fi
REMOTE

# Removes the traces of a finished operation. $1=unit.
# $2 = log file, $3 = run id. The log keeps a fixed name while the unit runs so
# --resume finds it again; only afterwards is it archived under the run id, so
# a later phase does not overwrite it.
read -r -d '' RS_DETACH_CLEAN <<'REMOTE' || true
set -u
unit="$1"; logf="${2:-}"; rid="${3:-}"
rm -f "/run/${unit}.rc" "/run/${unit}.sh"
systemctl reset-failed "$unit" >/dev/null 2>&1 || true
if [ -n "$logf" ] && [ -n "$rid" ] && [ -f "$logf" ]; then
  mv -f "$logf" "${logf%.log}-${rid}.log" 2>/dev/null || true
  chgrp pf "${logf%.log}-${rid}.log" 2>/dev/null || true
  chmod 640 "${logf%.log}-${rid}.log" 2>/dev/null || true
fi
echo CLEANED
REMOTE

read -r -d '' RS_FACTS <<'REMOTE' || true
set -u
echo "hostname=$(hostname -s)"
if [ -x "$PFCMD" ]; then
  echo "pf_version=$("$PFCMD" version 2>/dev/null | tr -d '\r' | awk '{print $NF}' | head -n1)"
else
  echo "pf_version="
fi
echo "do_upgrade=$([ -x ${PF_ROOT}/addons/upgrade/do-upgrade.sh ] && echo yes || echo no)"
echo "cluster_node_cmd=$([ -x ${PF_ROOT}/bin/cluster/node ] && echo yes || echo no)"
echo "mysql_avail_mb=$(df -Pm /var/lib/mysql 2>/dev/null | tail -n1 | awk '{print $4}')"
# run-upgrade.sh writes a full backup under /root before the package switch,
# and apt needs cache space. Both often - but not always - share the filesystem
# with /var/lib/mysql.
echo "root_avail_mb=$(df -Pm /root 2>/dev/null | tail -n1 | awk '{print $4}')"
echo "aptcache_avail_mb=$(df -Pm /var/cache/apt 2>/dev/null | tail -n1 | awk '{print $4}')"
echo "pfconfig_active=$(systemctl is-active packetfence-config 2>/dev/null || echo inactive)"
# Full package version - 'pfcmd version' reports only 15.1.0 and hides
# differing maintenance builds across the cluster.
echo "pf_pkg=$(dpkg-query -W -f='${Version}' packetfence 2>/dev/null || rpm -q --qf '%{VERSION}-%{RELEASE}' packetfence 2>/dev/null || true)"
# A half-configured package trips up every later apt/dpkg run.
if command -v dpkg >/dev/null 2>&1; then
  echo "pkg_broken=$(dpkg -l 2>/dev/null | awk 'NR>5 && $1!="ii" && $1!="rc" && $1 ~ /^[a-z]/ {c++} END{print c+0}')"
  echo "pkg_broken_list=$(dpkg -l 2>/dev/null | awk 'NR>5 && $1!="ii" && $1!="rc" && $1 ~ /^[a-z]/ {printf "%s(%s) ", $2, $1}')"
  # Modified non-conffiles: dpkg writes NO .dpkg-dist for them, so an upgrade
  # overwrites them silently. 'missing' only hits empty cache dirs.
  echo "pf_modified=$(dpkg -V packetfence 2>/dev/null | awk '$1!="missing" && $2!="c" {print $NF}' | tr '\n' ' ')"
else
  echo "pkg_broken=0"; echo "pkg_broken_list="; echo "pf_modified="
fi
REMOTE

# Sets the switches from 12.4.2/12.4.3 and 12.4.8/12.4.9 in the files the web
# UI writes: pfcron.conf [cluster_check] status, pf.conf [services]
# galera-autofix. $1 = enabled|disabled
read -r -d '' RS_TOGGLES <<'REMOTE' || true
set -u
want="$1"
case "$want" in enabled|disabled) ;; *) echo "BAD_ARG"; exit 1 ;; esac

set_ini() {   # <file> <section> <key> <value>
  f="$1"; sec="$2"; key="$3"; val="$4"
  [ -f "$f" ] || : > "$f"
  # Only the first time: otherwise 'finish' would overwrite the backup of the
  # pre-upgrade state with the "disabled" one written by 'prepare'.
  [ -f "${f}.pfclu.bak" ] || cp -a "$f" "${f}.pfclu.bak"
  awk -v sec="[$sec]" -v key="$key" -v val="$val" '
    BEGIN { insec=0; done=0 }
    /^[[:space:]]*\[/ {
      if (insec && !done) { print key "=" val; done=1 }
      insec = ($0 == sec)
    }
    insec && $0 ~ "^[[:space:]]*" key "[[:space:]]*=" { print key "=" val; done=1; next }
    { print }
    END {
      if (!done) {
        if (!insec) print sec
        print key "=" val
      }
    }' "$f" > "${f}.pfclu.tmp" && mv "${f}.pfclu.tmp" "$f" \
    || { echo "SET_INI_FAILED:$f"; rm -f "${f}.pfclu.tmp"; exit 1; }
  chown pf:pf "$f" 2>/dev/null || true
}

set_ini ${PF_ROOT}/conf/pfcron.conf cluster_check status "$want"
set_ini ${PF_ROOT}/conf/pf.conf     services      galera-autofix "$want"
# Reported, not fatal: the files are written, and the caller verifies them.
# Without the reload the switch only takes effect on the next one.
"$PFCMD" configreload hard >/dev/null 2>&1 || echo "CONFIGRELOAD_RC=$?"
echo "TOGGLES_SET:$want"
REMOTE

read -r -d '' RS_PERMS <<'REMOTE' || true
set -u
echo "uid=$(id -u)"
# Tools without which a phase would fail halfway through
for t in systemd-run systemctl mysql perl shred df stat tail find awk sed grep; do
  if command -v "$t" >/dev/null 2>&1; then echo "have_${t}=yes"; else echo "have_${t}=no"; fi
done
if command -v docker >/dev/null 2>&1; then echo "have_docker=yes"; else echo "have_docker=no"; fi
if command -v apt-get >/dev/null 2>&1; then echo "pkgmgr=apt"
elif command -v yum >/dev/null 2>&1; then echo "pkgmgr=yum"
else echo "pkgmgr=none"; fi
# Write access where the script actually writes
for d in /run /root /var/lock; do
  if [ -w "$d" ]; then echo "w_${d##*/}=yes"; else echo "w_${d##*/}=no"; fi
done
# Is systemd reachable? Without it neither services nor detach units run.
echo "systemd_state=$(systemctl is-system-running 2>/dev/null || echo unknown)"
# The Perl module RS_GALERA pulls the credentials from
if perl -I${PF_ROOT}/lib_perl/lib/perl5 -I${PF_ROOT}/lib -Mpf::db -e1 >/dev/null 2>&1; then
  echo "pfdb=yes"
else
  echo "pfdb=no"
fi
# Can root reach MariaDB over the socket? (otherwise do-upgrade.sh prompts)
if mysql -e "select 1" >/dev/null 2>&1; then echo "db_socket=yes"; else echo "db_socket=no"; fi
REMOTE

# Format per lib/pf/services/manager/pf.pm:
#   <unit name padded to 50 chars>\t<status>  <pid>
# Status words: started | stopped | disabled | reloading. The PID is no
# criterion - packetfence-config reports "started" with PID 0.
read -r -d '' RS_SERVICES <<'REMOTE' || true
set -u
[ -x "$PFCMD" ] || { echo "PFCMD_MISSING"; exit 0; }
raw=$("$PFCMD" service pf status 2>&1)
echo "RAW_BEGIN"; echo "$raw"; echo "RAW_END"
printf '%s\n' "$raw" \
  | sed 's/\x1b\[[0-9;]*m//g' \
  | awk -F'\t' 'NF>=2 {
      name=$1; sub(/[ \t]+$/,"",name);
      split($2, f, " "); st=f[1];
      if (name != "" && st != "") print "SVC:" name "=" st;
    }'

# What SHOULD run comes from systemd, not from pfconfig: the "disabled" status
# word of 'pfcmd service pf status' comes from isManaged() and thus from
# pfconfig. If pfconfig is empty or unreachable, pfcmd reports EVERY service as
# "disabled" - without this cross-check a dead node would look healthy.
for t in packetfence-cluster.target packetfence.target; do
    systemctl show -p Wants --value "$t" 2>/dev/null | tr ' ' '\n'
done | grep -E '\.(service|path)$' | sort -u | sed 's/^/WANT:/' || true

# In a cluster pfcmd isolates on packetfence-cluster.target, otherwise on
# packetfence.target. If neither is active, isolate never ran.
for t in packetfence-cluster.target packetfence.target; do
    echo "TGT:${t}=$(systemctl is-active "$t" 2>/dev/null || true)"
done
REMOTE

# Galera status of the LOCAL MariaDB. Do NOT go through 127.0.0.1:3306:
# haproxy-db listens there, mariadbd binds only the management_ip - another
# node may answer, or the backend is still marked down after a restart. The
# unix socket always hits this node's instance.
read -r -d '' RS_GALERA <<'REMOTE' || true
set -u
PL=${PF_ROOT}/lib_perl/lib/perl5
g() { perl -I"$PL" -I${PF_ROOT}/lib -Mpf::db -e "print \$pf::db::DB_Config->{$1}" 2>/dev/null; }
U=$(g user); P=$(g pass)
[ -n "$U" ] || { echo "NOCRED"; exit 0; }
SOCK=$(sed -n 's/^[[:space:]]*socket[[:space:]]*=[[:space:]]*//p' \
         "${PF_ROOT}/var/conf/mariadb.conf" 2>/dev/null | head -n1)
[ -n "$SOCK" ] || SOCK=/var/lib/mysql/mysql.sock
t=$(mktemp); chmod 600 "$t"
# This block runs in every wait loop; without the trap an interrupted run
# leaves the database password behind in /tmp.
trap 'rm -f "$t"' EXIT INT TERM
printf '[client]\nuser=%s\npassword=%s\nsocket=%s\n' "$U" "$P" "$SOCK" >"$t"
out=$(mysql --defaults-extra-file="$t" -N -B -e \
  "SHOW GLOBAL STATUS WHERE Variable_name IN
   ('wsrep_cluster_size','wsrep_cluster_status','wsrep_local_state_comment','wsrep_ready');" 2>&1)
rc=$?
rm -f "$t"
[ $rc -ne 0 ] && { echo "NOCONN"; echo "$out"; exit 0; }
echo "$out" | while IFS=$'\t' read -r k v; do echo "g:${k}=${v}"; done
REMOTE

# Note the return code handling in this block and the two below: they run with
# 'set -u' but WITHOUT 'set -e', because a service that is already down must not
# abort anything. What the last command echoes decides what the caller sees, so
# a failure has to be turned into a non-zero exit explicitly - otherwise every
# '|| die' at the call site is dead code.
read -r -d '' RS_STOP_PF <<'REMOTE' || true
set -u
# packetfence-config MUST keep running (Guide 12.4.4) so that
# /usr/local/pf/bin/cluster/node stays usable.
rc=0
"$PFCMD" service pf stop || rc=$?
systemctl is-active packetfence-config >/dev/null 2>&1 \
  || systemctl start packetfence-config
[ $rc -eq 0 ] || { echo "PF_STOP_RC=$rc"; exit $rc; }
echo "PF_STOPPED"
REMOTE

# The configuration half of the old RS_START_PF. It is a separate step because
# it needs nothing from the other nodes: in upgrade-c it therefore runs BEFORE
# A and B are stopped, which keeps it out of the outage window.
read -r -d '' RS_PREP_CONFIG <<'REMOTE' || true
set -u
SETTLE="${1:-20}"
rc=0
# Upgrade Guide 3.6
"$PFCMD" pfconfig clear_backend || rc=$?
[ $rc -eq 0 ] || { echo "PF_PREP_RC=clear_backend:$rc"; exit $rc; }
# A failed configreload is the usual cause of services that then start against
# a half-migrated configuration - it must not pass as success.
"$PFCMD" configreload hard || rc=$?
[ $rc -eq 0 ] || { echo "PF_PREP_RC=configreload:$rc"; exit $rc; }
# Let things settle: 'service pf restart' isolates on the cluster target and
# systemd releases 30+ services AT ONCE, all querying the just-emptied config
# cache. Services that die three times in a row are then locked out for good
# by StartLimitBurst.
sleep "$SETTLE"
echo "PF_PREPARED"
REMOTE

read -r -d '' RS_START_PF <<'REMOTE' || true
set -u
# 'service pf restart' already reports non-zero when a single unit is slow to
# come up; the wait loop that follows judges that, not this return code.
"$PFCMD" service pf restart || echo "PF_RESTART_RC=$?"
echo "PF_STARTED"
REMOTE

# Does this node hold the VIP? The address itself is the only answer that can
# be trusted - a keepalived reporting "started" says nothing about VRRP.
read -r -d '' RS_VIP <<'REMOTE' || true
set -u
VIP="${1:-}"
[ -n "$VIP" ] || { echo "VIP_UNKNOWN"; exit 0; }
# Field 4 is "<addr>/<prefix>"; compared as a string, so the dots of an IP
# are not read as regular-expression wildcards.
dev=$(ip -o addr show 2>/dev/null | awk -v v="$VIP" '{ split($4, a, "/"); if (a[1] == v) { print $2; exit } }')
if [ -n "$dev" ]; then echo "VIP_HERE=$dev"; else echo "VIP_ABSENT"; fi
REMOTE

# keepalived is held back while the traffic-bearing services come up, so the
# VIP does not arrive before the node can serve it. Masking, not stopping:
# 'service pf restart' isolates on the target and would start it again.
read -r -d '' RS_KEEPALIVED_MASK <<'REMOTE' || true
set -u
systemctl mask packetfence-keepalived >/dev/null 2>&1
systemctl stop packetfence-keepalived 2>/dev/null
echo "KEEPALIVED_MASKED"
REMOTE

# Ends on the real return code: a keepalived that did not come back means a
# node without a VIP, and the caller has to hear about it.
read -r -d '' RS_KEEPALIVED_START <<'REMOTE' || true
set -u
rc=0
systemctl unmask packetfence-keepalived >/dev/null 2>&1 || rc=$?
[ $rc -eq 0 ] || { echo "KEEPALIVED_RC=unmask:$rc"; exit $rc; }
"$PFCMD" service keepalived restart || rc=$?
[ $rc -eq 0 ] || { echo "KEEPALIVED_RC=restart:$rc"; exit $rc; }
echo "KEEPALIVED_STARTED"
REMOTE

# Poke units ONCE that are in the target's Wants and stuck in 'failed': after
# StartLimitBurst systemd never retries by itself.
read -r -d '' RS_REVIVE <<'REMOTE' || true
set -u
for t in packetfence-cluster.target packetfence.target; do
    systemctl show -p Wants --value "$t" 2>/dev/null | tr ' ' '\n'
done | grep -E '\.(service|path)$' | sort -u | while read -r u; do
    [ -n "$u" ] || continue
    [ "$(systemctl show -p ActiveState --value "$u" 2>/dev/null)" = failed ] || continue
    systemctl reset-failed "$u" 2>/dev/null || true
    systemctl start --no-block "$u" 2>/dev/null || true
    echo "REVIVED:$u"
done
echo "REVIVE_DONE"
REMOTE

# Stop packetfence-mariadb without waiting out the unit's TimeoutSec=1200.
# The unit is Type=notify, but pf-mariadb shuts mariadbd down and then hangs
# without notifying systemd - which waits 1200s, sends SIGKILL, and 'systemctl
# stop' still returns 0. The processes live until that SIGKILL, so the journal
# is the only early proof that the database is really down.
#   $1 = time limit for the marker, $2 = grace period after it
read -r -d '' RS_STOP_MARIADB <<'REMOTE' || true
set -u
LIMIT="${1:-600}"; GRACE="${2:-60}"

# NOT 'is-active --quiet': it also returns non-zero for "deactivating" and
# would call a still-shutting-down instance stopped - while the next step may
# be 'rm -fr /var/lib/mysql/*'.
mdb_stopped() {
    case "$(systemctl show -p ActiveState --value packetfence-mariadb 2>/dev/null)" in
        inactive|failed) return 0 ;;
        *)               return 1 ;;
    esac
}

mdb_stopped && { echo "MARIADB_ALREADY_STOPPED"; exit 0; }

# Timestamp taken ON THE NODE, so --since never matches an older shutdown.
T0="$(date '+%Y-%m-%d %H:%M:%S')"
systemctl stop --no-block packetfence-mariadb

closed=0; w=0
while [ "$w" -lt "$LIMIT" ]; do
    mdb_stopped && { echo "MARIADB_STOPPED_CLEAN ${w}"; exit 0; }
    if journalctl -u packetfence-mariadb --since "$T0" --no-pager 2>/dev/null \
         | grep -qE 'dtor state: CLOSED|mariadbd: Shutdown complete'; then
        closed=1; break
    fi
    sleep 5; w=$((w+5))
done

[ "$closed" -eq 1 ] || { echo "MARIADB_NO_MARKER ${w}"; exit 1; }
echo "MARIADB_SHUTDOWN_DONE ${w}"

# Grace: the unit may still clean up on its own.
g=0
while [ "$g" -lt "$GRACE" ]; do
    mdb_stopped && { echo "MARIADB_STOPPED_CLEAN ${w}"; exit 0; }
    sleep 5; g=$((g+5))
done

# Database provably down, unit stuck in 'deactivating'. systemd would do the
# same at TimeoutSec=1200 - just without the proof we already have.
echo "MARIADB_HUNG_AFTER_SHUTDOWN"
systemctl kill -s KILL packetfence-mariadb
k=0
while [ "$k" -lt 60 ]; do
    mdb_stopped && { echo "MARIADB_KILLED"; exit 0; }
    sleep 5; k=$((k+5))
done
echo "MARIADB_STILL_ACTIVE"; exit 1
REMOTE

read -r -d '' RS_WEBSERVICES <<'REMOTE' || true
set -u
awk '
  /^[[:space:]]*\[/ { insec = ($0 ~ /^[[:space:]]*\[webservices\]/) ? 1 : 0; next }
  insec && /^[[:space:]]*user[[:space:]]*=/ { sub(/^[^=]*=[[:space:]]*/,""); print "ws_user=" $0 }
  insec && /^[[:space:]]*pass[[:space:]]*=/ { sub(/^[^=]*=[[:space:]]*/,""); print "ws_pass=" $0 }
' ${PF_ROOT}/conf/pf.conf 2>/dev/null
REMOTE

# --- Determine the cluster ----------------------------------------------------

# The order in cluster.conf carries meaning (A, B, C) and must NOT be sorted.
parse_cluster_conf() {
    local cc="${PF_ROOT}/conf/cluster.conf"
    [[ -r "$cc" ]] || return 1
    local -a m=()
    local sec
    while IFS= read -r sec; do
        [[ -z "$sec" ]] && continue
        [[ "$sec" == *[[:space:]]* ]] && continue        # [node interface eth0]
        [[ "${sec^^}" == "CLUSTER" ]] && continue        # shared section
        # A section name becomes a node name, and node names end up in remote
        # shell text and in file paths. Anything exotic is not a hostname.
        [[ "$sec" =~ ^[A-Za-z0-9._-]+$ ]] || continue
        local dup=0 x
        for x in "${m[@]:-}"; do [[ "$x" == "$sec" ]] && dup=1; done
        [[ $dup -eq 0 ]] && m+=("$sec")
    done < <(sed -n 's/^\[\([^]]*\)\].*/\1/p' "$cc")
    [[ ${#m[@]} -gt 0 ]] || return 1
    NODES=("${m[@]}")
    return 0
}

node_mgmt_ip() {
    local want="$1" cc="${PF_ROOT}/conf/cluster.conf"
    [[ -r "$cc" ]] || return 1
    awk -v want="$want" '
        /^[[:space:]]*\[/ {
            sec = $0; gsub(/^[[:space:]]*\[|\][[:space:]]*$/, "", sec);
            insec = (sec == want) ? 1 : 0; next
        }
        insec && /^[[:space:]]*management_ip[[:space:]]*=/ {
            sub(/^[^=]*=[[:space:]]*/, ""); gsub(/[[:space:]]/, ""); print; exit
        }' "$cc"
}

resolve_roles() {
    if [[ ${#NODES[@]} -eq 0 ]]; then
        parse_cluster_conf || die \
            "Could not read the cluster nodes from ${PF_ROOT}/conf/cluster.conf." \
            "Set NODES=(nodeA nodeB nodeC) in ${CONFIG_FILE} or use --nodes."
    fi
    [[ ${#NODES[@]} -eq 3 ]] || die \
        "Found ${#NODES[@]} nodes (${NODES[*]}), expected 3." \
        "This script implements the 3-node procedure from Clustering Guide 12.4."

    # By default C is the last node in cluster.conf.
    if [[ -n "$PIONEER" ]]; then
        local found=0 n
        for n in "${NODES[@]}"; do [[ "$n" == "$PIONEER" ]] && found=1; done
        [[ $found -eq 1 ]] || die "--pioneer '${PIONEER}' is not a cluster member (${NODES[*]})."
        NODE_C="$PIONEER"
        local -a rest=()
        for n in "${NODES[@]}"; do [[ "$n" != "$NODE_C" ]] && rest+=("$n"); done
        NODE_A="${rest[0]}"; NODE_B="${rest[1]}"
    else
        NODE_A="${NODES[0]}"; NODE_B="${NODES[1]}"; NODE_C="${NODES[2]}"
    fi

    # Pin the roles once so --resume and later phases use the same assignment
    # as the first run.
    local saved; saved="$(state_get roles || true)"
    if [[ -n "$saved" && "$saved" != "${NODE_A} ${NODE_B} ${NODE_C}" ]]; then
        die "The role assignment differs from the running upgrade." \
            "Stored: ${saved}" \
            "Now determined: ${NODE_A} ${NODE_B} ${NODE_C}" \
            "Restore the original assignment with --pioneer, or delete ${STATE_FILE} when starting a new upgrade."
    fi
    state_set roles "${NODE_A} ${NODE_B} ${NODE_C}"

    resolve_ssh_targets

    log_info "Roles per cluster.conf:  A=${NODE_A}  B=${NODE_B}  C=${NODE_C}"
    log_dim  "C is detached from the cluster and upgraded first."
}

# --- State queries ------------------------------------------------------------

# Services a node should be running but is not; one comma-separated line.
# "disabled" is cross-checked against the target Wants: it comes from
# isManaged() and thus from pfconfig, so a failed pfconfig marks EVERY service
# "disabled" - and a dead node would look healthy.
services_down() {
    local out="$1" wants
    wants="$(sed -n 's/^WANT://p' <<<"$out" | sort -u)" || true

    # Without a Wants list nothing can be cross-checked; services_healthy
    # rejects the node for exactly that reason.
    if [[ -z "$wants" ]]; then
        sed -n 's/^SVC://p' <<<"$out" \
          | grep -vE '=(started|disabled)$' \
          | sed 's/=.*//' | sort | paste -sd, - || true
        return 0
    fi

    sed -n 's/^SVC://p' <<<"$out" | awk -F= -v w="$wants" '
        BEGIN { n = split(w, a, "\n"); for (i = 1; i <= n; i++) if (a[i] != "") want[a[i]] = 1 }
        {
            name = $1; st = $2;
            if (st == "started") next;
            if (st == "disabled" && !(name in want)) next;
            print name;
        }' | sort | paste -sd, - || true
    return 0
}

# Records a node's current state as a baseline. Some services are permanently
# down on a healthy cluster (e.g. radiusd-cli without CLI login configured);
# without this baseline every wait loop would run into its timeout.
# Always called inside "$(...)", so it cannot report anything through a
# variable - a subshell assignment never reaches the caller. The reason for a
# rejection therefore travels on stdout with a REJECT: prefix.
baseline_capture() {
    local node="$1" out rc=0 down nwant ndown
    out=$(rexec_retry "$node" "$RS_SERVICES") || rc=$?
    [[ $rc -ne 0 ]] && return 1
    grep -q 'RAW_BEGIN' <<<"$out" || return 1
    down="$(services_down "$out")"

    # A baseline accepting half of PacketFence as "allowed to be down" makes
    # every later wait_services report green no matter what is running.
    nwant=$(grep -c '^WANT:' <<<"$out" || true)
    ndown=0
    [[ -n "$down" ]] && ndown=$(awk -F, '{print NF}' <<<"$down")
    if (( nwant > 0 && ndown * 2 > nwant )); then
        printf 'REJECT:%s of %s wanted services are down: %s' \
            "$ndown" "$nwant" "$(cut -c1-200 <<<"$down")"
        return 2
    fi

    state_set "baseline.${node}" "${down}"
    printf '%s' "$down"
    return 0
}

# Records the baseline and reports the outcome. Needed by preflight and by
# 'status --rebaseline'.
baseline_refresh() {
    local node="$1" base rc=0
    base="$(baseline_capture "$node")" || rc=$?
    if [[ $rc -eq 2 ]]; then
        log_fail "${node}: baseline rejected - ${base#REJECT:}"
        log_info "  That many outages are not a baseline, they are a finding."
        log_info "  Fix the node first, then: ${SCRIPT_NAME} status --rebaseline"
        return 1
    fi
    if [[ $rc -eq 0 ]]; then
        if [[ -n "$base" ]]; then
            log_warn "${node}: baseline recorded, already down: ${base}"
            log_info "  These services no longer count as an outage."
            log_info "  If that is wrong, sort it out and run --rebaseline again."
        else
            log_ok "${node}: baseline recorded, all services running"
        fi
        return 0
    fi
    log_fail "${node}: service status not evaluable"
    return 1
}

# Is this service on the ignore list? 'pfcmd service pf status' and the systemd
# Wants list name the same thing differently ("keepalived" vs
# "packetfence-keepalived.service"), so both forms are reduced to the bare name.
svc_norm() {
    local n="${1%.service}"
    printf '%s' "${n#packetfence-}"
}

svc_ignored() {
    local want; want="$(svc_norm "$1")"
    local i
    for i in "${SERVICES_IGNORE[@]:-}"; do
        [[ -n "$i" && "$(svc_norm "$i")" == "$want" ]] && return 0
    done
    return 1
}

services_healthy() {
    local node="$1" out rc=0 down base d
    # Always reset: otherwise the next node's error message still carries the
    # previous node's outage list.
    SERVICES_DOWN_LAST=""
    out=$(rexec_retry "$node" "$RS_SERVICES") || rc=$?
    [[ -n "$RUN_LOG" ]] && { echo "--- service pf status ${node} ---"; echo "$out"; } >>"$RUN_LOG"
    [[ $rc -ne 0 ]] && { SERVICES_DOWN_LAST="not reachable"; return 1; }
    grep -q 'PFCMD_MISSING' <<<"$out" && { SERVICES_DOWN_LAST="${PFCMD} not present"; return 1; }
    grep -q 'RAW_BEGIN' <<<"$out" || return 1
    grep -q '^SVC:' <<<"$out" || {
        # Output arrived but could not be parsed: more likely a changed format
        # than a healthy node. Do not wave it through.
        SERVICES_DOWN_LAST="status output not parsable"
        return 1
    }
    # Without a Wants list "disabled" cannot be judged - see services_down.
    grep -q '^WANT:' <<<"$out" || {
        SERVICES_DOWN_LAST="systemd Wants list not parsable"
        return 1
    }
    # One of the two targets must be active, otherwise isolate never ran.
    grep -qE '^TGT:packetfence(-cluster)?\.target=active$' <<<"$out" || {
        SERVICES_DOWN_LAST="no active packetfence target"
        return 1
    }
    down="$(services_down "$out")"
    # A service deliberately held back is not an outage - see start_pf_vip_last.
    # Empty list = the list does not exist, and nothing changes.
    if [[ ${#SERVICES_IGNORE[@]} -gt 0 ]]; then
        local keep="" d2
        for d2 in ${down//,/ }; do
            svc_ignored "$d2" || keep="${keep:+${keep},}${d2}"
        done
        down="$keep"
    fi
    SERVICES_DOWN_LAST="services down: ${down}"
    [[ -z "$down" ]] && { SERVICES_DOWN_LAST=""; return 0; }
    base="$(state_get "baseline.${node}" || true)"
    # Only what was still running at preflight counts as unhealthy.
    for d in ${down//,/ }; do
        [[ ",${base}," == *",${d},"* ]] || return 1
    done
    return 0
}

# Only the test suite calls this; kept so the g: output format of RS_GALERA
# stays covered.
galera_field() {
    local node="$1" field="$2" out rc=0
    out=$(rexec "$node" "$RS_GALERA") || rc=$?
    sed -n "s/^g:${field}=//p" <<<"$out"
}

wait_services() {
    local node="$1" waited=0 ok=0 revived=0
    log_step "${node}: waiting for healthy services (max. ${SERVICE_WAIT_TIMEOUT}s)"
    [[ $DRY_RUN -eq 1 ]] && { log_dim "[dry-run] skipped"; return 0; }
    while (( waited < SERVICE_WAIT_TIMEOUT )); do
        if services_healthy "$node"; then
            ok=$((ok+1))
            if (( ok >= SERVICE_OK_POLLS )); then
                [[ $waited -gt 0 ]] && echo
                log_ok "${node}: services running (after ${waited}s, confirmed ${ok}x)"
                return 0
            fi
        else
            # A relapse invalidates the confirmations so far.
            ok=0
            # Help once if units are locked out for good - otherwise the loop
            # is guaranteed to hit the timeout.
            if (( SERVICE_REVIVE == 1 && revived == 0 && waited >= SERVICE_REVIVE_AFTER )); then
                revived=1
                revive_failed_units "$node"
            fi
        fi
        sleep "$POLL_SECS"; waited=$((waited+$(poll_step))); printf '.'
    done
    echo
    # Otherwise the error would read "services down: unclear" although the last
    # poll was green and only the confirmation was missing.
    (( ok > 0 )) && SERVICES_DOWN_LAST="last seen healthy, but only confirmed ${ok}x of ${SERVICE_OK_POLLS}"
    return 1
}

# The VIP of the cluster: management_ip of the [CLUSTER] section. It is read
# here and ONLY here - parse_cluster_conf skips that section on purpose,
# because the VIP must never become an ssh target (it moves).
cluster_vip() {
    [[ -n "$CLUSTER_VIP" ]] && { printf '%s' "$CLUSTER_VIP"; return 0; }
    local cc="${PF_ROOT}/conf/cluster.conf"
    [[ -r "$cc" ]] || return 1
    awk -F= '
        /^\[/ { insec = ($0 ~ /^\[[Cc][Ll][Uu][Ss][Tt][Ee][Rr]\][ \t]*$/); next }
        insec && $1 ~ /^[ \t]*management_ip[ \t]*$/ {
            gsub(/[ \t]/, "", $2); print $2; exit
        }' "$cc"
}

# wait_vip <node> - wait until the node really holds the VIP. Without a VIP in
# cluster.conf this is a warning, not a blocker: not every installation has one.
wait_vip() {
    local node="$1" vip waited=0 out
    vip="$(cluster_vip || true)"
    if [[ -z "$vip" ]]; then
        log_warn "${node}: no VIP in cluster.conf [CLUSTER] - cannot check the handover"
        log_info "  Set CLUSTER_VIP in ${CONFIG_FILE} to have it checked."
        return 0
    fi
    log_step "${node}: waiting for the VIP ${vip} (max. ${VIP_WAIT_TIMEOUT}s)"
    [[ $DRY_RUN -eq 1 ]] && { log_dim "[dry-run] skipped"; return 0; }
    while (( waited < VIP_WAIT_TIMEOUT )); do
        out=$(rexec "$node" "$RS_VIP" "$vip" 2>/dev/null) || true
        if grep -q '^VIP_HERE=' <<<"$out"; then
            [[ $waited -gt 0 ]] && echo
            log_ok "${node}: holds the VIP ${vip} on $(sed -n 's/^VIP_HERE=//p' <<<"$out") (after ${waited}s)"
            return 0
        fi
        sleep "$POLL_SECS"; waited=$((waited+$(poll_step))); printf '.'
    done
    echo
    log_fail "${node}: the VIP ${vip} did not arrive within ${VIP_WAIT_TIMEOUT}s"
    return 1
}

# start_pf_vip_last <node> [want_vip]
# Starts PacketFence with keepalived held back, so the VIP does not arrive
# before the node can carry traffic. Otherwise C can hold the VIP while
# radiusd and haproxy-portal are still starting.
start_pf_vip_last() {
    local node="$1" want_vip="${2:-yes}" rc=0
    # Set BEFORE the call, not after: a connection that drops between the mask
    # and its answer would otherwise leave keepalived masked with nobody left
    # who knows about it.
    [[ $DRY_RUN -eq 0 ]] && KEEPALIVED_MASKED_NODE="$node"
    rstep "$node" "hold keepalived back until the services are up" "$RS_KEEPALIVED_MASK" \
        || die "${node}: keepalived could not be held back."

    rstep "$node" "start the PacketFence services (Upgrade Guide 3.6)" "$RS_START_PF" || rc=$?
    if [[ $rc -ne 0 ]]; then
        keepalived_release "$node"
        return $rc
    fi

    # The held-back unit must not count as an outage while we wait for the rest.
    SERVICES_IGNORE=(keepalived)
    wait_services "$node" || rc=$?
    SERVICES_IGNORE=()
    if [[ $rc -ne 0 ]]; then
        keepalived_release "$node"
        return $rc
    fi

    keepalived_release "$node" || return 1
    [[ "$want_vip" == "yes" ]] && { wait_vip "$node" || return 1; }
    # The restart storm leaves path/service units outside the Wants list stuck.
    clear_stale_failures "$node"
    return 0
}

# Unmask and start. Also called on every failure path, so keepalived is never
# left masked - a masked keepalived means a cluster without a VIP.
keepalived_release() {
    local node="$1"
    # The marker stays set on failure: cleanup is then the last chance to get
    # the unit unmasked again.
    rstep "$node" "release keepalived and start it" "$RS_KEEPALIVED_START" \
        || { log_fail "${node}: keepalived did not start - the node carries no VIP"
             log_info "  By hand: systemctl unmask packetfence-keepalived; ${PFCMD} service keepalived restart"
             return 1; }
    verify "$node" "keepalived is unmasked and running" \
        '[ "$(systemctl is-enabled packetfence-keepalived 2>/dev/null)" = masked ] && exit 0
systemctl is-active --quiet packetfence-keepalived && echo VERIFY_OK' \
        "A masked or dead keepalived means this node carries no VIP." \
        || return 1
    KEEPALIVED_MASKED_NODE=""
    return 0
}

# Units that PacketFence does not list in its target's Wants never reach
# revive_failed_units - and packetfence-tracking-config lands in
# 'start-limit-hit' after every configuration storm. Left there it makes
# systemd report 'degraded' and preflight warn on the next run.
# Only the failed state is cleared here, plus a restart of the .path triggers;
# a service outside the Wants list is deliberately NOT started - PacketFence
# does not manage it.
# Proof that a node no longer answers: every service that could still take
# traffic must be down. Counting them ("at most six left") let radiusd or
# haproxy-portal pass while the other half of the cluster was taking over.
# packetfence-config is the exception - bin/cluster/node needs it (Guide 12.4.4).
# Both toggles read back from the files that hold them. @WANT@ is replaced by
# the caller with 'disabled' or 'enabled' - a literal from the code, never a
# value from outside. verify() passes no arguments to the remote side, hence
# the placeholder instead of "$1".
read -r -d '' RS_VERIFY_TOGGLES <<'REMOTE' || true
sed -n "/^\[cluster_check\]/,/^\[/p" ${PF_ROOT}/conf/pfcron.conf 2>/dev/null | grep -q "^status=@WANT@" || exit 0
sed -n "/^\[services\]/,/^\[/p" ${PF_ROOT}/conf/pf.conf | grep -q "^galera-autofix=@WANT@" && echo VERIFY_OK
REMOTE

read -r -d '' RS_VERIFY_STOPPED <<'REMOTE' || true
set -u
still=$("$PFCMD" service pf status 2>/dev/null \
  | sed 's/\x1b\[[0-9;]*m//g' \
  | awk -F'\t' 'NF>=2 {
        name = $1; sub(/[ \t]+$/, "", name);
        split($2, f, " ");
        if (f[1] != "started") next;
        if (name ~ /(keepalived|haproxy|radiusd|proxysql|pfdhcp|httpd\.|api-frontend|pfacct)/) print name;
    }' | paste -sd, -)
systemctl is-active --quiet packetfence-config || { echo "PFCONFIG_DOWN"; exit 0; }
if [ -n "$still" ]; then echo "STILL_SERVING:$still"; exit 0; fi
echo VERIFY_OK
REMOTE

read -r -d '' RS_CLEAR_FAILED <<'REMOTE' || true
set -u
wants=$(for t in packetfence-cluster.target packetfence.target; do
    systemctl show -p Wants --value "$t" 2>/dev/null | tr ' ' '\n'
done | grep -E '\.(service|path)$' | sort -u)
# --plain drops the status bullet, so the unit name is column 1 regardless of
# locale - without it the column number depends on systemd's output decoration.
systemctl list-units --state=failed --no-legend --no-pager --plain 'packetfence-*' 2>/dev/null \
  | awk '{print $1}' | while read -r u; do
    [ -n "$u" ] || continue
    printf '%s\n' "$wants" | grep -qxF "$u" && continue   # revive handles those
    systemctl reset-failed "$u" 2>/dev/null || true
    case "$u" in *.path) systemctl start --no-block "$u" 2>/dev/null || true ;; esac
    echo "CLEARED:$u"
done
echo "CLEAR_DONE"
REMOTE

# clear_stale_failures <node> - see RS_CLEAR_FAILED. Never fails the caller:
# this is tidying up, not a step of the procedure.
clear_stale_failures() {
    local node="$1" out list
    [[ $DRY_RUN -eq 1 ]] && { log_dim "[dry-run] ${node}: clear stale failed units"; return 0; }
    out=$(rexec_retry "$node" "$RS_CLEAR_FAILED") || return 0
    list="$(sed -n 's/^CLEARED://p' <<<"$out" | paste -sd, - || true)"
    [[ -n "$list" ]] || return 0
    log_ok "${node}: cleared the failed state of ${list}"
    log_dim "  Not managed by PacketFence - left failed they would show up as 'degraded'."
    return 0
}

# revive_failed_units <node> - poke once whatever is stuck in the start limit.
revive_failed_units() {
    local node="$1" out list
    out=$(rexec_retry "$node" "$RS_REVIVE") || return 0
    list="$(sed -n 's/^REVIVED://p' <<<"$out" | paste -sd, - || true)"
    [[ -n "$list" ]] || return 0
    echo
    log_warn "${node}: stuck in the start limit, poked once: ${list}"
    log_info "  systemd gives up for good after StartLimitBurst; a later attempt usually works."
    return 0
}

# 'systemctl set-environment MARIADB_ARGS=--force-new-cluster' (Guide 12.4.6)
# changes the environment of the systemd MANAGER. It survives every unit
# restart until it is unset or the node reboots. Left behind, the NEXT start of
# packetfence-mariadb - by galera-autofix, by 'finish', by a hand on the
# keyboard - bootstraps a new cluster with a new UUID next to the existing one.
# So it is cleared everywhere the procedure can come to rest.
clear_force_new_cluster() {
    local node="$1"
    [[ $DRY_RUN -eq 1 ]] && { log_dim "[dry-run] would clear MARIADB_ARGS on ${node}"; return 0; }
    rexec "$node" 'systemctl unset-environment MARIADB_ARGS >/dev/null 2>&1
echo ARGS_CLEARED' 2>/dev/null | grep -q ARGS_CLEARED \
        || log_warn "${node}: MARIADB_ARGS could not be cleared - check with 'systemctl show-environment | grep MARIADB'"
    return 0
}

# Stops packetfence-mariadb and interprets the markers from RS_STOP_MARIADB,
# whose header explains why 'systemctl stop' alone is not enough.
stop_mariadb() {
    local node="$1" secs
    rstep "$node" "stop packetfence-mariadb" "$RS_STOP_MARIADB" \
          "$MARIADB_STOP_TIMEOUT" "$MARIADB_STOP_GRACE" || {
        case "$RSTEP_OUT" in
            *MARIADB_NO_MARKER*)
                log_fail "${node}: no shutdown marker in the journal (waited ${MARIADB_STOP_TIMEOUT}s)"
                log_info "  The database never reported itself as shut down."
                log_info "  Look at: journalctl -u packetfence-mariadb -n 50"
                log_info "             ${PF_ROOT}/logs/mariadb.log"
                ;;
            *MARIADB_STILL_ACTIVE*)
                log_fail "${node}: packetfence-mariadb still runs after SIGKILL"
                ;;
            *)  log_fail "${node}: packetfence-mariadb could not be stopped" ;;
        esac
        return 1
    }
    [[ $DRY_RUN -eq 1 ]] && return 0
    secs="$(sed -n 's/^MARIADB_\(STOPPED_CLEAN\|SHUTDOWN_DONE\) //p' <<<"$RSTEP_OUT" | tail -n1)" || true
    case "$RSTEP_OUT" in
        *MARIADB_ALREADY_STOPPED*)
            log_ok "${node}: packetfence-mariadb was already stopped" ;;
        *MARIADB_HUNG_AFTER_SHUTDOWN*)
            log_warn "${node}: database was down after ${secs:-?}s, the unit hung on afterwards"
            log_info "  Ended with SIGKILL - saves up to the unit's TimeoutSec=1200." ;;
        *)  log_ok "${node}: packetfence-mariadb stopped (after ${secs:-0}s)" ;;
    esac
    return 0
}

# wait_db_reachable <node> [time limit]
# A database is not reachable the instant it starts, so a single query right
# after 'systemctl start' is a coin toss.
wait_db_reachable() {
    local node="$1" limit="${2:-$DB_WAIT_TIMEOUT}" waited=0 out
    log_step "${node}: waiting for the database (max. ${limit}s)"
    [[ $DRY_RUN -eq 1 ]] && { log_dim "[dry-run] skipped"; return 0; }
    local rc=0
    while (( waited < limit )); do
        rc=0; out=$(rexec "$node" "$RS_GALERA") || rc=$?
        # A POSITIVE sign is required. Judging by the absence of NOCONN/NOCRED
        # alone would count an ssh failure (rc 255), a "Host key verification
        # failed" or empty output as "database reachable" - and this call is the
        # gate right before /var/lib/mysql is wiped on A and B.
        if [[ $rc -eq 0 ]] && grep -q '^g:wsrep_' <<<"$out" \
           && ! grep -q 'NOCONN\|NOCRED' <<<"$out"; then
            [[ $waited -gt 0 ]] && echo
            log_ok "${node}: database reachable (after ${waited}s)"
            return 0
        fi
        sleep "$POLL_SECS"; waited=$((waited+$(poll_step))); printf '.'
    done
    echo
    if [[ $rc -ne 0 ]]; then
        log_info "  ${node} was not reachable at all (rc=${rc}) - this is a connection problem."
    elif grep -q 'NOCRED' <<<"$out"; then
        log_info "  The credentials could not be read from pf::db."
    elif grep -q 'NOCONN' <<<"$out"; then
        log_info "  The local MariaDB socket does not answer."
    else
        log_info "  Unexpected answer, no wsrep values: $(head -n2 <<<"$out" | tr '\n' ' ')"
    fi
    return 1
}

# wait_galera <node> <expected cluster_size>
# Uses rexec_retry, unlike wait_db_reachable: a resync may take an hour, and a
# dropped link in between says nothing about the cluster.
wait_galera() {
    local node="$1" want="$2" waited=0 out size state
    log_step "${node}: waiting for Galera (cluster_size=${want}, Synced; max. ${GALERA_WAIT_TIMEOUT}s)"
    [[ $DRY_RUN -eq 1 ]] && { log_dim "[dry-run] skipped"; return 0; }
    while (( waited < GALERA_WAIT_TIMEOUT )); do
        out=$(rexec_retry "$node" "$RS_GALERA") || true
        size=$(sed -n 's/^g:wsrep_cluster_size=//p' <<<"$out")
        state=$(sed -n 's/^g:wsrep_local_state_comment=//p' <<<"$out")
        if [[ "$state" == "Synced" && "$size" == "$want" ]]; then
            [[ $waited -gt 0 ]] && echo
            log_ok "${node}: Galera in sync (cluster_size=${size}, after ${waited}s)"
            return 0
        fi
        sleep "$POLL_SECS"; waited=$((waited+$(poll_step))); printf '.'
    done
    echo
    log_info "  last seen: state=${state:-?} cluster_size=${size:-?}"
    return 1
}

# --- PHASE preflight - the bare minimum ---------------------------------------

# Its own function so selftest.sh can replace the checks - otherwise
# phase_preflight would only be testable as root on a PF server.
check_local_prereqs() {
    [[ $EUID -eq 0 ]] || die "This script must run as root." \
        "It stops services, writes to /root and drives systemd on every node."
    [[ -x "$PFCMD" ]] || die "${PFCMD} not found - is this a PacketFence server?"

    local t missing=""
    for t in ssh scp ssh-keygen flock; do
        command -v "$t" >/dev/null 2>&1 || missing+=" $t"
    done
    [[ -z "$missing" ]] || die "Missing local tools:${missing}" \
        "Install the openssh-client and util-linux packages."

    # Where the script actually writes: log, state, lock.
    local d
    # LOG_DIR is a directory itself, the other two are files.
    for d in "$LOG_DIR" "$(dirname "$STATE_FILE")" "$(dirname "$LOCK_FILE")"; do
        [[ -w "$d" ]] || die "No write permission in ${d}." \
            "Needed for the log (${LOG_DIR}), state (${STATE_FILE}) and lock (${LOCK_FILE})."
    done

    log_ok "root, PacketFence, ssh tools and write permissions present"
}

# ssh silently rejects an overly permissive private key - which then looks like
# a permission problem on the far side.
# The README promises preflight checks this, so it had better do so: the file
# may hold the webservices password, and conf/ is readable by group pf.
check_config_perms() {
    local mode
    [[ -f "$CONFIG_FILE" ]] || return 0
    mode=$(stat -c '%a' "$CONFIG_FILE" 2>/dev/null || echo "")
    case "$mode" in
        400|600) log_ok "Configuration ${CONFIG_FILE}: permissions ${mode}" ;;
        "")      log_warn "Permissions of ${CONFIG_FILE} not readable" ;;
        *)
            if [[ -n "$WS_PASS" ]]; then
                log_fail "${CONFIG_FILE} has permissions ${mode} and holds a password"
            else
                log_warn "${CONFIG_FILE} has permissions ${mode}, expected 600"
            fi
            log_info "  Fix with: chmod 600 ${CONFIG_FILE}"
            ;;
    esac
}

check_ssh_key_perms() {
    local f="${1:-}" mode owner
    [[ -n "$f" && -f "$f" ]] || return 0
    mode=$(stat -c '%a' "$f" 2>/dev/null || echo "")
    owner=$(stat -c '%U' "$f" 2>/dev/null || echo "")
    case "$mode" in
        400|600) log_ok "Key ${f}: permissions ${mode}, owner ${owner}" ;;
        "")      log_warn "Permissions of ${f} not readable" ;;
        *)       log_fail "Key ${f} has permissions ${mode} - ssh rejects it"
                 log_info "  Fix with: chmod 600 ${f}" ;;
    esac
}

phase_preflight() {
    # "Changes nothing ON THE NODES" - locally it records the roles and the
    # service baseline, which is what --rebaseline is about.
    log_head "PREFLIGHT (does not change anything on the nodes)"

    # 1. local prerequisites
    check_local_prereqs

    # Preflight demands the state BEFORE the upgrade (all services up, Galera
    # 3/Synced). Mid-12.4 that is false by design and would record an unusable
    # baseline.
    if procedure_started; then
        NO_RESUME_HINT=1
        die "The procedure is already running - preflight is no longer meaningful here." \
            "It demands the initial state (Galera 3/Synced on every node)," \
            "which the cluster deliberately left as of 'prepare'." \
            "Current situation: ${SCRIPT_NAME} status" \
            "Continue:      ${SCRIPT_NAME} run --resume --target-version <version>" \
            "New baseline: ${SCRIPT_NAME} status --rebaseline" \
            "Start over:    delete ${STATE_FILE} (only after a finished or rolled-back upgrade)"
    fi

    resolve_roles

    # 1b. How each node is addressed - see ssh_target.
    local n tgt unreachable_name=0
    for n in "${NODES[@]}"; do
        tgt="$(ssh_target "$n")"
        if [[ "$tgt" != "$n" ]]; then
            log_ok "${n}: ssh via management_ip ${tgt}"
        elif getent hosts "$n" >/dev/null 2>&1; then
            log_ok "${n}: ssh via the name (no management_ip in cluster.conf)"
        else
            log_fail "${n}: neither management_ip in cluster.conf nor a resolvable name"
            unreachable_name=1
        fi
    done
    [[ $unreachable_name -eq 1 ]] && die \
        "At least one node has no usable address." \
        "Either add management_ip to cluster.conf or make the name resolvable." \
        "NODES=(<IP> ...) is NO way out: bin/cluster/node looks the node up by its" \
        "hostname and rejects an IP."

    # 2. Key: is one configured, and does it work?
    local out rc unreachable=0
    local -a peers=()
    for n in "${NODES[@]}"; do is_self "$n" || peers+=("$n"); done

    if [[ -z "$SSH_IDENTITY" ]]; then
        log_warn "No SSH_IDENTITY set in ${CONFIG_FILE}."
        log_info "  The script drives the other nodes over ssh and uses BatchMode -"
        log_info "  there is no password prompt per connection."
        if [[ ${#peers[@]} -eq 0 ]]; then
            log_info "  No remote nodes - nothing to set up."
        elif ask_yes_no "Create, distribute and record the key now?"; then
            ssh_identity_setup "${peers[@]}" || { ssh_identity_hint; die \
                "Setup failed."; }
        else
            ssh_identity_hint
            die "Without a key in ${CONFIG_FILE} the procedure cannot be driven."
        fi
    else
        if [[ ! -f "$SSH_IDENTITY" ]]; then
            log_fail "SSH_IDENTITY=${SSH_IDENTITY} - that file does not exist"
            ssh_identity_hint
            die "The key recorded in ${CONFIG_FILE} is missing."
        fi
        log_ok "Key from the configuration: ${SSH_IDENTITY}"
    fi
    check_ssh_key_perms "$SSH_IDENTITY"
    check_config_perms

    for n in "${NODES[@]}"; do
        if is_self "$n"; then log_ok "${n}: local node"; continue; fi
        rc=0; out=$(rexec "$n" 'id -u') || rc=$?
        if [[ $rc -ne 0 ]]; then
            log_fail "${n}: login not possible"
            log_dim "$(tail -n1 <<<"$out")"
            unreachable=1
        elif [[ "$(tail -n1 <<<"$out")" != "0" ]]; then
            log_fail "${n}: ssh user '${SSH_USER}' is not root"; unreachable=1
        else
            log_ok "${n}: reachable as root"
        fi
    done
    if [[ $unreachable -eq 1 ]]; then
        ssh_identity_hint
        die "Not all nodes are reachable." \
            "The procedure disables nodes against each other; without access to all" \
            "three it cannot be driven."
    fi

    # 2b. Permissions and tools per node. A gap here would otherwise fail a
    #     phase halfway through - at worst between two destructive steps.
    for n in "${NODES[@]}"; do
        local pout; pout=$(rexec "$n" "$RS_PERMS") \
            || { log_fail "${n}: permissions not checkable"; continue; }

        [[ "$(sed -n 's/^uid=//p' <<<"$pout")" == "0" ]] \
            || log_fail "${n}: does not run as root (uid=$(sed -n 's/^uid=//p' <<<"$pout"))"

        local t missing_tools=""
        for t in systemd-run systemctl mysql perl shred df stat tail find awk sed grep; do
            [[ "$(sed -n "s/^have_${t}=//p" <<<"$pout")" == "yes" ]] || missing_tools+=" $t"
        done
        if [[ -n "$missing_tools" ]]; then
            log_fail "${n}: missing tools:${missing_tools}"
            [[ "$missing_tools" == *systemd-run* ]] && \
                log_info "  Without systemd-run do-upgrade.sh cannot run detached."
        fi

        [[ "$(sed -n 's/^pkgmgr=//p' <<<"$pout")" == "none" ]] \
            && log_fail "${n}: neither apt-get nor yum found"

        local d
        for d in run root lock; do
            [[ "$(sed -n "s/^w_${d}=//p" <<<"$pout")" == "yes" ]] \
                || log_fail "${n}: no write permission in /${d/lock/var\/lock}"
        done

        local sysstate; sysstate=$(sed -n 's/^systemd_state=//p' <<<"$pout")
        case "$sysstate" in
            running)  : ;;
            degraded) log_warn "${n}: systemd reports 'degraded' - check failed units"
                      log_info "  systemctl --failed" ;;
            *)        log_fail "${n}: systemd not reachable (${sysstate:-?})" ;;
        esac

        [[ "$(sed -n 's/^pfdb=//p' <<<"$pout")" == "yes" ]] \
            || log_fail "${n}: pf::db not loadable - the Galera check needs it"

        # Not an error, just a warning: without socket login do-upgrade.sh
        # asks for the MariaDB root password.
        [[ "$(sed -n 's/^db_socket=//p' <<<"$pout")" == "yes" ]] \
            || log_warn "${n}: 'mysql -e select 1' does not work - the password will be asked for later"

        [[ "$(sed -n 's/^have_docker=//p' <<<"$pout")" == "yes" ]] \
            || log_info "${n}: no docker - the container check is skipped"

        log_ok "${n}: root, tools and write permissions complete"
    done

    # 3. Facts: version, tools, disk space
    local first_ver="" first_pkg=""
    for n in "${NODES[@]}"; do
        rc=0; out=$(rexec "$n" "$RS_FACTS") || rc=$?
        [[ $rc -eq 0 ]] || die "${n}: base facts not readable." "$out"
        local k v line
        while IFS= read -r line; do
            [[ "$line" == *=* ]] || continue
            k="${line%%=*}"; v="${line#*=}"; ni_set "$n" "$k" "$v"
        done <<<"$out"

        local ver; ver="$(ni_get "$n" pf_version)"
        [[ -n "$ver" ]] || log_fail "${n}: PacketFence version not determinable"
        if [[ -z "$first_ver" ]]; then
            first_ver="$ver"; first_pkg="$(ni_get "$n" pf_pkg)"
        elif [[ "$ver" != "$first_ver" ]]; then
            log_fail "${n}: version ${ver} differs (${NODES[0]} has ${first_ver})"
        fi

        local pkg; pkg="$(ni_get "$n" pf_pkg)"
        if [[ -n "$first_pkg" && -n "$pkg" && "$pkg" != "$first_pkg" ]]; then
            log_warn "${n}: different package level than ${NODES[0]}"
            log_info "  ${NODES[0]}: ${first_pkg}"
            log_info "  ${n}: ${pkg}"
            log_info "  do-upgrade.sh levels this out; before 12.4 it is only a note."
        fi

        [[ "$(ni_get "$n" do_upgrade)" == "yes" ]] \
            || log_fail "${n}: ${DO_UPGRADE} is missing or not executable"
        [[ "$(ni_get "$n" cluster_node_cmd)" == "yes" ]] \
            || log_fail "${n}: ${CLUSTER_NODE_CMD} is missing - detach/attach is impossible without it"

        local avail; avail="$(ni_get "$n" mysql_avail_mb)"
        if [[ -n "$avail" ]] && (( avail < MIN_FREE_MB_MYSQL )); then
            log_fail "${n}: /var/lib/mysql only ${avail} MB free (< ${MIN_FREE_MB_MYSQL} MB)"
            log_info "  In 12.4.6 A and B resynchronise the entire database."
        fi

        local ravail cavail
        ravail="$(ni_get "$n" root_avail_mb)"; cavail="$(ni_get "$n" aptcache_avail_mb)"
        if [[ -n "$ravail" ]] && (( ravail < MIN_FREE_MB_ROOT )); then
            log_fail "${n}: filesystem of /root only ${ravail} MB free (< ${MIN_FREE_MB_ROOT} MB)"
            log_info "  run-upgrade.sh writes a full backup there, plus the new images."
        fi
        if [[ -n "$cavail" ]] && (( cavail < MIN_FREE_MB_APTCACHE )); then
            log_fail "${n}: filesystem of /var/cache/apt only ${cavail} MB free (< ${MIN_FREE_MB_APTCACHE} MB)"
        fi

        # A half-configured package trips up every later apt run - right in the
        # middle of a phase meant to avoid exactly that.
        local broken; broken="$(ni_get "$n" pkg_broken)"
        if [[ -n "$broken" && "$broken" != "0" ]]; then
            log_fail "${n}: ${broken} package(s) in a broken state"
            log_info "  $(ni_get "$n" pkg_broken_list)"
            log_info "  Sort it out with 'dpkg --configure -a' first, and with a RUNNING"
            log_info "  packetfence-config - otherwise the postinst fails again."
        fi

        # Modified non-conffiles do not survive the upgrade and, unlike
        # conffiles, leave no .dpkg-dist behind.
        local modified; modified="$(ni_get "$n" pf_modified)"
        if [[ -n "${modified// /}" ]]; then
            log_warn "${n}: locally modified package files - the upgrade will overwrite them"
            local f
            for f in $modified; do log_info "  ${f}"; done
            log_info "  Back them up first and reapply afterwards."
        fi

        log_info "${n}: PacketFence ${ver} - /var/lib/mysql ${avail:-?} MB free, /root ${ravail:-?} MB free"
    done

    # 4. Services and Galera healthy? This is where the baseline is recorded -
    #    see baseline_capture.
    for n in "${NODES[@]}"; do
        # state_has, not state_get: an EMPTY baseline means "everything runs".
        if ! state_has "baseline.${n}" || [[ $REBASELINE -eq 1 ]]; then
            baseline_refresh "$n" || log_info "  Check with: ${PFCMD} service pf status"
        elif services_healthy "$n"; then
            log_ok "${n}: services as at the last preflight"
        else
            log_fail "${n}: ${SERVICES_DOWN_LAST:-service status unclear} (they were up at preflight)"
            log_info "  Check with: ${PFCMD} service pf status"
        fi
        out=$(rexec "$n" "$RS_GALERA") || true
        if grep -q 'NOCRED\|NOCONN' <<<"$out"; then
            log_fail "${n}: MariaDB status not queryable"
        else
            local size status state
            size=$(sed -n 's/^g:wsrep_cluster_size=//p' <<<"$out")
            status=$(sed -n 's/^g:wsrep_cluster_status=//p' <<<"$out")
            state=$(sed -n 's/^g:wsrep_local_state_comment=//p' <<<"$out")
            ni_set "$n" galera "${state:-?}/${size:-?}"
            if [[ "$status" == "Primary" && "$state" == "Synced" && "$size" == "3" ]]; then
                log_ok "${n}: Galera Primary/Synced, cluster_size=3"
            else
                log_fail "${n}: Galera status=${status:-?} state=${state:-?} size=${size:-?} (expected Primary/Synced/3)"
            fi
        fi
    done

    # 5. Target version: does the repository exist? A typo would otherwise
    #    surface only after run-upgrade.sh rewrote the package source. Warning
    #    only - behind a proxy the direct probe may legitimately fail.
    if [[ -n "$TARGET_VERSION" ]]; then
        local mm url; mm="$(ver_mm "$TARGET_VERSION")"
        url="http://inverse.ca/downloads/PacketFence/debian/${mm}/dists/bookworm/Release"
        if command -v curl >/dev/null 2>&1; then
            if curl -sfI --max-time 15 "$url" >/dev/null 2>&1; then
                log_ok "Repository for PacketFence ${mm} reachable"
            else
                log_warn "Repository for PacketFence ${mm} not reachable: ${url}"
                log_info "  Check the target version. Behind a proxy this is expected."
            fi
        fi

        # Already there? Nothing stops it - a maintenance build inside the same
        # minor (15.2.0 -> 15.2.1) is a legitimate reason. But the procedure
        # would run in full either way, and that is worth knowing beforehand.
        local n same=1
        for n in "${NODES[@]}"; do
            [[ "$(ver_mm "$(ni_get "$n" pf_version)")" == "$mm" ]] || { same=0; break; }
        done
        if [[ $same -eq 1 ]]; then
            log_warn "All nodes already run PacketFence ${mm}"
            log_info "  The procedure would still run in full: cluster check and"
            log_info "  galera-autofix off, ${NODE_C:-node C} detached, PacketFence stopped on the"
            log_info "  other two, and in 'reintegrate' their /var/lib/mysql wiped and"
            log_info "  resynchronised - an outage and a full resync for both of them."
            log_info "  Worthwhile only for a maintenance build inside ${mm}."
            log_info "  For a different version: --target-version <major.minor>"
            SAME_VERSION=1
        fi
    fi

    summary
    next_hint prepare
}


# Extract major.minor from a package version ("1:15.1.0-1" -> "15.1")
ver_mm() {
    local v="${1#*:}"
    sed -n 's/^\([0-9]\{1,\}\.[0-9]\{1,\}\).*/\1/p' <<<"$v"
}

# Predicts which prompts do-upgrade.sh would raise on this node, based on the
# source of addons/full-upgrade/run-upgrade.sh:
#   set_upgrade_to()       asks if UPGRADE_TO is empty
#   INCLUDE_OS_UPDATE      asks if the variable is empty
#   upgrade_database()     asks for the MariaDB root password when
#                          'mysql -e "select 1"' fails without credentials;
#                          skipped entirely with UPGRADE_CLUSTER_SECONDARY=yes
#   handle_devel_upgrade() asks if db/upgrade-X.X-X.Y.sql exists (devel)
doupgrade_prompts() {
    local node="$1"
    rexec "$node" '
set -u
if mysql -e "select 1" >/dev/null 2>&1; then echo "db_socket_auth=yes"; else echo "db_socket_auth=no"; fi
if [ -f ${PF_ROOT}/db/upgrade-X.X-X.Y.sql ]; then echo "devel_sql=yes"; else echo "devel_sql=no"; fi
'
}

# Full package version, e.g. "1:15.2.0-1". 'pfcmd version' and conf/pf-release
# only give 15.2.0 and hide the maintenance build.
node_pf_pkg() {
    [[ $DRY_RUN -eq 1 ]] && return 0
    local v
    v=$(rexec_retry "$1" 'dpkg-query -W -f="\${Version}" packetfence 2>/dev/null || true') || true
    printf '%s' "$v"
}

# Are all nodes already on the target major.minor? Then the upgrade itself has
# nothing to do - the procedure around it still costs an outage and a resync.
all_on_target() {
    # A dry-run queries nothing; the preflight warning already covers this.
    [[ $DRY_RUN -eq 1 ]] && return 1
    [[ -n "$TARGET_VERSION" ]] || return 1
    local mm n v
    mm="$(ver_mm "$TARGET_VERSION")"
    [[ -n "$mm" ]] || return 1
    for n in "${NODES[@]}"; do
        v=$(rexec_retry "$n" 'cat ${PF_ROOT}/conf/pf-release 2>/dev/null' \
            | awk '{print $NF}' | head -n1) || true
        [[ "$(ver_mm "$v")" == "$mm" ]] || return 1
    done
    return 0
}

# Proves do-upgrade.sh really ran through to the new version on the node. The
# return code alone is not enough: run-upgrade.sh uses 'set -o errexit' and can
# still bail out after the package switch without the unit counting as failed.
assert_upgraded() {
    local node="$1" want="$2" got
    [[ $DRY_RUN -eq 1 ]] && { log_dim "[dry-run] version check skipped"; return 0; }
    # Without '|| true' a missing pf-release makes the ASSIGNMENT fail under
    # pipefail - the ERR trap would then swallow the message below, in exactly
    # the case it was written for.
    got=$(rexec_retry "$node" 'cat ${PF_ROOT}/conf/pf-release 2>/dev/null' \
          | awk '{print $NF}' | head -n1) || true
    if [[ "$(ver_mm "$got")" == "$(ver_mm "$want")" ]]; then
        # Major.minor alone proves nothing when the target version is the one
        # already installed: 15.2 == 15.2 holds even if do-upgrade.sh did not
        # do a thing. The full package version does prove it.
        local before after
        before="$(state_get "pkg_before.${node}")"
        after="$(node_pf_pkg "$node")"
        if [[ -n "$before" && -n "$after" && "$before" == "$after" ]]; then
            log_fail "${node}: package version unchanged (${after})"
            log_info "  do-upgrade.sh changed nothing - neither package nor version."
            log_info "  Check ${LOG_DIR}/pfclu-doupgrade.log on the node."
            return 1
        fi
        log_ok "${node}: now runs PacketFence ${got}${after:+ (${after})}"
        return 0
    fi
    log_fail "${node}: conf/pf-release reports '${got:-?}', expected ${want}"
    return 1
}

# Stopping galera-autofix is not enough: the packetfence preinst runs
# 'systemctl isolate packetfence-base.target' and would start it AGAIN. The
# postinst then takes packetfence-config away from it, and without pfconfig it
# shuts down the local mariadbd - in the middle of the dpkg transaction.
autofix_immobilize() {
    local node="$1"
    rstep "$node" "immobilize galera-autofix (protects the local MariaDB)" '
systemctl mask packetfence-galera-autofix >/dev/null 2>&1
systemctl stop packetfence-galera-autofix 2>/dev/null
echo AUTOFIX_MASKED' || die "${node}: galera-autofix could not be immobilized."
    verify "$node" "galera-autofix is masked and stopped" \
        'systemctl is-active --quiet packetfence-galera-autofix && exit 0
[ "$(systemctl is-enabled packetfence-galera-autofix 2>/dev/null)" = "masked" ] && echo VERIFY_OK' \
        "Without masking, the isolate in packetfence-preinst starts it again."
    return 0
}

autofix_release() {
    local node="$1"
    rstep "$node" "release galera-autofix again" '
systemctl unmask packetfence-galera-autofix >/dev/null 2>&1
echo AUTOFIX_UNMASKED' || log_warn "${node}: galera-autofix stayed masked - please check"
    return 0
}

# run_do_upgrade <node> <secondary>
#   secondary="yes" sets UPGRADE_CLUSTER_SECONDARY=yes (Guide 12.4.5) - in the
#   same script, hence the same shell, as the guide requires.
# Runs detached by default (see rdetach), so every known prompt is disabled
# beforehand. --interactive-upgrade runs it on the terminal instead.
run_do_upgrade() {
    local node="$1" secondary="$2"
    local stdin_file="/run/pfclu-doupgrade.stdin"
    # handle_pkgnew_file() in run-upgrade.sh does a bare 'read'. Detached that
    # hits EOF, returns 1 and 'set -o errexit' aborts the run - after the
    # package and database steps, before fixpermissions and configreload.
    # Blank lines on stdin let the read return 0; one per .dpkg-dist is plenty.
    local PAD_LINES=200

    [[ -n "$TARGET_VERSION" ]] || die \
        "do-upgrade.sh needs the target version." \
        "Without it run-upgrade.sh prompts (set_upgrade_to) and would hang." \
        "Example: ${SCRIPT_NAME} ${PHASE} --target-version 15.2"

    # run-upgrade.sh inserts $UPGRADE_TO into the package source VERBATIM
    # (.../debian/$UPGRADE_TO bookworm bookworm). Those repos are named
    # major.minor - "15.2", not "15.2.0". A three-part version yields a 404,
    # and only AFTER the source has been rewritten.
    local upgrade_to; upgrade_to="$(ver_mm "$TARGET_VERSION")"
    [[ -n "$upgrade_to" ]] || die \
        "Cannot interpret target version '${TARGET_VERSION}'." \
        "Something like 15.2 or 15.2.0 is expected."
    if [[ $DRY_RUN -eq 0 ]]; then
        local repo_url="http://inverse.ca/downloads/PacketFence/debian/${upgrade_to}/dists/bookworm/Release"
        rexec "$node" 'curl -sfI --max-time 20 "http://inverse.ca/downloads/PacketFence/debian/$1/dists/bookworm/Release" >/dev/null && echo REPO_OK' \
            "$upgrade_to" 2>/dev/null | grep -q REPO_OK \
            || die "${node}: the package source for PacketFence ${upgrade_to} is not reachable from there." \
                   "  ${repo_url}" \
                   "Checked before the package source is rewritten - nothing changed on the node." \
                   "Check the target version (repos are named major.minor) or sort out the network/proxy."
        log_ok "${node}: package source for PacketFence ${upgrade_to} reachable"
    fi

    # Which prompts are likely on this node? Nothing is queried in dry-run.
    local pre=""
    [[ $DRY_RUN -eq 0 ]] && pre=$(doupgrade_prompts "$node") || true
    local socket_auth devel_sql
    socket_auth=$(sed -n 's/^db_socket_auth=//p' <<<"$pre")
    devel_sql=$(sed -n 's/^devel_sql=//p' <<<"$pre")
    [[ "$devel_sql" == "yes" ]] && log_warn \
        "${node}: ${PF_ROOT}/db/upgrade-X.X-X.Y.sql present (devel package) - do-upgrade.sh will then ask for the previous version"

    local script=""
    script+="export UPGRADE_TO=$(printf '%q' "$upgrade_to")"$'\n'
    script+="export INCLUDE_OS_UPDATE=$(printf '%q' "$INCLUDE_OS_UPDATE")"$'\n'
    # Detached means no terminal: run-upgrade.sh calls 'apt install' twice
    # without -y, and dpkg questions would come from debconf.
    script+='export DEBIAN_FRONTEND=noninteractive'$'\n'
    script+='export DEBIAN_PRIORITY=critical'$'\n'
    script+='export APT_LISTCHANGES_FRONTEND=none'$'\n'
    script+='export NEEDRESTART_MODE=a'$'\n'
    script+='export UCF_FORCE_CONFOLD=1'$'\n'
    [[ "$secondary" == "yes" ]] && script+="export UPGRADE_CLUSTER_SECONDARY=yes"$'\n'

    if [[ $INTERACTIVE_UPGRADE -eq 1 ]]; then
        log_warn "interactive mode: a dropped connection aborts do-upgrade.sh"
        local cmd; cmd="$(tr '\n' ';' <<<"$script")${DO_UPGRADE}"
        # The masking is not tied to the detached run - the preinst does its
        # isolate either way. This is the retry path after a stuck prompt, so
        # it is the LAST place where the protection may be missing.
        autofix_immobilize "$node"
        local irc=0
        rtty "$node" "do-upgrade.sh" "$cmd" || irc=$?
        autofix_release "$node"
        return $irc
    fi

    # For the check afterwards - see assert_upgraded. Only on the first
    # attempt: on --resume the node may already carry the new package.
    if [[ $DRY_RUN -eq 0 ]] && ! state_has "pkg_before.${node}"; then
        state_set "pkg_before.${node}" "$(node_pf_pkg "$node")"
    fi

    local need_pw=0
    [[ "$secondary" != "yes" && "$socket_auth" != "yes" ]] && need_pw=1

    # With --resume the unit may still be running with stdin already open. The
    # file is then not rewritten, only followed.
    local already_running=0
    if [[ $DRY_RUN -eq 0 ]] \
       && rexec "$node" 'systemctl is-active --quiet pfclu-doupgrade && echo RUNNING' \
          2>/dev/null | grep -q RUNNING; then
        already_running=1
    fi

    if [[ $already_running -eq 1 ]]; then
        log_info "${node}: the unit still runs there - stdin is left alone, only followed"
    elif [[ $need_pw -eq 1 ]]; then
        if [[ $DRY_RUN -eq 1 ]]; then
            log_dim "[dry-run] the MariaDB root password would be asked for and passed via ${stdin_file}"
        else
            log_info "${node}: 'mysql -e \"select 1\"' does not work - do-upgrade.sh will ask for the"
            log_info "  MariaDB root password. It is captured once now and handed to the run"
            log_info "  through a file with mode 0600."
            local pw=""
            printf '%s' "MariaDB root password (input hidden): "
            tty_flush
            read -rs pw </dev/tty || { printf '\n'; die_no_input; }
            printf '\n'
            [[ -n "$pw" ]] || die "No password entered." \
                "Without a password the detached run would stop at the prompt." \
                "Alternative: ${SCRIPT_NAME} ${PHASE} --interactive-upgrade"
            # The password reaches bash via stdin inside the script text, not
            # as an argument - so it never appears in a process list.
            local mk; mk="umask 077; printf '%s\\n' $(printf '%q' "$pw") > ${stdin_file}"
            rexec "$node" "$mk" >/dev/null || die "${node}: the credentials file could not be created."
            unset pw
            log_ok "${node}: password stored (shredded after the run)"
        fi
    else
        [[ "$secondary" == "yes" ]] \
            && log_dim "${node}: secondary node - run-upgrade.sh skips the database step" \
            || log_ok  "${node}: database access works without a password - no prompt expected"
        if [[ $DRY_RUN -eq 0 && $already_running -eq 0 ]]; then
            rexec "$node" "umask 077; : > ${stdin_file}" >/dev/null \
                || die "${node}: ${stdin_file} could not be created."
        fi
    fi

    # Append blank lines - the reason is above PAD_LINES.
    if [[ $DRY_RUN -eq 0 && $already_running -eq 0 ]]; then
        rexec "$node" "for i in \$(seq 1 ${PAD_LINES}); do echo; done >> ${stdin_file}" >/dev/null \
            || die "${node}: ${stdin_file} could not be extended."
    fi
    # install_gpg_key() pipes curl into 'gpg --dearmor -o
    # /etc/apt/keyrings/packetfence.gpg'. If that file exists, gpg asks on
    # /dev/tty, aborts when detached, curl gets EPIPE and errexit+pipefail end
    # run-upgrade.sh with 2. So move it aside; install_gpg_key recreates it,
    # and on a failed download it is restored.
    script+='PFCLU_KEY=/etc/apt/keyrings/packetfence.gpg'$'\n'
    script+='[ -e "$PFCLU_KEY" ] && mv -f "$PFCLU_KEY" "${PFCLU_KEY}.pfclu.bak"'$'\n'
    script+="${DO_UPGRADE} < ${stdin_file}"$'\n'
    script+="rc=\$?"$'\n'
    script+='[ -e "$PFCLU_KEY" ] || mv -f "${PFCLU_KEY}.pfclu.bak" "$PFCLU_KEY" 2>/dev/null'$'\n'
    script+='rm -f "${PFCLU_KEY}.pfclu.bak"'$'\n'
    script+="shred -u ${stdin_file} 2>/dev/null || rm -f ${stdin_file}"$'\n'
    script+="exit \$rc"

    autofix_immobilize "$node"

    local rc=0
    rdetach "$node" "pfclu-doupgrade" "do-upgrade.sh (Upgrade Guide 5.1)" "$script" || rc=$?
    autofix_release "$node"
    return $rc
}

# --- PHASE prepare - 12.4.2 and 12.4.3 ----------------------------------------

phase_prepare() {
    log_head "PREPARE - Clustering Guide 12.4.2 and 12.4.3"
    resolve_roles

    say ""
    say "Cluster check and galera-autofix are switched off - both would 'repair' the"
    say "upgrade state again during the procedure (12.4.2, 12.4.3)."
    say ""

    local n
    for n in "${NODES[@]}"; do
        done_skip "prepare.toggles.${n}" || {
            rstep "$n" "switch cluster check and galera-autofix off in the configuration" \
                "$RS_TOGGLES" "disabled" \
                || die "${n}: the switches could not be set." \
                       "Alternatively in the web UI:" \
                       "  Configuration -> System Configuration -> Maintenance -> Cluster Check" \
                       "  Configuration -> System Configuration -> Services -> galera-autofix"
            verify "$n" "cluster check and galera-autofix are switched off" \
                "${RS_VERIFY_TOGGLES//@WANT@/disabled}"
            mark_done "prepare.toggles.${n}"
        }
    done

    for n in "${NODES[@]}"; do
        done_skip "prepare.pfcron.${n}" || {
            rstep "$n" "restart pfcron (12.4.2)" '"$PFCMD" service pfcron restart' \
                || die "${n}: pfcron could not be restarted."
            mark_done "prepare.pfcron.${n}"
        }
    done

    for n in "${NODES[@]}"; do
        done_skip "prepare.autofix.${n}" || {
            rstep "$n" "stop galera-autofix (12.4.3)" '
set -e
"$PFCMD" service galera-autofix updatesystemd
"$PFCMD" service galera-autofix stop
echo AUTOFIX_STOPPED' \
                || die "${n}: galera-autofix could not be stopped." \
                       "Is the service really disabled in the web UI?"
            mark_done "prepare.autofix.${n}"
        }
    done

    state_set prepared 1
    log_ok "Preparation complete"
    say ""
    next_hint upgrade-c
}

# --- PHASE upgrade-c - 12.4.4 -------------------------------------------------

phase_upgrade_c() {
    log_head "UPGRADE NODE C - Clustering Guide 12.4.4"
    resolve_roles
    [[ -n "$TARGET_VERSION" ]] || die \
        "Target version missing." \
        "It is passed to do-upgrade.sh as UPGRADE_TO." \
        "Example: ${SCRIPT_NAME} upgrade-c --target-version 15.2"

    [[ "$(state_get prepared || true)" == "1" ]] || \
        log_warn "Phase 'prepare' is not recorded as done (12.4.2/12.4.3)."

    say ""
    say "Sequence on ${C_BLD}${NODE_C}${C_RST}:"
    say "  1. stop the services (packetfence-config stays up)"
    say "  2. ${NODE_A} and ${NODE_B} ignore ${NODE_C}; restart 7 services there"
    say "  3. ${NODE_C} ignores ${NODE_A} and ${NODE_B}, restart MariaDB"
    say "  4. do-upgrade.sh on ${NODE_C}"
    say "  5. checkup on ${NODE_C}"
    say "  6. stop ${NODE_A} and ${NODE_B} completely"
    say "  7. start the services on ${NODE_C}"
    say ""
    say "${C_YEL}From step 3 on, configuration and data changes on"
    say "${NODE_A} and ${NODE_B} are lost (Guide 12.4.4).${C_RST}"
    say ""
    say "${C_YEL}${C_BLD}Take VM snapshots of all three nodes first (12.4.1).${C_RST}"
    say ""

    # Asked here, not in preflight: this is where the changing part begins.
    if [[ $SAME_VERSION -eq 1 ]] || all_on_target; then
        say "${C_YEL}${C_BLD}All nodes already run PacketFence $(ver_mm "$TARGET_VERSION").${C_RST}"
        say "The upgrade itself would have nothing to do. This procedure would still"
        say "stop PacketFence on ${NODE_A} and ${NODE_B}, and in 'reintegrate' wipe and"
        say "resynchronise their databases (12.4.6) - an outage and a full resync."
        say "Worthwhile only for a maintenance build inside $(ver_mm "$TARGET_VERSION")."
        say ""
        confirm "Continue anyway?"
        say ""
    fi

    confirm "Snapshots in place and start the upgrade of ${NODE_C} now?"

    # --- Step 1: stop the services on C ---
    done_skip "c.stop" || {
        rstep "$NODE_C" "stop the PacketFence services (packetfence-config stays active)" "$RS_STOP_PF" \
            || die "${NODE_C}: services could not be stopped."
        verify "$NODE_C" "services are stopped, packetfence-config keeps running" \
            "$RS_VERIFY_STOPPED" \
            "Expected: no traffic-bearing service left, packetfence-config active." \
            "bin/cluster/node needs packetfence-config (Guide 12.4.4)."
        mark_done "c.stop"
    }

    # --- Step 2: A and B ignore C ---
    local n
    for n in "$NODE_A" "$NODE_B"; do
        done_skip "c.disable_on.${n}" || {
            rstep "$n" "disable ${NODE_C} in the cluster" \
                "${CLUSTER_NODE_CMD} \"\$1\" disable" "$NODE_C" \
                || die "${n}: '${CLUSTER_NODE_CMD} ${NODE_C} disable' failed." \
                       "Is packetfence-config running on ${n}?"
            verify_node_disabled "$n" "$NODE_C"
            mark_done "c.disable_on.${n}"
        }
    done

    # --- Step 2b: restart the services on A and B, node by node ---
    for n in "$NODE_A" "$NODE_B"; do
        done_skip "c.restart_services.${n}" || {
            log_step "${n}: restarting 7 services (guide order)"
            [[ "$n" == "$NODE_A" ]] && log_dim "Per the guide this briefly causes service outages on ${NODE_A}."
            local svc
            for svc in "${DETACH_RESTART_SERVICES[@]}"; do
                rstep "$n" "  service ${svc} restart" \
                    '"$PFCMD" service "$1" restart' "$svc" \
                    || die "${n}: restarting ${svc} failed."
                # 'pfcmd service X restart' returns 0 even for a service it
                # does not know - it prints a line and does nothing. The guide
                # uses names from older versions, so a silent no-op here means
                # the component still knows about C.
                if grep -qi 'is not managed by PacketFence' <<<"${RSTEP_OUT:-}"; then
                    log_warn "${n}: '${svc}' is not managed by PacketFence - the restart had no effect"
                    log_info "  The guide still uses this name from older versions."
                    log_info "  In 15.x the DHCP component is called 'pfdhcp'."
                    log_info "  Adjust the names via DETACH_RESTART_SERVICES in ${CONFIG_FILE}."
                fi
            done
            # A successful return code per service does not mean the node
            # carries traffic again - the guide warns about outages here.
            if [[ $DRY_RUN -eq 0 ]]; then
                wait_services "$n" \
                    || die "${n}: services are down after the restarts: ${SERVICES_DOWN_LAST:-unclear}" \
                           "The cluster has not switched over yet - ${NODE_C} is only detached." \
                           "Fix ${n} first, then: ${SCRIPT_NAME} run --resume"
            fi
            mark_done "c.restart_services.${n}"
        }
    done

    # --- Step 3: C ignores A and B, MariaDB restarted ---
    for n in "$NODE_A" "$NODE_B"; do
        done_skip "c.disable_peer.${n}" || {
            rstep "$NODE_C" "disable ${n} in the cluster" \
                "${CLUSTER_NODE_CMD} \"\$1\" disable" "$n" \
                || die "${NODE_C}: '${CLUSTER_NODE_CMD} ${n} disable' failed."
            verify_node_disabled "$NODE_C" "$n"
            mark_done "c.disable_peer.${n}"
        }
    done
    done_skip "c.mariadb_restart" || {
        # No 'restart': its stop half hangs just like a plain 'systemctl stop'
        # - see stop_mariadb.
        stop_mariadb "$NODE_C" \
            || die "${NODE_C}: packetfence-mariadb could not be stopped." \
                   "See the log: ${PF_ROOT}/logs/mariadb.log"
        rstep "$NODE_C" "start packetfence-mariadb (standalone now)" \
            'systemctl start packetfence-mariadb; echo MARIADB_RESTARTED' \
            || die "${NODE_C}: packetfence-mariadb does not start." \
                   "See the log: ${PF_ROOT}/logs/mariadb.log"
        # This used to go unchecked - a failure would only have surfaced in
        # the middle of do-upgrade.sh.
        wait_db_reachable "$NODE_C" \
            || die "${NODE_C}: database not reachable after the restart." \
                   "See the log: ${PF_ROOT}/logs/mariadb.log"
        mark_done "c.mariadb_restart"
    }
    log_ok "${NODE_C} is detached from the cluster"

    # --- Step 4: do-upgrade.sh ---
    done_skip "c.do_upgrade" || {
        say ""
        say "${C_BLD}The upgrade of ${NODE_C} runs now (Upgrade Guide 5.1).${C_RST}"
        say "This can take a while and may ask questions."
        run_do_upgrade "$NODE_C" "" \
            || die "${NODE_C}: do-upgrade.sh failed." \
                   "The output is above and in ${RUN_LOG}." \
                   "On the node: ${LOG_DIR}/pfclu-doupgrade.log" \
                   "The cluster has not switched over: ${NODE_A} and ${NODE_B} keep running." \
                   "Rolling back without data loss is still possible here (see 'rollback')."
        assert_upgraded "$NODE_C" "$TARGET_VERSION" \
            || die "${NODE_C}: do-upgrade.sh reported success, but the version is wrong." \
                   "run-upgrade.sh runs with 'set -o errexit' and may have bailed out after the" \
                   "package switch - e.g. at the prompt in handle_pkgnew_file." \
                   "Inspect on the node: ${LOG_DIR}/pfclu-doupgrade.log" \
                   "The cluster has not switched over; 'rollback' is still possible."
        mark_done "c.do_upgrade"
    }
    log_ok "${NODE_C} is upgraded"
    check_container_images "$NODE_C"

    # --- Step 5: checkup ---
    done_skip "c.checkup" || {
        rstep "$NODE_C" "start packetfence-proxysql" \
            'systemctl start packetfence-proxysql; echo PROXYSQL_STARTED' \
            || die "${NODE_C}: packetfence-proxysql does not start."
        if [[ $DRY_RUN -eq 1 ]]; then
            log_dim "[dry-run] ${NODE_C}: pfcmd checkup (evaluated for FATAL errors)"
        else
        log_step "${NODE_C}: pfcmd checkup"
        local out rc=0
        out=$(rexec "$NODE_C" '"$PFCMD" checkup 2>&1') || rc=$?
        [[ -n "$RUN_LOG" ]] && { echo "--- checkup ${NODE_C} ---"; echo "$out"; } >>"$RUN_LOG"
        local fatal warn
        fatal=$(grep -ci '^FATAL' <<<"$out" || true)
        warn=$(grep -ci '^WARNING' <<<"$out" || true)
        if [[ "$fatal" -gt 0 ]]; then
            grep -i '^FATAL' <<<"$out" | head -n 15 | while IFS= read -r l; do say "${C_RED}    $l${C_RST}"; done
            die "${NODE_C}: checkup reports ${fatal} FATAL error(s)." \
                "Per Guide 12.4.4 FATAL errors prevent the start and must be fixed at once." \
                "Then: ${SCRIPT_NAME} upgrade-c --resume"
        fi
        if [[ "$warn" -gt 0 ]]; then
            # People pointed at the log rarely look. Warnings belong where the
            # run is being watched.
            log_warn "${NODE_C}: checkup reports ${warn} warning(s)"
            grep -i '^WARNING' <<<"$out" | head -n 15 \
              | while IFS= read -r l; do say "${C_YEL}    $l${C_RST}"; done
            (( warn > 15 )) && log_dim "... and $((warn - 15)) more, in full in the log"
        fi
        log_ok "${NODE_C}: checkup without FATAL errors"
        fi
        mark_done "c.checkup"
    }

    # --- Step 5c: prepare the configuration on C ---
    # Deliberately BEFORE the stop of A and B: clear_backend, configreload and
    # the settle pause need nothing from the other two, and every second they
    # take here would otherwise be a second of outage.
    done_skip "c.prep_config" || {
        rstep "$NODE_C" "prepare the configuration (clear_backend, configreload)" \
            "$RS_PREP_CONFIG" "$CONFIG_SETTLE_SECS" \
            || die "${NODE_C}: the configuration could not be reloaded." \
                   "Logs: ${PF_ROOT}/logs; ${PFCMD} checkup"
        mark_done "c.prep_config"
    }

    # --- Step 6: stop A and B ---
    # From here until C holds the VIP, no node carries traffic. The two
    # timestamps make that window measurable instead of a matter of opinion.
    local window_start; window_start=$(date +%s)
    say ""
    say "${C_YEL}${C_BLD}${NODE_C} now takes over operations.${C_RST}"
    say "${NODE_A} and ${NODE_B} are being stopped (services and database)."
    for n in "$NODE_A" "$NODE_B"; do
        done_skip "c.stop_peer.${n}" || {
            rstep "$n" "stop the PacketFence services" "$RS_STOP_PF" \
                || die "${n}: services could not be stopped."
            # ${NODE_C} is about to take over on its own - a service still
            # running here would answer alongside it.
            verify "$n" "services are stopped, packetfence-config keeps running" \
                "$RS_VERIFY_STOPPED" \
                "Expected: no traffic-bearing service left, packetfence-config active."
            stop_mariadb "$n" \
                || die "${n}: packetfence-mariadb could not be stopped."
            mark_done "c.stop_peer.${n}"
        }
    done

    # --- Step 7: start C, keepalived last ---
    if done_skip "c.start"; then
        # The start was skipped, so start_pf_vip_last never ran and the health
        # of C has not been established in this run - check it now.
        wait_services "$NODE_C" || die "${NODE_C}: services did not come up completely." \
            "Back to ${NODE_A}/${NODE_B}: ${SCRIPT_NAME} rollback"
    else
        # On the normal path start_pf_vip_last has already waited for healthy
        # services AND for the VIP. Repeating that here would only lengthen the
        # outage window by a full service-wait round without checking
        # anything start_pf_vip_last has not just checked.
        start_pf_vip_last "$NODE_C" \
            || die "${NODE_C}: services did not come up completely." \
                   "Logs: ${PF_ROOT}/logs; ${PFCMD} checkup" \
                   "Back to ${NODE_A}/${NODE_B}: ${SCRIPT_NAME} rollback"
        mark_done "c.start"
    fi

    local window_end; window_end=$(date +%s)
    log_info "outage window: $((window_end - window_start))s ($(date -d "@${window_start}" '+%H:%M:%S') - $(date -d "@${window_end}" '+%H:%M:%S'))"

    state_set migrated_to_c 1
    log_head "12.4.5 - operations now run on ${NODE_C}"
    say ""
    say "${C_BLD}Please check now${C_RST} that everything works:"
    say "  - logging in to the web UI"
    say "  - RADIUS authentication (Auditing -> RADIUS Audit Log)"
    say "  - Captive Portal"
    say ""
    say "${C_YEL}After that there is no way back except via the snapshots.${C_RST}"
    say ""
    say "  All good:            ${C_BLD}${SCRIPT_NAME} upgrade-ab${C_RST}"
    say "  Something is wrong:  ${C_BLD}${SCRIPT_NAME} rollback${C_RST}"
    say ""
}

# --- PHASE rollback - 12.4.5 "If all goes wrong" ------------------------------

phase_rollback() {
    log_head "ROLLBACK - Clustering Guide 12.4.5 'If all goes wrong'"
    resolve_roles

    # 12.4.5 places this rollback BEFORE upgrade-ab. Past reintegrate the data
    # of A and B has been wiped and resynchronised from C - there is nothing
    # left to go back to, and starting A and B would only start two empty nodes.
    if [[ "$(state_get reintegrated)" == "1" ]]; then
        say ""
        say "${C_RED}${C_BLD}${NODE_A} and ${NODE_B} have already been resynchronised from ${NODE_C} (12.4.6).${C_RST}"
        say "Their old data is gone; this rollback cannot bring it back."
        say "The way back from here is the VM snapshots from 12.4.1."
        say ""
        confirm "Run it anyway?"
    fi
    say ""
    say "Operations go back to ${C_BLD}${NODE_A}${C_RST} and ${C_BLD}${NODE_B}${C_RST}"
    say "with the data as of before the switch-over."
    say ""
    say "${C_YEL}Data created on ${NODE_C} since the switch-over is lost.${C_RST}"
    say "${C_YEL}${NODE_C} stays on the new version - another attempt starts"
    say "again at 'upgrade-c'.${C_RST}"
    say ""
    confirm_typed "Perform the rollback to ${NODE_A} and ${NODE_B}?" "ROLLBACK"

    # ${NODE_C} must be PROVABLY down before A and B come up. A warning here
    # would leave two halves writing to their own database - exactly the split
    # the whole procedure is built to avoid.
    stop_mariadb "$NODE_C" \
        || die "${NODE_C}: MariaDB could not be stopped - ${NODE_A} and ${NODE_B} were NOT started." \
               "Two running halves would each accept writes." \
               "Stop it by hand and check: systemctl status packetfence-mariadb" \
               "Log: ${PF_ROOT}/logs/mariadb.log"
    rstep "$NODE_C" "stop the PacketFence services" "$RS_STOP_PF" \
        || die "${NODE_C}: the services could not be stopped - ${NODE_A} and ${NODE_B} were NOT started." \
               "Check by hand: ${PFCMD} service pf status"
    clear_force_new_cluster "$NODE_C"

    local n
    for n in "$NODE_A" "$NODE_B"; do
        rstep "$n" "start packetfence-mariadb" \
            'systemctl start packetfence-mariadb; echo OK' \
            || die "${n}: packetfence-mariadb does not start." "Log: ${PF_ROOT}/logs/mariadb.log"
    done
    # keepalived last, exactly like the forward path: a node coming back must
    # not pull the VIP over while its services are still starting. want_vip=no
    # because which of the two ends up holding it is keepalived's business.
    for n in "$NODE_A" "$NODE_B"; do
        start_pf_vip_last "$n" no \
            || log_fail "${n}: services not fully up - please check"
    done

    state_set migrated_to_c 0
    # The recorded steps of 'upgrade-c' no longer describe reality: A and B run
    # again, C is stopped. Kept, a later 'upgrade-c --resume' would skip stopping
    # A and B and start C alongside them - two live halves on one database.
    state_unset_prefix "done.c."
    # The same goes for 'upgrade-ab'. With ab_upgraded left at 1, a later
    # 'run --resume' would SKIP the review pause of 12.4.5 - the last point at
    # which this very rollback still works - and then skip upgrade-ab too, so
    # A and B would never get the configuration of the re-upgraded C.
    state_unset_prefix "done.ab."
    state_set ab_upgraded 0
    log_dim "Recorded steps of 'upgrade-c' and 'upgrade-ab' discarded - a retry starts from the top."
    log_ok "Rollback complete - operations run on ${NODE_A} and ${NODE_B}"
    say ""
    say "${NODE_A} and ${NODE_B} still consider each other the only"
    say "cluster members; ${NODE_C} stays disabled. That is the state from which"
    say "'upgrade-c' can be started again."
    say ""
    # stop_mariadb and the wait loops record into FAIL_LIST. Without this the
    # phase would exit 0 with a recorded failure - and 'run' would carry on.
    summary
}

# --- PHASE upgrade-ab - 12.4.5 "If all goes well" + config sync ---------------

# Obtain the webservices credentials for cluster/sync
load_webservices_creds() {
    [[ -n "$WS_USER" && -n "$WS_PASS" ]] && return 0
    if [[ $DRY_RUN -eq 1 ]]; then
        # Dry-run queries nothing and reads nothing from the nodes.
        WS_USER="${WS_USER:-<webservices-user>}"
        WS_PASS="${WS_PASS:-<webservices-password>}"
        log_dim "[dry-run] webservices credentials would be read from ${NODE_C}'s pf.conf"
        return 0
    fi
    local out rc=0
    out=$(rexec "$NODE_C" "$RS_WEBSERVICES") || rc=$?
    if [[ $rc -eq 0 ]]; then
        [[ -z "$WS_USER" ]] && WS_USER="$(sed -n 's/^ws_user=//p' <<<"$out" | head -n1)"
        [[ -z "$WS_PASS" ]] && WS_PASS="$(sed -n 's/^ws_pass=//p' <<<"$out" | head -n1)"
    fi
    if [[ -n "$WS_USER" && -n "$WS_PASS" ]]; then
        log_ok "webservices credentials read from ${NODE_C}'s pf.conf (user: ${WS_USER})"
        return 0
    fi
    say ""
    say "The webservices credentials could not be read from pf.conf."
    say "Found under: Configuration -> Integration -> Web Services"
    [[ -z "$WS_USER" ]] && {
        printf 'Webservices user: '
        tty_flush
        read -r WS_USER </dev/tty || die_no_input
    }
    if [[ -z "$WS_PASS" ]]; then
        printf 'Webservices password: '
        read -rs WS_PASS </dev/tty || { printf '\n'; die_no_input; }
        printf '\n'
    fi
    [[ -n "$WS_USER" && -n "$WS_PASS" ]] || die "Without webservices credentials the config sync is impossible."
}

phase_upgrade_ab() {
    log_head "UPGRADE NODE A AND B - Clustering Guide 12.4.5"
    resolve_roles
    [[ -n "$TARGET_VERSION" ]] || die \
        "Target version missing." \
        "Example: ${SCRIPT_NAME} upgrade-ab --target-version 15.2"

    [[ "$(state_get migrated_to_c || true)" == "1" ]] || \
        log_warn "It is not recorded that operations already run on ${NODE_C}."

    local cip; cip="$(node_mgmt_ip "$NODE_C" || true)"
    [[ -n "$cip" ]] || die "management_ip of ${NODE_C} not found in cluster.conf." \
        "Needed for '${CLUSTER_SYNC_CMD} --from='."
    log_info "Config source: ${NODE_C} (${cip})"

    # During a full run the pause after 12.4.5 already asked this.
    [[ "$RESUME_PHASE" == "run" ]] || confirm "Upgrade ${NODE_A} and ${NODE_B} now?"

    # A ignores B, B ignores A
    done_skip "ab.disable.${NODE_A}" || {
        rstep "$NODE_A" "disable ${NODE_B}" "${CLUSTER_NODE_CMD} \"\$1\" disable" "$NODE_B" \
            || die "${NODE_A}: disabling ${NODE_B} failed."
        mark_done "ab.disable.${NODE_A}"
    }
    done_skip "ab.disable.${NODE_B}" || {
        rstep "$NODE_B" "disable ${NODE_A}" "${CLUSTER_NODE_CMD} \"\$1\" disable" "$NODE_A" \
            || die "${NODE_B}: disabling ${NODE_A} failed."
        mark_done "ab.disable.${NODE_B}"
    }

    # Restart MariaDB, then upgrade. The guide writes the export in front of
    # both, but only run-upgrade.sh reads UPGRADE_CLUSTER_SECONDARY
    # (addons/full-upgrade/run-upgrade.sh) - and it gets it set in its own
    # script. In front of 'systemctl start' it is ritual, kept for fidelity.
    local n
    for n in "$NODE_A" "$NODE_B"; do
        done_skip "ab.mariadb.${n}" || {
            # Stop and start split: 'restart' hangs in its stop half just like
            # a plain 'stop' - see stop_mariadb.
            stop_mariadb "$n" \
                || die "${n}: packetfence-mariadb could not be stopped." \
                       "Log: ${PF_ROOT}/logs/mariadb.log"
            rstep "$n" "start packetfence-mariadb (UPGRADE_CLUSTER_SECONDARY)" '
set -e
export UPGRADE_CLUSTER_SECONDARY=yes
systemctl start packetfence-mariadb
echo MARIADB_RESTARTED' \
                || die "${n}: packetfence-mariadb does not start." "Log: ${PF_ROOT}/logs/mariadb.log"
            mark_done "ab.mariadb.${n}"
        }
        done_skip "ab.do_upgrade.${n}" || {
            say ""
            say "${C_BLD}Upgrade of ${n} (Upgrade Guide 5.1).${C_RST}"
            log_dim "UPGRADE_CLUSTER_SECONDARY=yes is set for the run (Guide 12.4.5)."
            run_do_upgrade "$n" "yes" \
                || die "${n}: do-upgrade.sh failed." \
                       "On the node: ${LOG_DIR}/pfclu-doupgrade.log" \
                       "Operations keep running on ${NODE_C}." \
                       "After fixing: ${SCRIPT_NAME} upgrade-ab --resume"
            assert_upgraded "$n" "$TARGET_VERSION" \
                || die "${n}: do-upgrade.sh reported success, but the version is wrong." \
                       "Inspect on the node: ${LOG_DIR}/pfclu-doupgrade.log" \
                       "Operations keep running on ${NODE_C}." \
                       "After fixing: ${SCRIPT_NAME} upgrade-ab --resume"
            mark_done "ab.do_upgrade.${n}"
        }
    done

    # Pull the configuration from C
    load_webservices_creds
    for n in "$NODE_A" "$NODE_B"; do
        done_skip "ab.sync.${n}" || {
            log_step "${n}: pulling the configuration from ${NODE_C} (${cip})"
            if [[ $DRY_RUN -eq 1 ]]; then
                log_dim "[dry-run] ${CLUSTER_SYNC_CMD} --from=${cip} --api-user=${WS_USER} --api-password=<hidden>"
            else
                local out rc=0 sync_script
                # The password travels INSIDE the script text, which rexec
                # feeds to bash over stdin. As an argument it would sit in the
                # local ssh argv and in 'bash -s -- <password>' on the target,
                # readable by anyone who can run ps there. The script text is
                # never written to the log - only the output below is, and that
                # is masked first.
                sync_script="set -e
${CLUSTER_SYNC_CMD} --from=$(printf '%q' "$cip") --api-user=$(printf '%q' "$WS_USER") --api-password=$(printf '%q' "$WS_PASS")
\"\$PFCMD\" configreload hard
echo SYNC_DONE"
                out=$(rexec "$n" "$sync_script") || rc=$?
                sync_script=""
                # Plain string replacement, no regex: a password with '[', '*'
                # or a trailing backslash would break sed - and sed failing here
                # would tear the run down BEFORE the step is marked done, so
                # every --resume would die at the same line.
                local shown="${out//"$WS_PASS"/<hidden>}"
                if [[ -n "$RUN_LOG" ]]; then
                    { echo "--- cluster/sync ${n} ---"
                      printf '%s\n' "$shown"; } >>"$RUN_LOG"
                fi
                [[ $rc -eq 0 ]] || {
                    tail -n 20 <<<"$shown" | sed 's/^/      /' | while IFS= read -r l; do say "$l"; done
                    die "${n}: config sync from ${NODE_C} failed." \
                        "Check the webservices credentials (Configuration -> Integration -> Web Services)." \
                        "Check reachability of ${cip}."
                }
                log_ok "${n}: configuration synchronised"
            fi
            mark_done "ab.sync.${n}"
        }
    done

    state_set ab_upgraded 1
    log_ok "${NODE_A} and ${NODE_B} are upgraded and carry the configuration of ${NODE_C}"
    say ""
    next_hint reintegrate
}

# --- PHASE reintegrate - 12.4.6 and 12.4.7 ------------------------------------

phase_reintegrate() {
    log_head "REINTEGRATION - Clustering Guide 12.4.6 and 12.4.7"
    resolve_roles
    [[ "$(state_get ab_upgraded || true)" == "1" ]] || \
        log_warn "It is not recorded that ${NODE_A} and ${NODE_B} have already been upgraded."

    say ""
    say "${NODE_A} and ${NODE_B} discard their database and resynchronise it"
    say "entirely from ${NODE_C}. During that the database is ${C_BLD}read-only${C_RST}."
    say "Per the guide this takes minutes up to an hour, depending on data volume."
    say ""

    # Re-enable every member everywhere
    local n m
    for n in "${NODES[@]}"; do
        done_skip "re.enable.${n}" || {
            for m in "$NODE_A" "$NODE_B" "$NODE_C"; do
                rstep "$n" "re-enable ${m}" "${CLUSTER_NODE_CMD} \"\$1\" enable" "$m" \
                    || die "${n}: enabling ${m} failed."
            done
            verify "$n" "all three members are active again on ${n}" \
                "ls ${PF_ROOT}/var/run/*-cluster-disabled >/dev/null 2>&1 || echo VERIFY_OK"
            mark_done "re.enable.${n}"
        }
    done

    # Bring C up as the new master
    done_skip "re.c_master" || {
        stop_mariadb "$NODE_C" \
            || die "${NODE_C}: MariaDB could not be stopped before the master start." \
                   "Log: ${PF_ROOT}/logs/mariadb.log"
        rstep "$NODE_C" "regenerate the config, start as the new master" '
set -e
"$PFCMD" generatemariadbconfig
systemctl set-environment MARIADB_ARGS=--force-new-cluster
systemctl start packetfence-mariadb
echo NEW_CLUSTER_STARTED' \
            || die "${NODE_C}: MariaDB does not start as the new master." \
                   "Log: ${PF_ROOT}/logs/mariadb.log"
        mark_done "re.c_master"
    }

    # Check reachability (guide: a connection must work despite read-only)
    wait_db_reachable "$NODE_C" \
        || die "${NODE_C}: no connection to the database after starting as master." \
               "See the log: ${PF_ROOT}/logs/mariadb.log"

    # A and B: discard the data and resynchronise. The expected cluster_size
    # grows along the way (C alone 1, +A 2, +B 3) - a fixed expectation would
    # wait out the timeout on the second node.
    local joined=1
    for n in "$NODE_A" "$NODE_B"; do
        done_skip "re.resync.${n}" || {
            say ""
            say "${C_YEL}${C_BLD}${n}: /var/lib/mysql is now wiped completely${C_RST}"
            say "${C_YEL}and resynchronised from ${NODE_C} (Guide 12.4.6).${C_RST}"
            # The stop must be PROVABLY complete before deleting: the return
            # code of 'systemctl stop' says nothing about the data directory.
            stop_mariadb "$n" \
                || die "${n}: MariaDB could not be stopped - /var/lib/mysql was NOT touched." \
                       "Log: ${PF_ROOT}/logs/mariadb.log"
            rstep "$n" "wipe the data directory, resynchronise" '
set -e
# Safety net: only empty it if this really is the MariaDB data directory
[ -d /var/lib/mysql ] || { echo "ERROR: /var/lib/mysql does not exist"; exit 1; }
rm -fr /var/lib/mysql/*
systemctl start packetfence-mariadb
echo RESYNC_STARTED' \
                || die "${n}: the resync could not be started." \
                       "Log: ${PF_ROOT}/logs/mariadb.log"
            mark_done "re.resync.${n}"
        }
        joined=$((joined+1))
        # Fatal, not a warning: the NEXT pass of this loop wipes /var/lib/mysql
        # on the other node. If the sync onto this one did not work, the second
        # one must stay untouched - it is then the only intact copy besides C.
        wait_galera "$n" "$joined" \
            || die "${n}: not in sync with ${NODE_C} (Guide 12.4.6)." \
                   "The data directory of the remaining node was NOT touched." \
                   "Check the disk space and ${PF_ROOT}/logs/mariadb.log on ${n} and ${NODE_C}." \
                   "Continue after fixing: ${SCRIPT_NAME} reintegrate --resume"
    done

    # All three in the Galera cluster?
    done_skip "re.wait_all" || {
        wait_galera "$NODE_C" 3 \
            || die "Not all three nodes are in the Galera cluster." \
                   "All members must be connected before the next step (Guide 12.4.6)." \
                   "Log: ${PF_ROOT}/logs/mariadb.log"
        mark_done "re.wait_all"
    }

    # Take C out of force-new-cluster mode
    done_skip "re.c_normal" || {
        stop_mariadb "$NODE_C" \
            || die "${NODE_C}: MariaDB could not be stopped." \
                   "It would keep running with --force-new-cluster."
        rstep "$NODE_C" "start MariaDB without --force-new-cluster" '
set -e
systemctl unset-environment MARIADB_ARGS
systemctl start packetfence-mariadb
echo MARIADB_NORMAL' \
            || die "${NODE_C}: MariaDB does not start in normal mode."
        verify "$NODE_C" "--force-new-cluster is gone" \
            'systemctl show-environment 2>/dev/null | grep -q "^MARIADB_ARGS=" && exit 0
echo VERIFY_OK' \
            "Left in place, the next MariaDB start would bootstrap a second cluster."
        mark_done "re.c_normal"
    }
    wait_galera "$NODE_C" 3 || die "${NODE_C}: Galera not complete again after the restart."

    # Start A and B. The guide requires haproxy-admin explicitly only "after
    # all services have been restarted" - so on BOTH nodes once both are up, not
    # on A while B is still down.
    # keepalived last here too: ${NODE_C} is carrying the traffic, and a node
    # coming back must not pull the VIP over while its services are still
    # starting. want_vip=no - which of the three ends up holding it is
    # keepalived's business, and C is a legitimate answer.
    for n in "$NODE_A" "$NODE_B"; do
        done_skip "re.start.${n}" || {
            rstep "$n" "prepare the configuration (clear_backend, configreload)" \
                "$RS_PREP_CONFIG" "$CONFIG_SETTLE_SECS" \
                || die "${n}: the configuration could not be reloaded." "Logs: ${PF_ROOT}/logs"
            # mark_done only on success: otherwise --resume skips a node whose
            # services never came up, and the phase still reports completion.
            start_pf_vip_last "$n" no \
                || die "${n}: services did not come up completely." \
                       "Logs: ${PF_ROOT}/logs; ${PFCMD} checkup"
            mark_done "re.start.${n}"
        }
    done
    for n in "$NODE_A" "$NODE_B"; do
        done_skip "re.haproxy_admin.${n}" || {
            rstep "$n" "restart haproxy-admin (Guide 12.4.6, addendum)" \
                '"$PFCMD" service haproxy-admin restart' \
                || die "${n}: restarting haproxy-admin failed."
            mark_done "re.haproxy_admin.${n}"
        }
    done

    # 12.4.7: restart C so it knows its peers again
    done_skip "re.restart_c" || {
        rstep "$NODE_C" "prepare the configuration (clear_backend, configreload)" \
            "$RS_PREP_CONFIG" "$CONFIG_SETTLE_SECS" \
            || die "${NODE_C}: the configuration could not be reloaded."
        # 12.4.7 restarts the node that is carrying the load. Holding keepalived
        # back means the VIP moves to a ready A or B and only comes back once
        # ${NODE_C} can serve it again.
        start_pf_vip_last "$NODE_C" no \
            || die "${NODE_C}: services did not come up completely after the restart." \
                   "Logs: ${PF_ROOT}/logs; ${PFCMD} checkup"
        mark_done "re.restart_c"
    }

    state_set reintegrated 1
    log_ok "All three nodes are back in the cluster"
    say ""
    next_hint finish
}

# --- PHASE finish - 12.4.8 and 12.4.9 -----------------------------------------

phase_finish() {
    log_head "FINISH - Clustering Guide 12.4.8 and 12.4.9"
    resolve_roles

    # Belt and braces: if reintegrate aborted after 're.c_master', the manager
    # environment of C still carries --force-new-cluster. galera-autofix, which
    # is switched back on below, would restart MariaDB with it and bootstrap a
    # second cluster.
    clear_force_new_cluster "$NODE_C"

    say ""
    say "Cluster check and galera-autofix are switched back on (12.4.8, 12.4.9)."
    say ""

    local n
    for n in "${NODES[@]}"; do
        done_skip "fin.toggles.${n}" || {
            rstep "$n" "switch cluster check and galera-autofix back on" \
                "$RS_TOGGLES" "enabled" \
                || die "${n}: the switches could not be set." \
                       "Alternatively in the web UI:" \
                       "  Configuration -> System Configuration -> Maintenance -> Cluster Check" \
                       "  Configuration -> System Configuration -> Services -> galera-autofix"
            # Same check as in 'prepare'. Without it the cluster would silently
            # stay without cluster check and without galera-autofix - and the
            # state file, which would show it, is deleted at the end of finish.
            verify "$n" "cluster check and galera-autofix are switched on" \
                "${RS_VERIFY_TOGGLES//@WANT@/enabled}"
            mark_done "fin.toggles.${n}"
        }
    done

    for n in "${NODES[@]}"; do
        done_skip "fin.pfcron.${n}" || {
            rstep "$n" "restart pfcron (12.4.8)" '"$PFCMD" service pfcron restart' \
                || die "${n}: pfcron could not be restarted."
            mark_done "fin.pfcron.${n}"
        }
    done
    for n in "${NODES[@]}"; do
        done_skip "fin.autofix.${n}" || {
            rstep "$n" "restart galera-autofix (12.4.9)" '
set -e
"$PFCMD" service galera-autofix updatesystemd
"$PFCMD" service galera-autofix restart
echo AUTOFIX_RESTARTED' \
                || die "${n}: galera-autofix could not be started." \
                       "Is the service enabled again in the web UI?"
            mark_done "fin.autofix.${n}"
        }
    done

    # Cleanup: if the detach unit dies hard, the credentials file is left.
    for n in "${NODES[@]}"; do
        rstep "$n" "remove leftovers of the upgrade runs" \
            'rm -f /run/pfclu-doupgrade.stdin; echo CLEANED' \
            || log_warn "${n}: /run/pfclu-doupgrade.stdin could not be removed"
    done

    # Any containers still on the old version? run-upgrade.sh does not pull the
    # images itself; postinst and service start do. Informational only.
    check_container_images

    # Catch-all: a run that reached this point without going through
    # start_pf_vip_last on every node would otherwise end 'degraded'.
    local cn
    for cn in "${NODES[@]}"; do clear_stale_failures "$cn"; done

    log_head "Final check"
    check_all

    # summary() exits 1 as soon as something failed, so everything the bad case
    # still has to say belongs BEFORE it. And 'finished' is recorded only after a
    # clean final check - otherwise 'finish --resume' would skip the phase.
    if [[ ${#FAIL_LIST[@]} -ne 0 ]]; then
        say ""
        say "The state file ${STATE_FILE} is kept because points remain open."
        say "After fixing them: ${SCRIPT_NAME} finish --resume"
        summary          # exits 1
        return 1
    fi

    state_set finished 1
    summary
    say "${C_GRN}${C_BLD}Upgrade complete. All three nodes run the new version.${C_RST}"
    say ""
    # The state file has served its purpose. Left behind, the next run would
    # wrongly consider every step done.
    if [[ $KEEP_STATE -eq 1 ]]; then
        say "State file kept on request: ${STATE_FILE}"
    elif [[ $DRY_RUN -eq 1 ]]; then
        log_dim "[dry-run] the state file would stay unchanged"
    elif rm -f "$STATE_FILE" "${STATE_FILE}.lock" 2>/dev/null; then
        log_ok "State file deleted - the next upgrade starts clean"
    else
        log_warn "Could not delete the state file: ${STATE_FILE}"
        log_info "  Remove it by hand before the next upgrade."
    fi
    say ""
}

# --- PHASE run - the whole procedure in one go --------------------------------

phase_run() {
    RESUME_PHASE="run"
    log_head "FULL RUN - Clustering Guide 12.4 from start to finish"

    [[ -n "$TARGET_VERSION" ]] || die \
        "The full run needs the target version." \
        "Example: ${SCRIPT_NAME} run --target-version 15.2"

    say ""
    say "The run works through them in order:"
    say "  preflight -> prepare -> upgrade-c -> ${C_BLD}Halt${C_RST} -> upgrade-ab -> reintegrate -> finish"
    say ""
    say "It pauses twice: before ${C_BLD}upgrade-c${C_RST} for the snapshots,"
    say "and after it for the functional check per Guide 12.4.5."
    say "Everything else runs through; any error ends the run at once."
    say ""

    # Skip phases already done - the same markers the individual calls set.
    if procedure_started; then
        log_ok "Phase preflight: skipped - the procedure is already running"
    else
        run_step preflight "" phase_preflight
    fi
    run_step prepare     prepared        phase_prepare
    run_step upgrade-c   migrated_to_c   phase_upgrade_c

    if [[ "$(state_get ab_upgraded)" != "1" ]]; then
        # With --resume upgrade-c is skipped, leaving the roles empty - the
        # most important question of the run would then name no nodes.
        resolve_roles
        say ""
        log_head "REVIEW PAUSE - Clustering Guide 12.4.5"
        say "The cluster now runs on ${C_BLD}${NODE_C}${C_RST} alone."
        say "${NODE_A} and ${NODE_B} are stopped and still ${C_BLD}unchanged${C_RST}."
        say ""
        say "${C_YEL}This is the last point where 'rollback' works without data loss.${C_RST}"
        say "The next step overwrites ${NODE_A} and ${NODE_B}."
        say ""
        say "Check it functionally now: login, portal, RADIUS, web UI."
        say ""
        confirm "Is everything working on ${NODE_C}? Continue with ${NODE_A} and ${NODE_B}?"
    fi

    run_step upgrade-ab  ab_upgraded     phase_upgrade_ab
    run_step reintegrate reintegrated    phase_reintegrate
    run_step finish      finished        phase_finish
}

# run_step <name> <state marker|""> <function>
run_step() {
    local name="$1" marker="$2" fn="$3"
    if [[ -n "$marker" && $RESUME -eq 1 && "$(state_get "$marker")" == "1" ]]; then
        log_ok "Phase ${name}: already done, skipping"
        return 0
    fi
    say ""
    say "${C_BLU}${C_BLD}>>> Phase ${name}${C_RST}"
    "$fn"
}

# --- Shared checks / status ---------------------------------------------------

# check_container_images [node ...] - all nodes without arguments
# Reports containers still on an image tag other than the target version; most
# services are containerised in 15.x. Informational only.
check_container_images() {
    [[ -n "$TARGET_VERSION" ]] || return 0
    [[ $DRY_RUN -eq 1 ]] && { log_dim "[dry-run] container check skipped"; return 0; }
    local n out tag stale
    local -a targets=("$@")
    [[ ${#targets[@]} -eq 0 ]] && targets=("${NODES[@]}")
    tag="maintenance-$(ver_mm "$TARGET_VERSION" | tr '.' '-')"
    for n in "${targets[@]}"; do
        out=$(rexec "$n" 'command -v docker >/dev/null 2>&1 && docker ps --format "{{.Image}}" 2>/dev/null || echo NODOCKER') || continue
        grep -q '^NODOCKER$' <<<"$out" && continue
        # Mind 'set -o pipefail': grep returns 1 when it finds NOTHING - which
        # is the good case here (all containers on the new tag). Without the
        # '|| true' a successful check would bring the script down.
        stale=$(grep ':' <<<"$out" | grep -v ":${tag}\$" | sort -u | paste -sd' ' - || true)
        if [[ -n "$stale" ]]; then
            log_warn "${n}: containers not on ${tag}: ${stale}"
            log_info "  Check the images and restart the affected services."
        else
            log_ok "${n}: all containers on ${tag}"
        fi
    done
}

check_all() {
    local n first_ver="" out
    for n in "${NODES[@]}"; do
        out=$(rexec "$n" "$RS_FACTS") || { log_fail "${n}: not reachable"; continue; }
        local ver; ver=$(sed -n 's/^pf_version=//p' <<<"$out")
        ni_set "$n" pf_version "$ver"
        if [[ -z "$first_ver" ]]; then first_ver="$ver"
        elif [[ "$ver" != "$first_ver" ]]; then
            log_fail "${n}: version ${ver} differs (${NODES[0]}: ${first_ver})"
        fi

        if services_healthy "$n"; then log_ok "${n}: services running"
        else log_fail "${n}: ${SERVICES_DOWN_LAST:-service status unclear}"; fi

        out=$(rexec "$n" "$RS_GALERA") || true
        local size status state
        size=$(sed -n 's/^g:wsrep_cluster_size=//p' <<<"$out")
        status=$(sed -n 's/^g:wsrep_cluster_status=//p' <<<"$out")
        state=$(sed -n 's/^g:wsrep_local_state_comment=//p' <<<"$out")
        ni_set "$n" galera "${state:-?}/${size:-?}"
        if [[ "$status" == "Primary" && "$state" == "Synced" && "$size" == "3" ]]; then
            log_ok "${n}: Galera Primary/Synced, cluster_size=3"
        else
            log_fail "${n}: Galera status=${status:-?} state=${state:-?} size=${size:-?}"
        fi
    done
}

phase_status() {
    log_head "STATUS"
    resolve_roles
    # 'status --rebaseline' re-records the baseline mid-procedure, where
    # preflight refuses to run.
    if [[ $REBASELINE -eq 1 ]]; then
        local n
        for n in "${NODES[@]}"; do
            baseline_refresh "$n" || log_info "  Check with: ${PFCMD} service pf status"
        done
        say ""
    fi
    check_all
    summary
}

summary() {
    log_head "Summary"
    local n role
    say "$(printf '%-24s %-6s %-14s %-18s' 'NODE' 'ROLE' 'PF-VERSION' 'GALERA')"
    for n in "${NODES[@]}"; do
        role="?"
        [[ "$n" == "$NODE_A" ]] && role="A"
        [[ "$n" == "$NODE_B" ]] && role="B"
        [[ "$n" == "$NODE_C" ]] && role="C"
        say "$(printf '%-24s %-6s %-14s %-18s' \
            "$n" "$role" "$(ni_get "$n" pf_version)" "$(ni_get "$n" galera)")"
    done
    say ""
    say "Warnings: ${#WARN_LIST[@]}   Errors: ${#FAIL_LIST[@]}"
    if [[ ${#WARN_LIST[@]} -gt 0 ]]; then
        say ""
        local w; for w in "${WARN_LIST[@]}"; do say "${C_YEL}  * ${w}${C_RST}"; done
    fi
    if [[ ${#FAIL_LIST[@]} -gt 0 ]]; then
        say ""
        say "${C_RED}${C_BLD}Blocking points:${C_RST}"
        local f; for f in "${FAIL_LIST[@]}"; do say "${C_RED}  * ${f}${C_RST}"; done
        say ""
        say "Log: ${RUN_LOG}"
        exit 1
    fi
    say ""
    say "Log: ${RUN_LOG}"
    say ""
}

# --- CLI ----------------------------------------------------------------------

usage() {
    cat <<EOF
${SCRIPT_NAME} ${SCRIPT_VERSION}
Cluster upgrade per PacketFence Clustering Guide 12.4

USAGE
  ${SCRIPT_NAME} <phase> [options]

PHASES
  run           the whole procedure in one go: preflight, prepare,
                upgrade-c, review pause (12.4.5), upgrade-ab, reintegrate,
                finish. Pauses exactly twice - before upgrade-c for the
                snapshots and after it for the functional check. Any error
                ends the run at once, naming the cause and how to resume.
                Requires --target-version.

INDIVIDUALLY (in this order)
  preflight     minimal pre-checks, changes nothing
  prepare       12.4.2 cluster check off, 12.4.3 galera-autofix off
  upgrade-c     12.4.4 detach node C, do-upgrade.sh, checkup,
                stop A and B, put C into service
                -> then the functional check (12.4.5)
  upgrade-ab    12.4.5 upgrade A and B, pull the config from C
  reintegrate   12.4.6 enable all members, C as master, resynchronise
                A and B, 12.4.7 restart C
  finish        12.4.8 and 12.4.9 cluster check and galera-autofix back on

  rollback      12.4.5 "If all goes wrong" - back to A and B
  status        short overview

OPTIONS
  --pioneer HOST   choose a different node C (default: last in cluster.conf)
  --nodes a,b,c    set the node list and order manually
  --target-version X.Y.Z
                   target version. Required for upgrade-c and upgrade-ab;
                   passed to do-upgrade.sh as UPGRADE_TO so it does not
                   prompt for it.
  --os-update      let do-upgrade.sh update the operating system too
  --config FILE    configuration file (default: ${CONFIG_FILE})
  --interactive-upgrade
                   run do-upgrade.sh on the terminal instead of detached.
                   Prompts can then be answered, but a dropped connection
                   aborts the upgrade.
  --dry-run        only show what would happen, change nothing
  --resume         skip steps already done
  --rebaseline     re-record the service baseline. 'preflight' remembers
                   which services are already down per node; afterwards only
                   a deterioration counts as an outage. After a version
                   switch the set of services changes legitimately.
                   Works with 'preflight' and 'status' - the latter is the
                   way once the procedure is already running.
  --yes            confirm prompts automatically (careful)
  --keep-state     keep the state file after 'finish' (deleted otherwise)
  --no-color       no colors
  -h, --help       this help

Roles A, B and C follow the order in cluster.conf. C is the node that is
detached and upgraded first.

Changing phases only run on the node recorded as MASTER_NODE in the
configuration. status and preflight work everywhere.
EOF
}

# The configuration file is read only AFTER the command line - it may be named
# by --config. Without these two, every option that also exists in the file
# would be silently overwritten by it: '--target-version 15.3' against a
# TARGET_VERSION=15.2 in the file would upgrade to 15.2.
declare -A CLI_OVERRIDE=()
declare -a CLI_NODES=()

cli_set() {
    CLI_OVERRIDE["$1"]="$2"
    printf -v "$1" '%s' "$2"
}

apply_cli_overrides() {
    local k
    for k in "${!CLI_OVERRIDE[@]}"; do
        printf -v "$k" '%s' "${CLI_OVERRIDE[$k]}"
    done
    # An array does not fit in CLI_OVERRIDE, so --nodes is kept separately.
    if [[ ${#CLI_NODES[@]} -gt 0 ]]; then
        NODES=("${CLI_NODES[@]}")
    fi
    return 0
}

parse_args() {
    [[ $# -eq 0 ]] && { usage; exit 2; }
    case "$1" in
        run|preflight|prepare|upgrade-c|upgrade-ab|reintegrate|finish|rollback|status)
            PHASE="$1"; shift ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Unknown phase: %s\n\n' "$1"; usage; exit 2 ;;
    esac
    # ${2:?} would exit 1 with a bare "2: parameter null or not set" - every
    # other operating error here exits 2 and shows the help.
    need_arg() {
        [[ $# -ge 2 && -n "$2" ]] && return 0
        printf 'Option %s needs a value.\n\n' "$1"; usage; exit 2
    }
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --pioneer) need_arg "$@"; cli_set PIONEER "$2"; shift 2 ;;
            --nodes)   need_arg "$@"; IFS=',' read -r -a NODES <<<"$2"
                       CLI_NODES=("${NODES[@]}"); shift 2 ;;
            # Not recorded: it only names the file that is about to be read.
            --config)  need_arg "$@"; CONFIG_FILE="$2"; shift 2 ;;
            --target-version) need_arg "$@"; cli_set TARGET_VERSION "$2"; shift 2 ;;
            --os-update)      cli_set INCLUDE_OS_UPDATE yes; shift ;;
            --interactive-upgrade) cli_set INTERACTIVE_UPGRADE 1; shift ;;
            --dry-run) cli_set DRY_RUN 1; shift ;;
            --resume)  cli_set RESUME 1; shift ;;
            --rebaseline) cli_set REBASELINE 1; shift ;;
            --yes|-y)  cli_set ASSUME_YES 1; shift ;;
            --keep-state) cli_set KEEP_STATE 1; shift ;;
            --no-color) cli_set NO_COLOR 1; shift ;;
            -h|--help) usage; exit 0 ;;
            *) printf 'Unknown option: %s\n\n' "$1"; usage; exit 2 ;;
        esac
    done
}

# config_check <file> - checks whether the file can be sourced safely; prints a
# message and returns 1 on objection. The shell sources the file, so only simple
# assignments are allowed. Comments are exempt - $(...) and ';' may appear there
# as text.
# Settings a configuration file may set. Anything else is refused by name, so
# a stray PATH= or IFS= cannot slip in.
CONFIG_KEYS="MASTER_NODE NODES PIONEER SSH_USER SSH_IDENTITY SSH_CONNECT_TIMEOUT
SSH_ALIVE_INTERVAL SSH_ALIVE_COUNT SSH_EXTRA_OPTS RETRY_COUNT RETRY_DELAY
WS_USER WS_PASS PF_ROOT LOG_DIR STATE_FILE KEEP_STATE MIN_FREE_MB_MYSQL
MIN_FREE_MB_ROOT MIN_FREE_MB_APTCACHE POLL_SECS SERVICE_WAIT_TIMEOUT
SERVICE_OK_POLLS GALERA_WAIT_TIMEOUT DB_WAIT_TIMEOUT CONFIG_SETTLE_SECS
SERVICE_REVIVE SERVICE_REVIVE_AFTER VERIFY_RETRIES VERIFY_RETRY_SECS
MARIADB_STOP_TIMEOUT MARIADB_STOP_GRACE VIP_WAIT_TIMEOUT CLUSTER_VIP
TARGET_VERSION INCLUDE_OS_UPDATE DETACH_TIMEOUT INTERACTIVE_UPGRADE
DETACH_RESTART_SERVICES"
CONFIG_ARRAY_KEYS="NODES DETACH_RESTART_SERVICES"

# config_parse <file> <assign>
# The configuration is data, never code - it is parsed, not sourced. The file is
# meant to be distributed by git (see the README), and sourcing would turn write
# access to that repository into root on every cluster deploying it. Values are
# taken literally: no expansion, no substitution, no word splitting except
# inside an explicit (list).
# Prints the objection and returns 1 on the first bad line; assigns only when
# <assign> is 1.
config_parse() {
    local f="$1" assign="$2" lineno=0 line key val v
    while IFS= read -r line || [[ -n "$line" ]]; do
        lineno=$((lineno + 1))
        [[ "$line" =~ ^[[:space:]]*(#|$) ]] && continue
        if [[ ! "$line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
            printf 'line %d is not a VARIABLE=VALUE assignment: %s\n' "$lineno" "$line"
            return 1
        fi
        key="${BASH_REMATCH[1]}"
        val="${BASH_REMATCH[2]}"
        if [[ " ${CONFIG_KEYS//$'\n'/ } " != *" ${key} "* ]]; then
            printf 'line %d sets an unknown option: %s\n' "$lineno" "$key"
            return 1
        fi
        # Values are literal, so these are harmless - but whoever wrote them
        # expected them to run, and silently storing '$(hostname)' as a node
        # name would be the more confusing answer.
        case "$val" in
            *'$('*|*'`'*|*'${'*)
                printf 'line %d: values are taken literally, no substitution: %s\n' "$lineno" "$line"
                return 1
                ;;
        esac
        case "$val" in
            '('*')')
                if [[ " ${CONFIG_ARRAY_KEYS} " != *" ${key} "* ]]; then
                    printf 'line %d: %s does not take a (list)\n' "$lineno" "$key"
                    return 1
                fi
                v="${val#\(}"; v="${v%\)}"
                # Reading into the variable NAMED by $key is the intent here.
                # shellcheck disable=SC2229
                if [[ $assign -eq 1 ]]; then read -ra "$key" <<<"$v" || true; fi
                ;;
            '"'*'"')
                v="${val#\"}"; v="${v%\"}"
                if [[ $assign -eq 1 ]]; then printf -v "$key" '%s' "$v"; fi
                ;;
            "'"*"'")
                v="${val#\'}"; v="${v%\'}"
                if [[ $assign -eq 1 ]]; then printf -v "$key" '%s' "$v"; fi
                ;;
            *)
                # An unquoted value with spaces used to be an assignment PLUS a
                # command when the file was sourced. It is merely wrong now, but
                # it is still a mistake worth naming.
                if [[ "$val" == *[[:space:]]* ]]; then
                    printf 'line %d: a value with spaces must be quoted: %s\n' "$lineno" "$line"
                    return 1
                fi
                if [[ $assign -eq 1 ]]; then printf -v "$key" '%s' "$val"; fi
                ;;
        esac
    done < "$f"
    return 0
}

config_check() {
    config_parse "$1" 0
}

load_config() {
    [[ -f "$CONFIG_FILE" ]] || return 0
    local msg
    # Checked first, assigned second: a bad line must not leave half the file
    # applied.
    if ! msg=$(config_parse "$CONFIG_FILE" 0); then
        die "${CONFIG_FILE} is not a valid configuration file." "$msg"
    fi
    config_parse "$CONFIG_FILE" 1
}

acquire_lock() {
    [[ $DRY_RUN -eq 1 ]] && return 0
    if ! ( set -o noclobber; printf '%s %s\n' "$$" "$(date -Is)" >"$LOCK_FILE" ) 2>/dev/null; then
        die "Another instance is already running (lock: ${LOCK_FILE}, $(cat "$LOCK_FILE" 2>/dev/null))." \
            "Remove the leftover with: rm -f ${LOCK_FILE}"
    fi
    LOCK_HELD=1
}

main() {
    parse_args "$@"
    setup_colors
    load_config
    # The command line beats the configuration file - see apply_cli_overrides.
    apply_cli_overrides
    setup_colors
    ssh_opts_init
    SELF_HOST="$(hostname -s)"

    # No chmod on LOG_DIR - it is shared with PacketFence, whose services
    # write there as user pf. Only the file itself gets the usual root:pf 0640.
    mkdir -p "$LOG_DIR" 2>/dev/null || true
    RUN_LOG="${LOG_DIR}/pfclu-${PHASE}-${RUN_ID}.log"
    : >"$RUN_LOG"
    chmod 640 "$RUN_LOG" 2>/dev/null || true
    chgrp pf  "$RUN_LOG" 2>/dev/null || true

    say "${C_BLD}${SCRIPT_NAME} ${SCRIPT_VERSION}${C_RST} - phase ${C_BLD}${PHASE}${C_RST} on ${SELF_HOST} (${RUN_ID})"
    [[ $DRY_RUN -eq 1 ]] && say "${C_YEL}DRY-RUN: nothing is changed.${C_RST}"
    [[ $ASSUME_YES -eq 1 ]] && say "${C_YEL}--yes active: nothing will be asked.${C_RST}"

    # Read-only phases are allowed on any node; changing ones only on the master.
    case "$PHASE" in
        preflight|status) : ;;
        *) require_master; acquire_lock ;;
    esac

    case "$PHASE" in
        run)         phase_run ;;
        preflight)   phase_preflight ;;
        prepare)     phase_prepare ;;
        upgrade-c)   phase_upgrade_c ;;
        upgrade-ab)  phase_upgrade_ab ;;
        reintegrate) phase_reintegrate ;;
        finish)      phase_finish ;;
        rollback)    phase_rollback ;;
        status)      phase_status ;;
    esac
}

# PF_UPGRADE_LIB=1 loads only the functions (test suite) without executing.
[[ "${PF_UPGRADE_LIB:-0}" == "1" ]] || main "$@"
