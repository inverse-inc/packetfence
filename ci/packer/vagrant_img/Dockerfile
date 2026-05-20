# WIP: packer build container for vagrant box builds
# See PLAN.md §6.5 for full design
# TODO task 001-build-container: fill in pinned versions and test

FROM debian:bookworm-slim

# packer
ARG PACKER_VERSION=1.11.0
# qemu, ansible, rclone will be added here

RUN apt-get update && apt-get install -y --no-install-recommends \
    qemu-system-x86 \
    qemu-utils \
    && rm -rf /var/lib/apt/lists/*

# TODO: install packer from releases.hashicorp.com
# TODO: install ansible
# TODO: install rclone
