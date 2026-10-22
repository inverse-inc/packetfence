#!/bin/bash
set -o nounset -o pipefail
# NOTE: Do NOT use errexit - we handle failures explicitly and refuse archive creation on sanitization failures to prevent secret leakage

# Replace all secrets that passed secret_is_valid test
# found in Venom results by REDACTED
# Create an archive

pf_logs_root=/usr/local/pf/logs
var_logs_root=/var/log
venom_root=/usr/local/pf/t/venom
venom_result_dir=${venom_root}/results
venom_result_archive=${venom_root}/results-$(hostname).tar.gz
venom_local_vars_file=${venom_root}/vars/local.yml
PSONO_CI_API_KEY_ID=${PSONO_CI_API_KEY_ID:-}
PSONO_CI_API_SECRET_KEY_HEX=${PSONO_CI_API_SECRET_KEY_HEX:-}

# Ansible runs us under `no_log: True`, so stdout vanishes. Mirror progress to
# a log file that survives a SIGTERM (10m PIPELINE_TIMEOUT_CLEANUP) — sits
# outside venom_result_dir so it isn't sanitized in place.
log_file=${venom_root}/sanitize-venom-logs.log
log()     { printf '[%(%H:%M:%S)T] %s\n' -1 "$*"     | tee -a "${log_file}"; }
log_err() { printf '[%(%H:%M:%S)T] ERROR: %s\n' -1 "$*" | tee -a "${log_file}" >&2; }

# https://stackoverflow.com/a/2705678
escape_secret () {
    local secret=$1
    printf '%s\n' "${secret}" | sed -e 's/[]\/$*.^[]/\\&/g'
}

# to simplify export of logs later
create_archive() {
    local result_dir=$1
    all_path=""
    if [[ -e ${result_dir} ]]; then
         all_path="${result_dir}"
    fi
    if [[ -d ${pf_logs_root} ]]; then
         # add pf logs if available
	 all_path="${all_path} ${pf_logs_root}"
    fi
    if [[ -d ${var_logs_root} ]]; then
         # add system logs if available
	 all_path="${all_path} ${var_logs_root}"
    fi
    if [[ -z "${all_path}" ]]; then
        log "Nothing to archive (no Venom results, no PF logs, no system logs)"
        return 0
    fi
    log "Creating archive ${venom_result_archive} from: ${all_path}"
    # Allow tar exit code 1 (warnings like "file changed as we read it"), fail only on 2+
    tar c -zf "${venom_result_archive}" ${all_path}
    local rc=$?
    if [[ $rc -ge 2 ]]; then
        log_err "tar failed with exit code $rc"
        return $rc
    fi
    log "Archive created (tar rc=$rc)"
    return 0
}

check_psono_vars() {
    if [ -n "${PSONO_CI_API_KEY_ID}" ] && [ -n "${PSONO_CI_API_SECRET_KEY_HEX}" ]; then
        log "Psono variables detected in environment"
        return 0
    else
        log "No Psono variables in environment (or incomplete)"
        return 1
    fi
}

remove_secrets() {
    # check if local vars file exists
    if [[ ! -f ${venom_local_vars_file} ]]; then
        log "Local vars file not found: ${venom_local_vars_file}"
        return 0
    else
        log "Local vars file found: ${venom_local_vars_file}"
    fi

    # get list of secret_id in local.yml file
    local secret_ids
    secret_ids=$(grep secret_id ${venom_local_vars_file} | awk -F ':' '{print $2}' || true)

    if [[ -z "${secret_ids}" ]]; then
        log "No secret_id found in ${venom_local_vars_file}"
        return 0
    else
        log "Found $(echo ${secret_ids} | wc -w) secret_id(s) to fetch"
    fi

    local sanitization_failed=0
    local sed_args=()

    # Fetch all secrets up front, then sanitize each log dir in ONE pass.
    # Per-secret fs walks over /var/log + PF logs blew the 10m cleanup timeout.
    for secret_id in ${secret_ids}; do
        log "Fetching secret ${secret_id} from Psono"
        if ! secret=$(psonoci secret get ${secret_id} password 2>/dev/null); then
            log_err "Failed to get secret ${secret_id}"
            sanitization_failed=1
            continue
        fi

        if [[ -z "${secret}" ]]; then
            log_err "Empty secret for ${secret_id}"
            sanitization_failed=1
            continue
        fi

        log "Got secret ${secret_id}"
        sed_args+=(-e "s/$(escape_secret "$secret")/REDACTED/g")
    done

    if [[ ${#sed_args[@]} -gt 0 ]]; then
        log "Built ${#sed_args[@]} sed expression(s); starting per-dir sanitize pass"
        for log_dir in "${venom_result_dir}" "${pf_logs_root}" "${var_logs_root}"; do
            if [[ -d "${log_dir}" ]]; then
                log "Sanitizing ${log_dir} (single pass over all secrets)"
                if ! find "${log_dir}" -type f -print0 2>/dev/null \
                    | xargs -0 -r sed -i "${sed_args[@]}" 2>/dev/null; then
                    log_err "Failed to sanitize secrets in ${log_dir}"
                    sanitization_failed=1
                else
                    log "Sanitized ${log_dir}"
                fi
            else
                log "Skipping ${log_dir} (does not exist)"
            fi
        done
    else
        log "No usable secrets — nothing to sanitize"
    fi

    if [[ $sanitization_failed -eq 1 ]]; then
        log_err "Sanitization failed - refusing to create archive to prevent secret leakage"
        return 1
    fi

    return 0
}

log "=== sanitize-venom-logs start (host=$(hostname)) ==="

# If Psono variables are defined in environment, we can get secrets and we will need to remove it
sanitization_required=0
if check_psono_vars; then
    sanitization_required=1
    if ! remove_secrets; then
        log_err "FATAL: Sanitization failed - aborting to prevent secret leakage"
        exit 1
    fi
else
    log "No secrets to remove"
fi

# Archive whatever exists: a run that failed before Venom started has no
# results dir, and its PF and system logs are then the only diagnostics.
if [[ ! -e ${venom_result_dir} ]]; then
    log "No venom result dir at ${venom_result_dir}, archiving system logs only"
fi

if ! create_archive ${venom_result_dir}; then
    log_err "Failed to create archive"
    exit 1
fi

if [[ $sanitization_required -eq 1 ]]; then
    log "SUCCESS: Logs sanitized and archived"
else
    log "SUCCESS: Logs archived (no sanitization required)"
fi

log "=== sanitize-venom-logs done ==="
