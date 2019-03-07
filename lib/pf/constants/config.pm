package pf::constants::config;

=head1 NAME

pf::constants::config - constants for config object

=cut

=head1 DESCRIPTION

pf::constants::config

=cut

use strict;
use warnings;
use base qw(Exporter);

our @EXPORT_OK = qw(
  $IF_ENFORCEMENT_DNS
  $IF_ENFORCEMENT_VLAN
  $IF_ENFORCEMENT_INLINE
  $IF_ENFORCEMENT_INLINE_L2
  $IF_ENFORCEMENT_INLINE_L3

  $NET_TYPE_DNS_ENFORCEMENT
  $NET_TYPE_VLAN_REG
  $NET_TYPE_VLAN_ISOL
  $NET_TYPE_INLINE
  $NET_TYPE_INLINE_L2
  $NET_TYPE_INLINE_L3

  $TIME_MODIFIER_RE
  $ACCT_TIME_MODIFIER_RE
  $DEADLINE_UNIT

  $SELFREG_MODE_EMAIL
  $SELFREG_MODE_SMS
  $SELFREG_MODE_SPONSOR
  $SELFREG_MODE_GOOGLE
  $SELFREG_MODE_FACEBOOK
  $SELFREG_MODE_GITHUB
  $SELFREG_MODE_INSTAGRAM
  $SELFREG_MODE_LINKEDIN
  $SELFREG_MODE_PINTEREST
  $SELFREG_MODE_WIN_LIVE
  $SELFREG_MODE_TWITTER
  $SELFREG_MODE_NULL
  $SELFREG_MODE_KICKBOX
  $SELFREG_MODE_BLACKHOLE
  %NET_INLINE_TYPES

  $DEFAULT_SMTP_PORT
  $DEFAULT_SMTP_PORT_SSL
  $DEFAULT_SMTP_PORT_TLS
  %ALERTING_PORTS

  $WIRELESS_802_1X
  $WIRELESS_MAC_AUTH
  $WIRED_802_1X
  $WIRED_MAC_AUTH
  $WIRED_SNMP_TRAPS
  $UNKNOWN
  $INLINE
  $WEBAUTH
  $WEBAUTH_WIRED
  $WEBAUTH_WIRELESS
    
  $WIRELESS
  $WIRED
  $EAP

  %connection_type
  %connection_type_to_str
  %connection_type_explained
  %connection_type_explained_to_str
  %connection_group
  %connection_group_to_str
);

use Readonly;

Readonly our $IF_ENFORCEMENT_DNS => 'dns';
Readonly our $IF_ENFORCEMENT_VLAN => 'vlan';
Readonly our $IF_ENFORCEMENT_INLINE => 'inline';
Readonly our $IF_ENFORCEMENT_INLINE_L2 => 'inlinel2';
Readonly our $IF_ENFORCEMENT_INLINE_L3 => 'inlinel3';

Readonly our $NET_TYPE_DNS_ENFORCEMENT => 'dns-enforcement';
Readonly our $NET_TYPE_VLAN_REG => 'vlan-registration';
Readonly our $NET_TYPE_VLAN_ISOL => 'vlan-isolation';
Readonly our $NET_TYPE_INLINE => 'inline';
Readonly our $NET_TYPE_INLINE_L2 => 'inlinel2';
Readonly our $NET_TYPE_INLINE_L3 => 'inlinel3';

Readonly our $TIME_MODIFIER_RE => qr/[smhDWMY]/;
Readonly our $ACCT_TIME_MODIFIER_RE => qr/[DWMY]/;
Readonly our $DEADLINE_UNIT => qr/[RF]/;

# Guest related
# The values matches the external authentication sources types
Readonly our $SELFREG_MODE_EMAIL => 'email';
Readonly our $SELFREG_MODE_SMS => 'sms';
Readonly our $SELFREG_MODE_SPONSOR => 'sponsoremail';
Readonly our $SELFREG_MODE_GOOGLE => 'google';
Readonly our $SELFREG_MODE_FACEBOOK => 'facebook';
Readonly our $SELFREG_MODE_GITHUB => 'github';
Readonly our $SELFREG_MODE_INSTAGRAM => 'instagram';
Readonly our $SELFREG_MODE_LINKEDIN   => 'linkedin';
Readonly our $SELFREG_MODE_PINTEREST   => 'pinterest';
Readonly our $SELFREG_MODE_WIN_LIVE   => 'windowslive';
Readonly our $SELFREG_MODE_TWITTER   => 'twitter';
Readonly our $SELFREG_MODE_NULL   => 'null';
Readonly our $SELFREG_MODE_KICKBOX   => 'kickbox';
Readonly our $SELFREG_MODE_BLACKHOLE => 'blackhole';

