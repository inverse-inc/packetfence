#!/bin/bash
# Resolve/download a fresh install before publishing. No package scripts execute.
set -euo pipefail
root=$(readlink -f "${1:?generated tree}")
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
if [[ -d "$root/debian" ]]; then
    : "${PF_PULP_DEBIAN_SOURCES_FILE:?Approved bookworm OS-only sources.list file}"
    mkdir -p "$work/apt/lists/partial" "$work/apt/archives/partial" "$work/apt/sources.list.d" "$work/apt/trusted.gpg.d"
    touch "$work/apt/status"
    cp "$PF_PULP_DEBIAN_SOURCES_FILE" "$work/apt/sources.list"
    # No fallback PacketFence/dependency repositories are allowed in the OS list.
    if grep -Eq 'PacketFence|pulp/content' "$work/apt/sources.list"; then echo 'OS source list contains package-host repositories' >&2; exit 1; fi
    gpg --batch --yes --dearmor -o "$work/pipeline.gpg" "$root/GPG_PUBLIC_KEY"
    printf 'deb [signed-by=%s] file:%s/debian bookworm main\n' "$work/pipeline.gpg" "$root" > "$work/apt/sources.list.d/pipeline.list"
    printf 'Package: *\nPin: release a=bookworm-gitlab,n=bookworm,c=main\nPin-Priority: 1001\n' > "$work/apt/preferences"
    mkdir "$work/apt/preferences.d"
    apt=(apt-get -o "Dir::Etc::preferences=$work/apt/preferences" -o "Dir::Etc::preferencesparts=$work/apt/preferences.d" -o "Dir::Etc::sourcelist=$work/apt/sources.list" -o "Dir::Etc::sourceparts=$work/apt/sources.list.d" -o "Dir::State::status=$work/apt/status" -o "Dir::State::lists=$work/apt/lists" -o "Dir::Cache::archives=$work/apt/archives" -o APT::Sandbox::User=root)
    "${apt[@]}" update
    "${apt[@]}" --download-only --no-install-recommends -y install packetfence packetfence-test
fi
if [[ -d "$root/centos/8/x86_64" ]]; then
    : "${PF_PULP_RPM_REPOS_DIR:?Approved EL8 OS-only .repo directory}"
    mkdir -p "$work/rpm-repos"
    cp "$PF_PULP_RPM_REPOS_DIR/"*.repo "$work/rpm-repos/"
    if grep -Eq 'PacketFence|pulp/content' "$work/rpm-repos/"*.repo; then echo 'OS repos contain package-host repositories' >&2; exit 1; fi
    printf '[pulp-pipeline]\nname=Pipeline validation\nbaseurl=file://%s/centos/8/x86_64\nenabled=1\ngpgcheck=1\nrepo_gpgcheck=1\nmodule_hotfixes=1\npriority=1\ngpgkey=file://%s/GPG_PUBLIC_KEY\n' "$root" "$root" > "$work/rpm-repos/pipeline.repo"
    dnf --disableplugin=local --installroot "$work/rpm-root" --releasever 8 --setopt="reposdir=$work/rpm-repos" --setopt=module_platform_id=platform:el8 --setopt=install_weak_deps=False -y --downloadonly install packetfence packetfence-test
fi
