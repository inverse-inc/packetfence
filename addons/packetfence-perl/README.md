# packetfence-perl package

## How it works

Two main steps:
* download and install all CPAN dependencies listed in dependencies.csv
* create RPM or Debian package with all Perl librairies installed at first
  step
  
## Prerequisites

You need to create following file: `$HOME/.cpan/CPAN/MyConfig.pm` with
following content:

```
$CPAN::Config = {
  'applypatch' => q[],
  'auto_commit' => q[0],
  'build_cache' => q[100],
  'build_dir' => q[/root/.cpan/build],
  'build_dir_reuse' => q[0],
  'build_requires_install_policy' => q[yes],
  'bzip2' => q[],
  'cache_metadata' => q[1],
  'check_sigs' => q[0],
  'cleanup_after_install' => q[0],
  'colorize_output' => q[0],
  'commandnumber_in_prompt' => q[1],
  'connect_to_internet_ok' => q[1],
  'cpan_home' => q[/root/.cpan],
  'curl' => q[/usr/bin/curl],
  'ftp_passive' => q[1],
  'ftp_proxy' => q[],
  'getcwd' => q[cwd],
  'gpg' => q[/usr/bin/gpg],
  'gzip' => q[/usr/bin/gzip],
  'halt_on_failure' => q[0],
  'histfile' => q[/root/.cpan/histfile],
  'histsize' => q[100],
  'http_proxy' => q[],
  'inactivity_timeout' => q[0],
  'index_expire' => q[1],
  'inhibit_startup_message' => q[0],
  'keep_source_where' => q[/root/.cpan/sources],
  'load_module_verbosity' => q[none],
  'make' => q[/usr/bin/make],
  'make_arg' => q[],
  'make_install_arg' => q[],
  'make_install_make_command' => q[/usr/bin/make],
  'makepl_arg' => q[INSTALL_BASE=/usr/local/pf/lib/perl_modules],
  'mbuild_arg' => q[],
  'mbuild_install_arg' => q[],
  'mbuild_install_build_command' => q[./Build],
  'mbuildpl_arg' => q[--install_base /usr/local/pf/lib/perl_modules],
  'no_proxy' => q[],
  'pager' => q[/usr/bin/less],
  'patch' => q[],
  'perl5lib_verbosity' => q[none],
  'prefer_external_tar' => q[1],
  'prefer_installer' => q[MB],
  'prefs_dir' => q[/root/.cpan/prefs],
  'prerequisites_policy' => q[follow],
  'recommends_policy' => q[1],
  'scan_cache' => q[atstart],
  'shell' => q[/bin/bash],
  'show_unparsable_versions' => q[0],
  'show_upload_date' => q[0],
  'show_zero_versions' => q[0],
  'suggests_policy' => q[0],
  'tar' => q[/usr/bin/tar],
  'tar_verbosity' => q[none],
  'term_is_latin' => q[1],
  'term_ornaments' => q[1],
  'test_report' => q[0],
  'trust_test_report_history' => q[0],
  'unzip' => q[/usr/bin/unzip],
  'urllist' => [q[https://cpan.metacpan.org/]],
  'use_prompt_default' => q[0],
  'use_sqlite' => q[0],
  'version_timeout' => q[15],
  'wget' => q[],
  'yaml_load_code' => q[0],
  'yaml_module' => q[YAML],
};
1;
__END__

```

Warning: paths to `tar`, `gzip` and `bzip2` are different on Debian.

## Download and install all CPAN dependencies

``` shell
./install.sh dependencies.csv
```

Logs are available in `/root/install_perl` directory.

## How to build RPM package ?

1. Update `Release` in `rhel8/SPECS/cpan_perl_module.spec` and add a changelog
   entry if necessary
1. Run following commands:

``` shell
./make_tar_from_source.sh
rpmbuild -ba ./rhel8/SPECS/cpan_perl_module.spec
# On Docker, you should have to specified the QA_RPATHS
QA_RPATHS=$(( 0x0001 )) rpmbuild -ba ./rhel8/SPECS/cpan_perl_module.spec
```

## How to build Debian package ?

1. Add a changelog entry in `debian/changelog` with new package version
1. Run following commands:

``` shell
./make_tar_from_source.sh
dpkg-buildpackage --no-sign -rfakeroot
```

## How to replace a Perl module installed by packetfence-perl packages by a package ?

1. Remove Perl module from `./dependencies.csv
1. Remove Perl module from  `./debian/control`
1. Update PacketFence SPEC files (Debian and RPM) to add a dependency to this package
