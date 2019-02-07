package pf::cmd::pf::connectionprofileconfig;
=head1 NAME

pf::cmd::pf::connectionprofileconfig add documentation

=head1 SYNOPSIS

pfcmd connectionprofileconfig get <all|default|ID>

pfcmd connectionprofileconfig add <ID> [assignments]

pfcmd connectionprofileconfig edit <ID> [assignments]

pfcmd connectionprofileconfig delete <ID>

pfcmd connectionprofileconfig clone <TO_ID> <FROM_ID> [assignments]

query/modify profiles.conf configuration file

=head1 DESCRIPTION

pf::cmd::pf::connectionprofileconfig

=cut

use strict;
use warnings;
use base qw(pf::base::cmd::config_store);
use pf::ConfigStore::Profile;

sub configStoreName { "pf::ConfigStore::Profile" }

sub display_fields { qw(id description logo redirecturl always_use_redirecturl locale) }

sub idKey { 'id' }

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

