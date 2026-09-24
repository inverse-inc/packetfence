#!/usr/bin/perl

=head1 NAME

log_signal_handlers

=head1 DESCRIPTION

Log4perl compiles "sub {...}" config values in a Safe compartment when
allow_code is 'restrictive' (set by pf::log). Safe->reval wipes every perl
signal handler, so the next such signal killed the process with
"Signal SIGxxx received, but no signal handler set.". pf::log wraps the Safe
compile to keep the handlers.

Each check runs in a forked child, so a regression shows up as a failed test
(the child dies with the signal number as exit status) instead of killing the
test run.

=cut

use strict;
use warnings;
use lib '/usr/local/pf/lib', '/usr/local/pf/lib_perl/lib/perl5';
use File::Temp qw(tempfile);
use POSIX qw(WNOHANG);
use Test::More tests => 5;

# require, not use: pf::log's import would init Log4perl with the service config
require pf::log;
# loaded up front so the Safe::reval hook below isn't replaced when Log4perl requires it
require Safe;

my $CONFIG = <<'CONF';
log4perl.rootLogger = sub { "INFO, STRING" }
log4perl.appender.STRING = Log::Log4perl::Appender::String
log4perl.appender.STRING.layout = Log::Log4perl::Layout::SimpleLayout
CONF

my ($fh, $config_file) = tempfile(UNLINK => 1);
print $fh $CONFIG;
close $fh;

# Runs $check in a child and returns its exit status: 0 when $check returns
# true, 1 when it returns false, the signal number when the child is killed by
# perl's "no signal handler set" exit.
sub in_child {
    my ($check) = @_;
    my $pid = fork;
    die "fork: $!" unless defined $pid;
    if ($pid == 0) {
        my $ok = eval { $check->() };
        diag("died: $@") if $@;
        POSIX::_exit($ok ? 0 : 1);
    }
    waitpid($pid, 0);
    return $? & 127 ? 128 + ($? & 127) : $? >> 8;
}

# Delivers a real signal to ourselves and gives perl a safe point to run the handler
sub raise {
    my ($signal) = @_;
    kill $signal => $$;
    1 for 1 .. 10;
}

# Forks a child that exits right away and waits for our SIGCHLD handler to reap it
sub child_exits {
    my ($reaped) = @_;
    my $start = $$reaped;
    my $pid = fork;
    POSIX::_exit(0) if $pid == 0;
    for (1 .. 50) {
        last if $$reaped > $start;
        select(undef, undef, undef, 0.02);
    }
    return $$reaped > $start;
}

sub install_handlers {
    my ($ran, $reaped) = @_;
    $SIG{USR1} = sub { $$ran++ };
    $SIG{CHLD} = sub {
        local ($!, $?);
        while (waitpid(-1, WNOHANG) > 0) { $$reaped++ }
    };
}

is(in_child(sub {
    my ($ran, $reaped) = (0, 0);
    install_handlers(\$ran, \$reaped);
    my $handler = $SIG{USR1};
    Log::Log4perl->init($config_file);
    raise('USR1');
    return ref $SIG{USR1} && $SIG{USR1} == $handler && $ran == 1;
}), 0, "a Log4perl init with a sub {} value keeps the USR1 handler and it still runs");

is(in_child(sub {
    my ($ran, $reaped) = (0, 0);
    install_handlers(\$ran, \$reaped);
    Log::Log4perl->init($config_file);
    return child_exits(\$reaped);
}), 0, "a child exit after a Log4perl init is reaped by the SIGCHLD handler");

is(in_child(sub {
    my ($ran, $reaped) = (0, 0);
    Log::Log4perl->init_and_watch($config_file, 300);
    install_handlers(\$ran, \$reaped);
    my $compiles = 0;
    my $compile = \&Log::Log4perl::Config::compile_in_safe_cpt;
    no warnings 'redefine';
    local *Log::Log4perl::Config::compile_in_safe_cpt = sub { $compiles++; goto &$compile };
    # config file changed after the watch interval: the next log call re-reads it
    my $future = time + 10;
    utime($future, $future, $config_file) or die "utime: $!";
    no warnings 'once';
    $Log::Log4perl::Config::WATCHER->{_last_checked_at} = 0;
    $Log::Log4perl::Config::Watch::NEXT_CHECK_TIME = 0;
    Log::Log4perl->get_logger('')->info("trigger the watch check");
    die "the config was not re-read\n" unless $compiles == 1;
    raise('USR1');
    return $ran == 1 && child_exits(\$reaped);
}), 0, "handlers survive an init_and_watch reload of a changed config");

is(in_child(sub {
    my ($ran, $reaped) = (0, 0);
    install_handlers(\$ran, \$reaped);
    my $reval = \&Safe::reval;
    no warnings 'redefine';
    # a child exits while the Safe compile is running
    local *Safe::reval = sub {
        my $pid = fork;
        POSIX::_exit(0) if $pid == 0;
        select(undef, undef, undef, 0.2);
        goto &$reval;
    };
    Log::Log4perl->init($config_file);
    1 for 1 .. 10;
    return $reaped == 1 && ref $SIG{CHLD};
}), 0, "a SIGCHLD arriving during the Safe compile is delivered to the restored handler");

is(in_child(sub {
    $SIG{PIPE} = 'IGNORE';
    Log::Log4perl->init($config_file);
    return defined $SIG{PIPE} && $SIG{PIPE} eq 'IGNORE';
}), 0, "an IGNORE disposition is left alone");

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
