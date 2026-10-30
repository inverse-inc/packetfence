# Opt-in complete pipeline repositories in Pulp

Default behavior is unchanged (`PF_PULP_ENABLED=no`). Enabling this path publishes
public CI repositories and first archives each signed repository tree in private
Object Storage. It does not cut over production release publishing or move Docker images. Legacy `deploy_pkg` jobs
are disabled in this mode so a staging test cannot also update the old package host.

The pipeline reads the version from `conf/pf-release`, locks an approved dependency
snapshot, publishes `gitlab/<id>/dependencies/`, builds/signs PacketFence, validates
a complete repository and publishes `gitlab/<id>/`. The original URL layout and
Debian source/SRPM outputs are retained. The generator's APT component remains
`main` and its suite is `bookworm-gitlab`.

## Setup

Use the matching infrastructure branch and follow
`packaging/docs/CI_DEPENDENCIES.md` there to provision the existing file repository
and a dedicated scoped publisher. The pinned helpers in `vendor/` come from that
repository; `SHA256SUMS` is checked before use. Refresh both files together from a
reviewed infrastructure revision and regenerate the checksums. No runtime checkout
of an unpinned helper branch is performed.

Build `containers/publish-ppa/Dockerfile`, run the test below, and publish the image
through the existing approved registry workflow. Configure these **protected** CI
variables, using GitLab file variables where indicated:

| Variable | Value |
|---|---|
| `PF_PULP_ENABLED` | `yes` only for the staging acceptance pipeline initially |
| `PF_PULP_IMAGE` | Tested publish-ppa image pinned with `@sha256:...`; needed before the check stage |
| `PF_PACKAGE_ORIGIN` | Public HTTPS origin serving `/downloads/PacketFence/gitlab/` |
| `PULP_CONTENT_ORIGIN` | HTTPS origin serving canonical `/pulp/content/` paths |
| `PULP_URL` | Management HTTPS origin allowed by the package host firewall |
| `PULP_USERNAME`, `PULP_PASSWORD` | Scoped file publisher; password masked, never admin |
| `REQUESTS_CA_BUNDLE` | Optional trusted internal CA file for API/content requests |
| `PF_PULP_REPOSITORY` | Name of the provisioned public CI file repository |
| `PF_PULP_BASES_FILE` | Protected file variable containing the operator's base policy JSON |
| `PF_PULP_BASE` | Explicit policy key for a feature branch/tag; otherwise `devel-X.Y` or `maintenance-X.Y` |
| `PF_PULP_OVERRIDES` | Optional path to reviewed candidate override JSON in the checkout |
| `PF_PULP_DEBIAN_SOURCES_FILE` | Protected file variable: approved bookworm **OS-only** apt `sources.list` |
| `PF_PULP_RPM_REPOS_DIR` | Trusted runner/image directory of approved EL8 **OS-only** `.repo` files and key references |
| `GPG_KEY_FINGERPRINT` | Exact approved metadata signing fingerprint |
| `PSONO_*` | Existing package-signing credentials/secret IDs |
| `PF_PACKAGE_ENVIRONMENT` | `staging` or `production` |
| `PF_PACKAGE_BACKUP_BUCKET` | Private versioned bucket name, supplied by the operator |
| `PF_PACKAGE_BACKUP_ENDPOINT` | HTTPS S3 origin, e.g. `https://s3.example.invalid` |
| `PF_PACKAGE_BACKUP_REGION` | S3 signing region supplied by the operator |
| `PF_PACKAGE_BACKUP_PREFIX` | Required operator-selected object prefix; no CI default |
| `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` | Protected, masked S3 credentials with read/list/upload and bucket-control inspection; deny deletion through bucket policy |

Both OS targets must be available for the normal two-build pipeline. Source
snapshots must be public `pulp_file` distributions with a pinned publication and
PULP_MANIFEST. Native-only bases need a separately prepared file snapshot; the
helper fails rather than guessing an inventory. Validate the configured snapshots
against the target release and operating systems before enabling publication.

The base policy is operator-controlled. A branch may request a named approved base
and exact candidates; it may not select arbitrary source URLs. Keep signing and
publisher secrets out of untrusted refs/forks. Both phases explicitly reject an
unprotected ref. Feature branch testing therefore requires a reviewed protected
branch or a trusted parent pipeline. A normal untrusted MR must use the existing
non-publishing CI workflow.

