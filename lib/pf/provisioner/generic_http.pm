package pf::provisioner::generic_http;

=head1 NAME

pf::provisioner::generic_http

=cut

=head1 DESCRIPTION

Generic HTTP provisioner. The HTTP request (URL, headers, body) is defined in
the configuration as pf::mini_template templates. The response body is
evaluated with a jq query (JQ::XS, backed by libjq); the device is authorized
when the query returns a truthy value (jq semantics: only C<null> and C<false>
are falsy).

=cut

use strict;
use warnings;
use Moo;
extends 'pf::provisioner';

use pf::log;
use pf::provisioner;
use pf::constants;
use pf::util qw(isdisabled);
use pf::mini_template;
use pf::node;
use LWP::UserAgent;
use HTTP::Request;
use JQ::XS;
use JSON::MaybeXS qw(decode_json);
use List::MoreUtils qw(any);
use Scalar::Util qw(blessed);

=head1 Attributes

=head2 method

The HTTP method of the request (GET, POST, PUT, PATCH or DELETE)

=cut

has method => (is => 'rw', default => 'GET');

=head2 url

The URL of the request (a pf::mini_template template)

=cut

has url => (is => 'rw', required => $TRUE);

=head2 headers

The headers of the request, one "Name: value" per line.
Both the name and the value are pf::mini_template templates.

=cut

has headers => (is => 'rw', default => '');

=head2 body

The body of the request (a pf::mini_template template).
Only sent for POST, PUT and PATCH requests.

=cut

has body => (is => 'rw', default => '');

=head2 content_type

The Content-Type of the request body

=cut

has content_type => (is => 'rw', default => 'application/json');

=head2 timeout

Timeout in seconds of the request

=cut

has timeout => (is => 'rw', default => 10);

=head2 username

Optional HTTP basic authentication username

=cut

has username => (is => 'rw');

=head2 password

Optional HTTP basic authentication password

=cut

has password => (is => 'rw');

=head2 verify_ssl

Whether or not the TLS certificate of the server is verified

=cut

has verify_ssl => (is => 'rw', default => 'enabled');

=head2 ca_file

Path of the CA certificate used to verify the server certificate

=cut

has ca_file => (is => 'rw');

=head2 client_cert_file

Path of the client TLS certificate

=cut

has client_cert_file => (is => 'rw');

=head2 client_key_file

Path of the client TLS private key

=cut

has client_key_file => (is => 'rw');

=head2 jq_query

The jq query applied to the response body.
The device passes when the query returns a truthy value.

=cut

has jq_query => (is => 'rw', required => $TRUE);

has url_tmpl => (is => 'lazy');

sub _build_url_tmpl {
    my ($self) = @_;
    return pf::mini_template->new($self->url);
}

has body_tmpl => (is => 'lazy');

sub _build_body_tmpl {
    my ($self) = @_;
    my $body = $self->body;
    return undef if !defined $body || $body eq '';
    return pf::mini_template->new($body);
}

has header_tmpls => (is => 'lazy');

