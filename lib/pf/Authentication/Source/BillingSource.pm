package pf::Authentication::Source::BillingSource;
=head1 NAME

pf::Authentication::Source::BillingSource

=cut

=head1 DESCRIPTION

pf::Authentication::Source::BillingSource

=cut

use strict;
use warnings;
use Moose;
use pf::config qw($default_pid $fqdn %Config);
use pf::constants qw($TRUE $FALSE);
use pf::Authentication::constants;
use pf::util;
use utf8;
use Locale::gettext qw(gettext ngettext);

extends 'pf::Authentication::Source';
with 'pf::Authentication::CreateLocalAccountRole';

=head2 Attributes

=head2 class

=cut

has '+class' => (default => 'abstact');

has '+type' => (default => 'Billing');

has 'currency' => (is => 'rw', default => 'USD');

has 'test_mode' => (is => 'rw', isa => 'Bool');

has 'send_email_confirmation' => (is => 'rw', default => 'disabled');

=head2 dynamic_routing_module

Which module to use for DynamicRouting

=cut

sub dynamic_routing_module { 'Authentication::Billing' }

=head2 has_authentication_rules

Whether or not the source should have authentication rules

=cut

sub has_authentication_rules { $FALSE }

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
    return [ ];
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

sub verify_url {
    my ($self, $iframe) = @_;
    my $base_path = $self->_build_base_path;
    $iframe //= $self->iframe;
    my $url = "$base_path/verify";
    if ($iframe) {
        $url .= '?iframe=1';
    }
    return $url;
}

=head2 iframe

Is in an iframe

=cut

sub iframe { 0 }

sub cancel_url {
    my ($self) = @_;
    my $base_path = $self->_build_base_path;
    return "$base_path/cancel";
}

sub _build_base_path {
    my ($self) = @_;
    my $id     = $self->id;
    my $base_path = "https://$fqdn/billing/$id";
    return $base_path;
}

=head2 prepare_payment

Prepare payment to display payments

=cut

sub prepare_payment {
    my ($self, $session, $tier, $params, $uri) = @_;
    return {};
}

=head2 verify

Verify the payment

=cut

sub verify {
    my ($self, $session, $parameters, $uri) = @_;
    return {};
}

=head2 cancel

Cancel the payment

=cut

sub cancel {
    my ($self, $session, $parameters, $uri) = @_;
    return {};
}

=head2 handle_hook

Handle hook from billing provider

=cut

sub handle_hook {
    my ($self) = @_;
    return ;
}

=head2 confirmationInfo

confirmationInfo

=cut

sub confirmationInfo {
    my ($self, $parameters, $tier, $session) = @_;
    require pf::web::constants;
    return {
        'firstname'        => $parameters->{firstname},
        'lastname'         => $parameters->{lastname},
        'email'            => $parameters->{email},
        'tier_name'        => $tier->{'name'},
        'tier_description' => $tier->{'description'},
        'tier_price'       => $tier->{'price'},
        'hostname'         => $Config{'general'}{'hostname'},
        'domain'           => $Config{'general'}{'domain'},
        'subject'          => i18n_format("%s: Network Access Order Confirmation", $Config{'general'}{'domain'}),
        pf::web::constants::to_hash(),
        $self->additionalConfirmationInfo($parameters, $tier, $session),
      };
}

=head2 i18n_format

Pass message id through gettext then sprintf it.

Meant to be called from the TT templates.

=cut

sub i18n_format {
    my ($msgid, @args) = @_;

    my $result = sprintf(gettext($msgid), @args);
    utf8::decode($result);
    return $result;
}

=head2 additionalConfirmationInfo

additionalConfirmationInfo

=cut

sub additionalConfirmationInfo { }

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and::or
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
