package pf::cmd::pf::switchconfig;
=head1 NAME

pf::cmd::pf::switchconfig add documentation

=head1 SYNOPSIS

pfcmd switchconfig get <all|default|ID>

pfcmd switchconfig add <ID> [assignments]

pfcmd switchconfig edit <ID> [assignments]

pfcmd switchconfig delete <ID>

pfcmd switchconfig clone <TO_ID> <FROM_ID> [assignments]

query/modify switches configuration file

=head1 DESCRIPTION

pf::cmd::pf::switchconfig

=cut

use strict;
use warnings;
use pf::log;
use pf::ConfigStore::Switch;
use base qw(pf::base::cmd::config_store);

sub configStoreName { "pf::ConfigStore::Switch" }

sub display_fields {
    qw(id ip type mode inlineTrigger VoIPEnabled vlans normalVlan
      registrationVlan isolationVlan guestVlan voiceVlan inlineVlan customVlan1 customVlan2 customVlan3 customVlan4 customVlan5
      uplink deauthMethod cliTransport cliUser cliPwd cliEnablePwd wsTransport wsUser wsPwd SNMPVersionTrap SNMPCommunityTrap
      SNMPUserNameTrap SNMPAuthProtocolTrap SNMPAuthPasswordTrap SNMPPrivProtocolTrap SNMPPrivPasswordTrap SNMPVersion
      SNMPCommunityRead SNMPCommunityWrite SNMPEngineID SNMPUserNameRead SNMPAuthProtocolRead SNMPAuthPasswordRead
      SNMPPrivProtocolRead SNMPPrivPasswordRead SNMPUserNameWrite SNMPAuthProtocolWrite SNMPAuthPasswordWrite
      SNMPPrivProtocolWrite SNMPPrivPasswordWrite radiusSecret controllerIp roles macSearchesMaxNb macSearchesSleepInterval)
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and::or
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

