#!/usr/bin/perl

=head1 NAME

root_only

=head1 DESCRIPTION

unit test for pf::cmd::pf::plugin: bin/pfcmd is setuid root, so every
"pfcmd plugin" command but help is refused unless the caller of pfcmd is
root (pf::cmd::caller_uid, the real uid bin/pfcmd.pl keeps before it switches
to root). The commands also refuse when loaded directly
("pfcmd plugin::install"), and a command name with "::" is unknown.

=cut

use strict;
use warnings;

# no setup_test_config: the command is refused, or what it would do is
# recorded, before it reads any configuration
use lib qw(/usr/local/pf/lib /usr/local/pf/lib_perl/lib/perl5);

use Test::More;
use pf::cmd;
use pf::cmd::pf;
use pf::cmd::pf::plugin;
use pf::cmd::help;
use pf::constants::exit_code qw($EXIT_FAILURE);
use pf::ui_plugins::packages;
use pf::ui_plugins::schema;

# what a command would do (install a package, change the tables, show the
# help): recorded instead
my @ran;
{
    no warnings 'redefine';
    for my $sub (qw(pf::ui_plugins::packages::install pf::ui_plugins::packages::uninstall
                    pf::ui_plugins::schema::apply pf::ui_plugins::schema::check
                    pf::ui_plugins::schema::drop)) {
        no strict 'refs';
        *$sub = sub { push @ran, $sub; return wantarray ? (1, '') : 0 };
    }
    *pf::ui_plugins::packages::list = sub { push @ran, 'pf::ui_plugins::packages::list'; return [] };
    *pf::cmd::help::run = sub { push @ran, 'pf::cmd::help'; return 0 };
    *pf::cmd::pf::help::run = sub { push @ran, 'pf::cmd::pf::help'; return 0 };
}

sub run_cmd {
    my ($class, @args) = @_;
    @ran = ();
    local *STDOUT;
    open(STDOUT, '>', \my $out) or die $!;
    local *STDERR;
    open(STDERR, '>', \my $err) or die $!;
    my $status = $class->new({ args => \@args })->run;
    return ($status, $err // '');
}

sub plugin { run_cmd('pf::cmd::pf::plugin', @_) }
sub pfcmd { run_cmd('pf::cmd::pf', @_) }

{
    local $pf::cmd::CALLER_UID = 1000;
    is(pf::cmd::caller_uid(), 1000, 'caller_uid: the uid bin/pfcmd.pl kept');
    for my $args (['list'], ['install', 'acme'], ['uninstall', 'acme', '--purge'],
                  ['schema', 'apply', 'acme'], ['schema', 'check', 'acme']) {
        my ($status, $err) = plugin(@$args);
        is($status, $EXIT_FAILURE, "not root: @$args refused");
        like($err, qr/only root/, "not root: @$args says why");
        is_deeply(\@ran, [], "not root: @$args not run");
    }
    for my $args (['plugin', 'install', 'acme'], ['plugin', 'uninstall', '--purge', 'acme'],
                  ['plugin', 'schema', 'apply', 'acme']) {
        my ($status, $err) = pfcmd(@$args);
        is($status, $EXIT_FAILURE, "not root: pfcmd @$args refused");
        is_deeply(\@ran, [], "not root: pfcmd @$args not run");
    }
    # "plugin::install" would load the command directly, not through
    # "pfcmd plugin": an unknown command, only the help runs
    for my $args (['plugin::install', '/nonexistent.deb'], ['plugin::uninstall', '--purge', 'acme'],
                  ['plugin::schema', 'apply', 'acme'], ['plugin::list']) {
        my ($status, $err) = pfcmd(@$args);
        is_deeply(\@ran, ['pf::cmd::pf::help'], "not root: pfcmd @$args is an unknown command");
    }
    # and loaded directly anyway, each command refuses on its own
    for my $class (qw(install uninstall list schema)) {
        my $module = "pf::cmd::pf::plugin::$class";
        eval "require $module" or die $@;
        my @args = $class eq 'schema' ? ('apply', 'acme') : $class eq 'list' ? () : ('acme');
        my ($status, $err) = run_cmd($module, @args);
        is($status, $EXIT_FAILURE, "not root: $module refused on its own");
        like($err, qr/only root/, "not root: $module says why");
        is_deeply(\@ran, [], "not root: $module not run");
    }
    my ($status) = plugin('help');
    is_deeply(\@ran, ['pf::cmd::help'], 'not root: help runs');
}

{
    local $pf::cmd::CALLER_UID = 0;
    for my $case ([['list'], 'pf::ui_plugins::packages::list'],
                  [['install', 'acme'], 'pf::ui_plugins::packages::install'],
                  [['uninstall', 'acme', '--purge'], 'pf::ui_plugins::packages::uninstall'],
                  [['schema', 'apply', 'acme'], 'pf::ui_plugins::schema::apply']) {
        my ($args, $sub) = @$case;
        my ($status) = plugin(@$args);
        is($status, 0, "root: @$args runs");
        is_deeply(\@ran, [$sub], "root: @$args, the command");
    }
}

# an action is the name of a module under the command: "::" (or anything but
# [a-z0-9_]) is an unknown command, the module is not loaded
for my $action ('plugin::install', 'Plugin', '../plugin', 'plugin-x', "plugin\n") {
    (my $label = $action) =~ s/\n/\\n/g;
    my $cmd = pf::cmd::pf->new({ args => [$action, 'acme'] });
    ok($cmd->parseArgs, "parseArgs \"$label\"");
    is($cmd->{subcmd}, $cmd->unknownActionCmd, "parseArgs \"$label\": unknown command");
    like($cmd->{help_msg}, qr/unknown command/, "parseArgs \"$label\": says why");
}
{
    my $cmd = pf::cmd::pf::plugin->new({ args => ['schema::apply', 'acme'] });
    $cmd->parseArgs;
    is($cmd->{subcmd}, $cmd->unknownActionCmd, 'parseArgs "schema::apply" under plugin: unknown command');
    $cmd = pf::cmd::pf->new({ args => ['plugin', 'list'] });
    $cmd->parseArgs;
    is($cmd->{subcmd}, 'pf::cmd::pf::plugin', 'parseArgs "plugin": its module');
    is_deeply($cmd->{subcmd_args}, ['list'], 'parseArgs "plugin": its arguments');
}

{
    local $pf::cmd::CALLER_UID;
    is(pf::cmd::caller_uid(), $<, 'caller_uid: the real uid when not run by bin/pfcmd');
}

done_testing();

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
