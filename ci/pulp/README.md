# CI publishing to the packaging Pulp

PacketFence CI publishes its packages and its container images to the
packaging Pulp behind packages.packetfence.com. Pulp serves the same `/downloads/PacketFence/`
paths, signed with the same key. Other names (inverse.ca, packetfence.org) reach it once their
DNS points at it; until then they still serve the older hosts.

## Packages

`ci/pulp/publish-packages.sh` publishes through the Pulp API (X.Y from `conf/pf-release`):

| Job | When | Destination |
|---|---|---|
| `check_pulp_release` | release tags, first | stops the pipeline unless the tag matches `conf/pf-release`, Pulp has this version's repositories (prepared by the release on the packaging side) and, for `vX.Y.0`, the new devel carries every package of X.Y (a later `vX.Y.Z` only warns); it publishes nothing |
| `publish_ppa_devel_release_branches_and_maintenance` | release tags, requested tests | `gitlab/<pipeline>/`, used by the CI tests (pruned after 3 days) |
| `deploy_maintenance_pulp` | `maintenance/X.Y`, after the tests | `debian/X.Y/`, `RHEL<N>/X.Y/x86_64/` |
| `deploy_branches_pulp` | feature branches with `DEPLOY_PKG=yes` (or `true`), after the tests | `debian/branches/X.Y/<pipeline>/`, `RHEL<N>/branches/X.Y/<pipeline>/x86_64/` |
| `deploy_maintenance_pkg_friendly_names` | `maintenance/X.Y` | `packetfence-release/-export/-upgrade/-ci-lib` in `debian/`, `RHEL<N>/` |

- The OS comes from what was built: each Debian suite goes to the X.Y repository serving it (a newer
  Debian is a suite in the same repository, same URL), each `centos/<N>` to `packetfence-X-Y-el<N>`;
  `ci/pulp/native.py` finds them by their Pulp labels. Without a native repository (a devel version not
  yet released) the Debian tree is merged into the published one and re-signed here (`GPG_KEY_FINGERPRINT`).
- A new OS: add it to `OS_SUPPORTED` (`ci/lib/common/functions.sh`) once the packaging side serves it;
  CI then builds it, and `check_pulp_release` requires its repositories on tags.
- `packetfence-export/-upgrade/-ci-lib` are `Architecture: all`: one copy serves every Debian release.
- A `*_DEST_NAME` may contain `{release}` and, for an RPM, `{n}` (the EL version).
- The `latest-<channel>-<OS>.txt` markers are not published by CI: they follow the release on the
  packaging side.
- The jobs share `resource_group: pulp-packetfence-pipelines`, so two pipelines never write
  the same repository at once.

The jobs publish as `ci-packages` (credentials from Psono) to the API on `PF_PACKAGE_ORIGIN`; Pulp is the only
place CI publishes packages.

GitHub Actions publish the two dependency packages they build, packetfence-perl and fingerbank (perl-client),
with `ci/pulp/publish-dependency.sh` (`.github/workflows/reusable_upload_packages.yml`): from `devel` and
`maintenance/X.Y` only, into the native repository of the branch's release (`conf/pf-release`), for the OS that
release supports. A version the repository already holds is left as it is; devel waits while its X.Y has no
repository. The workflow needs the repository variable `PSONO_CI_PULP_PACKAGES_ID` (the `ci-packages` entry,
readable by the Psono API key in the GitHub secrets). GitHub runs are serialized among themselves, not with the
GitLab deploys: a GitLab deploy that fails with "Distribution changed during publish" is retried.

### When packages are deployed

The deploy jobs run in the `deploy` stage: after the tests when the pipeline runs some
(`TEST=yes`) and only if they pass; without tests, as soon as the build,
signing, publish and image steps succeed. `DEPLOY_PKG` decides whether a pipeline deploys
(`yes`/`true`, `no`/`false`):

| Pipeline | Deploys | Turn it off / on |
|---|---|---|
| `maintenance/X.Y` (web, schedule) | by default | `DEPLOY_PKG=no` |
| release tag `vX.Y.Z` | never: its packages are already there from `maintenance/X.Y`; the tag runs the tests (configurator included), and ISO, ZEN and Vagrant stay manual jobs | — |
| feature branch (web, schedule) | only when asked, to `debian/branches/X.Y/<pipeline>/` and `RHEL<N>/branches/X.Y/<pipeline>/`, its images under their pipeline tag | `DEPLOY_PKG=yes`, or `deploy_pkg=yes` in the commit message |

Images of a release: the packages in `debian/X.Y` and `RHEL<N>/X.Y` are `maintenance/X.Y` builds, so a server
pulls the branch tag `maintenance-X-Y` (`conf/build_id`), not `vX.Y.Z`. Every later `maintenance/X.Y` deploy
moves that tag, after the packages that go with it; a server that pulls its images again without upgrading
its packages gets the newer ones. The `vX.Y.Z` images the tag pipeline builds are not referenced by any package.

