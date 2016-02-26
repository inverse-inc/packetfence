package pf::Authentication::Source::RADIUSSource;

=head1 NAME

pf::Authentication::Source::RADIUSSource

=head1 DESCRIPTION

=cut

use pf::constants qw($TRUE $FALSE);
use pf::Authentication::constants;
use pf::constants::authentication::messages;
use pf::log;

use Authen::Radius;

use Moose;
extends 'pf::Authentication::Source';

has '+type' => ( default => 'RADIUS' );
has 'host' => (isa => 'Maybe[Str]', is => 'rw', default => '127.0.0.1');
has 'port' => (isa => 'Maybe[Int]', is => 'rw', default => 1812);
has 'secret' => (isa => 'Str', is => 'rw', required => 1);
has 'stripped_user_name' => (isa => 'Str', is => 'rw', default => 'yes');

=head2 dynamic_routing_module

Which module to use for DynamicRouting

=cut

sub dynamic_routing_module { 'Authentication::Login' }

sub available_attributes {
  my $self = shift;

  my $super_attributes = $self->SUPER::available_attributes;
  my $own_attributes = [{ value => "username", type => $Conditions::SUBSTRING }];

  return [@$super_attributes, @$own_attributes];
}

=head2  authenticate

=cut

sub authenticate {

  my ( $self, $username, $password ) = @_;

  my $logger = get_logger();

  my $radius = new Authen::Radius(
    Host => "$self->{'host'}:$self->{'port'}",
    Secret => $self->{'secret'},
  );

  if (defined $radius) {
     my $result = $radius->check_pwd($username, $password);

     if ($radius->get_error() eq 'ENONE') {

       if ($result) {
        return ($TRUE, $AUTH_SUCCESS_MSG);
      } else {
        return ($FALSE, $AUTH_FAIL_MSG);
       }
     }
   }

   $logger->error("Unable to perform RADIUS authentication on any server: " . Authen::Radius::get_error() );

   return ($FALSE, $COMMUNICATION_ERROR_MSG);
 }

=head2 match_in_subclass

=cut

sub match_in_subclass {
    my ($self, $params, $rule, $own_conditions, $matching_conditions) = @_;
    $params->{'username'} = $params->{'stripped_user_name'} if (defined($params->{'stripped_user_name'} ) && $params->{'stripped_user_name'} ne '' && isenabled($self->{'stripped_user_name'}));
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

__PACKAGE__->meta->make_immutable;
1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
