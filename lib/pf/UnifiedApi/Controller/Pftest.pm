package pf::UnifiedApi::Controller::Pftest;

=head1 NAME

pf::UnifiedApi::Controller::Pftest -

=cut

=head1 DESCRIPTION

Exposes selected bin/pftest subcommands (authentication, profile_filter)
as HTTP endpoints so admins can run them from the GUI. The controller
spawns the CLI via safe_pf_run so output is byte-identical to a manual
invocation; ANSI escapes are stripped from the JSON 'output' field while
the original is retained as 'output_raw' for clients that want the
colored stream.

=cut

use strict;
use warnings;
use Mojo::Base 'pf::UnifiedApi::Controller::RestRoute';

use Capture::Tiny qw(capture_merged);
use Module::Load qw(load);
use Module::Loaded qw(is_loaded);

use pf::util qw(clean_mac);
use pf::log;

# Whitelist of subcommand modules that may be invoked from the GUI. The
# CLI dispatcher loads pf::pftest::<name> dynamically; we keep an explicit
# allow-list here so a typo in the body cannot reach `locationlog` (DB
# scan), `help`, or any future subcommand we have not vetted for the UI.
my %ALLOWED = map { $_ => 1 } qw(authentication profile_filter);

sub authentication {
    my ($self) = @_;
    my $body   = $self->req->json // {};
    my $resp   = $self->_run_authentication($body);
    return $self->render(json => $resp->{json}, status => $resp->{status});
}

sub profile_filter {
    my ($self) = @_;
    my $body   = $self->req->json // {};
    my $resp   = $self->_run_profile_filter($body);
    return $self->render(json => $resp->{json}, status => $resp->{status});
}

sub _run_authentication {
    my ($self, $body) = @_;

    my $user = $body->{user};
    my $pass = $body->{password};
    my $srcs = $body->{sources} // [];
    $srcs = [$srcs] if ref($srcs) ne 'ARRAY';

    unless (defined $user && length $user) {
        return { status => 422, json => {
            message => "user is required",
            errors  => [], status => 422,
        } };
    }
    # Password is optional — the CLI accepts an empty second arg, which
    # exercises sources that fail closed (LDAP rejects, SAML challenges,
    # etc.) and is a useful "is this source reachable at all" probe.
    $pass = '' unless defined $pass;

    return _invoke('authentication', $user, $pass, @$srcs);
}

sub _run_profile_filter {
    my ($self, $body) = @_;

    my $mac    = clean_mac($body->{mac} // '');
    my $params = $body->{params} // {};

    unless ($mac) {
        return { status => 422, json => {
            message => "mac is required and must be a valid MAC address",
            errors  => [], status => 422,
        } };
    }

    my @args;
    for my $k (sort keys %$params) {
        my $v = $params->{$k};
        next unless defined $k && $k =~ /^[A-Za-z0-9_-]+$/;
        next unless defined $v;
        push @args, "$k=$v";
    }
    return _invoke('profile_filter', $mac, @args);
}

# pfperl-api bind-mounts lib but not bin, so load the subcommand module
# in-process instead of shelling out to bin/pftest.
sub _invoke {
    my ($subcmd, @args) = @_;

    return { status => 422, json => {
        message => "Subcommand '$subcmd' is not exposed via the API",
        errors  => [], status => 422,
    } } unless $ALLOWED{$subcmd};

    my $module = "pf::pftest::$subcmd";
    my $exit_code = 0;
    my $merged = capture_merged {
        eval {
            load $module unless is_loaded($module);
            my $cmd = $module->new({ args => \@args });
            my $rc  = $cmd->run();
            $exit_code = defined $rc ? ($rc + 0) : 0;
            1;
        } or do {
            my $err = $@ || 'unknown error';
            print "ERROR: $err\n";
            $exit_code = -1;
        };
    };

    my $stripped = $merged;
    $stripped =~ s/\x1B\[[0-9;]*[A-Za-z]//g;

    return { status => 200, json => {
        output     => $stripped,
        output_raw => $merged,
        exit_code  => $exit_code,
    } };
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
