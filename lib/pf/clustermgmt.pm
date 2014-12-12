package pf::clustermgmt;

=head1 NAME

pf::clustermgmt

=cut

=head1 DESCRIPTION

Use as a rpc server and as a rpc client.
It will sync between all the cluster members somes configurations parameters.

=cut

use Apache2::RequestRec ();
use Apache2::Request;
use Apache2::Const;
use APR::URI ();
use DBI;
use NetAddr::IP;
use List::MoreUtils qw(uniq);
use Try::Tiny;
use Socket;

use strict;
use pf::config;
use pf::config::cached;
use pf::log(service => 'httpd.admin');
use pf::util;
use pf::ConfigStore::Interface;
use pf::ConfigStore::Pf;
use NetAddr::IP;
use Net::Interface;
use List::MoreUtils qw(uniq);
use pf::api::jsonrpcclient;
use pf::services;


our %REST_PARSERS = (
    status => \&status,
    mysql => {
        connect => \&connect,
        cluster => \&cluster,
    },
);

=head2 handler

The handler check the status of all the services of the cluster and only allow connection from
the management network (need it for haproxy check)

=cut

sub handler {

    my $r = (shift);

    my $parsed = APR::URI->parse($r->pool, $r->uri);

    my @uri_elements = split('/',$parsed->path);
    shift @uri_elements;

    my $function = findhash($r,\@uri_elements);
    $r->handler('modperl');
    $r->set_handlers( PerlResponseHandler => \&answer );
    if (defined(my $funct= eval $function) ) {
        return $funct->($r,\@uri_elements);
    } else {
        return  Apache2::Const::SERVER_ERROR;
    }

}

=head2 findhash

Find the corresponding sub based on the uri

=cut

sub findhash {
    my ($r,$uri_elements) =@_;

    my $function = '$REST_PARSERS';
    for my $elements (@{$uri_elements}) {
        $function .= '{'.$elements.'}';
        if (ref(eval($function)) eq 'CODE') {
            last;
        }
    }
    return $function;
}

=head2 status

Return 200 if the service is running, 500 else

=cut

sub status {

    my ($r,$uri_elements) = @_;

    my $service = pop @{$uri_elements};
    if (grep { $_ eq $service } @pf::services::ALL_SERVICES) {
        my $manager = pf::services::get_service_manager($service);
        if ($manager->status('1')) {
            return  Apache2::Const::OK;
        } else {
            return  Apache2::Const::SERVER_ERROR;
        }
    } else {
        return  Apache2::Const::SERVER_ERROR;
    }
    return Apache2::Const::OK;
}

=head2 connect_db

Local DBI connection, we use it to test the local database connection

=cut

sub connect_db {

    my $DB_Config = $Config{'database'};
    #we only want to test local access
    my $host = 'localhost';
    my $port = $DB_Config->{'port'};
    my $user = $DB_Config->{'user'};
    my $pass = $DB_Config->{'pass'};
    my $db   = $DB_Config->{'db'};
    my $mydbh = DBI->connect( "dbi:mysql:dbname=$db;host=$host;port=$port",
        $user, $pass, { RaiseError => 0, PrintError => 0, mysql_auto_reconnect => 1 } );
    if ($mydbh) {
        return ($mydbh);
    } else {
        return ();
    }
}

=head2 connect

Check if we can connect to mysql

=cut

sub connect {

    my ($r) = @_;

    my $mydbh = connect_db();
    if ($mydbh) {
        if ($mydbh->ping) {
            return Apache2::Const::OK;
        } else {
            return  Apache2::Const::SERVER_ERROR;
        }
    } else {
        return  Apache2::Const::SERVER_ERROR;
    }
}

=head2 cluster

Check the status of the cluster

=cut

sub cluster {

    my ($r) = @_;

    my $mydbh = connect_db();
    if ($mydbh) {
        my $query = $mydbh->prepare('SELECT 1 FROM node LIMIT 1');
        $query->execute;
        my ($val) = $query->fetchrow_array();
        if ($val eq '1') {
            return Apache2::Const::OK;
        } else {
            return  Apache2::Const::SERVER_ERROR;
        }
    } else {
        return  Apache2::Const::SERVER_ERROR;
    }
}

