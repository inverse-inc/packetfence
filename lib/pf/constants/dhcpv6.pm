package pf::constants::dhcpv6;

=head1 NAME

pf::constants::dhcpv6 - Constants for dhcpv6

=cut

=head1 DESCRIPTION

pf::constants::dhcpv6

=cut

use strict;
use warnings;

BEGIN {
    use Exporter qw(import);
    our (@ISA, %EXPORT_TAGS, @EXPORT_OK);
    @EXPORT_OK = qw(
        SOLICIT
        ADVERTISE
        REQUEST
        CONFIRM
        RENEW
        REBIND
        REPLY
        RELEASE
        DECLINE
        RECONFIGURE
        INFORMATION_REQUEST
        RELAY_FORW
        RELAY_REPL

        OPTION_CLIENTID
        OPTION_SERVERID
        OPTION_IA_NA
        OPTION_IA_TA
        OPTION_IAADDR
        OPTION_ORO
        OPTION_PREFERENCE
        OPTION_ELAPSED_TIME
        OPTION_RELAY_MSG
        OPTION_AUTH
        OPTION_UNICAST
        OPTION_STATUS_CODE
        OPTION_RAPID_COMMIT
        OPTION_USER_CLASS
        OPTION_VENDOR_CLASS
        OPTION_VENDOR_OPTS
        OPTION_INTERFACE_ID
        OPTION_RECONF_MSG
        OPTION_RECONF_ACCEPT
        OPTION_SIP_SERVER_D
        OPTION_SIP_SERVER_A
        OPTION_DNS_SERVERS
        OPTION_DOMAIN_LIST
        OPTION_IA_PD
        OPTION_IAPREFIX
        OPTION_NIS_SERVERS
        OPTION_NISP_SERVERS
        OPTION_NIS_DOMAIN
        OPTION_NISP_DOMAIN
        OPTION_SNTP_SERVERS
        OPTION_INFO_REFRESH_TIME
        OPTION_BCMCS_SERVER_D
        OPTION_BCMCS_SERVER_A
        OPTION_GEOCONF_CIVIC
        OPTION_REMOTE_ID
        OPTION_SUBSCRIBER_ID
        OPTION_CLIENT_FQDN
        OPTION_NEW_POSIX_TIMEZONE
        OPTION_NEW_TZDB_TIMEZONE
        OPTION_ERO
        OPTION_LQ_QUERY
        OPTION_CLIENT_DATA
        OPTION_CLT_TIME
        OPTION_LQ_RELAY_DATA
        OPTION_LQ_CLIENT_LINK
        OPTION_PANA_AGENT
        OPTION_V6_LOST
    );
    %EXPORT_TAGS = (
        all => \@EXPORT_OK,
    );
}


use constant SOLICIT             => 1;
use constant ADVERTISE           => 2;
use constant REQUEST             => 3;
use constant CONFIRM             => 4;
use constant RENEW               => 5;
use constant REBIND              => 6;
use constant REPLY               => 7;
use constant RELEASE             => 8;
use constant DECLINE             => 9;
use constant RECONFIGURE         => 10;
use constant INFORMATION_REQUEST => 11;
use constant RELAY_FORW          => 12;
use constant RELAY_REPL          => 13;

use constant OPTION_CLIENTID     => 1;
use constant OPTION_SERVERID     => 2;
use constant OPTION_IA_NA        => 3;
use constant OPTION_IA_TA        => 4;
use constant OPTION_IAADDR       => 5;
use constant OPTION_ORO          => 6;
use constant OPTION_PREFERENCE   => 7;
use constant OPTION_ELAPSED_TIME => 8;
use constant OPTION_RELAY_MSG    => 9;
### 10 is unassigned
use constant OPTION_AUTH          => 11;
use constant OPTION_UNICAST       => 12;
use constant OPTION_STATUS_CODE   => 13;
use constant OPTION_RAPID_COMMIT  => 14;
use constant OPTION_USER_CLASS    => 15;
use constant OPTION_VENDOR_CLASS  => 16;
use constant OPTION_VENDOR_OPTS   => 17;
use constant OPTION_INTERFACE_ID  => 18;
use constant OPTION_RECONF_MSG    => 19;
use constant OPTION_RECONF_ACCEPT => 20;
use constant OPTION_SIP_SERVER_D  => 21;
use constant OPTION_SIP_SERVER_A  => 22;
use constant OPTION_DNS_SERVERS   => 23;
use constant OPTION_DOMAIN_LIST   => 24;
use constant OPTION_IA_PD         => 25;
use constant OPTION_IAPREFIX      => 26;
use constant OPTION_NIS_SERVERS   => 27;
use constant OPTION_NISP_SERVERS  => 28;
use constant OPTION_NIS_DOMAIN    => 29;
use constant OPTION_NISP_DOMAIN   => 30;
use constant OPTION_SNTP_SERVERS  => 31;
use constant OPTION_INFO_REFRESH_TIME => 32;
use constant OPTION_BCMCS_SERVER_D => 33;
use constant OPTION_BCMCS_SERVER_A => 34;
### 35 is unassigned
use constant OPTION_GEOCONF_CIVIC => 36;
use constant OPTION_REMOTE_ID     => 37;
use constant OPTION_SUBSCRIBER_ID => 38;
use constant OPTION_CLIENT_FQDN   => 39;
use constant OPTION_PANA_AGENT => 40;
use constant OPTION_NEW_POSIX_TIMEZONE => 41;
use constant OPTION_NEW_TZDB_TIMEZONE => 42;
use constant OPTION_ERO => 43;
use constant OPTION_LQ_QUERY => 44;
use constant OPTION_CLIENT_DATA => 45;
use constant OPTION_CLT_TIME => 46;
use constant OPTION_LQ_RELAY_DATA => 47;
use constant OPTION_LQ_CLIENT_LINK => 48;

use constant OPTION_V6_LOST => 51;


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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
