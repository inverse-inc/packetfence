package pf::radius::custom;

=head1 NAME

pf::radius::custom - Module that deals with everything radius related

=head1 SYNOPSIS

The pf::radius module contains the functions necessary for answering radius queries.
Radius is the network access component known as AAA used in 802.1x, MAC authentication, 
MAC authentication bypass (MAB), etc. This module acts as a proxy between our radius 
perl module's SOAP requests (rlm_perl_packetfence.pl) and PacketFence core modules.

This modules extends pf::radius. Override methods for which you want to customize
behavior here.

=cut

use strict;
use warnings;
use diagnostics;
use Log::Log4perl;

use base ('pf::radius');
use pf::config;
use pf::locationlog;
use pf::node;
use pf::SNMP;
use pf::SwitchFactory;
use pf::util;
use pf::vlan::custom;
# constants used by this module are provided by
use pf::radius::constants;

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2009,2010 Inverse inc.

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
