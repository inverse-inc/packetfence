#!/usr/bin/perl

=head1 NAME

to-16.0-fingerbank-local-ids

=head1 DESCRIPTION

unit test for addons/upgrade/to-16.0-fingerbank-local-ids.pl

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}
use pf::file_paths qw($install_dir);
use File::Temp qw(tempdir);
require "$install_dir/addons/upgrade/to-16.0-fingerbank-local-ids.pl";
use Test::More tests => 8;

#This test will running last
use Test::NoWarnings;

is_deeply([local_ids("DEVICE::L12,MAC_VENDOR::42,(dhcp_fingerprint::l3&DEVICE::5),Nessus::L4", 'trigger')], ['L12', 'L3'],
    "the local IDs of the Fingerbank triggers are found, not the other triggers");
is_deeply([local_ids("1,L2, 33,l40", 'list')], ['L2', 'L40'], "the local IDs of a list are found");
is_deeply([local_ids("L1->2\n3->L4", 'list')], ['L1', 'L4'], "the local IDs of device class transitions are found");
is_deeply([local_ids("1,2,3", 'list')], [], "no local ID");

my $dir = tempdir(CLEANUP => 1);
sub write_file {
    my ($name, $content) = @_;
    my $file = "$dir/$name";
    open(my $fh, '>', $file) or die "$file: $!";
    print $fh $content;
    close($fh);
    return $file;
}

my $security_events = write_file('security_events.conf', "[1]\ntrigger=DEVICE::L7,DEVICE::8\ndesc=L9\n[2]\ntrigger=MAC_VENDOR::42\n");
my $provisioning = write_file('provisioning.conf', "[android]\noses=33,L5\n");
my $pf = write_file('pf.conf', "[fingerbank_device_change]\ntriggers=L1->2\n[general]\ndomain=L3\n");

my @found = find_local_fingerbank_ids(
    { file => $security_events, keys => ['trigger'], format => 'trigger' },
    { file => $provisioning, keys => ['oses'], format => 'list' },
    { file => $pf, sections => ['fingerbank_device_change'], keys => ['device_class_whitelist', 'triggers'], format => 'list' },
    { file => "$dir/missing.conf", keys => ['oses'], format => 'list' },
);

is_deeply(
    [ map { "$_->{section}.$_->{key}=$_->{id}" } @found ],
    [ '1.trigger=L7', 'android.oses=L5', 'fingerbank_device_change.triggers=L1' ],
    "only the local IDs of the Fingerbank settings are reported",
);

{
    open(my $out, '>', \my $output);
    my $old = select($out);
    print_local_fingerbank_ids(@found);
    select($old);
    like($output, qr/\[1\] trigger references the local Fingerbank entry L7/, "each local ID is printed");
}

{
    open(my $out, '>', \my $output);
    my $old = select($out);
    print_local_fingerbank_ids();
    select($old);
    like($output, qr/No setting references a local Fingerbank entry/, "nothing to report");
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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