sub _build_header_tmpls {
    my ($self) = @_;
    my @tmpls;
    for my $line (split /\r?\n/, ($self->headers // '')) {
        next if $line =~ /^\s*$/;
        my ($name, $value) = $line =~ /^\s*([^:]+?)\s*:\s*(.*)$/;
        if (!defined $name) {
            $self->logger->warn("Invalid header line '$line' in provisioner " . $self->id . ", expecting 'Name: value'");
            next;
        }

        push @tmpls, [pf::mini_template->new($name), pf::mini_template->new($value)];
    }

    return \@tmpls;
}

our %LOOKUP = (
    node => sub {
        my ($self, $mac, $node_info) = @_;
        return $node_info // node_view($mac);
    },
);

=head2 make_vars

Build the template variables for a MAC.
$mac is always available, $node.* is looked up lazily only when a template references it.

=cut

sub make_vars {
    my ($self, $mac, $node_info) = @_;
    my $vars = { mac => $mac };
    my @set = map { { tmpl => $_ } } grep { defined } (
        $self->url_tmpl,
        $self->body_tmpl,
        map { @$_ } @{ $self->header_tmpls }
    );
    pf::mini_template::update_variables_for_set(\@set, \%LOOKUP, $vars, $self, $mac, $node_info);
    return $vars;
}

=head2 make_request

Build the HTTP::Request from the configured templates.
Returns ($request, undef) on success, (undef, $error) on template failure.

=cut

sub make_request {
    my ($self, $mac, $node_info) = @_;
    my $req = eval {
        my $vars = $self->make_vars($mac, $node_info);
        my $method = uc($self->method || 'GET');
        my $r = HTTP::Request->new($method => $self->url_tmpl->process($vars));
        if (defined $self->username && $self->username ne '') {
            $r->authorization_basic($self->username, $self->password // '');
        }

        # set after basic auth so an explicit Authorization header wins
        for my $h (@{ $self->header_tmpls }) {
            $r->header($h->[0]->process($vars), $h->[1]->process($vars));
        }

        if (defined $self->body_tmpl && $method =~ /^(?:POST|PUT|PATCH)$/) {
            my $content_type = $self->content_type;
            if (!$r->content_type && defined $content_type && $content_type ne '') {
                $r->content_type($content_type);
            }

            $r->content($self->body_tmpl->process($vars));
        }

        $r;
    };
    if ($@) {
        return (undef, $@);
    }

    return ($req, undef);
}

=head2 get_lwp_client

Build the LWP::UserAgent with the configured timeout and TLS options

=cut

sub get_lwp_client {
    my ($self) = @_;
    my %ssl_opts;
    if (isdisabled($self->verify_ssl)) {
        $ssl_opts{verify_hostname} = 0;
        $ssl_opts{SSL_verify_mode} = 0x00;
    }

    my %files = (
        SSL_ca_file   => $self->ca_file,
        SSL_cert_file => $self->client_cert_file,
        SSL_key_file  => $self->client_key_file,
    );
    while (my ($opt, $file) = each %files) {
        $ssl_opts{$opt} = $file if defined $file && $file ne '';
    }

    my $timeout = $self->timeout;
    $timeout = 10 if !defined $timeout || $timeout !~ /^\d+$/ || $timeout == 0;
    return LWP::UserAgent->new(
        timeout => $timeout,
        (%ssl_opts ? (ssl_opts => \%ssl_opts) : ()),
    );
}

=head2 evaluate_jq

Evaluate a jq query (JQ::XS) against a JSON string.
Callable as a class method so the admin API tester can reuse it.
Returns ($pass, \@results, undef) on success, (undef, undef, $error) on
failure (invalid JSON, invalid query or a jq runtime error).
jq truthiness: a result passes unless every result is null or false (an empty
result set fails).

=cut

sub evaluate_jq {
    my ($class, $json_text, $query) = @_;
    my @results = eval { JQ::XS->new($query)->process(decode_json($json_text)) };
    if ($@) {
        my $err = $@;
        chomp $err;
        return (undef, undef, $err);
    }

    my $pass = (any { _jq_truthy($_) } @results) ? $TRUE : $FALSE;
    return ($pass, \@results, undef);
}

sub _jq_truthy {
    my ($v) = @_;
    return 0 if !defined $v;
    # boolean objects (JSON::PP::Boolean, ...) use their overloaded bool; jq
    # considers everything else truthy, including 0 and ""
    return !!$v ? 1 : 0 if blessed($v);
    return 1;
}

=head2 authorize

Send the templated request and evaluate the response with the jq query

=cut

sub authorize {
    my ($self, $mac, $node_info) = @_;
    my $logger = $self->logger;
    my ($req, $err) = $self->make_request($mac, $node_info);
    if (defined $err) {
        $logger->error("Cannot build the request of provisioner " . $self->id . " for $mac: $err");
        return $pf::provisioner::COMMUNICATION_FAILED;
    }

    my $res = $self->get_lwp_client->request($req);
    if (!$res->is_success) {
        $logger->error("Provisioner " . $self->id . " failed to communicate with " . $req->uri . ": " . $res->status_line);
        return $pf::provisioner::COMMUNICATION_FAILED;
    }

    my ($pass, $results, $jq_err) = $self->evaluate_jq($res->decoded_content, $self->jq_query);
    if (defined $jq_err) {
        # The server answered, a broken query or payload is a configuration error, not a communication error
        $logger->error("Provisioner " . $self->id . " failed to evaluate its jq query for $mac: $jq_err");
        return $FALSE;
    }

    $node_info //= node_view($mac);
    return $self->handleAuthorizeEnforce(
        $mac,
        {
            node_info       => $node_info,
            generic_http    => $results->[0],
            compliant_check => ($pass ? 1 : 0),
        },
        ($pass ? $TRUE : $FALSE)
    );
}

=head2 logger

Return the current logger for the provisioner

=cut

sub logger {
    my ($proto) = @_;
    return get_logger( ref($proto) || $proto );
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

1;
