package pf::Authentication::Source::TLSSource;

=head1 NAME

pf::Authentication::Source::TLSSource add documentation

=cut

=head1 DESCRIPTION

pf::Authentication::Source::TLSSource

=cut

use strict;
use warnings;
use Moose;
use pf::constants;
use pf::Authentication::constants;

extends 'pf::Authentication::Source';

has '+class' => (default => 'external');
has '+type' => (default => 'TLS');

=head2 available_attributes

Allow to make a condition on the user's email address.

=cut

sub available_attributes {
    my ($self) = @_;
    my $super_attributes = $self->SUPER::available_attributes;
    my @own_attributes = map { {value => $_, type => $Conditions::SUBSTRING}} qw(
      TLS-Client-Cert-Serial
      TLS-Client-Cert-Expiration
      TLS-Client-Cert-Issuer
      TLS-Client-Cert-Subject
      TLS-Client-Cert-Common-Name
      TLS-Client-Cert-Filename
      TLS-Client-Cert-Subject-Alt-Name-Email
    );
    return [@$super_attributes, @own_attributes];
}

=head2 available_actions

Only the authentication actions should be available

=cut

sub available_actions {
    return [@{$Actions::ACTIONS{$Rules::AUTH}}];
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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

