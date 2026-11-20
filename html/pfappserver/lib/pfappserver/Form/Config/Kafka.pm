package pfappserver::Form::Config::Kafka;

=head1 NAME

pfappserver::Form::Config::Kafka -

=head1 DESCRIPTION

pfappserver::Form::Config::Kafka

=cut

use strict;
use warnings;
use HTML::FormHandler::Moose;
use pf::cluster qw(@db_cluster_hosts);
extends 'pfappserver::Base::Form';
with 'pfappserver::Base::Form::Role::Help';

has_field 'iptables' => (
    type => 'Compound',
);

has_field 'iptables.clients' => (
   type => 'Repeatable',
);

has_field 'iptables.clients.contains' => (
   type   => 'IPAddress',
   accept => ['%mgmtip%'],
);

has_field 'iptables.cluster_ips' => (
   type => 'Repeatable',
);

has_field 'iptables.cluster_ips.contains' => (
   type   => 'IPAddress',
   accept => ['%mgmtip%'],
);

has_field 'general' => (
    type => 'Compound',
);

has_field 'general.broker_only_hosts' => (
   type => 'Select',
   multiple => 1,
   options_method => \&options_cluster_hosts,
   no_option_validation => 1,
   tags => {
       after_element => \&help,
       help => 'Servers of the cluster that run Kafka without being part of the controller quorum (e.g. the servers of a secondary zone). Run /usr/local/pf/bin/kafka-init.pl to apply: the controller quorum is fixed when the Kafka cluster is created, changing it requires to remove the Kafka data of every server.',
   },
);

has_field 'admin' => (
   type => 'UserPass',
);

has_field 'auths' => (
   type => 'Repeatable',
);

has_field 'auths.contains' => (
   type => 'UserPass',
);

has_field 'host_configs' => (
   type => 'Repeatable',
);

has_field 'host_configs.contains' => (
   type => 'Compound',
);

has_field 'host_configs.contains.config' => (
   type => 'Repeatable',
);

has_field 'host_configs.contains.config.contains' => (
   type => 'NameVal',
);

has_field 'host_configs.contains.host' => (
   type => 'Text',
);

has_field 'cluster' => (
   type => 'Repeatable',
);

has_field 'cluster.contains' => (
   type => 'NameVal',
);

=head2 options_cluster_hosts

The servers of the cluster, all the zones included

=cut

sub options_cluster_hosts {
    return map { +{ value => $_, label => $_ } } sort @db_cluster_hosts;
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
