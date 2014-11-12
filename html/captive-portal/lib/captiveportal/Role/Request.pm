package captiveportal::Role::Request;
=head1 NAME

captiveportal::Role::Request - html encode query parameters

=cut

=head1 DESCRIPTION

captiveportal::Role::Request

=cut

use strict;
use warnings;
use Moose::Role;
use HTML::Entities qw(encode_entities);

sub param_encoded {
    my ($self,$param) = @_;
    return encode_entities($self->param($param));
}

around param => sub {
    my ($orig,$self,@args) = @_;
    return @args ? scalar $self->$orig(@args) : undef;
};

sub param_old {
    my $self = shift;

    if ( @_ == 0 ) {
        return keys %{ $self->parameters };
    }

    if ( @_ == 1 ) {

        my $param = shift;

        unless ( exists $self->parameters->{$param} ) {
            return wantarray ? () : undef;
        }

        if ( ref $self->parameters->{$param} eq 'ARRAY' ) {
            return (wantarray)
              ? @{ $self->parameters->{$param} }
              : $self->parameters->{$param}->[0];
        }
        else {
            return (wantarray)
              ? ( $self->parameters->{$param} )
              : $self->parameters->{$param};
        }
    }
    elsif ( @_ > 1 ) {
        my $field = shift;
        $self->parameters->{$field} = [@_];
    }
}
 
=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2014 Inverse inc.

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

