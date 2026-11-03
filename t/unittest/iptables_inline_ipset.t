#!/usr/bin/perl

=head1 NAME

iptables_inline_ipset

=head1 DESCRIPTION

unit test for the inline ipset pre-population helpers of pf::iptables:
_inline_session_entry (the entry format of each pfsession set type) and
_ipset_restore (which lines reach ipset restore and what gets logged).

=cut

use strict;
use warnings;

BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::More tests => 31;
use Test::NoWarnings;

use pf::config qw($IPTABLES_MARK_REG $IPTABLES_MARK_ISOLATION $IPTABLES_MARK_UNREG);
use pf::iptables;

# _inline_session_entry: bitmap:ip everywhere, bitmap:ip,mac only for the
# unreg set of a split layer 2 network (see pf::ipset::iptables_generate)
{
    no warnings 'once';
    local *pf::iptables::ConfigNetworks = {
        '10.1.0.0' => { type => 'inlinel3' },
        '10.2.0.0' => { type => 'inlinel2', split_network => 'disabled' },
        '10.3.0.0' => { type => 'inlinel2', split_network => 'enabled' },
    };
    my ($ip, $mac) = ('10.9.9.7', 'aa:bb:cc:dd:ee:ff');
    is(pf::iptables::_inline_session_entry('10.1.0.0', $IPTABLES_MARK_REG, $ip, $mac), $ip, 'L3 reg: address');
    is(pf::iptables::_inline_session_entry('10.1.0.0', $IPTABLES_MARK_UNREG, $ip, $mac), $ip, 'L3 unreg: address');
    is(pf::iptables::_inline_session_entry('10.2.0.0', $IPTABLES_MARK_REG, $ip, $mac), $ip, 'L2 reg: address (the 15.2 failure)');
    is(pf::iptables::_inline_session_entry('10.2.0.0', $IPTABLES_MARK_ISOLATION, $ip, $mac), $ip, 'L2 isolation: address');
    is(pf::iptables::_inline_session_entry('10.2.0.0', $IPTABLES_MARK_UNREG, $ip, $mac), $ip, 'L2 unreg, not split: address');
    is(pf::iptables::_inline_session_entry('10.3.0.0', $IPTABLES_MARK_REG, $ip, $mac), $ip, 'split L2 reg: address');
    is(pf::iptables::_inline_session_entry('10.3.0.0', $IPTABLES_MARK_UNREG, $ip, $mac), "$ip,$mac", 'split L2 unreg: address,mac');
}

# _ipset_restore with a fake ipset and a logger that records the messages
my (%log, @restored, $list_out, $list_status, $restore_out, $restore_status);

{
    package FakeLogger;
    sub new { bless {}, shift }
    for my $level (qw(trace debug info warn error)) {
        no strict 'refs';
        *{$level} = sub { push @{$log{$level}}, $_[1] };
    }
}

sub run_restore {
    my (@ops) = @_;
    (%log, @restored) = ();
    no warnings 'redefine';
    local *pf::iptables::get_logger = sub { FakeLogger->new };
    local *pf::iptables::safe_pf_run = sub {
        my $opts = ref($_[-1]) eq 'HASH' ? $_[-1] : {};
        if (grep { $_ eq 'list' } @_) {
            ${$opts->{status_ref}} = $list_status if $opts->{status_ref};
            return $list_status == 0 ? map { "$_\n" } @$list_out : ();
        }
        open(my $fh, '<', $opts->{stdin}) or die "cannot read $opts->{stdin}: $!";
        @restored = <$fh>;
        close($fh);
        ${$opts->{status_ref}} = $restore_status if $opts->{status_ref};
        return $restore_out;
    };
    return pf::iptables::_ipset_restore(@ops);
}

($list_out, $list_status, $restore_out, $restore_status) = (['set_a', 'set_b'], 0, '', 0);
ok(run_restore('add set_a 10.9.9.1', 'add set_b 10.9.9.2'), 'all sets exist: success');
is_deeply(\@restored, ["add set_a 10.9.9.1\n", "add set_b 10.9.9.2\n"], 'every line sent, newline-terminated');
like($log{info}[0], qr/pre-populated 2 inline entries/, 'success logged with the count');

