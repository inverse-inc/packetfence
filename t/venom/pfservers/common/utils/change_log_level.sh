#!/bin/bash
set -o nounset -o pipefail -o errexit

current_log_level=${CURRENT_LOG_LEVEL:-INFO}
pf_log_level=${PF_LOG_LEVEL:-DEBUG}
pf_conf_dir=/usr/local/pf/conf
CI=${CI:-}

change_log_level() {
    sed -i s/${current_log_level}/${pf_log_level}/ ${pf_conf_dir}/log.conf
    sed -i s/${current_log_level}/${pf_log_level}/ ${pf_conf_dir}/log.conf.d/*.conf    
}

# only change log level automatically when $CI is set (in $CI)
[ -n "$CI" ] && change_log_level

exit 0
