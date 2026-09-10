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
use JSON::MaybeXS qw(decode_json encode_json);
use POSIX qw(:sys_wait_h);
use List::MoreUtils qw(any);
use Scalar::Util qw(blessed);

=head1 CONSTANTS

=head2 $MAX_RESPONSE_SIZE

Largest response body handed to the jq query. A jq program runs to completion
inside libjq and cannot be interrupted from Perl, so the input it is given is
bounded instead.

=cut

our $MAX_RESPONSE_SIZE = 8 * 1024 * 1024;

=head2 Error kinds

The kind of failure reported by L</evaluate_jq>: C<$ERR_JSON> when the payload
is not valid JSON, C<$ERR_QUERY> when the jq program does not compile and
C<$ERR_JQ> for a jq runtime error. Only C<$ERR_QUERY> is a configuration
error; the other two describe what the server answered.

=cut

our $ERR_JSON  = 'json';
our $ERR_QUERY = 'query';
our $ERR_JQ    = 'jq';

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

=head2 jq

The compiled jq program of L</jq_query>. The query is a constant of the
configuration and authorize runs on the RADIUS path, so it is compiled once
per provisioner instead of on every call.

=cut

has jq => (is => 'lazy');

sub _build_jq {
    my ($self) = @_;
    return JQ::XS->new($self->jq_query);
}

=head2 lwp_client

The LWP::UserAgent of this provisioner, built once so requests to the same
server can reuse a connection.

=cut

has lwp_client => (is => 'lazy', builder => 'get_lwp_client');

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

        # set after basic auth so an explicit Authorization header wins.
        # The first occurrence of a name replaces (so it beats basic auth),
        # any repeat of that same name is appended rather than overwriting it.
        my %seen;
        for my $h (@{ $self->header_tmpls }) {
            my $name  = $h->[0]->process($vars);
            my $value = $h->[1]->process($vars);
            if ($seen{lc $name}++) {
                $r->push_header($name, $value);
            } else {
                $r->header($name, $value);
            }
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
Returns ($pass, \@results, undef, undef) on success and
(undef, undef, $error, $kind) on failure, where $kind is one of $ERR_JSON,
$ERR_QUERY or $ERR_JQ so the caller can tell a configuration error from a bad
payload.
An already compiled JQ::XS program can be passed as the fourth argument to
avoid recompiling $query.
jq truthiness: a result passes unless every result is null or false (an empty
result set fails).

=cut

sub evaluate_jq {
    my ($proto, $json_text, $query, $jq) = @_;
    if (defined $json_text && length($json_text) > $MAX_RESPONSE_SIZE) {
        return (undef, undef, "payload is larger than $MAX_RESPONSE_SIZE bytes", $ERR_JSON);
    }

    my $data = eval { decode_json($json_text) };
    if ($@) {
        return (undef, undef, _clean_err($@), $ERR_JSON);
    }

    if (!defined $jq) {
        $jq = eval { JQ::XS->new($query) };
        if ($@) {
            return (undef, undef, _clean_err($@), $ERR_QUERY);
        }
    }

    my @results = eval { $jq->process($data) };
    if ($@) {
        return (undef, undef, _clean_err($@), $ERR_JQ);
    }

    my $pass = (any { _jq_truthy($_) } @results) ? $TRUE : $FALSE;
    return ($pass, \@results, undef, undef);
}

sub _clean_err {
    my ($err) = @_;
    $err = "$err";
    chomp $err;
    # drop the "at <file> line <n>." Perl adds: it is noise in a log line and
    # this text is shown to the admin by the tester
    $err =~ s/ at \S+ line \d+\.?$//;
    return $err;
}

=head2 evaluate_jq_guarded

Same as L</evaluate_jq> but bounded in time. A jq program cannot be
interrupted once it is running inside libjq, so the evaluation is done in a
child process that is killed when it overruns $timeout seconds (5 by default).
Used by the admin tester, where the query is arbitrary and untrusted.

=cut

sub evaluate_jq_guarded {
    my ($proto, $json_text, $query, $timeout) = @_;
    $timeout = 5 if !defined $timeout || $timeout !~ /^\d+$/ || $timeout == 0;
    my ($reader, $writer);
    if (!pipe($reader, $writer)) {
        return (undef, undef, "cannot create a pipe: $!", $ERR_JQ);
    }

    {
        my $pid = fork();
        if (!defined $pid) {
            close $reader;
            close $writer;
            return (undef, undef, "cannot fork: $!", $ERR_JQ);
        }

        if ($pid == 0) {
            # child: report back and leave without running the parent's END
            # blocks or tearing down its inherited handles
            close $reader;
            my ($pass, $results, $err, $kind) = $proto->evaluate_jq($json_text, $query);
            eval {
                print {$writer} encode_json({
                    pass    => (defined $pass ? ($pass ? 1 : 0) : undef),
                    results => $results,
                    error   => $err,
                    kind    => $kind,
                });
            };
            close $writer;
            POSIX::_exit(0);
        }

        close $writer;
        my $payload;
        my $ok = eval {
            local $SIG{ALRM} = sub { die "timeout\n" };
            alarm $timeout;
            local $/;
            $payload = <$reader>;
            alarm 0;
            1;
        };
        alarm 0;
        close $reader;
        if (!$ok) {
            kill 'KILL', $pid;
            waitpid($pid, 0);
            return (undef, undef, "the query did not complete within ${timeout}s", $ERR_JQ);
        }

        waitpid($pid, 0);
        my $out = eval { decode_json($payload // '') };
        if (!defined $out) {
            return (undef, undef, "the query could not be evaluated", $ERR_JQ);
        }

        if (defined $out->{error}) {
            return (undef, undef, $out->{error}, $out->{kind});
        }

        return (($out->{pass} ? $TRUE : $FALSE), ($out->{results} // []), undef, undef);
    }
}

=head2 _log_uri

The request URI with its query string redacted: it can carry an API key or a
token and this ends up in the logs.

=cut

sub _log_uri {
    my ($uri) = @_;
    my $safe = eval {
        my $u = $uri->clone;
        my $had_query = defined $u->query;
        $u->query(undef);
        "$u" . ($had_query ? '?<redacted>' : '');
    };
    return defined $safe ? $safe : '<unparseable uri>';
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

    my $res = $self->lwp_client->request($req);
    if (!$res->is_success) {
        $logger->error("Provisioner " . $self->id . " failed to communicate with " . _log_uri($req->uri) . " for $mac: " . $res->status_line);
        return $pf::provisioner::COMMUNICATION_FAILED;
    }

    my $jq = eval { $self->jq };
    if (!defined $jq) {
        # a query that does not compile is a configuration error
        $logger->error("Provisioner " . $self->id . " has an invalid jq query: " . _clean_err($@));
        return $FALSE;
    }

    my ($pass, $results, $jq_err, $err_kind) = $self->evaluate_jq($res->decoded_content, undef, $jq);
    if (defined $jq_err) {
        $logger->error("Provisioner " . $self->id . " failed to evaluate its jq query for $mac: $jq_err");
        # Only a query that does not compile is a configuration error. An
        # unparseable payload or a jq runtime error describes what the server
        # answered, so it must not de-authorize the device.
        return $err_kind eq $ERR_QUERY ? $FALSE : $pf::provisioner::COMMUNICATION_FAILED;
    }

    $node_info //= node_view($mac);
    return $self->handleAuthorizeEnforce(
        $mac,
        {
            node_info       => $node_info,
            generic_http    => {
                result  => $results->[0],
                results => $results,
            },
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
