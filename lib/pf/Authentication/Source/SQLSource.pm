package pf::Authentication::Source::SQLSource;

=head1 NAME

pf::Authentication::Source::SQLSource

=head1 DESCRIPTION

=cut

use pf::constants qw($TRUE $FALSE);
use pf::password;
use pf::Authentication::constants;
use pf::constants::authentication::messages;
use pf::Authentication::Action;
use pf::Authentication::Source;

use Moose;
extends 'pf::Authentication::Source';
with qw(pf::Authentication::InternalRole);

has '+type' => ( default => 'SQL' );

=head1 METHODS

=head2 dynamic_routing_module

Which module to use for DynamicRouting

=cut

sub dynamic_routing_module { 'Authentication::Login' }

=head2 available_attributes

=cut

sub available_attributes {
  my $self = shift;

  my $super_attributes = $self->SUPER::available_attributes;
  my $own_attributes = [{ value => "username", type => $Conditions::SUBSTRING }];

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

=head2 match

The SQLSource class overrides the match method of the Source parent class.

It has no conditions and therefore acts as a catchall as long as the username is found
in the password table.

The actions are defined in the password table and can be modified for each user
through the web admin interface.

=cut

sub match {
    my ($self, $params) = @_;
    my $common_attributes = $self->common_attributes();

    my $result;
    if ($params->{'username'}) {
        $result = pf::password::view($params->{'username'});
    } elsif ($params->{'email'}) {
        $result = pf::password::view_email($params->{'email'});
    }

    # User is defined in SQL source, let's build the actions and return that
    if (defined $result) {

        my @actions = ();
        my $action;

        my $access_duration = $result->{'access_duration'};
        if (defined $access_duration) {
            $action = pf::Authentication::Action->new({
                type    => $Actions::SET_ACCESS_DURATION,
                value   => $access_duration,
                class   => pf::Authentication::Action->getRuleClassForAction($Actions::SET_ACCESS_DURATION),
            });
            push(@actions, $action);
        }

        my $access_level = $result->{'access_level'};
        if (defined $access_level ) {
            $action = pf::Authentication::Action->new({
                type    => $Actions::SET_ACCESS_LEVEL,
                value   => $access_level,
                class   => pf::Authentication::Action->getRuleClassForAction($Actions::SET_ACCESS_LEVEL),
            });
            push(@actions, $action);
        }

        my $sponsor = $result->{'sponsor'};
        if ($sponsor == 1) {
            $action = pf::Authentication::Action->new({
                type    => $Actions::MARK_AS_SPONSOR,
                value   => 1,
                class   => pf::Authentication::Action->getRuleClassForAction($Actions::MARK_AS_SPONSOR),
            });
            push(@actions, $action);
        }

        my $unregdate = $result->{'unregdate'};
        if (defined $unregdate) {
            $action = pf::Authentication::Action->new({
                type    => $Actions::SET_UNREG_DATE,
                value   => $unregdate,
                class   => pf::Authentication::Action->getRuleClassForAction($Actions::SET_UNREG_DATE),
            });
            push(@actions, $action);
        }

        my $category = $result->{'category'};
        if (defined $category) {
            $action = pf::Authentication::Action->new({
                type    => $Actions::SET_ROLE,
                value   => $category,
                class   => pf::Authentication::Action->getRuleClassForAction($Actions::SET_ROLE),
            });
            push(@actions, $action);
        }

        my $time_balance = $result->{'time_balance'};
        if (defined $time_balance) {
            $action =  pf::Authentication::Action->new({type => $Actions::SET_TIME_BALANCE,
                                                        value => $time_balance});
            push(@actions, $action);
        }

        my $bandwidth_balance = $result->{'bandwidth_balance'};
        if (defined $bandwidth_balance) {
            $action =  pf::Authentication::Action->new({type => $Actions::SET_BANDWIDTH_BALANCE,
                                                        value => $bandwidth_balance});
            push(@actions, $action);
        }


        return \@actions;
    }

    return undef;
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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};
1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
