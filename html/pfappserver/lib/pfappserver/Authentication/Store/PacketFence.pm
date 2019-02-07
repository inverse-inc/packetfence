#!/usr/bin/perl

package pfappserver::Authentication::Store::PacketFence;

use base qw/Class::Accessor::Fast/;
use strict;
use warnings;

use pfappserver::Authentication::Store::PacketFence::User;
use Scalar::Util qw/blessed/;

our $VERSION = '0.001';

BEGIN { __PACKAGE__->mk_accessors(qw/file user_field user_class/) }

sub new {
  my ($class, $config, $app, $realm) = @_;

  $config->{user_class} ||= __PACKAGE__ . '::User';
  $config->{user_field} ||= 'username';

  bless { %$config }, $class;
}

sub find_user {
  my ($self, $authinfo, $c) = @_;
  my $username = $authinfo->{$self->user_field};
  my $roles = $c->session->{user_roles};
  $self->user_class->new($self, $username, $roles);
}

sub user_supports {
  my $self = shift;
  Catalyst::Authentication::Store::LDAP::User->supports(@_);
}

sub from_session {
  my ($self, $c, $username) = @_;
  $self->find_user({ username => $username }, $c);
}

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
