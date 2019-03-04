package pf::util::statsd;

=head1 NAME

pf::StatsD::util - module for StatsD related utilities

=cut

=head1 DESCRIPTION

pf::StatsD::util contains functions and utilities used to send StatsD messages.
modules.

=cut

our $VERSION = 1.000000;

use Exporter 'import';

our @EXPORT_OK = qw(called);

=head1 SUBROUTINES

=over

=item called

Returns the name of the function enclosing this call.

E.g. sub mysub { called() }; should return "mysub".

=cut

sub called {
    return (caller(1))[3];
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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
