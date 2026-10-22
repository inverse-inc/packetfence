# Simplified publish-ppa container without external dependencies
FROM debian:bookworm

ENV DEBIAN_FRONTEND=noninteractive

# Runtime deps:
#   deploy-artifacts.sh: rsync, openssh-client
#   psono.py (GPG key fetch): python3, python3-nacl, python3-requests
#   generate-pages.sh APT repo build: reprepro
#   generate-pages.sh YUM repo build: createrepo-c
#   generate-pages.sh: tree (optional, for directory visualization)
#   publish_ppa job: gnupg (for GPG key import / repo signing)
RUN apt-get update -qq \
    && apt-get install -yq --no-install-recommends \
        tree \
        rsync \
        openssh-client \
        gnupg \
        reprepro \
        createrepo-c \
        python3 python3-nacl python3-requests \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy our internal scripts
COPY ci/configs/ssh_config /etc/ssh/ssh_deploy_config
COPY ci/scripts/generate-pages.sh /usr/local/bin/generate-pages

LABEL maintainer="Inverse Inc <info@inverse.ca>"
LABEL description="PacketFence publish_ppa container: reprepro + createrepo-c repo builder (self-contained, no gitlab-buildpkg-tools)"
LABEL org.opencontainers.image.source="https://gitlab.com/inverse-inc/packetfence"
LABEL org.opencontainers.image.licenses="GPL-3.0 AND GPL-2.0-or-later"
