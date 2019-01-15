package pf::ast::var;

=head1 NAME

pf::ast::var -

=head1 DESCRIPTION

pf::ast::var

=cut

use strict;
use warnings;

sub new {
    my ($proto, $keys) = @_;
    my $class = ref($proto) || $proto;
    return bless($keys, $class);
}

sub value {
    my ($self, $ctx) = @_;
    my $v;
    my @keys = @$self;
    my $last = pop @keys;
    for my $k (@keys) {
        if (!exists $ctx->{$k}) {
            return undef;
        }

        $v = $ctx->{$k};
        if (ref ($v) ne 'HASH') {
            return undef;
        }

        $ctx = $v;
    }

    if (!exists $ctx->{$last}) {
        return undef;
    }

    return $ctx->{$last};
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

