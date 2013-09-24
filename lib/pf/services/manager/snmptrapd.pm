package pf::services::manager::snmptrapd;
=head1 NAME

pf::services::manager::snmptrapd add documentation

=cut

=head1 DESCRIPTION

pf::services::manager::snmptrapd

=cut

use strict;
use warnings;
use Moo;
use pf::file_paths;
use pf::services::snmptrapd qw(generate_snmptrapd_conf);
extends 'pf::services::manager';

has '+name' => (default => sub { 'snmptrapd' } );

has '+launcher' => (default => sub { "%1\$s -n -c $generated_conf_dir/snmptrapd.conf -C -A -Lf $install_dir/logs/snmptrapd.log -p $install_dir/var/run/snmptrapd.pid -On" } );

sub generateConfig {
   generate_snmptrapd_conf();
}

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

