#!/usr/bin/perl

=head1 NAME

change_system_init_key -

=head1 DESCRIPTION

change_system_init_key

=head1 SYNOPSIS

change_system_init_key --new-key=<NEW_KEY> --old-key=<OLD_KEY>  [FILES]

    --new-key   The new key. Required
    --old-key   The old key. Default the contents of /usr/local/pf/conf/system_init_key or environmental variable PF_SYSTEM_INIT_KEY.
    --dry-run   Don't change just show what may happen.
    --help      Show help

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);
use lib qw(/usr/local/pf/lib_perl/lib/perl5);
use pf::IniFiles;
use pf::config::crypt;
use pf::file_paths;
use File::Copy;
use pf::ConfigStore::All;
use Pod::Usage;
use Getopt::Long;
use pf::file_paths qw($system_init_key_file);

my $new_key;
my $old_key = $pf::config::crypt::SYSTEM_INIT_KEY;
my $help;
my $no_update;
my $dry_run;
GetOptions (
    "new-key=s"   => \$new_key,
    "old-key=s"   => \$old_key,
    "dry-run!"   => \$dry_run,
    "help|h" => \$help,
) or pod2usage();

if($help){
  pod2usage( -verbose => 1 );
}

if (!$old_key) {
    $old_key = $pf::config::crypt::SYSTEM_INIT_KEY;
}

sub change_key {
    my ($old_key, $new_key, $file) = @_;
    my $ini = pf::IniFiles->new(-file => $file, -allowempty => 1);
    my $changed = 0;
    foreach my $section ( $ini->Sections() ) {
        for my $param ($ini->Parameters($section)) {
            my $val = $ini->val($section, $param);
            next if (rindex($val, $pf::config::crypt::PREFIX));
            my $data = pf::config::crypt::pf_decrypt_with_key($old_key, $val);
            die "failed to decrypt $section.$param = $val\n" if !defined $data;
            if ($dry_run) {
                print "Would update $section.$param = $val\n";
                next;
            }

            my $new_val = pf::config::crypt::pf_encrypt_with_key($new_key, $data);
            print "$section.$param = $val => $new_val\n";
            $ini->setval($section, $param, $new_val);
            $changed |= 1;
        }
    }

    if ($changed) {
        copy($file, "${file}.bak");
        $ini->RewriteConfig();
    }

    return $changed;
}

my $new_derived_key = pf::config::crypt::derived_key($new_key);
my $old_derived_key = pf::config::crypt::derived_key($old_key);
my $changed = 0;
for my $storeClass (@{pf::ConfigStore::All::all_stores() || []}) {
    my $store = $storeClass->new;
    my $file_path = $store->configFile;
    next if !defined $file_path || !-e $file_path;
    print "Updating ", $file_path, " with new key", "\n";
    $changed |= change_key($old_derived_key, $new_derived_key, $file_path);
}

print "export PF_SYSTEM_INIT_KEY=$new_key\n";
open(my $fh, ">", $system_init_key_file);
print $fh $new_key;
close($fh);

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301,
USA.

=cut
