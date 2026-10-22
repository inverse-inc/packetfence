#!/usr/bin/perl

=head1 NAME

safe_pf_run

=cut

=head1 DESCRIPTION

unit test for pf::util::safe_pf_run

safe_pf_run runs a command via IPC::Open3 with the binary and arguments passed
as a list (never through a shell), so these tests focus on:

* the return-value contract in scalar / list / void context
* that no shell interpretation (globbing, metacharacters, word splitting)
  happens on the arguments
* the option hash: status_ref, accepted_exit_status, stdin, stdout,
  stdout_append, redirect_stderr_to_stdout, working_directory, log_strip
* that large output on stdout (and on a merged stdout+stderr) is fully drained
  and does not deadlock waitpid

=cut

use strict;
use warnings;
#
BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 33;
use Test::NoWarnings;

use File::Temp qw(tempfile tempdir);
use File::Slurp qw(read_file write_file);
use Cwd qw(getcwd abs_path);
use POSIX qw(WNOHANG);

use pf::util qw(safe_pf_run);

# The child process used throughout is the running perl interpreter. It is
# always present and lets us produce deterministic output / exit codes without
# depending on the behaviour of external utilities.
my $PERL = $^X;

# Run a coderef under an alarm so a regression that reintroduces a pipe-buffer
# deadlock fails fast instead of hanging the whole suite. Returns the eval
# error ('' on success).
sub run_with_timeout {
    my ($seconds, $code) = @_;
    my $err = '';
    eval {
        local $SIG{ALRM} = sub { die "timeout\n" };
        alarm($seconds);
        $code->();
        alarm(0);
        1;
    } or $err = $@;
    alarm(0);
    return $err;
}

# --- return value contract -------------------------------------------------

is(
    safe_pf_run($PERL, '-e', 'print "hello"'),
    "hello",
    "scalar context returns the captured stdout"
);

is(
    safe_pf_run($PERL, '-e', 'print "line\n"'),
    "line\n",
    "scalar context preserves a trailing newline"
);

is_deeply(
    [ safe_pf_run($PERL, '-e', 'print "a\nb\nc\n"') ],
    [ "a\n", "b\n", "c\n" ],
    "list context returns one element per line (newlines retained)"
);

# --- no shell: arguments are passed verbatim -------------------------------

is(
    safe_pf_run($PERL, '-e', 'print $ARGV[0]', 'foo; echo INJECTED `whoami` $(id)'),
    'foo; echo INJECTED `whoami` $(id)',
    "shell metacharacters in an argument are passed literally (no shell)"
);

is(
    safe_pf_run($PERL, '-e', 'print $ARGV[0]', '*'),
    '*',
    "a '*' argument is not glob-expanded (no shell)"
);

is(
    safe_pf_run($PERL, '-e', 'print scalar(@ARGV)', 'one two three', 'four'),
    '2',
    "an argument containing spaces is a single argv element (no word splitting)"
);

is(
    safe_pf_run($PERL, '-e', 'print join("|", @ARGV)', 'a b', 'c'),
    'a b|c',
    "argument values are delivered to the child unchanged"
);

# --- status_ref ------------------------------------------------------------

{
    my $status;
    safe_pf_run($PERL, '-e', 'exit 0', { status_ref => \$status });
    is($status, 0, "status_ref is 0 on success");
}

{
    my $status;
    safe_pf_run($PERL, '-e', 'exit 3', { status_ref => \$status });
    is($status >> 8, 3, "status_ref carries the raw wait status (exit code 3)");
}

# --- failure handling ------------------------------------------------------

is(
    safe_pf_run($PERL, '-e', 'exit 1'),
    undef,
    "a non-zero exit returns undef in scalar context"
);

# --- accepted_exit_status --------------------------------------------------

is(
    safe_pf_run($PERL, '-e', 'print "data"; exit 3', { accepted_exit_status => [3] }),
    "data",
    "accepted_exit_status treats the listed code as success and returns output"
);

is(
    safe_pf_run($PERL, '-e', 'exit 5', { accepted_exit_status => [3] }),
    undef,
    "an exit code not in accepted_exit_status still fails"
);

# --- stdin -----------------------------------------------------------------

{
    my (undef, $infile) = tempfile();
    write_file($infile, "hello\n");
    is(
        safe_pf_run($PERL, '-e', 'local $/; print uc <STDIN>', { stdin => $infile }),
        "HELLO\n",
        "stdin feeds the file contents to the command"
    );
    unlink $infile;
}

# --- stdout to file --------------------------------------------------------

{
    my (undef, $outfile) = tempfile();
    my $ret = safe_pf_run($PERL, '-e', 'print "tofile"', { stdout => $outfile });
    is($ret, undef, "with stdout redirected to a file the scalar return is undef");
    is(read_file($outfile), "tofile", "stdout is written to the file");
    unlink $outfile;
}

