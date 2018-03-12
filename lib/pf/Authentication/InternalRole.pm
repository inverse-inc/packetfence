package pf::Authentication::InternalRole;

=head1 NAME

pf::Authentication::InternalRole -

=cut

=head1 DESCRIPTION

pf::Authentication::InternalRole

=cut

use strict;
use warnings;

use Moose::Role;
use pf::util qw(isenabled);
use pf::constants qw($TRUE $FALSE);
use List::MoreUtils qw(any);

has 'realms' => (isa => 'ArrayRef[Str]', is => 'rw');

=head2 realmIsAllowed

Checks to see if a realm is allowed for the source

A realm is allowed if realms is empty (undef or zero length)
Or if the realm is in the list of realms

=cut

sub realmIsAllowed {
    my ($self, $realm) = @_;
    my $realms = $self->realms;
    return $TRUE if !defined $realms || @$realms == 0;
    $realm //= 'null';
    $realm = lc($realm);
    return ( any { $_ =~ /^\Q$realm\E$/i } @$realms ) ? $TRUE : $FALSE;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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