`BUILD_ARTIFACTS_PKG=no` and `BUILD_IMG_CONTAINER=no` (or `build_img_container=no` in the commit message)
stop every deploy too, even when requested tests build the packages and images anyway.

Every deploy job has an environment of its own branch (`<name>/$CI_COMMIT_REF_SLUG`), so that the project
setting *Prevent outdated deployment jobs* (Settings > CI/CD > General pipelines, without *Allow job retries for
rollback deployments*) only compares pipelines of the same branch: an older pipeline that finishes last cannot
put its older packages and images back. `publish_ppa` only prepares (`action: prepare`): each pipeline has its
own tree. A CI/CD variable scoped to one of these environments needs a wildcard scope (`maintenance/*`).

The publish job (the pipeline's `gitlab/<pipeline>/` tree) runs on release tags and when tests are
requested, since those install from it; a deploy builds its own tree from the signed packages.

### Feature branches

`gitlab/<pipeline>/` is pruned after 3 days. A feature branch that deploys keeps that same tree in
`debian/branches/X.Y/<pipeline>/` and `RHEL<N>/branches/X.Y/<pipeline>/` (the `x86_64/` repository), with:

- `packetfence-release-branches.el<N>.noarch.rpm`, `packetfence-export-branches.el<N>.noarch.rpm`,
  `packetfence-upgrade-branches.el<N>.noarch.rpm`, `packetfence-export_branches.deb`,
  `packetfence-upgrade_branches.deb` and `packetfence-ci-lib_branches.deb`: this build's files under fixed names;
  nothing of a feature branch goes to the `debian/` and `RHEL<N>/` roots;
- `pipeline.json`: branch, slug, pipeline, commit, X.Y and date.

Its `packetfence-release` points `packetfence-branches` at that folder (`%pf_branches_pipeline`, `Makefile`; a
maintenance build has no such repository), and its
packages pull the images under their pipeline tag (`conf/build_id`, `ci/lib/common/image-tag.sh`), which
`deploy_containers` pushes to the registry too. The packaging side keeps the 2 newest pipelines of each branch,
packages and images alike. To install one by hand: `addons/vagrant/extra_vars_branches.yml` with
`-e pf_branches_pipeline=<pipeline>`.

## Container images

On `maintenance/X.Y` and feature branches, the service images (`pfdeb_br_maint`, `pfdeb_based_br_maint`,
`img_br_maint`, `rad_*_br_maint`) are pushed to GHCR only as `<slug>-p<pipeline>`
(`ci/lib/common/pipeline-image-tag.sh`). The test VMs pull that tag: provisioning writes
`/etc/packetfence-ci-image-tag` and `manage-images.sh` retags the images locally with the
package's `TAG_OR_BRANCH_NAME`. On `maintenance/X.Y` the packages keep their branch tag:
`deploy_containers` (deploy stage) then copies the manifests to the branch tags on
GitHub (`maintenance-X-Y`; `ci/lib/upload/promote-images.py`), then pushes
the same images to the registry on `PF_PACKAGE_ORIGIN` under the same tags
(`ci/pulp/container-push.sh`). It runs on the same pipelines as the package deploy, so the branch
tags and the published packages always come from one pipeline; when a pipeline does run tests, the
deploy stage keeps both behind them. A release tag `vX.Y.Z` builds its images on GHCR as
`vX.Y.Z` and keeps them there: nothing is pushed to the registry on `PF_PACKAGE_ORIGIN`. A feature branch's
packages name the pipeline tag itself: a deploying feature branch promotes nothing on GitHub and pushes that
tag to the registry. Builder images (`pfbuild-*`, `kaniko-build`, `signing-packages`, `publish-ppa`) keep
their branch tags (`BUILDER_TAG` in the Dockerfiles). The registry keeps a feature branch's pipeline tags
with its `branches/` folders (the 2 newest pipelines); GHCR keeps every pipeline tag.

The push runs on the runner with `skopeo` (in the `publish-ppa` image): for each image of
`ci/pulp/container-images.json` that carries this pipeline's tag, `skopeo copy --all
--preserve-digests` from GHCR to `<registry>/inverse-inc/packetfence/<image>:<tag>`,
so the digests match GitHub's. Pulp fetches nothing. `devel` and `maintenance/X.Y` need a protected ref
and may push only `devel`, `latest` and `maintenance-X-Y`; any other branch only its own `<slug>-p<pipeline>`;
a tag pipeline pushes nothing. If it fails, `deploy_containers` fails (the
GitHub tags are already moved).

The push runs as `ci-docker` (credentials from Psono); the password reaches `skopeo` through a private temporary
auth file. `ci-docker` may push tags and add images under `inverse-inc/` only; it cannot
delete or reconfigure an image (private infrastructure repository, `packaging/docs/CONTAINERS.md`).

## New images and making an image public

The registry only receives images listed in `ci/pulp/container-images.json` **and** public on GHCR
(the push reads GHCR anonymously).

1. **New service image.** Add its name to `ci/pulp/container-images.json` in the same change as
   its build job; `test_every_service_image_is_in_the_push_list` fails otherwise.
2. **While it is private on GHCR**, `deploy_containers` logs
   `<image>: not public on GHCR (private or not created yet), skipped` and pushes the others.
   Nothing about it reaches the registry.
3. **To publish it**, make the package public on GitHub (package settings → Change visibility →
   Public). Nothing to do on the registry side: the next `deploy_containers` (tested
   `maintenance/X.Y`) copies it, and the registry creates it **public**. Only
   tags pushed from then on are copied; to publish an existing tag right away, run that branch's
   pipeline with the tests.
4. **Making it private again** on GitHub only stops new pushes: the registry keeps serving what it
   has. An administrator of the packaging Pulp must make it private or remove it (`ci-docker`
   cannot).

An image that must stay private in the registry needs the private publishing path instead; this
pipeline does not publish private images.

## Vendored helpers

`vendor/pulp_publish.py` and `vendor/pipeline_repository.py` come from the private
infrastructure repository (`packaging/scripts/`). `vendor/SHA256SUMS` is checked before any upload: refresh
the helpers and the checksums together, from a reviewed infrastructure revision.

## Documentation

`deploy_docs_pulp_release` and `deploy_docs_pulp_maintenance` publish the built guides (`build_artifacts_doc_*`: `docs/*.html`, `docs/*.pdf`, `docs/images/`,
`docs/styles/*.min.css`) to `/downloads/PacketFence/doc/X.Y.0/`, X.Y from `conf/pf-release`, after the tests:

- a release tag `vX.Y.Z` (`build_artifacts_doc_release`);
- a `maintenance/X.Y` pipeline started from the web or the API with `BUILD_ARTIFACTS_DOC=yes` (or
  `build_artifacts_doc=yes` in the commit message), to rebuild that version's docs.

Never `devel`: a devel version has no published docs. The folder then holds exactly this build
(`ci/pulp/publish-docs.sh`, as `ci-docs`). The folder must exist: the packaging side creates it when X.Y is
released, starting with a copy of the previous docs. The unversioned guide links
(`/downloads/PacketFence/doc/<guide>.html`) point to the newest released version only, so rebuilding an older
version's docs never moves them.

## Secrets

The `ci-packages`, `ci-docker` and `ci-docs` usernames and passwords are read from Psono at run time
(`ci/pulp/psono-field.sh`, with the pipeline's `PSONO_CI_API_*`), like the signing key;
their entry IDs are the GitLab variables `PSONO_CI_PULP_PACKAGES_ID`, `PSONO_CI_PULP_DOCKER_ID` and
`PSONO_CI_PULP_DOCS_ID` (empty by default in `.gitlab-ci.yml`). They are **not protected**: feature branches
publish their PPA (tests) and, with `DEPLOY_PKG=yes`, their `branches/X.Y/<pipeline>/` folder and images, and a
protected variable is empty on an unprotected branch. The IDs are not secrets; `PSONO_CI_API_SECRET_KEY_HEX` is,
so it is masked. The infrastructure provisions the accounts from the same entries, so a
password changed in Psono applies to both after the next packaging deploy. Disable debug tracing
(`CI_DEBUG_TRACE`, `CI_DEBUG_SERVICES`) for these jobs, and never collect environment dumps,
signing homes or credential files as artifacts. Publishing artifacts require Developer
access (`artifacts:access: developer`).

Variables the Pulp jobs need (GitLab CI/CD settings, not protected):

| Variable | Used by |
|---|---|
| `PSONO_CI_API_KEY_ID`, `PSONO_CI_API_SECRET_KEY_HEX` (masked) | every Psono read |
| `PSONO_GPG_PRIVATE_KEY_SECRET_ID` | package signing and the signed PPA tree |
| `GPG_USER_ID`, `GPG_KEY_FINGERPRINT` | package signing; `GPG_KEY_FINGERPRINT` also re-signs a merged Debian tree |
| `PSONO_CI_PULP_PACKAGES_ID` | PPA, branch folders, release packages, published files |
| `PSONO_CI_PULP_DOCKER_ID` | `deploy_containers` |
| `PSONO_CI_PULP_DOCS_ID` | docs publishing |

## Local checks

```sh
python3 -m unittest discover -s ci/pulp/tests -p 'test_*.py' -v
```
