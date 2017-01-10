package pf::Authentication::Source::TwilioSource;

=head1 NAME

pf::Authentication::Source::TwilioSource

=head1 DESCRIPTION

=cut

use pf::Authentication::constants;
use pf::constants qw($TRUE $FALSE);
use pf::error qw(is_success);
use pf::log;

use Moose;
use WWW::Twilio::API;

extends 'pf::Authentication::Source';

has '+type'                     => (default => 'Twilio');
has '+class'                    => (isa => 'Str', is => 'ro', default => 'external');
has '+dynamic_routing_module'   => (is => 'rw', default => 'Authentication::SMS');
has 'can_send_sms'              => (isa => 'Bool', is => 'rw', default => $TRUE);
has 'api_url'                   => (isa => 'Maybe[Str]', is => 'rw', default => 'https://api.twilio.com/2010-04-01/Accounts/$account_sid/Messages.json');
has 'account_sid'               => (isa => 'Str', is => 'rw');
has 'auth_token'                => (isa => 'Str', is => 'rw');
has 'twilio_phone_number'       => (isa => 'Str', is => 'rw', default => '+15555551234');


=head2 available_rule_classes

Only allow 'authentication' rules

=cut

sub available_rule_classes {
    return [ grep { $_ ne $Rules::ADMIN } @Rules::CLASSES ];
}


=head2 available_actions

Only allow 'authentication' actions

=cut

sub available_actions {
    my @actions = map( { @$_ } $Actions::ACTIONS{$Rules::AUTH});
    return \@actions;
}


=head2 available_attributes

Allow to make a condition on the provided phone number

=cut

sub available_attributes {
  my $self = shift;

  my $super_attributes = $self->SUPER::available_attributes;
  my $own_attributes = [{ value => "phonenumber", type => $Conditions::SUBSTRING }];

  return [@$super_attributes, @$own_attributes];
}


=head2 mandatoryFields

List of mandatory fields for this source

=cut

sub mandatoryFields {
    return qw(telephone);
}


=head2 match_in_subclass

=cut

sub match_in_subclass {
    my ($self, $params, $rule, $own_conditions, $matching_conditions) = @_;
    return $params->{'username'};
}


=head2 sendSMS

Interact with Twilio API to send an SMS

=cut

sub sendSMS {
    my ( $self, $activation_code ) = @_;
    my $logger = pf::log::get_logger;

    my ($hash_version, $pin) = pf::activation::_unpack_activation_code($activation_code);
    my $activation = pf::activation::view_by_code($activation_code);
    my $phone_number = $activation->{'contact_info'};

    my $twilio = WWW::Twilio::API->new(
        AccountSid  => $self->account_sid,
        AuthToken   => $self->auth_token,
    );

    my $response = $twilio->POST(
        'Messages',
        From    => $self->twilio_phone_number,
        To      => $phone_number,
        Body    => "PIN: $pin",
    );

    unless ( is_success($response->{'code'}) ) {
        $logger->error("Can't send SMS to '$phone_number': " . $response->{'message'});
        return $FALSE;
    }

    $logger->info("SMS sent to '$phone_number' (Network Activation)");
    return $TRUE;
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

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
