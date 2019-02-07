package pf::Authentication::Source::AdminProxySource;

=head1 NAME

pf::Authentication::Source::AdminProxySource - Class for AdminProxy

=cut

=head1 DESCRIPTION

pf::Authentication::Source::AdminProxySource

=cut

use strict;
use warnings;
use Moose;
use List::MoreUtils qw(any);

use pf::config;
use pf::constants qw($FALSE $TRUE);
use pf::Authentication::constants;
use pf::Authentication::Condition;
extends 'pf::Authentication::Source';

has '+type' => (default => 'AdminProxy');

has '+class' => (default => 'exclusive');

has 'proxy_addresses' => (is => 'rw', required => 1);

has 'user_header' => (is => 'rw', required => 1);

has 'group_header' => (is => 'rw', required => 1);

=head1 METHODS

=head2 available_attributes

=cut

sub available_attributes {
  my $self = shift;

  my $super_attributes = $self->SUPER::available_attributes;
  my @attributes = map { { value => $_, type => $Conditions::SUBSTRING } } qw(group_header);

  return [@$super_attributes, sort { $a->{value} cmp $b->{value} } @attributes];
}

=head2 available_actions

The only available action for this source is SET_ACCESS_LEVEL

=cut

sub available_actions {
    return [$Actions::SET_ACCESS_LEVEL];
}

=head2 available_rule_classes

This source has only admin rules

=cut

sub available_rule_classes {
    return [$Rules::ADMIN];
}


=head2 authenticate

Authenticate using the address and headers

=cut

sub authenticate {
    my ($self, $address, $headers) = @_;
    my @address = split /\s*,\s*/ , $self->proxy_addresses;
    return ($FALSE, 'Invalid proxy address') unless any { $_ eq $address } @address ;
    return ($TRUE, "Valid proxy address");
}

=head2 getUserFromHeader

get the user name from the headers

=cut

sub getUserFromHeader {
    my ($self,$headers) = @_;
    return $headers->header($self->user_header);
}

=head2 getGroupFromHeader

get the group from the headers

=cut

sub getGroupFromHeader {
    my ($self,$headers) = @_;
    return $headers->header($self->group_header);
}

=head2 match_in_subclass

Match against the group_header

=cut

sub match_in_subclass {
    my ($self, $params, $rule, $own_conditions, $matching_conditions) = @_;
    my $group_header =  $params->{'group_header'};
    foreach my $condition (@{ $own_conditions }) {
        if ($condition->{'attribute'} eq "group_header") {
            if ( $condition->matches("group_header", $group_header) ) {
                push(@{ $matching_conditions }, $group_header);
            }
        }
    }
    return $group_header;
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
