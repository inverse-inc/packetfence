#!/bin/bash
set -o nounset -o pipefail -o errexit

# Replace all secrets that passed secret_is_valid test
# found in Venom results by REDACTED
# Create an archive

venom_root=/usr/local/pf/t/venom
venom_result_dir=${venom_root}/results
venom_result_archive=${venom_root}/results-$(hostname).tar.gz
venom_local_vars_file=${venom_root}/vars/local.yml
PSONO_CI_API_KEY_ID=${PSONO_CI_API_KEY_ID:-}

# https://stackoverflow.com/a/2705678
escape_secret () {
    local secret=$1
    printf '%s\n' "$secret" | sed -e 's/[]\/$*.^[]/\\&/g'
}

# to simplify export of logs later
create_archive() {
    local result_dir=$1
    tar c -zf ${venom_result_archive} $result_dir
}

check_psono_vars() {
    if [ -n "${PSONO_CI_API_KEY_ID}" ]; then
        echo "Psono variables detected in environment"
    else
        echo "No Psono variables in environment"
    fi
}

remove_secrets() {
    # get list of secret_id in local.yml file
    for secret_id in $(grep secret_id ${venom_local_vars_file} | awk -F ':' '{print $2}'); do
        # get real secret
        secret=$(psonoci secret get ${secret_id} password)
        escaped_secret=$(escape_secret $secret)
        # replace secret in results **files**
        find ${venom_result_dir} -type f -print0 | xargs -0 sed -i "s/${escaped_secret}/REDACTED/g"
    done
}

# If Psono variables are defined in environment, we can get secrets and we will need to remove it
if check_psono_vars; then
    remove_secrets
else
    echo "No secrets to remove"
fi
if [[ -d ${venom_result_dir} ]] || [[ -f ${venom_result_dir} ]]; then
    create_archive ${venom_result_dir}
fi
