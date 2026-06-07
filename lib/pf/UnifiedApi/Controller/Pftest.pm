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

use pf::util qw(safe_pf_run clean_mac);
use pf::file_paths qw($install_dir);
use pf::log;

my $PFTEST_BIN = "$install_dir/bin/pftest";

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

    unless (defined $user && length $user && defined $pass && length $pass) {
        return { status => 422, json => {
            message => "user and password are required",
            errors  => [], status => 422,
        } };
    }

    return _spawn('authentication', $user, $pass, @$srcs);
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
    return _spawn('profile_filter', $mac, @args);
}

# Run bin/pftest <subcmd> @args, capture stdout+stderr together, return:
#   { status => 200, json => { output => stripped, output_raw => raw, exit_code => N } }
# pftest may exit non-zero for legitimate "test failed" cases (e.g. auth
# failure); we treat all exit codes 0..255 as "ran successfully" and let
# the caller inspect exit_code.
sub _spawn {
    my ($subcmd, @args) = @_;
    my $status = 0;
    my $raw = safe_pf_run(
        $PFTEST_BIN, $subcmd, @args,
        {
            redirect_stderr_to_stdout => 1,
            accepted_exit_status      => [0..255],
            status_ref                => \$status,
        },
    );
    $raw //= '';
    my $exit_code = ($status == -1) ? -1 : ($status >> 8);

    my $stripped = $raw;
    $stripped =~ s/\x1B\[[0-9;]*[A-Za-z]//g;

    return { status => 200, json => {
        output     => $stripped,
        output_raw => $raw,
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
