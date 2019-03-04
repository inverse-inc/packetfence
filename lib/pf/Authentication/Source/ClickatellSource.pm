package pf::Authentication::Source::ClickatellSource;

=head1 NAME

pf::Authentication::Source::ClickatellSource

=head1 DESCRIPTION

=cut

use pf::Authentication::constants;
use pf::constants qw($TRUE $FALSE);
use pf::error qw(is_success);
use pf::log;
use URI::Escape::XS qw(uri_escape);

use Moose;

extends 'pf::Authentication::Source';
with qw(pf::Authentication::CreateLocalAccountRole pf::Authentication::SMSRole);


has '+type'                     => (default => 'Clickatell');
has '+class'                    => (isa => 'Str', is => 'ro', default => 'external');
has '+dynamic_routing_module'   => (is => 'rw', default => 'Authentication::SMS');
has 'api_key'                   => (isa => 'Str', is => 'rw');
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

  return [@$super_attributes];
}

=head2 match_in_subclass

=cut

sub match_in_subclass {
    my ($self, $params, $rule, $own_conditions, $matching_conditions) = @_;
    return $params->{'username'};
}


=head2 sendSMS

Use Clickatell url to send an SMS

=cut

sub sendSMS {
    my ($self, $info) = @_;
    my $to = $info->{to};
    my $message = $info->{message};
    my $api_key = $self->api_key;
    my $logger = pf::log::get_logger;

    use LWP::UserAgent;

    my $url = "https://platform.clickatell.com/messages/http/send";
    my $query = join("&",
        "apiKey=".uri_escape($api_key), 
        "to=".uri_escape($to), 
        "content=".uri_escape($message),
    );

    my $ua = LWP::UserAgent->new;
    my $response = $ua->get("$url?$query");
 
    unless($response->is_success) {
        $logger->error("Can't send SMS to '$to': " . $response->{'message'});
        return $FALSE;
    }

    $logger->info("SMS sent to '$to' (Network Activation)");
    return $TRUE;
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
