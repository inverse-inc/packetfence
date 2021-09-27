package pf::validator::Field::IPAddress;

=head1 NAME

pf::validator::Field::IPAddress -

=head1 DESCRIPTION

pf::validator::Field::IPAddress

=cut

use strict;
use warnings;
use Moose;
extends qw(pf::validator::Field);
use pf::util qw(valid_ip);

sub validate_field {
    my ($self, $ctx, $val) = @_;
    if ($ctx->has_errors) {
        return;
    }

    if (defined $val && !valid_ip($val)) {
        $ctx->add_error({ field => $self->name, message => 'must be an IP Address' });
    }

    return;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2021 Inverse inc.

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
