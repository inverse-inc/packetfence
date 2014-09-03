package pf::vlan::custom;

=head1 NAME

pf::vlan::custom - Object oriented module for VLAN isolation oriented functions 

=head1 SYNOPSIS

The pf::vlan::custom module implements VLAN isolation oriented functions that are custom 
to a particular setup.

This module extends pf::vlan

=cut

use strict;
use warnings;

use Log::Log4perl;
use threads;
use threads::shared;

use base ('pf::vlan');

use pf::config;
use pf::node qw(node_attributes node_exist node_modify);
use pf::Switch::constants;
use pf::util;
use pf::violation qw(violation_count_trap violation_exist_open violation_view_top);

use pf::authentication;
use pf::Authentication::constants;
use pf::Portal::ProfileFactory;
use pf::vlan::filter;

our $VERSION = 1.04;

=head1 SUBROUTINES

=over

=cut


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
