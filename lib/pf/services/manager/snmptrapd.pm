package pf::services::manager::snmptrapd;

=head1 NAME

pf::services::manager::snmptrapd add documentation

=cut

=head1 DESCRIPTION

pf::services::manager::snmptrapd

=cut


use strict;
use warnings;
use Moo;
use pf::cluster;
use pf::constants;
use pf::config qw($management_network);
use pf::file_paths qw(
    $install_dir
    $generated_conf_dir
    $var_dir
    $conf_dir
);
use pf::SwitchFactory;
use pf::util;
use lib qw(/usr/local/pf/lib);
use pf::constants qw($TRUE);
use Data::Dumper;
use pf::log;

use Template;
extends 'pf::services::manager';

has '+name' => (default => sub { 'snmptrapd' } );
has configFilePath => (is => 'rw', builder => 1, lazy => 1);
has configTemplateFilePath => (is => 'rw', builder => 1, lazy => 1);

my $management_ip = '';

if (ref($management_network)) {
    if ( $pf::cluster::cluster_enabled ) {
        $management_ip = pf::cluster::management_cluster_ip();
    } else {
        $management_ip = defined($management_network->tag('vip')) ? $management_network->tag('vip') : $management_network->tag('ip');
    }
    
    $management_ip .= ':162';
}

sub _build_configFilePath {
    my ($self) = @_;
    my $name = $self->name;
    return "$generated_conf_dir/${name}.conf";
}

sub _build_configTemplateFilePath {
    my ($self) = @_;
    my $name = $self->name;
    return "$conf_dir/${name}.conf";

}

has '+launcher' => (default => sub { "%1\$s -n -c $generated_conf_dir/snmptrapd.conf -C -A -Lf $install_dir/logs/snmptrapd.log -p $install_dir/var/run/snmptrapd.pid -On $management_ip" } );

=head2 generateConfig

generate the snmptrapd.conf configuration

=cut

sub generateConfig {
    my ($self) = @_;
    my $vars = $self->createVars();
    my $tt = Template->new(ABSOLUTE => 1);
    $tt->process($self->configTemplateFilePath, $vars, $self->configFilePath) or die $tt->error();
    print Dumper ($self);
    return 1;
}


=head2 CreateVars

Returns a tuple of three hashref. One with all SNMPv3 Trap Users values, another parameter containing the SNMPv3 Key value and one with unique communities.

=cut

sub createVars {
    my $logger = get_logger();

    my %switchConfig = %{ pf::SwitchFactory->config };

    my (%snmpv3_users, %snmp_communities, %auth_users);
    foreach my $key ( sort keys %switchConfig ) {
        next if ( $key =~ /^default$/i );

        # TODO we can probably make this more performant if we avoid object instantiation (can we?)
        my $switch = pf::SwitchFactory->instantiate($key);
        if (!$switch) {
            $logger->error("Can not instantiate switch $key!");
        } else {
            if ( $switch->{_SNMPVersionTrap} eq '3' ) {
                $snmpv3_users{"$switch->{_SNMPEngineID} $switch->{_SNMPUserNameTrap}"} =
                    '-e ' . $switch->{_SNMPEngineID} . ' ' . $switch->{_SNMPUserNameTrap} . ' '
                    . $switch->{_SNMPAuthProtocolTrap} . ' ' . $switch->{_SNMPAuthPasswordTrap} . ' '
                    . $switch->{_SNMPPrivProtocolTrap} . ' ' . $switch->{_SNMPPrivPasswordTrap};
            $auth_users{$switch->{_SNMPUserNameTrap}} = 1;
            } else {
                $snmp_communities{$switch->{_SNMPCommunityTrap}} = $TRUE;
            }
        }
    }
    return {
           auth_users=> [keys %auth_users],
           snmpv3_users => [values %snmpv3_users],
           snmp_communities => [keys %snmp_communities],
    };

}
=head1 AUTHOR

Inverse inc. <info@inverse.ca>


=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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
