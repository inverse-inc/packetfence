package pf::Authentication::Source::TeltonikaSMSGatewaySource;

=head1 NAME

pf::Authentication::Source::TeltonikaSMSGatewaySource

=head1 DESCRIPTION

=cut

use pf::Authentication::constants;
use pf::constants qw($TRUE $FALSE);
use pf::error qw(is_success);
use pf::log;
use URI::Escape::XS qw(uri_escape);
use JSON;

use Moose;

extends 'pf::Authentication::Source';
with qw(pf::Authentication::CreateLocalAccountRole pf::Authentication::SMSRole);


has '+type'                     => (default => 'TeltonikaSMSGateway');
has '+class'                    => (default => 'external');
has '+dynamic_routing_module'   => (is => 'rw', default => 'Authentication::SMS');
has 'url'                       => (isa => 'Str', is => 'rw', default => 'https://192.168.1.1');
has 'username'                  => (isa => 'Str', is => 'rw', default => 'admin');
has 'password'                  => (isa => 'Str', is => 'rw');
has 'message'                   => (isa => 'Maybe[Str]', is => 'rw', default => 'PIN: $pin');

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
  my $own_attributes = [
    { value => "username", type => $Conditions::SUBSTRING },
    { value => "password", type => $Conditions::SUBSTRING },
    { value => "url",      type => $Conditions::SUBSTRING }
  ];

  return [@$super_attributes, @$own_attributes];
}

=head2 match_in_subclass

=cut

sub match_in_subclass {
    my ($self, $params, $rule, $own_conditions, $matching_conditions) = @_;
    return ($params->{'username'}, undef);
}


=head2 sendSMS

Use TeltonikaSMSGateway url to send an SMS

=cut

sub sendSMS {
    my ($self, $info) = @_;
    my $to = $info->{to};
    my $url = $self->url;
    my $username = $self->username;
    my $password = $self->password;
    my $message = $info->{message};
    my $logger = pf::log::get_logger;

    use LWP::UserAgent;

    my %login_params = (
        "username" => $username,
        "password" => $password,
    );

    my $json_login_params = encode_json(\%login_params);

    my %params = (
        'data' => {
            'number' => $to,
            'message' => $message,
            'modem' => "1-1"
        }
    );

    my $json_params = encode_json(\%params);

    my $ua = LWP::UserAgent->new;
    $ua->ssl_opts(verify_hostname => 0);

    my $login_response = $ua->post("$url/api/login", Content => $json_login_params, 'Content-Type' => 'application/json');
    unless($login_response->is_success) {
        $logger->error("Can't login to '$url': " . $login_response->as_string());
        return $FALSE;
    }

    my $login_content = decode_json($login_response->decoded_content);
    my $token = $login_content->{'data'}->{'token'};

    my $response = $ua->post("$url/api/messages/actions/send", Content => $json_params, Authorization => "Bearer $token", 'Content-Type' => 'application/json');

    unless($response->is_success) {
        $logger->error("Can't send SMS to '$to': " . $response->as_string());
        return $FALSE;
    }

    $logger->info("SMS sent to '$to' (Network Activation)");
    return $TRUE;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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