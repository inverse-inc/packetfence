# Third-party Debian packages

Recipes for packages that PacketFence ships in its apt repo but Debian doesn't
provide (or provides in an unusable version). See
`docs/pf-repo-third-party-packages.md` for the inventory and which packages
still need a recipe.

Every recipe is built the same way by `build.sh`, locally or in CI.

## Layout

```
addons/third-party/
  build.sh          generic builder: ./build.sh <pkg>
  Makefile          list / build / docker-build / clean
  <pkg>/            named after the source package
    recipe.conf     where to get the upstream sources
    debian/         packaging (control, rules, changelog, copyright, source/format);
                    leave it out to use the debian/ shipped in the sources
```

`recipe.conf` is sourced by `build.sh` and sets either a tarball:

```sh
UPSTREAM_VERSION=0.9.0
SOURCE_URL=https://example.org/foo-${UPSTREAM_VERSION}.tar.gz
SOURCE_SHA256=<sha256 of the tarball>  # .tar.gz, .tar.xz or .tar.bz2
```

or a git ref (for forks):

```sh
UPSTREAM_VERSION=1.2.3
SOURCE_GIT=https://example.org/foo.git
SOURCE_REF=<tag or commit>
```

`recipe.conf` can also set:

```sh
# recipes to build and install before this one, for build dependencies that
# only exist as recipes (their packages don't go to result/)
RECIPE_BUILD_DEPS="libparse-eyapp-perl"

# run in the source tree before the build dependencies are installed
prepare_source() {
    make -f debian/rules debian/control
}
```

`debian/changelog` sets the exact package version: no CI suffix is added, so
versions pinned elsewhere (containers, `debian/control`) stay stable. Its
upstream part must match `UPSTREAM_VERSION`. When rebuilding a package that
was already published for an older Debian, bump the Debian revision so the new
build wins on upgrade.

## How a build works

`build.sh <pkg>` runs these steps, in order; each prints a `log_section`
header, so a failing build shows which step broke:

1. **Install build tools** (`mk-build-deps`, `dpkg-buildpackage`, lintian,
   curl, git) if the image lacks them.
2. **Fetch sources** into `build/third-party/<pkg>/` (wiped first): download
   `SOURCE_URL` and check `SOURCE_SHA256`, or `git archive` `SOURCE_REF` from
   `SOURCE_GIT`. Either way it becomes `<pkg>_<UPSTREAM_VERSION>.orig.tar.*`.
3. **Prepare source tree**: unpack into `<pkg>-<UPSTREAM_VERSION>/`, then
   replace its `debian/` with the recipe's, if the recipe has one.
4. **Check name and version**: the source name in `debian/changelog` must be
   the recipe directory name, and its upstream version must equal
   `UPSTREAM_VERSION`.
5. **`apt-get update`**: pfbuild images ship without apt lists.
6. **Recipe dependencies**: each recipe in `RECIPE_BUILD_DEPS` is built by
   calling `build.sh` recursively (results in `build/third-party/<pkg>/deps/`)
   and its debs are installed.
7. **`prepare_source()`**, if `recipe.conf` defines it, runs in the source tree.
8. **Install build dependencies** from `debian/control` with `mk-build-deps`.
9. **Build** with `dpkg-buildpackage -us -uc -sa` (unsigned; CI signs later).
10. **Lintian**: informational only, it never fails the build.
11. **Copy results**: only the files listed in the `.changes`, plus the
    `.changes` itself, go to `result/<os id>/<codename>/`.

Two constraints shape this:

- CI builds one recipe per pipeline, and `deploy-artifacts.sh deb` uploads
  only the last `.changes` in `result/`. That's why `RECIPE_BUILD_DEPS`
  packages stay out of `result/`: they'd otherwise be uploaded in place of the
  recipe (or not at all). Publish a dependency by running its own pipeline.
- Copying from the `.changes` (instead of globbing) keeps stray files, such
  as the fetched tarball of a native package, out of the upload.

## Add a recipe

