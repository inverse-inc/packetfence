package pf::Switch::AeroHIVE::BR100;

=head1 NAME

pf::Switch::AeroHIVE::AP - Object oriented module to access AP series via Telnet/SSH

=head1 SYNOPSIS

The pf::Switch::AeroHIVE::AP module implements an object oriented interface
to access AP  Series via Telnet/SSH

=head1 STATUS

This module is currently only a placeholder, see pf::Switch::AeroHIVE

=cut

use strict;
use warnings;
use Log::Log4perl;
use Net::SNMP;
use Try::Tiny;

use base ('pf::Switch::AeroHIVE');
use pf::config;
use pf::Switch::constants;
use pf::util;
use pf::accounting qw(node_accounting_current_sessionid);
use pf::node qw(node_attributes);
use pf::util::radius qw(perform_coa perform_disconnect);
sub description { 'AeroHive BR100' }


# CAPABILITIES
# access technology supported
sub supportsWiredMacAuth { return $TRUE; }
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

