# Vagrant box builds

Packer builds the prebuilt Vagrant boxes used by the CI tests, distributed via
the private Linode bucket `packetfence-vagrant-box` (see `upload-to-linode.sh`).
Each build resolves its version at consume time from the box's `metadata.json`
(single source); `t/venom/test-wrapper.sh:prefetch_private_box` pulls the box
with authenticated rclone before `vagrant up`.

| Box | Base | Bakes | Build (`make`) |
|-----|------|-------|----------------|
| `pfdeb12{dev,stable,branch}` | bookworm | PacketFence server | `pfdeb12dev` / `…_generic` |
| `pfel8{dev,stable,branch}` | generic/rhel8 | PacketFence server | `pfel8dev` / `…_generic` |
| `pfad11{dev,branch}` | bullseye | Samba4 AD | `pfad11dev` / `…_generic` |
| `pfnode11{dev,stable,branch}` | bullseye | node + wireless client layer | `pfnode11dev` / `…_generic` |

## pfnode11 — shared node + wireless box

One box backs `node01/02/03` and `wireless01` (all `debian/bullseye64`). The
goal is robustness + speed: bake the stable, Internet-dependent layer so test
runs don't refetch it.

- **Baked** (`bake.yml` runs the real `nodes_pre_prov.yml` — the *same* pre-prov
  the tests run before the nodes lose Internet): serial console, venom, and the
  PacketFence-repo packages `wpasupplicant`, `sscep`, `rsync`.
- **Not baked** (stays at `vagrant up`): `packetfence-test` (per-pipeline PPA
  `…/gitlab/$CI_PIPELINE_ID` — the package under test, reinstalled each run) and
  all role config. The per-pipeline PPA is disabled at build via `--extra-vars`,
  so the box is **pipeline-independent**. IPs are runtime, assigned by libvirt.
- **Build**: `build.pkr.hcl` block `node_box` on `source.qemu.bullseye-11`; the
  build host joins groups `["nodes","wireless"]`. CI jobs
  `build_pf_img_vagrant_node_{devel,maintenance,branch}_debian_bullseye` produce
  `pfnode11dev` / `pfnode11stable` / `pfnode11branch`. Unlike the PF/AD boxes
  they need **neither `deploy_packages` nor `publish_ppa`**.

### Bootstrap (first use)

The inventory points `node01/02/03` + `wireless01` at `pfnode11branch`. That box
must be **built + uploaded once** before tests can prefetch it, or they 403. The
build jobs are gated by `BUILD_PF_IMG_VAGRANT=yes` (or commit message
`build_pf_img_vagrant=yes`) on a `web`/`api` pipeline — so run one such pipeline
first, then normal runs consume the box.

### First-run watch points

- `bake.yml` reuses the real `nodes_pre_prov.yml` (PacketFence repo); the build
  installs the test galaxy deps from `addons/vagrant/requirements.yml`.
- Packer HCL / the build itself — only validatable in CI (needs packer + KVM).
