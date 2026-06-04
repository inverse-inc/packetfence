FROM debian:bookworm

# Zen appliance builder: packer qemu build against /dev/kvm, then
# qcow2 -> VMware OVA. ovftool is not redistributable, so
# ci/zen/zen-in-docker.sh bind-mounts it from the host; alternative:
# https://github.com/buildo/packer-ovftool/blob/master/Dockerfile

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates curl gnupg zip \
        qemu-system-x86 qemu-utils \
        ansible \
        rclone \
        genisoimage \
        openssh-client && \
    install -d -m 0755 /etc/apt/keyrings && \
    curl -fsSL https://apt.releases.hashicorp.com/gpg \
        | gpg --dearmor -o /etc/apt/keyrings/hashicorp.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com bookworm main" \
        > /etc/apt/sources.list.d/hashicorp.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends packer && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Dangling until zen-in-docker.sh mounts the host's ovftool dir there.
RUN ln -s /opt/vmware-ovftool/ovftool /usr/local/bin/ovftool

# Let an arbitrary host UID self-register in /etc/passwd at startup.
RUN chmod a+w /etc/passwd /etc/group

# Smoke-test the toolchain at build time so a broken image fails to push.
RUN packer version && \
    qemu-system-x86_64 --version | head -n1 && \
    qemu-img --version | head -n1 && \
    ansible --version | head -n1 && \
    rclone version | head -n1
