# Ansible Galaxy dependency cache

`ansible-galaxy-cache.sh` installs roles and collections once per SHA-256 of a
requirements file. Unchanged requirements reuse the completed installation
without calling Galaxy. Different versions in the provisioning and scenario
requirements stay in separate directories. Switching branches selects the
corresponding cache, including when switching back to an older version.

The default location is `$XDG_CACHE_HOME/packetfence/ansible-galaxy`, or
`$HOME/.cache/packetfence/ansible-galaxy`. Set `ANSIBLE_GALAXY_CACHE_DIR` to
override it. Keep it on a local filesystem outside the checkout so GitLab's
checkout cleanup cannot remove it. The Docker wrappers bind-mount separate
`vagrant-builder` and `zen-builder` subdirectories across container runs.

The Vagrant builder image also contains completed entries under
`/opt/packetfence/ansible-galaxy`. These are used directly if the writable cache
has no matching entry. `ANSIBLE_GALAXY_SEED_DIR` overrides this location.
Rebuild the image to bake changes to either requirements file; an older image
can still install changed requirements into its mounted writable cache.

Each installation holds a lock for its requirements hash. Roles and collections
are installed separately into a temporary directory, retried up to three times,
and published only after both commands succeed. Failed installs do not become
cache hits. Completed entries are immutable while jobs use them.

The helper exports an absolute `ANSIBLE_CONFIG`, `ANSIBLE_ROLES_PATH`, and both
`ANSIBLE_COLLECTIONS_PATH` and `ANSIBLE_COLLECTIONS_PATHS` (for older Ansible,
including Bookworm). Installation and execution use the same paths.

Run a command with a dependency set:

```sh
bash ci/lib/ansible-galaxy-cache.sh \
  addons/vagrant/requirements.yml addons/vagrant/ansible.cfg \
  ansible-playbook addons/vagrant/site.yml
```

Scripts can source the helper and call
`prepare_ansible_dependencies requirements.yml ansible.cfg`. Call it again when
switching requirements; it selects the appropriate environment even on a cache
hit. Packer builds should go through the Makefile/container entry points, or
use the helper around a direct `packer build` invocation.

Pin dependency versions, including Git revisions. Unpinned dependencies and
mutable Git branches stay at the first successfully installed revision until
the cache is refreshed. To refresh without affecting running jobs, choose a
new `ANSIBLE_GALAXY_CACHE_DIR` and set `ANSIBLE_GALAXY_SEED_DIR` to an empty
or nonexistent directory (also inside the container, for Docker builds).
Old cache entries can be removed when no jobs use them. Existing
checkout-local `roles`/`ansible_collections` directories from the old installer
should also be cleared once when migrating: Ansible may discover dependencies
adjacent to a playbook before checking the configured cache paths.

## Backport to maintenance/15.x

Port the shared helper and its offline tests first, then adapt the call sites
present in each branch. The current remote layouts differ:

- `maintenance/15.0` and `maintenance/15.1` retain
  `ci/packer/packer-wrapper.sh`, `pfbuild.json`, and `cpanbuild.json`.
  Prepare the selected template's requirements before `packer validate/build`.
  Remove the provisioners' Galaxy installation settings and their hard-coded
  role/collection environment overrides so they inherit the helper's paths.
  These templates include the `pfbuild-bookworm` build from the timeout log.
  Their ZEN entry point also lives under `ci/packer/zen`, rather than `ci/zen`.
- `maintenance/15.2` uses the newer Vagrant and ZEN container build layout.
- Adapt the test-wrapper changes on all three branches: select dependencies
  before provisioning, scenarios, and teardown, and retain the external cache
  during VM cleanup. No global GitLab cache or cleanup-policy change is needed.

Validate on the maintenance branch before merging forward into devel. The
offline regression suite runs with
`python3 -m unittest discover -s ci/lib/tests -v`; full Packer and VM provisioning
still need a runner with Ansible, Packer, and KVM.
