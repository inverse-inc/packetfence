#!/bin/bash
set -o nounset -o pipefail -o errexit

# Replace all secrets that passed secret_is_valid test
# found in Venom results by REDACTED
# Create an archive

venom_root=/usr/local/pf/t/venom
venom_result_dir=${venom_root}/results
venom_result_archive=${venom_root}/results.tar.gz
venom_local_vars_file=${venom_root}/vars/local.yml

# https://unix.stackexchange.com/a/680002
# In the POSIX aka C locale, the POSIX [:punct:] character class contains the characters in the following set:
# !"#$%&'()*+,-./:;<=>?@[\]^_`{|}~
secret_is_valid () {
    # used a sed delimiter, should be avoid
    local avoid='[~]'
    [[ $1 =~ [[:upper:]] ]] &&
    [[ $1 =~ [[:lower:]] ]] &&
    [[ $1 =~ [[:digit:]] ]] &&
    [[ $1 =~ [[:punct:]] ]] &&
    [[ ! $1 =~ $avoid ]]
}

# to simplify export of logs later
create_archive() {
    local result_dir=$1
    tar c -zf ${venom_result_archive} $result_dir
}

# get list of secret_id in local.yml file
for secret_id in $(grep secret_id ${venom_local_vars_file} | awk -F ':' '{print $2}'); do
    # get real secret
    secret=$(psonoci secret get ${secret_id} password)
    secret_is_valid $secret

    # replace secret in results **files**
    # we used ~ as sed delimiter, this character is not allowed in secrets
    find ${venom_result_dir} -type f -print0 | xargs -0 sed --silent -i " s~${secret}~REDACTED~g" {} \;
done

create_archive ${venom_result_dir}
