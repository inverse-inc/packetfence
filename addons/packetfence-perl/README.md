# packetfence-perl package

## How it works

Two main steps:
* download and install all CPAN dependencies listed in dependencies.csv (using `install_cpan.sh`)
* create RPM or Debian package with all Perl librairies installed at first
  step (manual step, see below)

## Download and install all CPAN dependencies

``` shell
./install_cpan.sh dependencies.csv &> $HOME/install_cpan.log
```

Logs for installation of each module are available in `/root/install_perl`
directory.

Script will stop at first error, you can look at `$HOME/install_cpan.log` to
have more details.

### Upgrades and downgrades behavior

Installation of modules listed in `dependencies.csv` could install *latest*
version of other modules. If these other modules are also listed in
`dependencies.csv` but with an older version, CPAN will need to downgrade
modules.

Depending of the order of dependencies in `dependencies.csv` and values in
`META.yml` of modules, you can get modules with a version that don't match
what you have in `dependencies.csv`. `install_cpan.sh` will warn you if this
is the case. The best option will be to look at `META.yml` of modules and
certainly update `dependencies.csv` with new version.

## How to build RPM package ?

1. Update `Release` or `Version` in `rhel8/SPECS/packetfence-perl.spec` and add a changelog
   entry if necessary
1. Run following commands:

``` shell
./make_tar_from_source.sh
rpmbuild -bb ./rhel8/SPECS/packetfence-perl.spec --clean --rmsource --define "_sourcedir ${PWD}/rhel8/SOURCES"
```

If you build inside a Docker container, you need to define `QA_RPATHS=$((
0x0001 ))` inside environment used by `rpmbuild` to avoid error related to RPATHS

## How to build Debian package ?

1. Add a changelog entry in `debian/changelog` with new package version
1. Run following commands:

``` shell
./make_tar_from_source.sh
dpkg-buildpackage --no-sign -rfakeroot
```

## How to replace a Perl module installed by packetfence-perl package by a package ?

1. Remove Perl module from `./dependencies.csv`
1. Remove Perl module from  `./debian/control`
1. Update PacketFence SPEC files (Debian and RPM) to add a dependency to this package

## How to add a new dependency

Before adding a new dependency, you need to verify:
  * if this dependency is not part of a Perl distribution already present in
    `dependencies.csv` (for example: `Log::Log4perl::Catalyst` is part of
    `Log::Log4perl` distribution and already mentioned in `dependencies.csv`)
  * name and version of dependency (first and second columns in `dependencies.csv`) match name
    returned by `get_modules_installed.pl`


1. Add new dependency in `./dependencies.csv` based on CPAN informations
1. Remove dependency from our repositories (Debian and RPM)
