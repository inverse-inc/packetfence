package pf::ui_plugins;

=head1 NAME

pf::ui_plugins - the registry of the admin UI plugins

=head1 SYNOPSIS

    use pf::ui_plugins;

    # when the plugin serves its manifest
    my ($status, $error) = pf::ui_plugins::register({ name => 'acme', host => 'acme.example', port => 8080 });

    # when the plugin stops
    ($status, $error) = pf::ui_plugins::deregister('acme');

=head1 DESCRIPTION

A plugin service registers itself when it is ready and deregisters itself when
it stops. These accessors behave like the Go ones (go/uiplugins Register,
Deregister, Get, List, Validate): the same rows, the same validation. The
PacketFence database is used through pf::dal::chi_cache, its credentials stay
in the PacketFence configuration, the plugin never handles them.

One row of the chi_cache table per plugin:

    key         ui_plugins::<name>
    value       {"name":"<name>","host":"<host>","port":<port>}
    expires_at  NULL, the row stays until it is deregistered

The manifest of the plugin is then fetched from
<scheme>://<host>:<port>/manifest.json, GET /api/v1/plugins lists the plugins
and /api/v1/plugin/<name>/<path> is proxied to <scheme>://<host>:<port>/<path>.
The scheme is http for a loopback host (127.0.0.0/8, ::1, localhost), https
otherwise, with a certificate valid for the host.

A plugin that crashes without deregistering stays listed: its manifest cannot
be fetched, so the admin UI leaves it out, its pages answer 502.

See docs/ui-plugins/README.md.

=cut

use strict;
use warnings;
use JSON::MaybeXS qw(encode_json decode_json);
use Socket qw(inet_pton AF_INET AF_INET6);
use pf::constants qw($TRUE $FALSE);
use pf::error qw(is_error is_success);
use pf::dal::chi_cache;
use pf::log;

=head2 $KEY_PREFIX

The prefix of the chi_cache keys of the registrations

=cut

our $KEY_PREFIX = 'ui_plugins::';

# keep in sync with nameRe and hostRe in go/uiplugins/registration.go
our $NAME_RE = qr/^[a-z][a-z0-9_-]{0,62}\z/;
our $HOST_RE = qr/^[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*\z/;

=head2 validate

    my ($ok, $error) = pf::ui_plugins::validate({ name => 'acme', host => 'acme', port => 8080 });

Checks a registration without writing it:

=over

=item name: ^[a-z][a-z0-9_-]{0,62}$ (a URL segment)

=item host: a hostname or an IP address

=item port: 1 to 65535

=back

=cut

sub validate {
    my ($registration) = @_;
    return ($FALSE, 'a registration is a hash') if ref($registration) ne 'HASH';
    my ($name, $host, $port) = @{$registration}{qw(name host port)};
    if (!defined $name || ref($name) || $name !~ $NAME_RE) {
        return ($FALSE, sprintf('invalid name "%s"', $name // ''));
    }
    if (!defined $host || ref($host) || !_valid_host($host)) {
        return ($FALSE, sprintf('invalid host "%s"', $host // ''));
    }
    if (!defined $port || ref($port) || $port !~ /^[0-9]{1,5}\z/ || $port < 1 || $port > 65535) {
        return ($FALSE, sprintf('invalid port "%s"', $port // ''));
    }
    return ($TRUE, undef);
}

sub _valid_host {
    my ($host) = @_;
    return $TRUE if inet_pton(AF_INET, $host) || inet_pton(AF_INET6, $host);
    return length($host) <= 253 && $host =~ $HOST_RE;
}

=head2 register

    my ($status, $error) = pf::ui_plugins::register({ name => 'acme', host => 'acme', port => 8080 });

Adds or replaces the registration of a plugin: call it once the plugin serves
its manifest. Returns $STATUS::OK, $STATUS::CREATED, or an error status and
its reason ($STATUS::UNPROCESSABLE_ENTITY for an invalid registration).

=cut

sub register {
    my ($registration) = @_;
    my ($ok, $error) = validate($registration);
    return ($STATUS::UNPROCESSABLE_ENTITY, $error) if !$ok;
    my %data = (
        name => "$registration->{name}",
        host => "$registration->{host}",
        port => 0 + $registration->{port},
    );
    my $row = pf::dal::chi_cache->new({
        key        => $KEY_PREFIX . $data{name},
        value      => encode_json(\%data),
        expires_at => undef,
    });
    my $status = $row->upsert;
    if (is_error($status)) {
        return ($status, "unable to register the UI plugin $data{name}");
    }
    return ($status, undef);
}

=head2 deregister

    my ($status, $error) = pf::ui_plugins::deregister('acme');

Removes the registration of a plugin: call it when the plugin stops. An
unknown name is not an error ($STATUS::OK).

=cut

sub deregister {
    my ($name) = @_;
    return ($STATUS::UNPROCESSABLE_ENTITY, 'missing name') if !defined $name || ref($name);
    my $status = pf::dal::chi_cache->remove_by_id({ key => $KEY_PREFIX . $name });
    if (is_error($status) && $status != $STATUS::NOT_FOUND) {
        return ($status, "unable to deregister the UI plugin $name");
    }
    return ($STATUS::OK, undef);
}

sub _decode {
    my ($key, $value) = @_;
    my $registration = eval { decode_json($value) };
    if (!$registration || ref($registration) ne 'HASH') {
        return (undef, "invalid registration $key");
    }
    # exactly name, host and port, like the Go accessors
    my @keys = sort keys %$registration;
    if ("@keys" ne 'host name port') {
        return (undef, "invalid registration $key: the properties must be name, host and port");
    }
    my ($ok, $error) = validate($registration);
    return (undef, "invalid registration $key: $error") if !$ok;
    if ($KEY_PREFIX . $registration->{name} ne $key) {
        return (undef, "invalid registration $key: name \"$registration->{name}\"");
    }
    return ({ name => $registration->{name}, host => $registration->{host}, port => 0 + $registration->{port} }, undef);
}

=head2 get

    my $registration = pf::ui_plugins::get('acme');

The registration of a plugin, undef when it is not registered or invalid

=cut

sub get {
    my ($name) = @_;
    return undef if !defined $name || ref($name);
    my ($status, $row) = pf::dal::chi_cache->find({ key => $KEY_PREFIX . $name });
    return undef if is_error($status);
    my ($registration, $error) = _decode($row->{key}, $row->{value});
    get_logger->warn($error) if $error;
    return $registration;
}

=head2 list

    my $registrations = pf::ui_plugins::list();

The valid registrations by name, the invalid rows are logged and skipped.
Undef when the database cannot be read.

=cut

sub list {
    (my $like = $KEY_PREFIX) =~ s/_/\\_/g;
    my ($status, $iter) = pf::dal::chi_cache->search(
        -where => { key => { -like => "$like%" } },
        -no_default_join => 1,
    );
    return undef if is_error($status);
    my %registrations;
    while (my $row = $iter->next(undef)) {
        my ($registration, $error) = _decode($row->{key}, $row->{value});
        if ($error) {
            get_logger->warn($error);
            next;
        }
        $registrations{$registration->{name}} = $registration;
    }
    return \%registrations;
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
