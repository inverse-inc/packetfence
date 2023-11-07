package pf::Switch::Fortinet::FortiSwitchOS_v7_4;

=head1 NAME

pf::Switch::Fortinet::FortiSwitch - Object oriented module to FortiSwitch using the 802.1x with the radius disconnect (CoA) on port 3799

=head1 SYNOPSIS

The pf::Switch::Fortinet::FortiSwitch  module implements an object oriented interface to interact with the FortiSwitch

=head1 STATUS

802.1X tested with FortiOS X.X

=cut

=head1 BUGS AND LIMITATIONS


=cut

use strict;
use warnings;
use pf::util;
use pf::log;
use pf::constants;
use pf::accounting qw(node_accounting_dynauth_attr);
use pf::config qw(
    $WIRED_802_1X
    $WIRED_MAC_AUTH
);

use base ('pf::Switch::Fortinet::FortiSwitchOS_v7_2');

=head1 METHODS

=cut

sub description { 'FortiSwitchOS v7.4' }

use pf::SwitchSupports qw(
    WiredMacAuth
    WiredDot1x
    ~AccessListBasedEnforcement
);


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2023 Inverse inc.

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
