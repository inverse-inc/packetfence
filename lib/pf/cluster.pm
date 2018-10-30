package pf::cluster;

=head1 NAME

pf::cluster

=cut

=head1 DESCRIPTION

Interface to get information about the cluster based on the cluster.conf

=cut

use strict;
use warnings;

use pf::log;
use pfconfig::cached_hash;
use pfconfig::cached_array;
use pfconfig::cached_scalar;
use List::MoreUtils qw(first_index firstval uniq);
use Net::Interface;
use NetAddr::IP;
use Socket;
use pf::file_paths qw(
    $cluster_config_file
    $config_version_file
    $maintenance_file
    $var_dir
);
use pf::util;
use pf::constants;
use pf::constants::cluster qw(@FILES_TO_SYNC);
use Config::IniFiles;
use File::Slurp qw(read_file write_file);
use Time::HiRes qw(time);
use POSIX qw(ceil);
use Crypt::CBC;
use pf::config::cluster;

use Module::Pluggable
  'search_path' => [qw(pf::ConfigStore)],
  'sub_name'    => '_all_stores',
  'require'     => 1,
  'inner'       => 0,
  ;


use Exporter;
our ( @ISA, @EXPORT );
@ISA = qw(Exporter);
@EXPORT = qw(%ConfigCluster @cluster_servers @cluster_hosts @db_cluster_servers @db_cluster_hosts @config_cluster_servers @config_cluster_hosts $cluster_enabled $host_id $CLUSTER $cluster_name);

our (%clusters_hostname_map, $cluster_enabled, $cluster_name, %ConfigCluster, @cluster_servers, @cluster_hosts, @db_cluster_servers, @db_cluster_hosts, @config_cluster_servers, @config_cluster_hosts);
tie %clusters_hostname_map, 'pfconfig::cached_hash', 'resource::clusters_hostname_map';

our $CLUSTER = "CLUSTER";

our $host_id = $pf::config::cluster::host_id;

$cluster_enabled = $pf::config::cluster::cluster_enabled;

if($cluster_enabled) {
    $cluster_name = $clusters_hostname_map{$host_id} // die "Can't determine cluster name for host $host_id\n";
    tie %ConfigCluster, 'pfconfig::cached_hash', "config::Cluster($cluster_name)";
    tie @cluster_servers, 'pfconfig::cached_array', "resource::cluster_servers($cluster_name)";
    tie @cluster_hosts, 'pfconfig::cached_array', "resource::cluster_hosts($cluster_name)";
    tie @db_cluster_servers, 'pfconfig::cached_array', "resource::all_cluster_servers($cluster_name)";
    tie @db_cluster_hosts, 'pfconfig::cached_array', "resource::all_cluster_hosts($cluster_name)";
    tie @config_cluster_servers, 'pfconfig::cached_array', "resource::all_cluster_servers($cluster_name)";
    tie @config_cluster_hosts, 'pfconfig::cached_array', "resource::all_cluster_hosts($cluster_name)";
}

=head2 node_disabled_file

Path to the file that states whether or not a node is disabled

=cut

sub node_disabled_file {
    my ($hostname) = @_;
    return "$var_dir/run/$hostname-cluster-disabled";
}

=head2 enabled_servers

Returns the @cluster_servers list without the servers that are disabled on this host

=cut

sub enabled_servers {
    return map { (-f node_disabled_file($_->{host})) ? () : $_ } @cluster_servers;
}

=head2 enabled_hosts

Returns the @cluster_hosts list without the servers that are disabled on this host

=cut

sub enabled_hosts {
    return map { (-f node_disabled_file($_)) ? () : $_ } @cluster_hosts;
}

=head2 db_enabled_servers

Returns the @db_cluster_servers list without the servers that are disabled on this host

=cut

sub db_enabled_servers {
    return map { (-f node_disabled_file($_->{host})) ? () : $_ } @db_cluster_servers;
}

=head2 db_enabled_hosts

