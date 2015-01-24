package pf::Authentication::Source::ChainedSource;
=head1 NAME

pf::Authentication::Source::ChainedSource

=cut

=head1 DESCRIPTION

pf::Authentication::Source::ChainedSource

=cut

use strict;
use warnings;
use Moose;
use pf::constants;
use pf::config;
use pf::Authentication::constants;
use pf::util;
use pf::log;

extends 'pf::Authentication::Source';

=head2 Attributes

=head2 class

=cut

has '+class' => (default => 'internal');
has '+type' => (default => 'Chained');
has '+unique' => (default => 1 );
has chained_authentication_source => ( is => 'rw', required => 1 );
has authentication_source => ( is => 'rw', required => 1 );

=head2 available_attributes

Allow to make a condition on the user's email address.

=cut

sub available_attributes {
  my $self = shift;

  my $super_attributes = $self->SUPER::available_attributes;
  my $own_attributes = [{ value => "username", type => $Conditions::SUBSTRING }];

  return [@$super_attributes, @$own_attributes];
}

=head2 available_actions

For an Null source, we limit the available actions to B<set role>, B<set access duration>, and B<set unreg date>.

=cut

sub available_actions {
    return [
            $Actions::SET_ROLE,
            $Actions::SET_ACCESS_DURATION,
            $Actions::SET_UNREG_DATE,
            $Actions::SET_ACCESS_LEVEL,
           ];
}

=head2 match_in_subclass

=cut

sub match_in_subclass {
    my ($self, $params, $rule, $own_conditions, $matching_conditions) = @_;
    my $username =  $params->{'username'};
    foreach my $condition (@{ $own_conditions }) {
        if ($condition->{'attribute'} eq "username") {
            if ( $condition->matches("username", $username) ) {
                push(@{ $matching_conditions }, $condition);
            }
        }
    }
    return $username;
}

=head2 authenticate

=cut

sub authenticate {
    my ($self, $username, $password) = @_;
    my $source = $self->getAuthenticationSourceObject();
    my $logger = get_logger();
    $logger->trace("authenticating with " . $source->id );
    return ($source->authenticate($username, $password));
}

=head2 getAuthenticationSourceObject

Get the real authentication source object

=cut

sub getAuthenticationSourceObject {
    my ($self) = @_;
    return pf::authentication::getAuthenticationSource($self->authentication_source);
}


=head2 getChainedAuthenticationSourceObject

Get the chained authentication source

=cut

sub getChainedAuthenticationSourceObject {
    my ($self) = @_;
    return pf::authentication::getAuthenticationSource($self->chained_authentication_source);
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

