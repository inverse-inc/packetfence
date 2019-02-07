#!/usr/bin/perl

package pfappserver::Authentication::Store::PacketFence::User;
use base qw/Catalyst::Authentication::User Class::Accessor::Fast/;

use strict;
use warnings;

use pf::constants;
use pf::config qw($WEB_ADMIN_ALL);
use pf::authentication;
use pf::Authentication::constants qw($LOGIN_SUCCESS $LOGIN_CHALLENGE);
use pf::log;
use List::MoreUtils qw(all any);
use pf::config::util;
use pf::util;
use pf::constants::realm;

BEGIN { __PACKAGE__->mk_accessors(qw/_user _store _roles _challenge/) }

use overload '""' => sub { shift->id }, fallback => 1;

sub new {
  my ( $class, $store, $user, $roles ) = @_;

  return unless $user;
  $roles = [qw(NONE)] unless $roles;
  bless { _store => $store, _user => $user, _roles => $roles }, $class;

}

sub id {
  my $self = shift;
  return $self->_user;
}

sub supported_features {
  return {
    password => { self_check => 1, },
    session => 1,
    roles => 1,
  };
}

sub check_password {
  my ($self, $password) = @_;

  my ($result, $roles) = pf::authentication::adminAuthentication($self->_user, $password);
  if($result == $LOGIN_SUCCESS) {
    $self->_roles($roles);
    return $TRUE;
  }
  elsif($result == $LOGIN_CHALLENGE) {
    $self->_challenge();
  }
  else {
    return $FALSE;
  }
}

sub roles {
    my ($self) = @_;
    return @{$self->_roles};
}

*for_session = \&id;

*get_object = \&_user;

sub AUTOLOAD {
  my $self = shift;

  ( my $method ) = ( our $AUTOLOAD =~ /([^:]+)$/ );

  return if $method eq "DESTROY";

  $self->_user->$method;
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