Returns the @db_cluster_hosts list without the servers that are disabled on this host

=cut

sub db_enabled_hosts {
    return map { (-f node_disabled_file($_)) ? () : $_ } @db_cluster_hosts;
}

=head2 config_enabled_servers

Returns the @config_cluster_servers list without the servers that are disabled on this host

=cut

sub config_enabled_servers {
    return map { (-f node_disabled_file($_->{host})) ? () : $_ } @config_cluster_servers;
}

=head2 config_enabled_hosts

Returns the @config_cluster_hosts list without the servers that are disabled on this host

=cut

sub config_enabled_hosts {
    return map { (-f node_disabled_file($_)) ? () : $_ } @config_cluster_hosts;
}

=head2 all_hosts

Returns the list of all the hosts this server interracts with whether its DB servers or app servers

=cut

sub all_hosts {
    return uniq(@cluster_hosts, @db_cluster_hosts);
}

=head2 is_management

Returns 1 if this node is the management node (i.e. owning the management ip)

=cut

sub is_management {
    my $logger = get_logger();
    unless($cluster_enabled){
        $logger->debug("Clustering is not enabled. Cannot be management node.");
        return 0;
    }
    my $cluster_ip = management_cluster_ip();
    my @all_ifs = Net::Interface->interfaces();
    foreach my $inf (@all_ifs) {
        my @masks = $inf->netmask(AF_INET());
        my @addresses = $inf->address(AF_INET());
        for my $i (0 .. $#masks) {
            if (inet_ntoa($addresses[$i]) eq $cluster_ip) {
                return 1;
            }
        }
    }
    return 0;

}

=head2 get_host_id

Returns the current host id (hostname)

=cut

sub get_host_id {
    return $host_id;
}

=head2 current_server

Returns the cluster config for this server

=cut

sub current_server {
    return (enabled_servers())[cluster_index()];
}

=head2 cluster_ip

Returns the cluster IP address for an interface

=cut

sub cluster_ip {
    my ($interface) = @_;
    return $ConfigCluster{$CLUSTER}->{"interface $interface"}->{ip};
}

=head2 cluster_ipv6

Returns the cluster IPv6 address for an interface

=cut

sub cluster_ipv6 {
    my ( $interface ) = @_;
    return $ConfigCluster{$CLUSTER}->{"interface $interface"}->{ipv6_address};
}

=head2 management_cluster_ip

Returns the management cluster IP address for the cluster

=cut

sub management_cluster_ip {
    return $ConfigCluster{$CLUSTER}->{management_ip};
}

=head2 cluster_index

Returns the index of this server in the cluster (lower is better)

=cut

sub cluster_index {
    my $cluster_index = first_index { $_ eq $host_id } enabled_hosts();
    return $cluster_index;
}

=head2 mysql_servers

Get the list of the MySQL servers ordered by priority

=cut

sub mysql_servers {
    return reverse(db_enabled_servers());
}

=head2 members_ips

Get all the members IP for an interface

=cut

sub members_ips {
    my ($interface) = @_;
    my $logger = get_logger();
    unless(exists($ConfigCluster{$host_id}->{"interface $interface"}->{ip})){
        $logger->warn("requesting member ips for an undefined interface...");
        return {};
    }
    my %data = map { $_->{host} => $_->{"interface $interface"}->{ip} } enabled_servers();
    return \%data;
}

=head2 api_call_each_server

Call an API method on each member of the cluster

=cut

sub api_call_each_server {
    my ($asynchronous, $api_method, @api_args) = @_;

    require pf::api::jsonrpcclient;
    my @failed;
    my $method = $asynchronous ? "notify" : "call";
    foreach my $server (config_enabled_servers()){
        next if($server->{host} eq $host_id);
        my $apiclient = pf::api::jsonrpcclient->new(host => $server->{management_ip}, proto => 'https');
        eval {
            pf::log::get_logger->info("Calling $api_method on $server->{host}");
            my ($result) = $apiclient->$method($api_method, @api_args);
        };
        if($@){
            pf::log::get_logger->error("Failed to call $api_method . $@");
            push @failed, $server->{host};
        }
    }
    return \@failed;
}