At check time, `prepare_pulp_dependencies` generates the lock and publishes the
fixed dependency repository. The artifact includes the pipeline and commit IDs;
builds and final publication reject a lock for another commit or release. Every
package download is size/SHA256 checked. Package identity comes from dpkg/rpm,
not from filename parsing. Base versions are selected with native version ordering;
explicit candidates replace all base versions of the same package name.

Build jobs disable the old PacketFence sources in their disposable containers,
use the dependency repository for build requirements, then install exact
build/both overrides. Existing compiler/tool packages in the build image and
external OS repositories remain inputs: pin those separately.

The final publish job uses the original signed `.changes` and RPM artifacts.
It excludes dependencies replaced by this build, generates/signs metadata,
resolves/downloads a fresh PacketFence installation with APT/DNF, then uploads.
Package scripts do not execute during that validation. The normal VM/Venom tests
remain required. Test VM provisioning and pipeline ISO generation select the
combined repository; they do not fall back to a different PacketFence release.

The current integration retains unrelated NodeSource/OS inputs. Provide approved
OS keys/mirrors in the validation image or its configuration. All package and
metadata signature checks stay enabled. If historical dependency RPMs use a
separate trusted signing key, make that key available in the validation keyring
and clients as part of the approved image/configuration; do not disable checking.

## Overrides

An override file contains a JSON array. Each entry specifies `target`
(`debian/bookworm` or `centos/8`), allowed candidate `distribution`, relative `path`,
exact `package`, `version`, `architecture`, `sha256`, and `use` (`build`, `runtime`,
`both`). RPM versions include the epoch, e.g. `0:2.0-1.el8`. The operator policy
must allow the candidate distribution. Update the actual Debian/RPM dependency
requirements too when necessary. Missing transitive dependencies fail validation.
All candidate packages remain available in the final repository, even build-only
ones; use controls the explicit build-container installation.

## Retry and storage

Both phases share `resource_group: pulp-packetfence-pipelines`. Do not introduce
another project/manual writer without an external shared lock. Pulp API writes
are not a multi-request transaction.

The file publisher never removes content. Same path/same hash is reused; same
path/different hash fails before uploading. Metadata is immutable once published,
so restarting with changed inputs/signatures requires a new pipeline ID. Preserve
the exact generated tree for an interrupted upload; inspect unpublished Pulp
versions before retrying. Automatic cleanup/retention is not enabled.

Pulp deduplicates identical stored artifacts, but this first implementation still
transfers dependency bytes through the runner. Size runner disk/network capacity
for both dependency packages and generated repository trees. Public output includes
`pipeline-lock.json` and `dependency-selection.json`; never put secrets in them.

## Local checks and rollout

```sh
python3 -m unittest discover -s ci/pulp/tests -p 'test_*.py' -v
# Build first with the usual Docker build context at the PacketFence repository root.
docker build -f containers/publish-ppa/Dockerfile -t packetfence-pulp-ci-test .
docker run --rm --network none -v "$PWD:/work:ro" -w /work \
  packetfence-pulp-ci-test bash ci/pulp/tests/check_repository.sh
```

Run infrastructure's publisher/lock tests too. Then run a protected staging
pipeline with dependencies for the target release, both package builds and VM tests. Review
lock/publication artifacts, verify all dependency overrides actually installed,
check an existing pipeline still works, and only then change production inputs.
No production credentials, registry push or live CI activation is part of this
branch preparation.

## Maintenance and development container images

`sync_pulp_branch_images` is a separate opt-in job. Set the protected
`PF_PULP_CONTAINER_SYNC_ENABLED=yes` variable on reviewed protected branches.
The job runs after earlier stages succeed and asks Pulp to fetch the current
public GHCR image layers directly:

| Branch | Pipeline sources | Selected tags |
|---|---|---|
| `maintenance/X.Y` | Web, API, schedule | `maintenance-X-Y` |
| `devel` | Push, web, API, schedule | Available `devel`, `latest`, `maintenance-99-9` aliases |

It imports only tags actually published for each approved image; it does not
invent an alias or replace a missing maintenance tag with `latest`. The source
tag is resolved when this job runs, not guaranteed to belong to this exact commit.
Unprotected refs, feature branches, release-tag and merge-request pipelines cannot
run this writer. It does not add a second Docker push or change runtime image
references. The synthetic branch `maintenance/99.9` is rejected; its published image alias
is copied only through the `devel` branch.

