package pf::task::pfsnmp_parsing;

=head1 NAME

pf::task::pfsnmp_parsing - snmp parsing

=cut

=head1 DESCRIPTION

pf::task::pfsnmp_parsing

=cut

use strict;
use warnings;
use base 'pf::task';
use pf::log;
use pf::Redis;
use pf::SwitchFactory;
use pf::Switch::constants;
use pf::pfqueue::producer::redis;
use pf::StatsD::Timer;
use pf::rate_limiter;
use pf::config::util;
use pf::constants qw($TRUE $FALSE);
use pf::util;
use pf::config qw(%Config);
use pf::util::pfqueue qw(task_counter_id consumer_redis_client);
use pf::constants::pfqueue qw($PFQUEUE_COUNTER);

=head2 doTask

Parse the snmp trap for a switch and queue the trap for processing

=cut

my $logger = get_logger();

sub doTask {
    my $timer = pf::StatsD::Timer->new;
    my ($self, $args) = @_;
    my ($trapInfo, $variables) = @$args;
    my $switch_id = $trapInfo->{switchIp};
    unless (defined $switch_id) {
        my $msg = "No switch found in trap";
        $logger->error($msg);
        return {message => $msg, status => 422}, undef;
    }

    my $switch = pf::SwitchFactory->instantiate($switch_id);
    unless ($switch) {
        my $msg = "Can not instantiate switch '$switch_id' !";
        $logger->error($msg);
        return {message => $msg, status => 404}, undef;
    }

    my $trap = $switch->normalizeTrap($args);
    unless ($trap) {
        my $msg = "Unable to normalize trap sent from '$switch_id' !";
        $logger->error($msg);
        return {message => $msg, status => 422}, undef;
    }

    if ($trap->{trapType} eq 'unknown') {
        $logger->debug("ignoring unknown trap for '$switch_id'");
        return undef, undef;
    }

    if ($self->performTrapLimiting($switch, $trap->{trapIfIndex})) {
        $logger->debug("too many traps for $switch_id");
        return undef, undef;
    }

    unless ($switch->handleTrap($trap)) {
        $logger->error("Skipping general trap handling for $switch_id");
        return undef, undef;
    }

    $trap->{switchId} = $switch_id;
    $trap->{trapVariables} = $variables;
    $trap->{trapMeta} = $trapInfo;

    # Set default values
    for my $key (qw(trapVlan trapOperation trapMac trapSSID trapClientUserName trapIfIndex trapConnectionType)) {
        $trap->{$key} //= '';
    }

    if (ignoreTrap($switch, $trap)) {
        $logger->debug("Trap ignored for '$switch_id'");
        return undef, undef;
    }

    my $client = pf::pfqueue::producer::redis->new(queue => 'pfsnmp');
    $client->submit("pfsnmp", "pfsnmp", $trap);
    return undef, undef;
}

=head2 ignoreTrap

ignoreTrap

=cut

sub ignoreTrap {
    my ($switch, $trap) = @_;
    my $type = $trap->{trapType};
    if ($type eq 'secureMacAddrViolation') {
        if (!$switch->isPortSecurityEnabled($trap->{trapIfIndex})) {
            return 1;
        }
        my $counter_id = task_counter_id("pfsnmp", "pfsnmp", $trap);
        my $redis = consumer_redis_client();
        my $count = $redis->hget($PFQUEUE_COUNTER, $counter_id);
        if (defined $count && $count > 0) {
            return 1;
        }
    } elsif ($type eq 'mac') {
        if ( $trap->{trapVlan} ne $switch->getVlan($trap->{trapIfIndex})) {
            return 1;
        }
    }
    return 0;
}

# sub performTrapLimiting {{{1
sub performTrapLimiting {
    # skipping if feature is disabled
    return $FALSE if (isdisabled($Config{'snmp_traps'}{'trap_limit'}));

    my ($self, $switch, $switchIfIndex) = @_;
    # skipping if trapIfIndex is undef or empty
    return $FALSE if (!defined($switchIfIndex) || $switchIfIndex eq '');

    my $trapsLimitAction = $Config{'snmp_traps'}{'trap_limit_action'};

    # if there's no action configured then let's continue parsing the trap
    return $FALSE if ( isempty($trapsLimitAction) );

    # Poking tied config files here instead of declaring them globally is arguably discutable on terms of performances
    my $trapsLimitThreshold = $Config{'snmp_traps'}{'trap_limit_threshold'};

    my $switchId = $switch->{_id};

    return $FALSE unless pf::rate_limiter::is_pass_limit("trap.${switchId}.${switchIfIndex}", $trapsLimitThreshold, 60);

    if ( is_in_list('email', $trapsLimitAction) || is_in_list('shut', $trapsLimitAction) ) {
        my %email;

        $email{'subject'} = "Too many traps coming from switch $switchId";
        $email{'message'} = "Too many SNMP traps were received from a switchport according to the threshold.\n\n";
        $email{'message'} .= "Switch: $switchId\n";
        $email{'message'} .= "ifIndex: $switchIfIndex\n";
        $email{'message'} .= "Threshold: maximum $trapsLimitThreshold SNMP traps per 1 minute.\n";

        if ( is_in_list('shut', $trapsLimitAction) ) {
            $email{'message'} .= "Action: PacketFence SHUTTED THE PORT";
            $switch->setAdminStatus($switchIfIndex, $SNMP::DOWN);
        }
        #Send an alert only once every hour
        unless (pf::rate_limiter::is_pass_limit("trapemail.${switchId}.${switchIfIndex}", 1 , 3600 )) {
            pfmailer(%email);
        }
    }

    $logger->warn(
        "We received many traps (over $trapsLimitThreshold) in a minute "
        . "from ifIndex $switchIfIndex of switch $switch->{_id}"
    );

    return $TRUE;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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
