# vagrant-build

Container image used by the CI vagrant box build jobs. Ships packer, qemu-system-x86, ansible-core, rclone, make, and python3.

## KVM requirement

`/dev/kvm` must be accessible — either on the host or passed through to the container. Without KVM, QEMU falls back to software emulation (TCG) and a full Debian install takes many hours.

- **CI**: runners tagged `shell-v7` have KVM available on the host
- **Local**: pass `--device /dev/kvm` to `docker run` (requires the host kernel to support KVM and your user to be in the `kvm` group)

## Build the image locally

```bash
./containers/vagrant-build/build-local.sh   # produces vagrant-build:local-test
```

## Run a packer box build locally

The Makefile entry targets wrap the container run (`vagrant-in-docker.sh`):

```bash
make -C ci/packer/vagrant_img pfdeb12dev
# use a specific image instead of vagrant-build:local-test:
VAGRANT_BUILD_IMAGE=ghcr.io/inverse-inc/packetfence/vagrant-build:devel \
  make -e -C ci/packer/vagrant_img pfdeb12dev
```

Output box: `ci/packer/vagrant_img/results/pfdeb12dev/pfdeb12dev-libvirt.box`

To also upload to Linode Object Storage (what CI does), export `UPLOAD_BOX=yes`
plus the `RCLONE_*` credentials before calling make.

## Smoke test (no KVM needed)

```bash
docker run --rm vagrant-build:local-test packer version
docker run --rm vagrant-build:local-test qemu-system-x86_64 --version
docker run --rm vagrant-build:local-test ansible --version
docker run --rm vagrant-build:local-test rclone version
```