=head2 sync_files

Sync files through all members of a cluster

=cut

sub sync_files {
    my ($files, %options) = @_;
    unless($cluster_enabled){
        get_logger->trace("Won't sync files because we're not in a cluster");
        return [];
    }

    my @failed;
    foreach my $file (@$files){
        pf::log::get_logger->info("Synching file $file to cluster members");
        my %data = ( conf_file => $file, from => pf::cluster::current_server()->{management_ip} );
        push @failed, @{api_call_each_server($options{async}, 'distant_download_configfile', %data)};
    }
    return \@failed;
}


=head2 sync_file_deletes

Sync files that were deleted

=cut

sub sync_file_deletes {
    my ($files, %options) = @_;
    unless($cluster_enabled){
        get_logger->trace("Won't sync files because we're not in a cluster");
        return [];
    }
    my @failed;
    push @failed, @{api_call_each_server($options{async}, 'delete_files', $files)};
    return \@failed;
}


=head2 send_dir_copy

Send a message to the other cluster servers to copy a directory from their filesystem

=cut

sub send_dir_copy {
    my ($source_dir, $dest_dir, %options) = @_;
    return api_call_each_server($options{async}, 'copy_directory', $source_dir, $dest_dir);
}

=head2 sync_storages

Sync a storage through all members of a cluster

=cut

sub sync_storages {
    my ($stores, %options) = @_;
    require pf::api::jsonrpcclient;
    my $apiclient = pf::api::jsonrpcclient->new();
    foreach my $store (@$stores){
        eval {
            get_logger->info("Synching storage : $store");
            my $cs = $store->new;
            my $pfconfig_namespace = $cs->pfconfigNamespace;
            my $config_file = $cs->configFile;
            my %data = (
                namespace => $pfconfig_namespace,
                conf_file => $config_file,
            );
            my ($result) = $apiclient->call( 'expire_cluster', %data );
        };
        if($@){
            print STDERR "ERROR !!! Failed to sync store : $store ($@) \n";
        }
    }
}

=head2 is_vip_running

=cut

sub is_vip_running {
    my ($int) = @_;

    if ( defined($ConfigCluster{$CLUSTER}->{"interface $int"}) ) {

        my @all_ifs = Net::Interface->interfaces();
        foreach my $inf (@all_ifs) {
            if ($inf->name eq $int) {
                my @masks = $inf->netmask(AF_INET());
                my @addresses = $inf->address(AF_INET());
                for my $i (0 .. $#masks) {
                    if (inet_ntoa($addresses[$i]) eq cluster_ip($int)) {
                        return $TRUE;
                    }
                }
                return $FALSE;
            }
        }
    }
    return $FALSE;
}

=head2 sync_directory_empty

=cut

sub sync_directory_empty {
    my ($dir, %options) = @_;
    unless($cluster_enabled){
        get_logger->trace("Won't sync files because we're not in a cluster");
        return [];
    }
    my @failed;
    push @failed, @{api_call_each_server($options{async}, 'directory_empty', $dir)};
    return \@failed;
}

=head2 notify_each_server

Will dispatch an notify call to each server part of the cluster.
If this is not a cluster, it will dispatch the notification only to itself.

=cut

sub notify_each_server {
    my (@args) = @_;
    if($cluster_enabled) {
        foreach my $server (config_enabled_servers()) {
            my $apiclient = pf::api::jsonrpcclient->new(proto => 'https', host => $server->{management_ip});
            $apiclient->notify(@args);
        }
    }
    else {
        my $apiclient = pf::client::getClient();
        $apiclient->notify(@args);
    }
}

=head2 call_server

Call an API method on a cluster member

=cut