=head2 answer

ResponseHandler answer

=cut

sub answer {

    my ($r) = @_;

    return Apache2::Const::OK;
}

=head2 sync_cluster

RPC Client that send his configuration and adapt his own

=cut

sub sync_cluster {
    my $logger = get_logger;
    pf::config::cached::ReloadConfigs();

    my $client = pf::api::jsonrpcclient->new;

    my @all_members;
    my $priority;
    my @priority;

    my $int = $management_network->{'Tint'};
    my @members = split(',',$Config{"active_active"}{'members'});
    @members = grep { $_ ne $Config{"interface $int"}{'ip'} } @members;

    my @ints = uniq(@listen_ints,@dhcplistener_ints);

    my $cs = pf::ConfigStore::Interface->new();

    foreach my $interface ( @ints ) {
        my $dhcpd_master = 0;
        my $mysql_master = 0;
        my $cfg = $Config{"interface $interface"};
        if (isenabled($cfg->{'active_active_enabled'})) {

            if ( (defined $Config{"interface $int"}{'active_active_mysql_master'}) && ($Config{"interface $int"}{'ip'} eq $Config{"interface $int"}{'active_active_mysql_master'}) ) {
                $priority = '150';
            } else {
                $priority = $Config{"interface $interface"}{'active_active_priority'} || 0;
            }
            my @all_members;
            for my $member (@members) {
                my %data = (
                    'ip' => $cfg->{'ip'},
                    'dhcpd' => $cfg->{'active_active_dhcpd_master'},
                    'activeip' => $cfg->{'active_active_ip'},
                    'mysql' => $cfg->{'active_active_mysql_master'} || 0,
                    'priority' => $priority,
                );
                $client->{'proto'} = 'https';
                $client->{'host'} = $member;
                my ($result) = $client->call('active_active',%data);
                if ($result){
                    $dhcpd_master = $result->{'dhcpd_master'} if ($result->{'dhcpd_master'} && defined($cfg->{'active_active_dhcpd_master'}));
                    $mysql_master = $result->{'mysql_master'} if ($result->{'mysql_master'} && defined($cfg->{'active_active_mysql_master'}));
                    push(@all_members , split(',',$result->{'active_active_members'}));
                    push(@all_members , $result->{'member_ip'});
                    $logger->error("There is more than one dhcpd master, fix that") if ($result->{'dhcpd_master'} && $Config{"interface $int"}{'active_active_dhcpd_master'});
                    push(@priority, $result->{'priority'});
                    if ($priority eq $result->{'priority'}) {
                        my $i = 100;
                        while (grep { $_ eq $priority } @priority) {
                            $priority = $i;
                            $i++;
                        }
                        $cs->update($interface, { active_active_priority => $priority});
                    }
                } else {
                    @all_members = grep { $_ ne $member } @all_members;
                }
            }
            push (@all_members,$cfg->{'ip'});
            my @uniq_members = uniq(@all_members);

            $cs->update($interface, { active_active_members => join(',',@uniq_members)});
            $cs->update($interface, { active_active_dhcpd_master => 0}) if ($dhcpd_master && defined($cfg->{'active_active_dhcpd_master'} ) && $cfg->{'type'} ne 'management');
            $cs->update($interface, { active_active_mysql_master => $mysql_master}) if ($mysql_master && defined($cfg->{'active_active_mysql_master'} ) &&  $cfg->{'type'} eq 'management');
            $cs->update($interface, { active_active_dhcpd_master => 1}) if (!$dhcpd_master && defined($cfg->{'active_active_dhcpd_master'} ) && $cfg->{'type'} ne 'management');
            $cs->update($interface, { active_active_mysql_master => $Config{"interface $int"}{ip}}) if (!$mysql_master && defined($cfg->{'active_active_mysql_master'} ) && $cfg->{'type'} eq 'management' );
            $cs->update($interface, { active_active_priority => $priority}) if ($priority eq 150);
            undef(@all_members);
        }
        $cs->commit();
        #Reload configuration
        pf::config::cached::ReloadConfigs();
    }
}

=head2 update_services

Update some configuration parameter to run or stop task

=cut

