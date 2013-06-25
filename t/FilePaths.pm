package FilePaths;
=head1 NAME

FilePaths

=cut

=head1 DESCRIPTION

FilePaths
Overrides the $pf::file_paths::switches_config_file to point to the test config

=cut

use strict;
use warnings;

BEGIN {
    use pf::file_paths;
    $pf::file_paths::switches_config_file  = './data/switches.conf';
    $pf::file_paths::chi_config_file       = './data/chi.conf';
    $pf::file_paths::switches_overlay_file = './data/switches-overlay.conf';
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

