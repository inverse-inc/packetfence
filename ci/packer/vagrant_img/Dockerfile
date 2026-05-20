FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# Layer 1: apt packages — rebuild only when package list changes, not when
# packer version changes.
RUN apt-get update -qq && apt-get install -y --no-install-recommends \
        ansible-core \
        ca-certificates \
        curl \
        libvirt-clients \
        make \
        python3 \
        qemu-system-x86 \
        qemu-utils \
        rclone \
        unzip \
    && rm -rf /var/lib/apt/lists/*

# Layer 2: packer binary — separate from apt so bumping PACKER_VERSION only
# invalidates this layer.
ARG PACKER_VERSION=1.11.2
RUN set -eux; \
    PACKER_ZIP="packer_${PACKER_VERSION}_linux_amd64.zip" \
    && curl -fsSL \
        "https://releases.hashicorp.com/packer/${PACKER_VERSION}/${PACKER_ZIP}" \
        -o "/tmp/${PACKER_ZIP}" \
    && curl -fsSL \
        "https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_SHA256SUMS" \
        -o /tmp/packer_SHA256SUMS \
    && grep "${PACKER_ZIP}" /tmp/packer_SHA256SUMS \
        | (cd /tmp && sha256sum -c) \
    && unzip "/tmp/${PACKER_ZIP}" packer -d /usr/local/bin \
    && chmod 0755 /usr/local/bin/packer \
    && rm -f "/tmp/${PACKER_ZIP}" /tmp/packer_SHA256SUMS \
    && packer version
