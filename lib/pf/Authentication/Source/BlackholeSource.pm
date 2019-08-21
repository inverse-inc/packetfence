package pf::Authentication::Source::BlackholeSource;

=head1 NAME

pf::Authentication::Source::BlackholeSource add documentation

=cut

=head1 DESCRIPTION

pf::Authentication::Source::BlackholeSource

=cut

use strict;
use warnings;
use Moose;
use pf::constants;
use pf::config;
use pf::Authentication::constants;
use pf::constants::authentication::messages;
use pf::util;
use pf::constants::role qw($REJECT_ROLE);

extends 'pf::Authentication::Source';

=head2 Attributes

=head2 class

=cut

has '+class' => (default => 'exclusive');

has '+type' => (default => 'Blackhole');

=head2 dynamic_routing_module

Which module to use for DynamicRouting

=cut

sub dynamic_routing_module { 'Authentication::Blackhole' }

=head2 available_attributes

Allow to make a condition on the user's email address.

=cut

sub available_attributes {
  my $self = shift;

  my $super_attributes = $self->SUPER::available_attributes;
  my $own_attributes = [{ value => "username", type => $Conditions::SUBSTRING }];

  return [@$super_attributes, @$own_attributes];
}

=head2 available_rule_classes

Blackhole sources only allow 'authentication' rules

=cut

sub available_rule_classes {
    return [ grep { $_ ne $Rules::ADMIN } @Rules::CLASSES ];
}

=head2 available_actions

For a Blackhole source, only the authentication actions should be available

=cut

sub available_actions {
    my @actions = map( { @$_ } $Actions::ACTIONS{$Rules::AUTH});
    return \@actions;
}

=head2 match_in_subclass

=cut

sub match {
    my ($self, $params) = @_;
    return pf::Authentication::Rule->new(
        id => $self->id,
        class => $Rules::AUTH,
        actions => [
            pf::Authentication::Action->new({
                type    => $Actions::SET_ROLE,
                value   => $REJECT_ROLE,
                class   => pf::Authentication::Action->getRuleClassForAction($Actions::SET_ROLE),
            })
        ],
    );
       
}

=head2 authenticate

always return false

=cut

sub authenticate {
    my ($self, $username, $password) = @_;
    return ($FALSE, 'Not allowed');
}

=head2 has_authentication_rules

Whether or not the source should have authentication rules

=cut

sub has_authentication_rules { $FALSE }

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
