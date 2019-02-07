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

=head2 param_encoded

Returns the parameter as the encoded value

=cut

sub param_encoded {
    my ($self,$param) = @_;
    return encode_entities($self->param($param));
}

=head2 around param

This was overridden to always return a single value

See L<http://blog.gerv.net/2014/10/new-class-of-vulnerability-in-perl-web-applications/> for further information

=cut

around param => sub {
    my ($orig,$self,@args) = @_;
    return @args ? scalar $self->$orig(@args) : undef;
};



=head2 param_multiple

Return multiple

=cut

sub param_multiple {
    my ($self,$param) = @_;
    return () unless exists $self->parameters->{$param};
    return @{ $self->parameters->{$param} };
}

=head2 param_names

Return the parameters names

=cut

sub param_names {
    my ($self) = @_;
    return keys %{ $self->parameters };
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

