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
use pf::config;
use pf::Authentication::constants;
use pf::Authentication::Condition;
extends 'pf::Authentication::Source';

has '+type' => (default => 'AdminProxy');

has '+class' => (default => 'admin');

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

=head2 authenticate

=cut

sub authenticate {
    my ($self, $username, $password) = @_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__);
    return ($FALSE, 'Invalid login or password');
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
