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

# https://stackoverflow.com/a/2705678
escape_secret () {
    local secret=$1
    printf '%s\n' "${secret}" | sed -e 's/[]\/$*.^[]/\\&/g'
}

# to simplify export of logs later
create_archive() {
    local result_dir=$1
    all_path="${result_dir}"
    if [[ -d ${pf_logs_root} ]]; then
         # add pf logs if available
	 all_path="${all_path} ${pf_logs_root}"
    fi
    if [[ -d ${var_logs_root} ]]; then
         # add system logs if available
	 all_path="${all_path} ${var_logs_root}"
    fi
    # Allow tar exit code 1 (warnings like "file changed as we read it"), fail only on 2+
    tar c -zf "${venom_result_archive}" ${all_path}
    local rc=$?
    if [[ $rc -ge 2 ]]; then
        echo "Error: tar failed with exit code $rc" >&2
        return $rc
    fi
    return 0
}

check_psono_vars() {
    if [ -n "${PSONO_CI_API_KEY_ID}" ] && [ -n "${PSONO_CI_API_SECRET_KEY_HEX}" ]; then
        echo "Psono variables detected in environment"
        return 0
    else
        echo "No Psono variables in environment (or incomplete)"
        return 1
    fi
}

remove_secrets() {
    # check if local vars file exists
    if [[ ! -f ${venom_local_vars_file} ]]; then
        echo "Local vars file not found: ${venom_local_vars_file}"
        return 0
    fi

    # get list of secret_id in local.yml file
    local secret_ids=$(grep secret_id ${venom_local_vars_file} | awk -F ':' '{print $2}' || true)

    if [[ -z "${secret_ids}" ]]; then
        echo "No secret_id found in ${venom_local_vars_file}"
        return 0
    fi

    local sanitization_failed=0

    for secret_id in ${secret_ids}; do
        # get real secret (suppress error output to avoid leaking secret fragments)
        if ! secret=$(psonoci secret get ${secret_id} password 2>/dev/null); then
            echo "ERROR: Failed to get secret ${secret_id}" >&2
            sanitization_failed=1
            continue
        fi

        if [[ -z "${secret}" ]]; then
            echo "ERROR: Empty secret for ${secret_id}" >&2
            sanitization_failed=1
            continue
        fi

        escaped_secret=$(escape_secret "$secret")

        # replace secret in all log directories that will be archived
        for log_dir in "${venom_result_dir}" "${pf_logs_root}" "${var_logs_root}"; do
            if [[ -d "${log_dir}" ]]; then
                echo "Sanitizing secrets in ${log_dir}"
                if ! find "${log_dir}" -type f -print0 2>/dev/null | xargs -0 -r sed -i "s/${escaped_secret}/REDACTED/g" 2>/dev/null; then
                    echo "ERROR: Failed to sanitize secrets in ${log_dir}" >&2
                    sanitization_failed=1
                fi
            fi
        done
    done

    if [[ $sanitization_failed -eq 1 ]]; then
        echo "ERROR: Sanitization failed - refusing to create archive to prevent secret leakage" >&2
        return 1
    fi

    return 0
}

# If Psono variables are defined in environment, we can get secrets and we will need to remove it
sanitization_required=0
if check_psono_vars; then
    sanitization_required=1
    if ! remove_secrets; then
        echo "FATAL: Sanitization failed - aborting to prevent secret leakage" >&2
        exit 1
    fi
else
    echo "No secrets to remove"
fi

if [[ -d ${venom_result_dir} ]] || [[ -f ${venom_result_dir} ]]; then
    if ! create_archive ${venom_result_dir}; then
        echo "ERROR: Failed to create archive" >&2
        exit 1
    fi
    if [[ $sanitization_required -eq 1 ]]; then
        echo "SUCCESS: Logs sanitized and archived"
    else
        echo "SUCCESS: Logs archived (no sanitization required)"
    fi
fi