ok(run_restore('add set_a 10.9.9.1', 'add missing 10.9.9.2', 'add missing 10.9.9.3', 'add missing 10.9.9.4'), 'missing set: the other lines still applied');
is_deeply(\@restored, ["add set_a 10.9.9.1\n"], 'lines for the missing set are not sent');
is(scalar(@{$log{warn} // []}), 1, 'one warning for the missing set, not one per line');
like($log{warn}[0], qr/ipset missing does not exist, skipping 3 entries \(first: 'add missing 10\.9\.9\.2'\)/, 'warning names the set, the count and the first line');

($list_out, $list_status) = ([], 0);
ok(run_restore('add set_a 10.9.9.1'), 'successful but empty listing: nothing exists');
is_deeply(\@restored, [], 'nothing is sent to ipset restore');

($list_out, $list_status) = ([], 256);
run_restore('add set_a 10.9.9.1');
is_deeply(\@restored, ["add set_a 10.9.9.1\n"], 'failed listing: no filtering, the lines are sent');

($list_out, $list_status, $restore_out, $restore_status) = (['set_a'], 0, "ipset v7.17: Error in line 1: Syntax error: Elem separator in 10.9.9.7,aa:bb:cc:dd:ee:ff, but settype bitmap:ip supports none\n", 256);
ok(!run_restore('add set_a 10.9.9.7,aa:bb:cc:dd:ee:ff'), 'ipset restore failure: returns false instead of dying');
like($log{error}[0], qr/ipset restore failed \(exit 1\) while pre-populating 1 inline entries: ipset v7\.17: Error in line 1: Syntax error/, "failure logged with ipset's own message");

# A restore killed by a signal has the exit code 0: say it was killed
($list_out, $list_status, $restore_out, $restore_status) = (['set_a'], 0, '', 9);
ok(!run_restore('add set_a 10.9.9.1'), 'ipset restore killed: returns false');
like($log{error}[0], qr/ipset restore failed \(killed by signal 9\)/, 'the signal is reported, not exit 0');

is(pf::iptables::_exit_description(256), 'exit 1', 'exit code');
is(pf::iptables::_exit_description(15), 'killed by signal 15', 'signal');
is(pf::iptables::_exit_description(-1), 'could not be run', 'command not run');
is(pf::iptables::_exit_description(undef), 'exit unknown', 'no status');

# inline_mangle_rules: what is pre-populated for the registered nodes
{
    my @ops;
    require pf::security_event;
    require pf::ip4log;
    no warnings qw(redefine once);
    local *pf::iptables::is_inline_enforcement_enabled = sub { 1 };
    local *pf::config::is_network_type_inline = sub { 1 };
    local *pf::iptables::get_inline_snat_interface = sub { '' };
    local *pf::iptables::get_logger = sub { FakeLogger->new };
    local *pf::iptables::ConfigNetworks = { '10.1.0.0' => { type => 'inlinel3', netmask => '255.255.255.0' } };
    local *pf::iptables::NetworkConfig = { '10.1.0.0' => { interface => { int => 'eth1' } } };
    local *pf::ip4log::list_open = sub {
        return ({ mac => '00:11:22:33:44:01', ip => '10.1.0.11' }, { mac => '00:11:22:33:44:02', ip => '10.1.0.12' });
    };
    # the same node twice, and a node registered without a role
    local *pf::iptables::nodes_registered_not_violators = sub {
        return ({ mac => '00:11:22:33:44:01', category_id => 5 }, { mac => '00:11:22:33:44:01', category_id => 5 }, { mac => '00:11:22:33:44:02', category_id => undef });
    };
    local *pf::security_event::security_event_view_open_uniq = sub { () };
    local *pf::iptables::_ipset_restore = sub { @ops = @_; return 1 };
    pf::iptables::inline_mangle_rules('test', {});
    is(scalar(grep { /^add pfsession_\S+_10\.1\.0\.0 10\.1\.0\.11$/ } @ops), 1, 'a node listed twice is added once');
    is(scalar(grep { $_ eq 'add PF-iL3_ID5_10.1.0.0 10.1.0.11' } @ops), 1, 'its role set entry is added once');
    is(scalar(grep { /^add pfsession_\S+_10\.1\.0\.0 10\.1\.0\.12$/ } @ops), 1, 'a node without a role gets its session entry');
    is(scalar(grep { /^add PF-iL\S*_10\.1\.0\.0 10\.1\.0\.12$/ } @ops), 0, 'but no entry in a role set that does not exist');
    my %seen;
    is(scalar(grep { $seen{$_}++ } @ops), 0, 'no duplicate line reaches ipset restore');
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
