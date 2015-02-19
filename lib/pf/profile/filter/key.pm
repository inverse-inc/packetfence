package pf::profile::filter::key;
=head1 NAME

pf::profile::filter::key add documentation

=cut

=head1 DESCRIPTION

pf::profile::filter::key

=cut

use strict;
use warnings;

use Moo;
extends 'pf::profile::filter';

=head1 ATTRIBUTES

=head2 key

The key of the value in the data hash

=cut

has key => ( is => 'ro', required => 1 );

=head1 METHODS

=head2 match

Matches value based off key in provided hash 

=cut

sub match {
    my ($self,$data) = @_;
    my $key = $self->key;
    return exists $data->{$key} && defined $data->{$key} && $data->{$key} eq $self->value;
}
 
=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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

