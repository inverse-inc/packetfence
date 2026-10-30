#!/bin/bash
# Run inside the existing package build container, before make build_deb/build_rpm.
set -euo pipefail
[[ ${PF_PULP_ENABLED:-no} == yes ]] || exit 0
: "${PF_PULP_DEPENDENCY_URL:?Missing prepare_pulp_dependencies artifact}"
python3 ci/pulp/check-lock.py pipeline-lock.json
[[ "$PF_PULP_DEPENDENCY_URL" =~ ^https://[a-zA-Z0-9./:_-]+/dependencies$ ]] || exit 2
kind=${1:?deb or rpm}
case "$kind" in
    deb)
        [[ $(. /etc/os-release; echo "$VERSION_CODENAME") == bookworm ]] || exit 2
        curl --fail --silent --show-error "$PF_PULP_DEPENDENCY_URL/GPG_PUBLIC_KEY" -o /tmp/pulp-ci-key.asc
        : "${GPG_KEY_FINGERPRINT:?}"
        fingerprint=$(gpg --show-keys --with-colons /tmp/pulp-ci-key.asc | awk -F: '$1=="fpr" {print $10;exit}')
        [[ "$fingerprint" == "$GPG_KEY_FINGERPRINT" ]] || { echo 'Unexpected repository signing key' >&2; exit 1; }
        gpg --batch --yes --dearmor -o /usr/share/keyrings/pulp-ci.gpg /tmp/pulp-ci-key.asc
        # Disable the old PF source in this disposable build container. OS sources stay enabled.
        python3 ci/pulp/configure-sources.py deb
        printf 'deb [signed-by=/usr/share/keyrings/pulp-ci.gpg] %s/debian bookworm main\n' "$PF_PULP_DEPENDENCY_URL" > /etc/apt/sources.list.d/pulp-ci.list
        printf 'Types: deb-src\nURIs: %s/debian\nSuites: bookworm\nComponents: main\nSigned-By: /usr/share/keyrings/pulp-ci.gpg\n' "$PF_PULP_DEPENDENCY_URL" > /etc/apt/sources.list.d/pulp-ci.sources
        printf 'Package: *\nPin: release a=bookworm-gitlab,n=bookworm,c=main\nPin-Priority: 1001\n' > /etc/apt/preferences.d/pulp-ci
        apt-get update
        apt-get build-dep -y .
        ;;
    rpm)
        : "${GPG_KEY_FINGERPRINT:?}"
        curl --fail --silent --show-error "$PF_PULP_DEPENDENCY_URL/GPG_PUBLIC_KEY" -o /tmp/pulp-ci-key.asc
        fingerprint=$(gpg --show-keys --with-colons /tmp/pulp-ci-key.asc | awk -F: '$1=="fpr" {print $10;exit}')
        [[ "$fingerprint" == "$GPG_KEY_FINGERPRINT" ]] || exit 1
        rpm --import /tmp/pulp-ci-key.asc
        python3 ci/pulp/configure-sources.py rpm
        printf '[pulp-ci]\nname=Pulp pipeline dependencies\nbaseurl=%s/centos/8/x86_64\nenabled=1\ngpgcheck=1\nrepo_gpgcheck=1\nmodule_hotfixes=1\npriority=1\ngpgkey=%s/GPG_PUBLIC_KEY\n' "$PF_PULP_DEPENDENCY_URL" "$PF_PULP_DEPENDENCY_URL" > /etc/yum.repos.d/pulp-ci.repo
        dnf builddep -y rpm/packetfence.spec
        ;;
    *) exit 2 ;;
esac
# Explicit build overrides must be selected even if an installed image package
# already satisfies Build-Depends/BuildRequires. Never interpolate shell commands.
python3 ci/pulp/install-overrides.py "$kind"
