# vagrant-build

Container image used by the CI vagrant box build jobs. Ships packer, qemu-system-x86, ansible-core, rclone, make, and python3.

## KVM requirement

`/dev/kvm` must be accessible — either on the host or passed through to the container. Without KVM, QEMU falls back to software emulation (TCG) and a full Debian install takes many hours.

- **CI**: runners tagged `shell-v7` have KVM available on the host
- **Local**: pass `--device /dev/kvm` to `docker run` (requires the host kernel to support KVM and your user to be in the `kvm` group)

## Build the image locally

```bash
cd /path/to/packetfence
docker build -f containers/vagrant-build/Dockerfile -t vagrant-build:test .
```

## Run a packer box build locally

```bash
docker run --rm \
  --device /dev/kvm \
  -v "$(pwd):/workspace" \
  -w /workspace/ci/packer/vagrant_img \
  -e PACKER_LOG=1 \
  vagrant-build:test \
  packer build -only="dev.qemu.debian-12" \
    -var "output_dir=/workspace/ci/packer/vagrant_img/results/pfdeb12dev" \
    -var "ansible_group=dev" \
    -var "pfserver_name=pfdeb12dev" \
    -var "box_version=15.1.$(date -u +%Y%m%d%H%M%S)" \
    -var "pf_version=15.1" \
    .
```

Output box: `ci/packer/vagrant_img/results/pfdeb12dev/pfdeb12dev-libvirt.box`

## Smoke test (no KVM needed)

```bash
docker run --rm vagrant-build:test packer version
docker run --rm vagrant-build:test qemu-system-x86_64 --version
docker run --rm vagrant-build:test ansible --version
docker run --rm vagrant-build:test rclone version
```