sub call_server {
    my ($cluster_id, @args) = @_;
    require pf::api::jsonrpcclient;
    my $server = firstval { $_->{host} eq $cluster_id } @config_cluster_servers;
    my $apiclient = pf::api::jsonrpcclient->new(proto => 'https', host => $server->{management_ip});
    return $apiclient->call(@args);
}

=head2 queue_stats

Get queue stats for the cluster

=cut

sub queue_stats {
    require pf::api::jsonrpcclient;
    my @stats;
    foreach my $server (enabled_servers()) {
        my $apiclient = pf::api::jsonrpcclient->new(proto => 'https', host => $server->{management_ip});
        my %s = (
            %$server,
            stats  => $apiclient->call('queue_stats')
        );
        push @stats, \%s;
    }
    return \@stats;
}

=head2 get_all_config_version

Get the configuration version from all the cluster members

Returns a map of the format {SERVER_NAME => VERSION, SERVER_NAME_2 => VERSION, ...} and one of the format {VERSION1 => [SERVER_NAME_1, SERVER_NAME_2], VERSION2 => [SERVER_NAME_3]}

=cut

sub get_all_config_version {
    my %results;
    foreach my $server (config_enabled_hosts()) {
        eval {
            $results{$server} = [pf::cluster::call_server($server, 'get_config_version')]->[0]->{version};
        };
        if($@) {
            get_logger->error("Failed to get the config version for $server");
            $results{$server} = 0;
        }
    }

    my $servers_map = \%results;

    my $versions_map = {};
    while(my ($server, $version) = each(%$servers_map)){
        $versions_map->{$version} //= [];
        push @{$versions_map->{$version}}, $server;
    }

    return ($servers_map, $versions_map);
}

=head2 handle_config_conflict

Detect and handle any configuration conflict between the cluster members

See the Clustering guide for details on the algorithm

=cut

sub handle_config_conflict {
    my $quorum_version;

    my $version = pf::config::cluster::get_config_version();
    my ($servers_map, $versions_map) = pf::cluster::get_all_config_version();

    # We make sure we have the right version for this node (in case webservices is currently dead)
    $servers_map->{$host_id} = $version;


    if(keys(%$versions_map) == 2 && (defined($versions_map->{0}) && @{$versions_map->{0}} > 0)) {
        get_logger->warn("Not all servers were checked for the configuration version but all alive ones are running the same version.");
    }
    elsif(keys(%$versions_map) > 1) {
        get_logger->warn("Current version is not the same as the one on all the other cluster servers");
        
        # Can't quorum using 2 hosts
        if(scalar(config_enabled_hosts()) > 2) {
            my $half = (scalar(config_enabled_hosts()) / 2);
            my $quorum = int($half) == $half ? $half + 1 : ceil($half);

            my $servers_count = 0;
            # Figure out which servers have the quorum on the version ID
            while(my ($version, $servers) = each(%$versions_map)) {
                if (scalar(@$servers) > $servers_count) {
                    $servers_count = scalar(@$servers);
                    $quorum_version = $version;
                }
            }

            # Ensuring they have quorum and that its not the dead servers that have quorum (through the version not being 0)
            if ($quorum_version == 0) {
                get_logger->warn("There are more dead servers than alive ones with the same version. Most recent configuration will be selected.");
                goto SYNC_MOST_RECENT;
            }
            elsif($servers_count >= $quorum) {
                get_logger->info("Quorum found between servers : ".join(',', @{$versions_map->{$quorum_version}}));
                goto SYNC_QUORUM;
            }
            else {
                get_logger->warn("Failed to find quorum in the cluster. Most recent configuration will be selected.");
                goto SYNC_MOST_RECENT;
            }
        }
        else {
            get_logger->info("Quorum not possible in 2 servers clusters. Most recent configuration will be selected.");
            goto SYNC_MOST_RECENT;
        }
    }

    get_logger->info("All servers running the same configuration version. (".join(',', keys(%$servers_map)).") have been checked.");
    # If we're here, we should return as the gotos below should be called directly
    return;

    SYNC_MOST_RECENT:

    my $latest = [sort(keys(%$versions_map))]->[-1];

    if($latest == $version) {
        get_logger->info("This server is part of the nodes that are at the latest version. Synching from this node as master.");
        sync_config_as_master();
    }
    else {
        # pick the first server of the ones that are at that version and remotely call the sync on it
        my $server = $versions_map->{$latest}->[0];
        get_logger->info("Using $server from the servers holding running the latest version to sync as the master.");
        call_server($server, 'sync_config_as_master');
    }

    return;

    SYNC_QUORUM:

    if($quorum_version == $version) {
        get_logger->info("This server is part of the servers that have the quorum. Synching from this node as master.");
        sync_config_as_master();
    }
    else {
        my $server = $versions_map->{$quorum_version}->[0];
        get_logger->info("Using $server from the servers holding quorum to sync as the master.");
        call_server($server, 'sync_config_as_master');
    }

    return;

}

