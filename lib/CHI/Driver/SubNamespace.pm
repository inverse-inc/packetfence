package CHI::Driver::SubNamespace;
=head1 NAME

CHI::Driver::SubNamespace - A CHI driver that creates a sub namespace within a namesapce

=cut

=head1 DESCRIPTION

CHI::Driver::SubNamespace

=cut

use Moo;
use MooX::Types::MooseLike::Base qw(:all);
use strict;
use warnings;

extends 'CHI::Driver';

has 'chi_object'   => ( is => 'ro', isa => InstanceOf['CHI::Driver'], required => 1 );

=head2 fetch

=cut

sub fetch {
    my ($self, $key) = @_;
    my $namespace = $self->namespace;
    return scalar($self->chi_object->get("${namespace}:${key}"));
}

=head2 store

=cut

sub store {
    my ($self,$key,@args) = @_;
    my $namespace = $self->namespace;
    return $self->chi_object->set("${namespace}:${key}",@args);
}

=head2 remove

=cut

sub remove {
    my ($self, $key) = @_;
    my $namespace = $self->namespace;
    $self->chi_object->remove( "${namespace}:${key}");
}

=head2 clear

=cut

sub clear {
    my $self = shift;
    my $namespace = $self->namespace;
    return $self->chi_object->clear( grep { /^\Q$namespace\E/ } $self->chi_object->get_keys(@_));
}

=head2 get_keys

=cut

sub get_keys {
    my $self = shift;
    my $namespace = $self->namespace;
    local $_;
    return grep { s/^\Q$namespace\E// } $self->chi_object->get_keys(@_);
}

=head2 get_namespaces

=cut

sub get_namespaces {
    my $self = shift;
    return $self->chi_object->get_namespaces(@_);
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

