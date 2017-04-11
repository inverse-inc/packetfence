package pf::task::pfsnmp_parsing;

=head1 NAME

pf::task::pfsnmp_parsing - snmp parsing

=cut

=head1 DESCRIPTION

pf::task::pfsnmp_parsing

=cut

use strict;
use warnings;
use pf::log;
use pf::SwitchFactory;
use pf::pfqueue::producer::redis;
use pf::StatsD::Timer;

=head2 doTask

Parse the snmp trap for the switch

=cut

my $logger = get_logger();

sub doTask {
    my $timer = pf::StatsD::Timer->new;
    my ($self, $args) = @_;
    my ($trapInfo, $variables) = @$args;
    my $switch_id = $trapInfo->{switchIp};
    unless (defined $switch_id) {
        $logger->error("No switch found in trap");
        return;
    }

    my $switch = pf::SwitchFactory->instantiate($switch_id);
    unless ($switch) {
        $logger->error("Can not instantiate switch '$switch_id' !");
        return;
    }

    my $trap = $switch->normalizeTrap($args);
    unless ($trap) {
        $logger->error("Unable to normalize trap sent from '$switch_id' ");
        return;
    }

    if ($trap->{trapType} eq 'unknown') {
        $logger->debug("ignoring unknown trap for '$switch_id'");
        return;
    }

    $trap->{switchId} = $switch_id;
    $trap->{trapVariables} = $variables;
    $trap->{trapMeta} = $trapInfo;

    # Set default values
    for my $key (qw(trapVlan trapOperation trapMac trapSSID trapClientUserName trapIfIndex trapConnectionType)) {
        $trap->{$key} //= '';
    }

    my $client = pf::pfqueue::producer::redis->new(queue => 'pfsnmp');
    $client->submit("pfsnmp", "pfsnmp", $trap);
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

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
