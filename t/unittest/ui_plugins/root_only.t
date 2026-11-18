#!/usr/bin/perl

=head1 NAME

root_only

=head1 DESCRIPTION

unit test for pf::cmd::pf::plugin: bin/pfcmd is setuid root, so every
"pfcmd plugin" command but help is refused unless the caller of pfcmd is
root (pf::cmd::caller_uid, the real uid bin/pfcmd.pl keeps before it switches
to root).

=cut

use strict;
use warnings;

# no setup_test_config: the command is refused or recorded before it reads
# any configuration
use lib qw(/usr/local/pf/lib /usr/local/pf/lib_perl/lib/perl5);

use Test::More;
use pf::cmd;
use pf::cmd::pf::plugin;
use pf::constants::exit_code qw($EXIT_FAILURE);

# a command that would run: recorded instead
my @ran;
{
    no warnings 'redefine';
    *pf::cmd::subcmd::_run = sub { push @ran, $_[0]{subcmd}; return 0 };
}

sub plugin {
    my (@args) = @_;
    @ran = ();
    local *STDERR;
    open(STDERR, '>', \my $err) or die $!;
    my $status = pf::cmd::pf::plugin->new({ args => \@args })->run;
    return ($status, $err // '');
}

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
    my ($status) = plugin('help');
    is_deeply(\@ran, ['pf::cmd::help'], 'not root: help runs');
}

{
    local $pf::cmd::CALLER_UID = 0;
    my ($status) = plugin('list');
    is($status, 0, 'root: list runs');
    is_deeply(\@ran, ['pf::cmd::pf::plugin::list'], 'root: the list command');
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
