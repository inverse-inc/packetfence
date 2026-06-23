FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# Layer 1: apt packages — rebuild only when package list changes, not when
# packer version changes.
RUN apt-get update -qq && apt-get install -y --no-install-recommends \
        ansible-core \
        apt-cacher-ng \
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

# Layer 3: pre-install packer plugins so builds work without outbound access at runtime
COPY ci/packer/vagrant_img/plugins.pkr.hcl /tmp/packer-init/
RUN packer init /tmp/packer-init && rm -rf /tmp/packer-init

# Layer 4: bake Ansible Galaxy collections so builds skip the download step
COPY ci/packer/vagrant_img/provisioners/requirements.yml /tmp/galaxy-requirements.yml
RUN ansible-galaxy role install -r /tmp/galaxy-requirements.yml \
    && ansible-galaxy collection install -r /tmp/galaxy-requirements.yml \
    && rm /tmp/galaxy-requirements.yml

# Entrypoint starts apt-cacher-ng before handing off to packer.
# Mount /var/cache/apt-cacher-ng as a Docker volume to persist cache across CI jobs.
COPY ci/packer/vagrant_img/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
