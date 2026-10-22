FROM centos:8

ENV PATH=/usr/local/go/bin:$PATH

ARG GOVERSION
ARG PF_MINOR_RELEASE

# CentOS 8 is EOL — switch base repos to a snapshot mirror before any dnf call.
RUN sed -i 's/mirrorlist/#mirrorlist/g; s|#baseurl=http://mirror.centos.org|baseurl=http://mirror.nsc.liu.se/centos-store|g' \
        /etc/yum.repos.d/CentOS-Linux-*.repo

# python3-requests (baseos) pairs with python3-pynacl (EPEL, installed below):
# addons/packetfence-perl/psono.py needs both to fetch build secrets.
RUN dnf install -y python3 python3-requests dnf-plugins-core rpm-build make git && \
    alternatives --set python /usr/bin/python3

RUN dnf -y module install ruby:3.0

# Inverse + NodeSource RPM keys and repos (replaces inverse_inc.gitlab_buildpkg_tools role).
RUN rpm --import https://inverse.ca/downloads/GPG_PUBLIC_KEY && \
    rpm --import https://rpm.nodesource.com/gpgkey/ns-operations-public.key && \
    printf '%s\n' \
        '[packetfence]' \
        'name=packetfence' \
        'baseurl=http://inverse.ca/downloads/PacketFence/RHEL$releasever/'"${PF_MINOR_RELEASE}"'/$basearch' \
        'enabled=1' \
        'gpgcheck=1' \
        'module_hotfixes=1' \
        > /etc/yum.repos.d/packetfence.repo && \
    printf '%s\n' \
        '[nodejs]' \
        'name=nodejs' \
        'baseurl=https://rpm.nodesource.com/pub_20.x/nodistro/nodejs/$basearch' \
        'enabled=1' \
        'gpgcheck=1' \
        'module_hotfixes=1' \
        > /etc/yum.repos.d/nodejs.repo && \
    dnf install -y epel-release && \
    dnf install -y python3-pynacl && \
    dnf upgrade -y

# NodeSource workaround for https://github.com/nodesource/distributions/issues/845
RUN cd /tmp && \
    dnf download nodejs --disablerepo=appstream && \
    rpm -ivh --nodeps nodejs*.rpm && \
    rm -f /tmp/nodejs*.rpm

COPY rpm/ /tmp/rpm
RUN dnf builddep -y /tmp/rpm/packetfence.spec

# PACKER_BUILD_NAME triggers the script's short-circuit that skips `go mod download`.
COPY addons/dev-helpers/setup-go-env.sh /tmp/setup-go-env.sh
RUN GOVERSION=${GOVERSION} PACKER_BUILD_NAME=inDockerBuild /tmp/setup-go-env.sh

RUN gem install asciidoctor asciidoctor-pdf rouge

RUN rm -rf /tmp/rpm /tmp/setup-go-env.sh && \
    dnf clean all && \
    rm -rf /var/cache/dnf/*