1. `mkdir addons/third-party/<pkg>`, named after the **source** package.
2. Write `recipe.conf`. Get the checksum with
   `curl -fsSL <url> | sha256sum`. Pin git sources to a commit, not a branch.
3. Provide packaging. Pick the closest existing recipe and copy it:

   | Case | Example |
   |---|---|
   | Our own `debian/` around an upstream tarball | `sscep`, `libparse-eyapp-perl` |
   | Upstream/Debian sources already ship `debian/` (no recipe `debian/`) | `snmp-mibs-downloader`, `freeradius` |
   | Upstream ships `debian/` that needs a generation step | `freeradius` (`prepare_source()`) |
   | Upstream sources plus our patches (`3.0 (quilt)`, `debian/patches/`) | `libnet-nessus-xmlrpc-perl` |
   | Built from a fork at a commit | `libcisco-accesslist-parser-perl` |
   | Build-depends on another recipe | `libcisco-accesslist-parser-perl` (`RECIPE_BUILD_DEPS`) |
   | Build that needs custom steps | `libapache2-mod-systemd` (`debian/rules` overrides) |

   Pick a version that sorts above whatever Debian ships when we patch the
   package (e.g. `0.30+pf1-1` > `0.30-3`); check with
   `dpkg --compare-versions <ours> gt <debian>`. A `3.0 (native)` source
   can't have a Debian revision: use `3.0 (quilt)` if you need one.
4. Build it: `make -C addons/third-party docker-build PKG=<pkg>`
5. Test the result in a clean container, not the build image (which has the
   build dependencies installed):

   ```sh
   docker run --rm -v $PWD/result/debian/trixie:/debs debian:trixie bash -c \
       'apt-get update && apt-get install -y /debs/<pkg>_*.deb && <smoke test>'
   ```

6. Add or update the package's row in `docs/pf-repo-third-party-packages.md`
   and its "Recipes so far" line.
7. If something pins the version (`debian/control`, a container's
   Dockerfile), update the pin.
8. Delete `result/` before committing; it isn't tracked.

## Changing build.sh

Every recipe goes through `build.sh`, so a change must keep the existing
recipes building unchanged:

- New `recipe.conf` variable: give it an empty default before
  `source ${RECIPE_DIR}/recipe.conf` (next to `RECIPE_BUILD_DEPS=`), so
  recipes that don't set it still pass `set -o nounset`.
- New hook: make it optional, like `prepare_source()`
  (`if declare -F <hook> >/dev/null; then <hook>; fi`), and call it from the
  step where it's needed.
- Don't put more than one package's `.changes` in `result/` (see above).
- Document the option in this README (the `recipe.conf` section and
  "How a build works") and in the header comment of `build.sh`.
- Test: rebuild `sscep` (the plain case) and every recipe that uses the
  feature you touched, then check `result/debian/trixie/` holds only the
  files listed in each `.changes`.

## Build locally

```sh
make -C addons/third-party list
make -C addons/third-party docker-build PKG=sscep  # any host with docker
make -C addons/third-party build PKG=sscep         # on a Debian trixie host or container
```

Build dependencies are installed with `mk-build-deps`, so `build` needs root.
The sources are unpacked and built in `build/third-party/<pkg>/`. The files
listed in the `.changes` are copied to `result/debian/trixie/`.

## Build and publish from CI

These jobs are in every pipeline (except scheduled ones) and only run when
started:

1. `build_third_party_pkg` (manual): run it from the pipeline page with the
   variable `THIRD_PARTY_PKG=<pkg>`.
2. `sign_third_party_pkg`: signs the `.deb` files with the repo key
   (`ci/lib/sign/sign-packages.sh`, with `SIGN_RPM=no`). It runs after the
   build.
3. `deploy_third_party_pkg` (manual): uploads to the repo of the current
   context with `ci/lib/upload/deploy-artifacts.sh deb`. Tags, `devel` and
   `maintenance/X.Y` deploy to `debian/<PF minor release>`, any other branch
   to `debian-branches/<PF minor release>`.
