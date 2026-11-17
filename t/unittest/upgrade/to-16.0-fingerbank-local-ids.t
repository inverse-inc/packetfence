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
use pf::IniFiles;
use File::Temp qw(tempdir);
require "$install_dir/addons/upgrade/to-16.0-fingerbank-local-ids.pl";
use Test::More tests => 25;

#This test will running last
use Test::NoWarnings;

sub cleaned {
    my ($value, $format) = @_;
    my $r = clean_value($value, $format);
    return [ $r->{value}, $r->{removed}, $r->{kept} ];
}

# Security event triggers
is_deeply(cleaned("DEVICE::L12,MAC_VENDOR::42", 'trigger'), ['MAC_VENDOR::42', ['L12'], []],
    "a trigger that requires a local entry is removed");
is_deeply(cleaned("(dhcp_fingerprint::l3&role::guest),device::5", 'trigger'), ['device::5', ['L3'], []],
    "combined conditions that require a local entry are removed");
is_deeply(cleaned("(device_is_not::L4&role::guest)", 'trigger'), ['role::guest', ['L4'], []],
    "a device_is_not condition on a local entry is removed from the conditions it is combined with");
is_deeply(cleaned("( device_is_not::L4 & role::guest & device::5 )", 'trigger'), ['(role::guest&device::5)', ['L4'], []],
    "the other combined conditions are kept together");
is_deeply(cleaned("device_is_not::L4,device::5", 'trigger'), [undef, [], ['L4']],
    "a device_is_not trigger on a local entry alone is kept: removing it would change what matches");
is_deeply(cleaned("device::L1,(mac_vendor::L2&role::x)", 'trigger'), [undef, [], ['L1', 'L2']],
    "the triggers are kept when they all use a local entry");
like(clean_value("device::L1", 'trigger')->{reason}, qr/can't be triggered anymore/, "and the reason is given");
is_deeply(cleaned("Nessus::L4,device::5,(role::guest&device_is_not::7)", 'trigger'), [undef, [], []],
    "the other triggers are left alone");

# Lists
is_deeply(cleaned("33, L5,l6", 'included'), ['33', ['L5', 'L6'], []], "the local IDs of an included list are removed when other IDs remain");
is_deeply(cleaned("L5,l6", 'included'), [undef, [], ['L5', 'L6']], "an included list of local IDs only is kept: empty, it would match every device");
is_deeply(cleaned("L5,l6", 'excluded'), ['', ['L5', 'L6'], []], "the local IDs of an excluded list are removed");
is_deeply(cleaned("1,2", 'included'), [undef, [], []], "no local ID");

# Device class transitions
is_deeply(cleaned("L1->2, 3->4\n5 -> l6,*->7", 'transitions'), ['3->4,*->7', ['L1', 'L6'], []], "the transitions that use a local ID are removed");
is_deeply(cleaned("1->2", 'transitions'), [undef, [], []], "no local transition");

my $dir = tempdir(CLEANUP => 1);
sub write_file {
    my ($name, $content) = @_;
    my $file = "$dir/$name";
    open(my $fh, '>', $file) or die "$file: $!";
    print $fh $content;
    close($fh);
    return $file;
}

my $security_events = write_file('security_events.conf', "[1]\ntrigger=DEVICE::L7,DEVICE::8\ndesc=L9\n[2]\ntrigger=MAC_VENDOR::42\n[3]\ntrigger=device::L1\n");
my $provisioning = write_file('provisioning.conf', "[android]\noses=33,L5\n[custom]\noses=L6\n");
my $nbp = write_file('network_behavior_policies.conf', "[policy]\ndevices_included=L1,2\ndevices_excluded=L3\n");
my $pf = write_file('pf.conf', "[fingerbank_device_change]\ntriggers=L1->2,3->4\n[general]\ndomain=L3\n");

my @results = clean_local_fingerbank_ids(
    { file => $security_events, keys => ['trigger'], format => 'trigger' },
    { file => $provisioning, keys => ['oses'], format => 'included' },
    { file => $nbp, keys => ['devices_included'], format => 'included' },
    { file => $nbp, keys => ['devices_excluded'], format => 'excluded' },
    { file => $pf, sections => ['fingerbank_device_change'], keys => ['device_class_whitelist', 'triggers'], format => 'transitions' },
    { file => "$dir/missing.conf", keys => ['oses'], format => 'included' },
);

is_deeply(
    [ map { "$_->{section}.$_->{key}: -" . join(' ', @{$_->{removed}}) . " +" . join(' ', @{$_->{kept}}) } @results ],
    [
        '1.trigger: -L7 +',
        '3.trigger: - +L1',
        'android.oses: -L5 +',
        'custom.oses: - +L6',
        'policy.devices_included: -L1 +',
        'policy.devices_excluded: -L3 +',
        'fingerbank_device_change.triggers: -L1 +',
    ],
    "only the local IDs of the Fingerbank settings are cleaned or reported",
);

sub val {
    my ($file, $section, $key) = @_;
    return pf::IniFiles->new(-file => $file, -allowempty => 1)->val($section, $key);
}

is(val($security_events, '1', 'trigger'), 'DEVICE::8', "the cleaned trigger is saved");
is(val($security_events, '1', 'desc'), 'L9', "the other settings are left alone");
is(val($security_events, '3', 'trigger'), 'device::L1', "the kept trigger is saved as it was");
is(val($provisioning, 'android', 'oses'), '33', "the cleaned list is saved");
is(val($nbp, 'policy', 'devices_excluded'), '', "the cleaned excluded list is saved");
is(val($pf, 'fingerbank_device_change', 'triggers'), '3->4', "the cleaned transitions are saved");

{
    open(my $out, '>', \my $output);
    my $old = select($out);
    print_results(@results);
    select($old);
    like($output, qr/\[1\] trigger: removed the local Fingerbank entries L7\n/, "each removal is printed");
    like($output, qr/\[custom\] oses: kept the local Fingerbank entries L6 because it only has local entries/, "each kept local ID is printed with the reason");
}

{
    open(my $out, '>', \my $output);
    my $old = select($out);
    print_results();
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
