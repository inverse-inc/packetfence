#!/usr/bin/perl

=head1 NAME

security_event_same_device

=head1 DESCRIPTION

A security event with same_device_fields is opened and closed on every node
sharing these fields with the node (#7825)

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 30;
use Test::MockModule;
use pf::node qw(node_add);
use pf::person qw(person_add);
use pf::dal::person;
use pf::class;
use pf::dal::node;
use pf::dal::security_event;
use pf::security_event;

#This test will running last
use Test::NoWarnings;

my $ID = '1100022';
my $OTHER_ID = '1100021';
my $PID = 'same-device-7825';
my ($A, $B, $C, $D, $E) = map { sprintf("02:78:25:00:00:%02x", $_) } 1 .. 5;
my @MACS = ($A, $B, $C, $D, $E);

my (@reevaluated, @actions);
my $enforcement = Test::MockModule->new('pf::enforcement');
$enforcement->mock(reevaluate_access => sub { push @reevaluated, $_[0]; 1 });
my $action = Test::MockModule->new('pf::action');
$action->mock(action_execute => sub { push @actions, $_[0]; 1 });

sub cleanup {
    pf::dal::security_event->remove_items(-where => { mac => \@MACS });
    pf::dal::node->remove_items(-where => { mac => \@MACS });
    pf::dal::person->remove_items(-where => { pid => $PID });
}

sub open_macs {
    my ($id) = @_;
    return [ sort grep { pf::security_event::security_event_exist_open_or_delayed($_, $id) } @MACS ];
}

cleanup();
END { cleanup() }

# the class of the security event, as loaded from t/data/security_events.conf
my $class = $pf::security_event_config::SecurityEvent_Config{$ID};
is_deeply($class->{same_device_fields}, [qw(pid computername)], 'same_device_fields is a list in the configuration');
pf::class::class_merge($ID, $class->{desc}, 'Y', 3, 0, 0, undef, 4, 'generic', '', '', 'Enable Network', 'Y', 'isolation', '', 0, '', '', 'log');

person_add($PID);
node_add($A, pid => $PID, computername => 'laptop');
node_add($B, pid => $PID, computername => 'laptop');
node_add($C, pid => $PID, computername => 'desktop');
node_add($D, pid => $PID, computername => '');
node_add($E, pid => 'default', computername => 'laptop');

is_deeply([security_event_siblings($A, $ID)], [$B], 'the node sharing the owner and the computer name is a sibling');
is_deeply([security_event_siblings($B, $ID)], [$A], 'and the other way around');
is_deeply([security_event_siblings($C, $ID)], [], 'a node with another computer name has no sibling');
is_deeply([security_event_siblings($D, $ID)], [], 'a node with an empty field has no sibling');
is_deeply([security_event_siblings($E, $ID)], [], 'a node of the default owner has no sibling');
is_deeply([security_event_siblings($A, $OTHER_ID)], [], 'a security event without same_device_fields has no sibling');
is_deeply([security_event_siblings($A, '1234567')], [], 'an unknown security event has no sibling');

# open
ok(security_event_add($A, $ID) > 0, 'the security event is added for the node');
is_deeply(open_macs($ID), [$A, $B], 'and for the node of the same device, not the others');
is_deeply([sort @actions], [$A, $B], 'the actions ran for both');
is(pf::security_event::security_event_count_open_security_event_id($B, $ID), 1, 'one security event for the sibling');

@actions = ();
ok(security_event_add($B, $ID) > 0, 'adding it again for the sibling returns the existing security event');
is(pf::security_event::security_event_count_open_security_event_id($B, $ID), 1, 'still one security event for the sibling');
is(pf::security_event::security_event_count_open_security_event_id($A, $ID), 1, 'and one for the node');
is_deeply(\@actions, [], 'no action ran again');

# force close
@reevaluated = ();
ok(security_event_force_close($A, $ID), 'the security event is force closed for the node');
is_deeply(open_macs($ID), [], 'and closed for the node of the same device');
is_deeply(\@reevaluated, [$B], 'the access of the node of the same device is reevaluated, the caller handles the node');

# close
@actions = @reevaluated = ();
ok(security_event_add($B, $ID) > 0, 'the security event is added for the sibling');
is_deeply(open_macs($ID), [$A, $B], 'and for the node');
isnt(security_event_close($B, $ID), -1, 'the security event is closed for the sibling');
is_deeply(open_macs($ID), [], 'and for the node');
is_deeply(\@reevaluated, [$A], 'the access of the node is reevaluated');

# a propagated close stays on its node, and a closed sibling is skipped
@reevaluated = ();
ok(security_event_add($A, $ID) > 0, 'the security event is added for the node');
ok(security_event_force_close($B, $ID, 1), 'the security event is closed for the sibling as a propagated close');
is_deeply(open_macs($ID), [$A], 'the node keeps its security event');
ok(security_event_force_close($A, $ID), 'the security event is closed for the node');
is_deeply(\@reevaluated, [], 'the already closed sibling is left alone');

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
