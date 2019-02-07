package pfconfig::namespaces::resource::isolation_passthroughs;

=head1 NAME

pfconfig::namespaces::resource::isolation_passthroughs

=cut

=head1 DESCRIPTION

pfconfig::namespaces::resource::isolation_passthroughs

=cut

use strict;
use warnings;

use base 'pfconfig::namespaces::resource::passthroughs';

=head2 build

Build the passthroughs hash

    {
        # All the non-wildcard passthroughs
        normal => {
            "example.com" => ["tcp:80", ...],
            ...
        },
        wildcard => {
            "wild.example.com" => ["tcp:80", ...],
            ...
        }

    }

=cut

sub build {
    my ($self) = @_;

    my @all_passthroughs = (
        @{$self->{config}->{fencing}->{isolation_passthroughs} // []},
    );

    return $self->_build(\@all_passthroughs);
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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

