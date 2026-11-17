#!/usr/bin/perl

=head1 NAME

addons/upgrade/to-16.0-fingerbank-local-ids.pl

=cut

=head1 DESCRIPTION

Report the settings that reference a local Fingerbank entry (an ID that starts
with L, ex: L12). The local Fingerbank database was removed in 16.0: these IDs
don't exist anymore, so the security event triggers, provisioners, scan engines,
self service and network behavior policies that use them never match them.

Nothing is changed: replace or remove the reported IDs.

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib /usr/local/pf/lib_perl/lib/perl5);
use pf::IniFiles;
use pf::file_paths qw(
    $security_events_config_file
    $provisioning_config_file
    $scan_config_file
    $self_service_config_file
    $network_behavior_policy_config_file
    $pf_config_file
);

main() if not caller();

sub main {
    my @found = find_local_fingerbank_ids(config_files());
    print_local_fingerbank_ids(@found);
}

=head2 config_files

The configuration files to check, with how each one stores Fingerbank IDs

=cut

our $TRIGGER_TYPES = qr/device|device_is_not|dhcp_fingerprint|dhcp_vendor|dhcp6_fingerprint|dhcp6_enterprise|mac_vendor/i;

sub config_files {
    return (
        { file => $security_events_config_file, keys => ['trigger'], format => 'trigger' },
        { file => $provisioning_config_file, keys => ['oses'], format => 'list' },
        { file => $scan_config_file, keys => ['oses'], format => 'list' },
        { file => $self_service_config_file, keys => ['device_registration_allowed_devices'], format => 'list' },
        { file => $network_behavior_policy_config_file, keys => ['devices_included', 'devices_excluded'], format => 'list' },
        { file => $pf_config_file, sections => ['fingerbank_device_change'], keys => ['device_class_whitelist', 'triggers'], format => 'list' },
    );
}

=head2 find_local_fingerbank_ids

Returns a hashref (file, section, key, id) for each local Fingerbank ID found

=cut

sub find_local_fingerbank_ids {
    my (@configs) = @_;
    my @found;
    for my $config (@configs) {
        next unless -f $config->{file};
        my $ini = pf::IniFiles->new(-file => $config->{file}, -allowempty => 1) or next;
        my @sections = $config->{sections} ? @{$config->{sections}} : $ini->Sections();
        for my $section (@sections) {
            for my $key (@{$config->{keys}}) {
                my $value = $ini->val($section, $key) // next;
                for my $id (local_ids($value, $config->{format})) {
                    push @found, { file => $config->{file}, section => $section, key => $key, id => $id };
                }
            }
        }
    }
    return @found;
}

=head2 local_ids

The local Fingerbank IDs of a value

=cut

sub local_ids {
    my ($value, $format) = @_;
    if ($format eq 'trigger') {
        return map { uc } $value =~ /\b(?:$TRIGGER_TYPES)::(L\d+)\b/gi;
    }
    # A list of IDs, or of device class transitions (ID->ID)
    return map { uc } grep { /^L\d+$/i } split(/[\s,>-]+/, $value);
}

=head2 print_local_fingerbank_ids

=cut

sub print_local_fingerbank_ids {
    my (@found) = @_;
    if (!@found) {
        print "No setting references a local Fingerbank entry\n";
        return;
    }
    for my $f (@found) {
        print "$f->{file}: [$f->{section}] $f->{key} references the local Fingerbank entry $f->{id}\n";
    }
    print "The local Fingerbank entries were removed: replace or remove these IDs, they never match\n";
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
