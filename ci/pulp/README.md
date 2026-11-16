# CI publishing to the packaging Pulp

PacketFence CI publishes its packages and its `devel`/`maintenance` container images to the
packaging Pulp behind packages.packetfence.com. Pulp serves the same `/downloads/PacketFence/`
paths, signed with the same key. Other names (inverse.ca, packetfence.org) reach it once their
DNS points at it; until then they still serve the older hosts.

## Packages (default, `PF_PULP_PUBLISH=yes`)

`ci/pulp/publish-packages.sh` publishes through the Pulp API (X.Y from `conf/pf-release`):

| Job | When | Destination |
|---|---|---|
| `publish_ppa` | pipelines that build packages | `gitlab/<pipeline>/`, used by the CI tests |
| `deploy_debian_pulp` | `devel`, `maintenance/X.Y`, after the tests | `debian/X.Y/` and `RHEL8/X.Y/x86_64/` |
| `deploy_branches_pulp` | feature branches with `publish_ppa=yes`, after the tests | `debian/branches/X.Y/` and `RHEL8/branches/X.Y/x86_64/` |

- When Pulp has the native repository (`packetfence-X-Y-bookworm`, `packetfence-X-Y-el8`), it
  receives the binary packages and Pulp signs its index. Otherwise the Debian tree is merged
  with the published one (newest build of each package wins) and re-signed here
  (`GPG_KEY_FINGERPRINT`); EL8 is left unchanged.
- Tags keep the existing `deploy_pkg` release path.
- The jobs share `resource_group: pulp-packetfence-pipelines`, so two pipelines never write
  the same repository at once.

The jobs publish as `ci-packages` to the API on `PF_PACKAGE_ORIGIN`. `PF_PULP_PUBLISH=no`
falls back to the rsync upload to web.inverse.ca.

## Container images (`devel` and `maintenance/X.Y`)

On `devel` and `maintenance/X.Y`, the service images (`pfdebian`, `radiusd` and their
`*_related` matrices) are pushed to GHCR only as `<slug>-p<pipeline>`
(`ci/lib/common/pipeline-image-tag.sh`). The test VMs pull that tag: provisioning writes
`/etc/packetfence-ci-image-tag` and `manage-images.sh` retags the images locally with the
package's `TAG_OR_BRANCH_NAME`, so the packages themselves keep their branch tag. After the
tests pass, `deploy_containers` (deploy stage) copies the manifests to the branch tags on
GitHub (`devel,latest` or `maintenance-X-Y`; `ci/lib/upload/promote-images.py`), then pushes
the same images to packages.packetfence.com under the same tags (`ci/pulp/container-push.sh`).
It runs only in pipelines that run tests, so a pipeline without tests leaves the branch tags
unchanged. Builder images (`pfbuild-*`, `kaniko-build`, `signing-packages`, `publish-ppa`) keep
their branch tags (`BUILDER_TAG` in the Dockerfiles). Pipeline tags are not deleted automatically.

The push runs on the runner with `skopeo` (in the `publish-ppa` image): for each image of
`ci/pulp/container-images.json` that carries this pipeline's tag, `skopeo copy --all
--preserve-digests` from GHCR to `packages.packetfence.com/inverse-inc/packetfence/<image>:<tag>`,
so the digests match GitHub's. Pulp fetches nothing. It needs a protected ref and refuses any
tag but `devel`, `latest` and `maintenance-X-Y`; if it fails, `deploy_containers` fails (the
GitHub tags are already moved).

The push runs as `ci-docker`; its password reaches `skopeo` through a private temporary
auth file. `ci-docker` may push tags and add images under `inverse-inc/` only; it cannot
delete or reconfigure an image (private infrastructure repository, `packaging/docs/CONTAINERS.md`).

## Vendored helpers

`vendor/pulp_publish.py` and `vendor/pipeline_repository.py` come from the private
infrastructure repository (`packaging/scripts/`). `vendor/SHA256SUMS` is checked before any upload: refresh
the helpers and the checksums together, from a reviewed infrastructure revision.

## Secrets

The `ci-packages` and `ci-docker` passwords are read from Psono at run time
(`ci/pulp/psono-password.sh`, with the pipeline's `PSONO_API_KEY_*`), like the signing key;
their entry IDs are the protected GitLab variables `PF_PULP_PACKAGES_PSONO_ID` and
`PF_PULP_DOCKER_PSONO_ID` (empty by default in `.gitlab-ci.yml`). The infrastructure provisions the accounts from the same entries, so a
password changed in Psono applies to both after the next packaging deploy. Disable debug tracing
(`CI_DEBUG_TRACE`, `CI_DEBUG_SERVICES`) for these jobs, and never collect environment dumps,
signing homes or credential files as artifacts. Publishing artifacts require Developer
access (`artifacts:access: developer`).

## Local checks

```sh
python3 -m unittest discover -s ci/pulp/tests -p 'test_*.py' -v
```