=head2 stores_to_sync

Returns the list of ConfigStore to synchronize between cluster members

=cut

our %ignored_stores = (
    'pf::ConfigStore::Wrix'                 => 1,
    'pf::ConfigStore::Group'                => 1,
    'pf::ConfigStore::Interface'            => 1,
    'pf::ConfigStore::Hierarchy'            => 1,
    'pf::ConfigStore::Role::ValidGenericID' => 1,
    'pf::ConfigStore::Role::ReverseLookup'  => 1,
    'pf::ConfigStore::Role::TenantID'       => 1,
);

sub stores_to_sync {
    my @tmp_stores = __PACKAGE__->_all_stores();
    my @stores = grep {!exists $ignored_stores{$_} || !$ignored_stores{$_}} @tmp_stores;
    return \@stores;
}

=head2 sync_config_as_master

Synchronize the configuration to other cluster members using this server as the master

=cut

sub sync_config_as_master {
    pf::cluster::sync_storages(pf::cluster::stores_to_sync());
    pf::cluster::sync_files(\@FILES_TO_SYNC);
}

=head2 is_in_maintenance

Whether or not this member of the cluster is in maintenance

=cut

sub is_in_maintenance {
    return (-f $maintenance_file);
}

=head2 activate_maintenance

Activate the maintenance mode for this node

=cut

sub activate_maintenance {
    touch_file($maintenance_file);
}

=head2 deactivate_maintenance

Dectivate the maintenance mode for this node

=cut

sub deactivate_maintenance {
    unlink($maintenance_file);
}

=head2 encryption_password

Takes the active_active.password and ensures its a 56 bytes password
Will pad the password with zeros if its less than that
Will strip the password to 56 bytes if its more than that

=cut

sub encryption_password {
    require pf::config;
    my $password = $pf::config::Config{active_active}{password};
    
    my $desired_length = 56;

    # Ensure it isn't more than 56 bytes
    $password = substr($password, 0, $desired_length);

    my $missing = $desired_length - length($password) - 1;
    for my $i (0..$missing) {
        $password .= "0";
    }

    return $password;
}

=head2 cipher

Get the cipher to encrypt/decrypt cluster communications

=cut

sub cipher {
    return Crypt::CBC->new(
        -key => encryption_password(),
        -cipher => 'Blowfish',
    );
}

=head2 encrypt_message

Encrypt a message using the cluster shared key

=cut

sub encrypt_message {
    my ($text) = @_;
    cipher()->encrypt_hex($text);
}

=head2 decrypt_message

Decrypt a message using the cluster shared key

=cut

sub decrypt_message {
    my ($text) = @_;
    cipher()->decrypt_hex($text);
}

=head2 find_server_by_hostname

Finds a server configuration using the hostname

=cut

sub find_server_by_hostname {
    my ($hostname) = @_;
    return firstval { $_->{host} eq $hostname } pf::cluster::config_enabled_servers;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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
