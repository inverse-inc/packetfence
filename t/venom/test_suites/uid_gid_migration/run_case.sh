#!/bin/bash
# Exercise the real migration script without changing the test VM's accounts or services.
set -euo pipefail

scenario=${1:?Missing migration test case}
suite_dir=$(cd "$(dirname "$0")" && pwd)
migration=${2:-$suite_dir/../../../../addons/upgrade/to-15.0-fix-uid-gid-pf-fingerbank.sh}
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
export MIGRATION_FIXTURE="$fixture" MIGRATION_CASE="$scenario"

mkdir -p "$fixture/bin" "$fixture/pf/bin" "$fixture/pf/var" "$fixture/pf/conf" "$fixture/pf/logs"
printf '996 995 995\n' > "$fixture/pf.ids"
printf '997 998 998\n' > "$fixture/fingerbank.ids"
printf '0:995\n' > "$fixture/logs.owner"
printf '0:995\n' > "$fixture/logfile.owner"
touch "$fixture/pf/conf/pf.conf" "$fixture/pf/logs/packetfence.log" "$fixture/calls"

case "$scenario" in
    already_migrated)
        printf '2025 2025 2025\n' > "$fixture/pf.ids"
        printf '2026 2026 2026\n' > "$fixture/fingerbank.ids"
        ;;
    lingering_real_uid|lingering_effective_uid|process_exit_race)
        touch "$fixture/process"
        ;;
    success|usermod_failure|groupmod_failure|verification_failure|retry_permissions|service_failure|fixpermissions_failure|retry_fixpermissions) ;;
    *) echo "Unknown test case: $scenario" >&2; exit 2 ;;
esac

cat > "$fixture/bin/mock" <<'MOCK'
#!/bin/bash
set -euo pipefail
command=${0##*/}
{
    printf 'CALL %s' "$command"
    printf ' %s' "$@"
    printf '\n'
} >> "$MIGRATION_FIXTURE/calls"

case "$command" in
    id|getent)
        user=${!#}
        read -r uid gid group < "$MIGRATION_FIXTURE/$user.ids"
        if [ "$command" = getent ]; then
            printf '%s:x:%s:\n' "$user" "$group"
        elif [ "$1" = -u ]; then
            echo "$uid"
        else
            echo "$gid"
        fi
        ;;
    usermod|groupmod)
        if [ "$MIGRATION_CASE" = "${command}_failure" ]; then
            echo "$command: simulated account update failure" >&2
            exit 8
        fi
        if [ "$MIGRATION_CASE" != verification_failure ]; then
            user=${!#}
            read -r uid gid group < "$MIGRATION_FIXTURE/$user.ids"
            if [ "$command" = groupmod ]; then
                # groupmod also updates users whose primary GID was this group.
                if [ "$gid" = "$group" ]; then gid=$2; fi
                group=$2
            elif [ "$1" = -u ]; then uid=$2
            else gid=$2
            fi
            printf '%s %s %s\n' "$uid" "$gid" "$group" > "$MIGRATION_FIXTURE/$user.ids"
        fi
        ;;
    pgrep)
        [ -f "$MIGRATION_FIXTURE/process" ] || exit 1
        [ "$2" = 996 ] || [ "$2" = pf ] || exit 1
        case "$MIGRATION_CASE:$1" in
            lingering_real_uid:-U|lingering_effective_uid:-u|process_exit_race:-U) echo 12345 ;;
            *) exit 1 ;;
        esac
        ;;
    pkill)
        if [ "$MIGRATION_CASE" = process_exit_race ]; then
            rm -f "$MIGRATION_FIXTURE/process"
            exit 1
        fi
        ;;
    systemctl)
        case "$1" in
            is-active)
                [ "${!#}" = packetfence-config ] && [ "$MIGRATION_CASE" != service_failure ] || exit 3
                ;;
        esac
        ;;
    chown)
        [ "$MIGRATION_CASE" != retry_permissions ] || exit 1
        owner=$1
        shift
        read -r uid gid group < "$MIGRATION_FIXTURE/pf.ids"
        case "$owner" in
            root:pf) owner="0:$group" ;;
            pf:pf) owner="$uid:$group" ;;
        esac
        for path in "$@"; do
            case "$path" in
                "$MIGRATION_FIXTURE/pf/logs"|"$MIGRATION_FIXTURE/pf/logs/")
                    echo "$owner" > "$MIGRATION_FIXTURE/logs.owner"
                    ;;
                "$MIGRATION_FIXTURE/pf/logs/packetfence.log")
                    echo "$owner" > "$MIGRATION_FIXTURE/logfile.owner"
                    ;;
            esac
        done
        ;;
    pfcmd)
        if [ "$*" = 'fixpermissions strict' ]; then
            case "$MIGRATION_CASE" in
                fixpermissions_failure|retry_fixpermissions) exit 1 ;;
            esac
        fi
        ;;
    chmod|sleep|ps) ;;
    *) echo "Unexpected mock command: $command" >&2; exit 2 ;;
esac
MOCK
chmod +x "$fixture/bin/mock"
for command in id getent usermod groupmod pgrep pkill systemctl chown chmod sleep ps pfcmd; do
    ln -s mock "$fixture/bin/$command"
done
ln -s "$fixture/bin/mock" "$fixture/pf/bin/pfcmd"

# Only the installation path changes; the migration's control flow is unmodified.
sed "s|/usr/local/pf|$fixture/pf|g" "$migration" > "$fixture/migration.sh"
export PATH="$fixture/bin:$PATH" UPGRADE_CLUSTER_SECONDARY=yes
unset PACKETFENCE

run_migration() {
    if bash "$fixture/migration.sh" > "$fixture/output" 2>&1; then
        migration_status=0
    else
        migration_status=$?
    fi
    cat "$fixture/output"
}

pending() {
    if [ -f "$fixture/pf/var/uid-gid-migration.pending" ]; then echo yes; else echo no; fi
}

run_migration
if [ "$scenario" = retry_permissions ] || [ "$scenario" = retry_fixpermissions ]; then
    echo "FIRST_EXIT=$migration_status"
    echo "FIRST_PENDING=$(pending)"
    # Retry with the account state left by the first invocation.
    export MIGRATION_CASE=success
    : > "$fixture/calls"
    run_migration
fi
echo "MIGRATION_EXIT=$migration_status"
echo "PF_IDS=$(cat "$fixture/pf.ids")"
echo "FINGERBANK_IDS=$(cat "$fixture/fingerbank.ids")"
echo "LOGS_OWNER=$(cat "$fixture/logs.owner")"
echo "LOGFILE_OWNER=$(cat "$fixture/logfile.owner")"
echo "PENDING=$(pending)"
cat "$fixture/calls"
