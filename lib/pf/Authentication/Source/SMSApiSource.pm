package pf::Authentication::Source::SMSApiSource;

=head1 NAME

pf::Authentication::Source::SMSApiSource

=head1 DESCRIPTION

An SMS source using a Clickatell compatible HTTP API on a configurable URL.

=cut

use pf::Authentication::constants;
use pf::constants qw($TRUE $FALSE);
use pf::log;
use LWP::UserAgent;
use URI;
use URI::Escape::XS qw(uri_escape);

use Moose;

extends 'pf::Authentication::Source';
with qw(pf::Authentication::CreateLocalAccountRole pf::Authentication::SMSRole);


has '+type'                     => (default => 'SMSApi');
has '+class'                    => (isa => 'Str', is => 'ro', default => 'external');
has '+dynamic_routing_module'   => (is => 'rw', default => 'Authentication::SMS');
has 'api_protocol'              => (isa => 'Str', is => 'rw', default => 'https');
has 'api_url'                   => (isa => 'Str', is => 'rw');
has 'api_key'                   => (isa => 'Str', is => 'rw');
has 'message'                   => (isa => 'Maybe[Str]', is => 'rw', default => 'PIN: $pin');
has 'timeout'                   => (isa => 'Int', is => 'rw', default => 10);

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
    return ($params->{'username'}, undef);
}


=head2 build_api_url

Build the full URL from api_protocol and api_url.
Anything other than 'http' in api_protocol is sent over https, so a hand edited
configuration can't select another scheme.
Returns undef when api_url is empty, contains whitespace, carries its own scheme,
has no host or has a non numeric port

=cut

sub build_api_url {
    my ($protocol, $url) = @_;
    return undef unless defined $url && length $url;
    return undef if $url =~ /\s/;
    return undef if $url =~ m{^[a-z][a-z0-9+.-]*://}i;
    my $scheme = (defined $protocol && $protocol eq 'http') ? 'http' : 'https';
    my $uri = URI->new("$scheme://$url");
    # [userinfo@]host[:port] where host is a name, an IPv4 or a bracketed IPv6
    # address and the port, when present, is numeric and in range
    my $authority = $uri->authority // '';
    return undef unless $authority =~ m{^(?:[^@]*@)?(?:\[[0-9A-Fa-f:.]+\]|[^:\[\]@]+)(?::(\d{1,5}))?$};
    my $port = $1;
    return undef if defined $port && ($port < 1 || $port > 65535);
    return $uri;
}

=head2 sendSMS

Use the configured API url to send an SMS

=cut

sub sendSMS {
    my ($self, $info) = @_;
    my $to = $info->{to};
    my $message = $info->{message};
    my $logger = pf::log::get_logger;

    my $url = $self->api_url // '';
    my $uri = build_api_url($self->api_protocol, $url);
    unless ($uri) {
        $logger->error("Can't send SMS to '$to': api_url '$url' on source " . $self->id . " is not a valid URL without a protocol");
        return $FALSE;
    }

    # Merge into any query the configured URL already carries; a fragment would swallow the query.
    # Encoded with uri_escape (space as %20) to stay byte identical with ClickatellSource
    $uri->fragment(undef);
    my $query = join('&',
        "apiKey=" . uri_escape($self->api_key // ''),
        "to=" . uri_escape($to // ''),
        "content=" . uri_escape($message // ''),
    );
    my $existing = $uri->query;
    $uri->query(defined $existing && length $existing ? "$existing&$query" : $query);

    # Never follow redirects: the apiKey is in the query string and would be
    # re-sent to wherever the gateway points (possibly over plain http)
    my $ua = LWP::UserAgent->new(timeout => $self->timeout, max_redirect => 0);
    my $response = $ua->get($uri);

    unless($response->is_success) {
        $logger->error("Can't send SMS to '$to': " . $response->status_line);
        return $FALSE;
    }

    $logger->info("SMS sent to '$to' (Network Activation)");
    return $TRUE;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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
