#!/usr/bin/perl

=head1 NAME

addons/upgrade/to-16.0-disable-use-connector.pl

=cut

=head1 DESCRIPTION

Disable the use of the connector in the existing configuration: the
PacketFence Connector is not part of PacketFence anymore, it is available as a
plugin, so nothing answers the connections sent through it until the plugin is
installed.

=over

=item switches.conf: SNMPUseConnector=N and radiusDeauthUseConnector=N in the
switches and switch groups that enabled them.

=item authentication.conf: use_connector=0 in the LDAP, Active Directory,
eDirectory, Google Workspace LDAP and RADIUS sources that enabled it or relied
on its previous default.

=item firewall_sso.conf: use_connector=0 in the firewalls that enabled it.

=back

It runs before add-default-params-to-auth.pl, which would write the defaults
of the new sources in them.

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib /usr/local/pf/lib_perl/lib/perl5);
use pf::IniFiles;
use pf::file_paths qw(
    $switches_config_file
    $authentication_config_file
    $firewall_sso_config_file
);
use pf::util;

main() if not caller();

sub main {
    run_as_pf();

    my $updated = 0;
    my @files = (
        [$switches_config_file, \&disable_switches_use_connector],
        [$authentication_config_file, \&disable_sources_use_connector],
        [$firewall_sso_config_file, \&disable_firewalls_use_connector],
    );
    for my $file (@files) {
        my ($path, $disable) = @$file;
        unless (-e $path) {
            print "$path does not exist\n";
            next;
        }
        my $ini = pf::IniFiles->new(-file => $path, -allowempty => 1);
        if (my $count = $disable->($ini)) {
            $ini->RewriteConfig();
            $updated += $count;
        }
    }
    if ($updated) {
        print "Install the PacketFence Connector plugin and enable these parameters again to keep using a connector\n";
    }
}

=head2 disable_switches_use_connector

Writes N in the SNMPUseConnector and radiusDeauthUseConnector parameters that
are enabled in the switches and the switch groups. Returns the number of
values written.

=cut

our @SWITCH_USE_CONNECTOR_PARAMS = qw(SNMPUseConnector radiusDeauthUseConnector);

sub disable_switches_use_connector {
    my ($ini) = @_;
    my $updated = 0;
    for my $section ($ini->Sections()) {
        for my $name (@SWITCH_USE_CONNECTOR_PARAMS) {
            next unless isenabled($ini->val($section, $name));
            $ini->setval($section, $name, 'N');
            print "Set $name to 'N' in the switch $section\n";
            $updated++;
        }
    }
    return $updated;
}

=head2 disable_sources_use_connector

Writes use_connector=0 in the sources of %SOURCE_TYPES_USING_CONNECTOR that
enabled it or don't define it, since it was enabled by default. Returns the
number of values written.

=cut

our %SOURCE_TYPES_USING_CONNECTOR = map { $_ => 1 } qw(LDAP AD EDIR GoogleWorkspaceLDAP RADIUS);

sub disable_sources_use_connector {
    my ($ini) = @_;
    my $updated = 0;
    for my $section ($ini->Sections()) {
        next if $section =~ / /;
        my $type = $ini->val($section, 'type') // '';
        next unless $SOURCE_TYPES_USING_CONNECTOR{$type};
        if ($ini->exists($section, 'use_connector')) {
            next unless isenabled($ini->val($section, 'use_connector'));
            $ini->setval($section, 'use_connector', 0);
        }
        else {
            $ini->newval($section, 'use_connector', 0);
        }
        print "Set use_connector to '0' in the $type source $section\n";
        $updated++;
    }
    return $updated;
}

=head2 disable_firewalls_use_connector

Writes use_connector=0 in the firewalls that enabled it. Returns the number of
values written.

=cut

sub disable_firewalls_use_connector {
    my ($ini) = @_;
    my $updated = 0;
    for my $section ($ini->Sections()) {
        next unless isenabled($ini->val($section, 'use_connector'));
        $ini->setval($section, 'use_connector', 0);
        print "Set use_connector to '0' in the firewall $section\n";
        $updated++;
    }
    return $updated;
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

1;
