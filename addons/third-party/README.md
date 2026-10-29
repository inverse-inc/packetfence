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
SOURCE_SHA256=<sha256 of the tarball>
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

## Add a recipe

1. `mkdir addons/third-party/<pkg>`
2. Write `recipe.conf`. Get the checksum with
   `curl -fsSL <url> | sha256sum`.
3. Write `debian/`. If Debian or upstream already has packaging, start
   from it.
4. Build it: `make -C addons/third-party docker-build PKG=<pkg>`

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