Use `PF_PULP_CONTAINER_USERNAME` and `PF_PULP_CONTAINER_PASSWORD` for the dedicated
sync account, plus the existing `PULP_URL`, pinned `PF_PULP_IMAGE`, and optional
`REQUESTS_CA_BUNDLE`. To advance moving maintenance/development tags, explicitly set
`PF_PULP_CONTAINER_ALLOW_TAG_UPDATE=yes`; otherwise a different existing digest
fails. Provision repositories with `--latest-only` (`retain_repo_versions=1`) before
allowing CI to update tags. Infrastructure owns pruning of superseded manifests
and orphan cleanup; the CI account receives no deletion/admin privileges. Each
tag exposes its current digest, while other branches' tags are preserved. Do not run this CI writer concurrently with that cron
job: its GitLab resource group does not acquire the host refresh lock.

The job stores `container-plan.json` and `container-publication.json`. Images
without matching tags are listed as omissions.
The catalog is a reviewed snapshot of the 54 public GHCR PacketFence packages,
including historical builders. New images/tags require operator provisioning
and account scope updates before CI can import them. Keep the catalog and
vendored helper synchronized with infrastructure.

Follow infrastructure's `packaging/docs/CONTAINER_IMAGES.md` for HTTPS registry
routes, ES256 token keys, exact-tag remotes, scoped permissions, initial import,
rollback and staging acceptance. The public registry is available at
`<packaging-host>/inverse-inc/packetfence/<image>:maintenance-X-Y` once enabled.
Apply/cherry-pick this integration onto `devel` and each intended maintenance
branch. All approved development aliases must also be present in the operator
plan used to provision remotes and the scoped synchronizer grants. Enabling CI
does not configure the host's worker egress, catalog refresh or backup schedule.

## Required package archive

Both `prepare` and `publish` archive the generated signed tree before switching
Pulp's publication. Backup failure stops publication; Pulp failure after backup
leaves a valid archive for retry. Rebuild `containers/publish-ppa/Dockerfile`
(which now includes `python3-boto3`), test it and update `PF_PULP_IMAGE` before
running this changed integration.

Packages are real `.deb`/`.rpm`/source files under
`<prefix>/packages/<filename>/<sha256>/<unique-id>/<filename>`. A small checksum
index reuses identical bytes across pipelines and alternate filenames. Changed
bytes for a known filename warn and receive a new immutable name. JSON, CSV and
HTML catalogs reference the shared objects and record signed metadata, dependency
locks, original repository paths, hashes and exact S3 versions. The bucket stays
private; download the HTML/CSV catalog through authenticated storage access.
There is no package duplication just to create a readable catalog.

GitLab keeps `package-backup-*.json` receipts with `when: always`. Pulp job
artifacts require Developer or higher access through the GitLab UI/API. Receipts
contain storage locations and object versions; preserve them securely beyond the
seven-day artifact expiry. Keep one writer per bucket/prefix;
the existing resource group coordinates these two jobs but not manual backups,
other GitLab projects or migration scripts. Concurrent writers can duplicate
objects. No object or version is deleted; random new names do not replace bucket
retention controls or a deletion-denying policy.

The infrastructure repository's `packaging/docs/READABLE_BACKUP.md` documents
migration of existing hash-based backups, named full-Pulp recovery snapshots,
and reconstruction of a CI tree with `archive_ci_packages.py --restore-catalog`.
The CI tree backup alone is not a Pulp database export. Full Pulp recovery retains
repository definitions, guards and URL mappings in its separate recovery manifest.
Sharing a pool shares its storage read scope; use separate credentials/prefixes
where production/staging/private-package isolation requires it.

These changes are prepared and locally tested. A real protected staging pipeline,
Object Storage receipt and fresh-Pulp/client acceptance are still required.

## Deployment information and secrets

Keep actual bucket names, endpoints, regions, prefixes, management URLs and secret
references in protected GitLab variables or the private infrastructure inventory.
Examples in this directory are not deployment configuration. The archive schema
names in vendored helpers are format identifiers, not storage credentials.

Mask secret variables and disable debug tracing (`CI_DEBUG_TRACE` and
`CI_DEBUG_SERVICES`) for jobs with credentials. Run signing/publishing only on
trusted, isolated runners: the existing Psono helper accepts credentials as
process arguments. Do not collect environment dumps, signing homes or credential
files as artifacts.

Set project **CI/CD visibility** to **Only project members** and restrict the
job-token allowlist. Artifact download restrictions do not replace those controls
or prevent authorized downstream jobs from receiving artifacts. See the
[GitLab artifact access documentation](https://docs.gitlab.com/ci/yaml/#artifactsaccess).
Public repository locks intentionally include public dependency URLs and package
provenance; never put private storage locations or credentials in those inputs.
