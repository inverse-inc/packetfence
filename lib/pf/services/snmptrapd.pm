package pf::services::snmptrapd;

=head1 NAME

pf::services::snmptrapd - helper configuration module for snmptrapd

=head1 DESCRIPTION

This module contains some functions that generates snmptrapd configuration
according to what PacketFence needs to accomplish.

=head1 CONFIGURATION AND ENVIRONMENT

Reads the following configuration files: F<conf/snmptrapd.conf>.

Generates the following configuration files: F<var/conf/snmptrapd.conf>.

=cut

use strict;
use warnings;

use Log::Log4perl;

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT_OK );
    @ISA = qw(Exporter);
    @EXPORT_OK = qw(generate_snmptrapd_conf);
}

use pf::config;
use pf::SwitchFactory;
use pf::util;

=head1 SUBROUTINES

=over

=item generate_snmptrapd_conf

=cut

sub generate_snmptrapd_conf {
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my ($snmpv3_users, $snmp_communities) = _fetch_trap_users_and_communities();

    my %tags;
    $tags{'authLines'} = '';
    $tags{'userLines'} = '';

    foreach my $user_key ( sort keys %$snmpv3_users ) {
        $tags{'userLines'} .= "createUser " . $snmpv3_users->{$user_key} . "\n";

        # grabbing only the username portion of the key
        my (undef, $username) = split(/ /, $user_key);
        $tags{'authLines'} .= "authUser log $username priv\n";
    }

    foreach my $community ( sort keys %$snmp_communities ) {
        $tags{'authLines'} .= "authCommunity log $community\n";
    }

    $tags{'template'} = "$conf_dir/snmptrapd.conf";
    $logger->info("generating $generated_conf_dir/snmptrapd.conf");
    parse_template( \%tags, "$conf_dir/snmptrapd.conf", "$generated_conf_dir/snmptrapd.conf" );
    return $TRUE;
}

=item _fetch_trap_users_and_communities

Returns a tuple of two hashref. One with SNMPv3 Trap Users Auth parameters and one with unique communities.

=cut

sub _fetch_trap_users_and_communities {
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $switchFactory = pf::SwitchFactory->getInstance();
    my %switchConfig = %{ $switchFactory->config };

    my (%snmpv3_users, %snmp_communities);
    foreach my $key ( sort keys %switchConfig ) {
        next if ( $key =~ /^default$/i );

        # TODO we can probably make this more performant if we avoid object instantiation (can we?)
        my $switch = $switchFactory->instantiate($key);
        if (!$switch) {
            $logger->error("Can not instantiate switch $key!");
        } else {
            if ( $switch->{_SNMPVersionTrap} eq '3' ) {
                $snmpv3_users{"$switch->{_SNMPEngineID} $switch->{_SNMPUserNameTrap}"} =
                    '-e ' . $switch->{_SNMPEngineID} . ' ' . $switch->{_SNMPUserNameTrap} . ' '
                    . $switch->{_SNMPAuthProtocolTrap} . ' ' . $switch->{_SNMPAuthPasswordTrap} . ' '
                    . $switch->{_SNMPPrivProtocolTrap} . ' ' . $switch->{_SNMPPrivPasswordTrap}
                ;
            } else {
                $snmp_communities{$switch->{_SNMPCommunityTrap}} = $TRUE;
            }
        }
    }

    return (\%snmpv3_users, \%snmp_communities);
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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
