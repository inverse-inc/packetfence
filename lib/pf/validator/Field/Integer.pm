package pf::validator::Field::Integer;

=head1 NAME

pf::validator::Field::Integer -

=head1 DESCRIPTION

pf::validator::Field::Integer

=cut

use strict;
use warnings;
use Moose;
extends qw(pf::validator::Field);

has '+optionsType' => (
    default => 'integer',
);

has 'range_start' => (
    isa => 'Int|Undef',
    is => 'ro',
);

has 'range_end'   => (
    isa => 'Int|Undef',
    is => 'ro',
);

sub test_ranges {
    my ($self, $ctx, $val) = @_;
    return if !defined $val;

    my $low  = $self->range_start;
    my $high = $self->range_end;

    if ( defined $low && defined $high ) {
        unless ($low <= $val && $val <= $high) {
            $ctx->add_error({ field => $self->name, message => 'out of range' });
        }

        return;
    }

    if ( defined $low ) {
        unless ($low <= $val) {
            $ctx->add_error({ field => $self->name, message => 'value too low' });
        }

        return;
    }

    if ( defined $high ) {
        unless ($val <= $high) {
            $ctx->add_error({ field => $self->name, message => 'value too high' });
        }

        return;
    }

    return;
}

sub validate_field {
    my ($self, $ctx, $val) = @_;

    if (defined $val && $val !~ /^[-+]?[0-9]+$/) {
        $ctx->add_error({ field => $self->name, message => 'must be an Integer' });
    }

    return;
}

sub additionalOptionsMeta {
    my ($self) = @_;
    my $o      = $self->SUPER::additionalOptionsMeta();
    my $low    = $self->range_start;
    my $high   = $self->range_end;
    if (defined $low) {
        $o->{min_value} = $low;
    }

    if (defined $high) {
        $o->{max_value} = $high;
    }

    return $o;
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

