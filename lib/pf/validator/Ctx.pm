package pf::validator::Ctx;

=head1 NAME

pf::validator::Ctx -

=head1 DESCRIPTION

pf::validator::Ctx

=cut

use strict;
use warnings;
use Moose;

has errors => (
    traits    => ['Array'],
    is        => 'rw',
    isa       => 'ArrayRef',
    handles   => {
        add_error  => 'push',
        has_errors => 'count',
        clear_errors => 'clear',
    },
    default => sub { [] },
);

has warnings => (
    traits    => ['Array'],
    is        => 'rw',
    isa       => 'ArrayRef',
    handles   => {
        add_warning  => 'push',
        has_warnings => 'count',
        clear_warnings => 'clear',
    },
    default => sub { [] },
);

sub reset {
    my ($self) = @_;
    for my $m (qw(clear_errors clear_warnings)) {
        $self->$m()
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