# --- stdout_append ---------------------------------------------------------

{
    my (undef, $appendfile) = tempfile();
    safe_pf_run($PERL, '-e', 'print "AA"', { stdout => $appendfile });
    safe_pf_run($PERL, '-e', 'print "BB"', { stdout => $appendfile, stdout_append => 1 });
    is(read_file($appendfile), "AABB", "stdout_append appends instead of truncating");
    unlink $appendfile;
}

# --- redirect_stderr_to_stdout ---------------------------------------------

{
    my $merged = safe_pf_run(
        $PERL, '-e', 'print STDOUT "OUT"; print STDERR "ERR"',
        { redirect_stderr_to_stdout => 1 },
    );
    ok(
        defined($merged) && $merged =~ /OUT/ && $merged =~ /ERR/,
        "redirect_stderr_to_stdout captures both streams"
    );
}

is(
    safe_pf_run($PERL, '-e', 'print STDOUT "OUT"; print STDERR "ERR"'),
    "OUT",
    "without redirect, only stdout is returned (stderr is drained, not returned)"
);

# --- working_directory -----------------------------------------------------

{
    my $orig = getcwd();
    my $dir  = tempdir(CLEANUP => 1);
    my $child_cwd = safe_pf_run(
        $PERL, '-MCwd', '-e', 'print Cwd::abs_path(q{.})',
        { working_directory => $dir },
    );
    is($child_cwd, abs_path($dir), "the command runs in working_directory");
    is(getcwd(), $orig, "the caller's cwd is restored after the command");
}

# --- environment -----------------------------------------------------------

is(
    safe_pf_run($PERL, '-e', 'print $ENV{LANG} // "no-lang"'),
    "C",
    "LANG is forced to C for the child"
);

# --- log_strip -------------------------------------------------------------

is(
    safe_pf_run($PERL, '-e', 'print "topsecret"', { log_strip => "secret" }),
    "topsecret",
    "log_strip redacts only log output, not the returned value"
);

# --- failure to launch -----------------------------------------------------

{
    my $status;
    my $ret = safe_pf_run("/no/such/binary_xyz", "arg", { status_ref => \$status });
    is($ret, undef, "a command that cannot be launched returns undef");
    is($status, -1, "status_ref is set to -1 when the command cannot be launched");
}

# --- large output must not deadlock (regression) ---------------------------
# The child writes far more than a pipe buffer (~64KB). safe_pf_run must drain
# stdout before waitpid, otherwise the child blocks on a full pipe and we hang.

{
    my $big;
    my $size = 1024 * 256; # 256KB
    my $err = run_with_timeout(30, sub {
        $big = safe_pf_run($PERL, '-e', "print q{x} x $size");
    });
    is($err, '', "large stdout does not deadlock");
    is(length($big // ''), $size, "large stdout is fully captured");
}

{
    my $merged;
    my $half = 1024 * 200; # 200KB on each stream
    my $err = run_with_timeout(30, sub {
        $merged = safe_pf_run(
            $PERL, '-e', "print STDOUT q{o} x $half; print STDERR q{e} x $half",
            { redirect_stderr_to_stdout => 1 },
        );
    });
    is($err, '', "large merged stdout+stderr does not deadlock");
    is(length($merged // ''), $half * 2, "large merged output is fully captured");
}

# --- competing SIGCHLD reaper (regression) ---------------------------------
# The long-running daemons (pfconfig, pfqueue, pfqueue-backend, pffilter,
# pfdhcplistener) install a $SIG{CHLD} handler that reaps any terminated child
# with waitpid(-1, WNOHANG) and discards its status. Because safe_pf_run drains
# the child's pipes to EOF before waiting, the child has already exited by the
# time it waits -- so unless safe_pf_run blocks SIGCHLD across the fork/wait,
# the daemon's reaper collects the child first and safe_pf_run's own waitpid
# returns -1: a false failure for a command that actually succeeded.

{
    local $SIG{CHLD} = sub { 1 while waitpid(-1, WNOHANG) > 0 };

    my $status;
    my $out = safe_pf_run($PERL, '-e', 'print "ok"; exit 0', { status_ref => \$status });
    is($out, "ok", "output is returned despite a competing SIGCHLD reaper");
    is($status, 0, "status_ref is 0 despite a competing SIGCHLD reaper");

    is_deeply(
        [ safe_pf_run($PERL, '-e', 'print "a\nb\n"') ],
        [ "a\n", "b\n" ],
        "list context still works with a competing SIGCHLD reaper",
    );

    my $fstatus;
    safe_pf_run($PERL, '-e', 'exit 4', { status_ref => \$fstatus });
    is($fstatus >> 8, 4, "a genuine non-zero exit is still reported with a competing reaper");
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
