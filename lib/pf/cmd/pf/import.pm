package pf::cmd::pf::import;
=head1 NAME

pf::cmd::pf::import add documentation

=head1 SYNOPSIS

pfcmd import <format> <filename>

Bulk import into the database. File input must be a of CSV format. Default
pid, category and voip status assigned to the imported nodes can be modified
in pf.conf.

Supported format:
- nodes

Nodes import format:
<MAC>

Node import automatically registers MACs with pid = 1 unless you configured
otherwise in pf.conf.

example:
  pfcmd import nodes /tmp/new-nodes.csv

=head1 DESCRIPTION

pf::cmd::pf::import

=cut

use strict;
use warnings;
use base qw(pf::cmd::subcmd);


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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

