package pf::services::radiusd;

=head1 NAME

pf::services::radiusd - helper configuration module for RADIUS (radiusd daemon)

=head1 DESCRIPTION

This module contains some functions that generates the RADIUS configuration
according to what PacketFence needs to accomplish.

=head1 CONFIGURATION AND ENVIRONMENT

Read the following configuration files:
F<conf/radiusd/radiusd.conf>
F<conf/radiusd/eap.conf>
F<conf/radiusd/sql.conf>

Generates the following configuration files:
F<var/radiusd/radiusd.conf>
F<var/radiusd/eap.conf/>
F<var/radiusd/sql.conf>

=cut

use strict;
use warnings;
use Log::Log4perl;
use Net::Netmask;
use POSIX;
use Readonly;

use pf::config;
use pf::util;
use pf::ConfigStore::SwitchOverlay;

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT_OK );
    @ISA = qw(Exporter);
    @EXPORT_OK = qw(
        generate_radiusd_conf
    );
}

=head1 SUBROUTINES

=over


=item * generate_radiusd_conf

Generates the RADIUS configuration files

=cut

sub generate_radiusd_conf {
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    generate_radiusd_mainconf();
    generate_radiusd_eapconf();
    generate_radiusd_sqlconf();

    #Build the nas table for RADIUS
    require pf::freeradius;
    pf::freeradius::freeradius_populate_nas_config(\%SwitchConfig);

    return 1;
}

=item * generate_radiusd_mainconf

Generates the radiusd.conf configuration file

=cut

sub generate_radiusd_mainconf {
    my %tags;

    $tags{'template'}    = "$conf_dir/radiusd/radiusd.conf";
    $tags{'install_dir'} = $install_dir;
    $tags{'management_ip'} = defined($management_network->tag('vip')) ? $management_network->tag('vip') : $management_network->tag('ip');
    $tags{'arch'} = `uname -m` eq "x86_64" ? "64" : "";

    parse_template( \%tags, "$conf_dir/radiusd/radiusd.conf", "$install_dir/raddb/radiusd.conf" );
}

=item * generate_radiusd_eapconf

Generates the eap.conf configuration file

=cut

sub generate_radiusd_eapconf {
   my %tags;

   $tags{'template'}    = "$conf_dir/radiusd/eap.conf";
   $tags{'install_dir'} = $install_dir;

   parse_template( \%tags, "$conf_dir/radiusd/eap.conf", "$install_dir/raddb/eap.conf" );
}

=item * generate_radiusd_sqlconf

Generates the sql.conf configuration file

=cut

sub generate_radiusd_sqlconf {
   my %tags;

   $tags{'template'}    = "$conf_dir/radiusd/sql.conf";
   $tags{'install_dir'} = $install_dir;
   $tags{'db_host'} = $Config{'database'}{'host'};
   $tags{'db_port'} = $Config{'database'}{'port'};
   $tags{'db_database'} = $Config{'database'}{'db'};
   $tags{'db_username'} = $Config{'database'}{'user'};
   $tags{'db_password'} = $Config{'database'}{'pass'};

   parse_template( \%tags, "$conf_dir/radiusd/sql.conf", "$install_dir/raddb/sql.conf" );
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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
