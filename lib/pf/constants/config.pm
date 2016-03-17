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
  $SELFREG_MODE_LINKEDIN
  $SELFREG_MODE_WIN_LIVE
  $SELFREG_MODE_TWITTER
  $SELFREG_MODE_NULL
  $SELFREG_MODE_KICKBOX
  $SELFREG_MODE_BLACKHOLE
  %NET_INLINE_TYPES
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
Readonly our $SELFREG_MODE_LINKEDIN   => 'linkedin';
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


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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