Readonly our %NET_INLINE_TYPES =>  (
    $NET_TYPE_INLINE    => undef,
    $NET_TYPE_INLINE_L2 => undef,
    $NET_TYPE_INLINE_L3 => undef,
);

Readonly our $DEFAULT_SMTP_PORT => 25;
Readonly our $DEFAULT_SMTP_PORT_SSL => 465;
Readonly our $DEFAULT_SMTP_PORT_TLS => 587;

Readonly our %ALERTING_PORTS => (
    none => $DEFAULT_SMTP_PORT,
    ssl => $DEFAULT_SMTP_PORT_SSL,
    starttls => $DEFAULT_SMTP_PORT_TLS,
);

# Interface enforcement techniques
# connection type constants
# 1 : Wireless
# 2 : Eap
# 3 : Wired
# 4 : Inline
# 5 : SNMP
# 6 : WebAuth

Readonly our $WIRELESS_802_1X     => 0b1100000000;
Readonly our $WIRELESS_MAC_AUTH   => 0b1000000001;
Readonly our $WIRED_802_1X        => 0b0110000010;
Readonly our $WIRED_MAC_AUTH      => 0b0010000011;
Readonly our $WIRED_SNMP_TRAPS    => 0b0010100100;
Readonly our $INLINE              => 0b0001000101;
Readonly our $UNKNOWN             => 0b0000000000;
Readonly our $WEBAUTH_WIRELESS    => 0b1000010111;
Readonly our $WEBAUTH_WIRED       => 0b0010011000;

# masks to be used on connection types
Readonly our $WIRELESS   => 0b1000000000;
Readonly our $WIRED      => 0b0010000000;
Readonly our $EAP        => 0b0100000000;
Readonly our $WEBAUTH    => 0b0000010000;

# TODO we should build a connection data class with these hashes and related constants
# String to constant hash
Readonly our %connection_type => (
    'Wireless-802.11-EAP'   => $WIRELESS_802_1X,
    'Wireless-802.11-NoEAP' => $WIRELESS_MAC_AUTH,
    'Ethernet-EAP'          => $WIRED_802_1X,
    'Ethernet-NoEAP'        => $WIRED_MAC_AUTH,
    'SNMP-Traps'            => $WIRED_SNMP_TRAPS,
    'Inline'                => $INLINE,
    'Ethernet-Web-Auth'     => $WEBAUTH_WIRED,
    'Wireless-Web-Auth'     => $WEBAUTH_WIRELESS,
);
Readonly our %connection_group => (
    'Wireless'              => $WIRELESS,
    'Ethernet'              => $WIRED,
    'EAP'                   => $EAP,
    'Web-Auth'              => $WEBAUTH,
);

Readonly our %connection_type_to_str => (
    $WIRELESS_802_1X => 'Wireless-802.11-EAP',
    $WIRELESS_MAC_AUTH => 'Wireless-802.11-NoEAP',
    $WIRED_802_1X => 'Ethernet-EAP',
    $WIRED_MAC_AUTH => 'Ethernet-NoEAP',
    $WIRED_SNMP_TRAPS => 'SNMP-Traps',
    $INLINE => 'Inline',
    $UNKNOWN => '',
    $WEBAUTH_WIRELESS => 'Wireless-Web-Auth',
    $WEBAUTH_WIRED  => 'Ethernet-Web-Auth',
);
Readonly our %connection_group_to_str => (
    $WIRELESS => 'Wireless',
    $WIRED => 'Ethernet',
    $EAP => 'EAP',
    $WEBAUTH => 'Web-Auth',
);

# Their string equivalent for database storage
# String to constant hash
# these duplicated in html/admin/common.php for web admin display
# changes here should be reflected there
Readonly our %connection_type_explained => (
    $WIRELESS_802_1X => 'WiFi 802.1X',
    $WIRELESS_MAC_AUTH => 'WiFi MAC Auth',
    $WIRED_802_1X => 'Wired 802.1x',
    $WIRED_MAC_AUTH => 'Wired MAC Auth',
    $WIRED_SNMP_TRAPS => 'Wired SNMP',
    $INLINE => 'Inline',
    $UNKNOWN => 'Unknown',
    $WEBAUTH_WIRELESS => 'Wifi Web Auth',
    $WEBAUTH_WIRED => 'Wired Web Auth',
);

Readonly our %connection_type_explained_to_str => map { $connection_type_explained{$_} => $connection_type_to_str{$_} } keys %connection_type_explained;

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

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