sub update_services {
    my($mode) =@_;

    my $pfcs = pf::ConfigStore::Pf->new();
    my $maintenance = $pfcs->read('maintenance');

    my $iplog_cleanup_interval = $maintenance->{'temporary_iplog_cleanup_interval'} || $maintenance->{'iplog_cleanup_interval'};
    my $locationlog_cleanup_interval = $maintenance->{'temporary_locationlog_cleanup_interval'} || $maintenance->{'locationlog_cleanup_interval'};
    my $node_cleanup_interval = $maintenance->{'temporary_node_cleanup_interval'} || $maintenance->{'node_cleanup_interval'};
    my $traplog_cleanup_interval = $maintenance->{'temporary_traplog_cleanup_interval'} || $maintenance->{'traplog_cleanup_interval'};
    my $nodes_maintenance_interval = $maintenance->{'temporary_nodes_maintenance_interval'} || $maintenance->{'nodes_maintenance_interval'};
    my $violation_maintenance_interval = $maintenance->{'temporary_violation_maintenance_interval'} || $maintenance->{'violation_maintenance_interval'};
    my $inline_accounting_maintenance_interval = $maintenance->{'temporary_inline_accounting_maintenance_interval'} || $maintenance->{'inline_accounting_maintenance_interval'};
    my $acct_maintenance_interval = $maintenance->{'temporary_acct_maintenance_interval'} || $maintenance->{'acct_maintenance_interval'};
    my $provisioning_compliance_poll_interval = $maintenance->{'temporary_provisioning_compliance_poll_interval'} || $maintenance->{'provisioning_compliance_poll_interval'};

    if ($mode eq 'master') {

        $pfcs->update('maintenance', { iplog_cleanup_interval => $iplog_cleanup_interval, locationlog_cleanup_interval => $locationlog_cleanup_interval, node_cleanup_interval => $node_cleanup_interval, traplog_cleanup_interval =>  $traplog_cleanup_interval, nodes_maintenance_interval => $nodes_maintenance_interval, violation_maintenance_interval => $violation_maintenance_interval, inline_accounting_maintenance_interval => $inline_accounting_maintenance_interval, acct_maintenance_interval => $acct_maintenance_interval, provisioning_compliance_poll_interval => $provisioning_compliance_poll_interval});

    } elsif ($mode eq 'slave') {

        $pfcs->update('maintenance', { iplog_cleanup_interval => '0s', locationlog_cleanup_interval => '0s', node_cleanup_interval => '0s', traplog_cleanup_interval =>  '0s', nodes_maintenance_interval => '0s', violation_maintenance_interval => '0s', inline_accounting_maintenance_interval => '0s', acct_maintenance_interval => '0s', provisioning_compliance_poll_interval => '0s'});
        $pfcs->update('maintenance', { temporary_iplog_cleanup_interval => $iplog_cleanup_interval, temporary_locationlog_cleanup_interval => $locationlog_cleanup_interval, temporary_node_cleanup_interval => $node_cleanup_interval, temporary_traplog_cleanup_interval =>  $traplog_cleanup_interval, temporary_nodes_maintenance_interval => $nodes_maintenance_interval, temporary_violation_maintenance_interval => $violation_maintenance_interval, temporary_inline_accounting_maintenance_interval => $inline_accounting_maintenance_interval, temporary_acct_maintenance_interval => $acct_maintenance_interval, temporary_provisioning_compliance_poll_interval => $provisioning_compliance_poll_interval});

    }

    $pfcs->commit();
}

=head2 is_vip_running

=cut

sub is_vip_running {
    my ($int) = @_;

    my $cfg = $Config{"interface $int"};

    if (isenabled($cfg->{'active_active_enabled'})) {

        my @all_ifs = Net::Interface->interfaces();
        foreach my $inf (@all_ifs) {
            if ($inf->name eq $int) {
                my @masks = $inf->netmask(AF_INET());
                my @addresses = $inf->address(AF_INET());
                for my $i (0 .. $#masks) {
                    if (inet_ntoa($addresses[$i]) eq $Config{"interface $int"}{'active_active_ip'}) {
                        return 'master';
                    }
                }
                return 'slave';
            }
        }
    }
    return 0;
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2014 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and::or
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
