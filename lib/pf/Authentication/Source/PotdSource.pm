package pf::Authentication::Source::PotdSource;

=head1 NAME

pf::Authentication::Source::PotdSource

=head1 DESCRIPTION

=cut

use pf::Authentication::constants;
use pf::constants::authentication::messages;
use pf::Authentication::Source;
use pf::constants;
use pf::password;
use pf::constants qw($TRUE $FALSE);

use Moose;
extends 'pf::Authentication::Source';
with qw(pf::Authentication::InternalRole);

has '+type' => ( default => 'Potd' );
has 'password_rotation' => (isa => 'Str', is => 'rw', default => '10m');
has 'password_email_update' => (isa => 'Maybe[Str]', is => 'rw');
has 'password_length' => (isa => 'Maybe[Int]', is => 'rw', default => 8);

=head2 available_attributes

=cut

sub available_attributes {
    my $self = shift;

    my $super_attributes = $self->SUPER::available_attributes;
    my $own_attributes = [{ value => 'username', type => $Conditions::SUBSTRING }];

    return [@$super_attributes, @$own_attributes];
}

=head2 authenticate

=cut

sub authenticate {
   my ( $self, $username, $password ) = @_;

   my $result = pf::password::validate_password($username, $password);

   if ($result == $pf::password::AUTH_SUCCESS) {
     return ($TRUE, $AUTH_SUCCESS_MSG);
   }

   return ($FALSE, $AUTH_FAIL_MSG);
}

=head2 match_in_subclass

=cut

sub match_in_subclass {
    my ($self, $params, $rule, $own_conditions, $matching_conditions) = @_;
    foreach my $condition (@{ $own_conditions }) {
        if ($condition->{'attribute'} eq "username") {
            if ( $condition->matches("username", $params->{'username'}) ) {
                push(@{ $matching_conditions }, $condition);
            }
        }
    }
    return $params->{'username'};
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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};
1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:


