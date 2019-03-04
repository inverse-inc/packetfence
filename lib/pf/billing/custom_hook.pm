package pf::billing::custom_hook;

=head1 NAME

pf::billing::custom_hook - billing hook

=cut

=head1 DESCRIPTION

pf::billing::custom_hook is where to hook into httpd callbacks from billing providers

=cut

use strict;
use warnings;
use HTTP::Status qw(:constants);

=head1 SUBROUTINES

=head2 handle_hook ($billing_source, $headers, $content)

    The entry point for handling callbacks from billing providers

    Returns:
        An httpd status

=cut

sub handle_hook {
    my ($source, $headers, $content) = @_;
    return HTTP_OK;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

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
