package pf::clustermgmt;

=head1 NAME

pf::clustermgmt

=cut

=head1 DESCRIPTION

Use as a rpc server and as a rpc client.
It will sync between all the cluster members somes configurations parameters.

=cut

use strict;
use pf::config;
use pf::config::cached;
use pf::log;
use pf::util;
use pf::ConfigStore::Interface;
use pf::ConfigStore::Pf;
use NetAddr::IP;
use List::MoreUtils qw(uniq);
use JSON::RPC::Client;

use base qw(JSON::RPC::Procedure);  # for :Public and :Private attributes

=head2 active_active

RPC server function that return his local cluster configuration and adapt his own.

=cut

sub active_active : Public(ip:str, dhcpd:bool, activeip:str, mysql:str, priority:int) {
    my($s, $obj) = @_;
    my $logger = get_logger;

    pf::config::cached::ReloadConfigs();

    my $ip = new NetAddr::IP::Lite clean_ip($obj->{ip});
    my @ints = uniq(@listen_ints,@dhcplistener_ints);
    my $cs = pf::ConfigStore::Interface->new();

    foreach my $interface ( @ints ) {
        my $cfg = $Config{"interface $interface"};
        next unless $cfg;
        next if (!isenabled($cfg->{'active_active_enabled'}));
        my $current_network = NetAddr::IP->new( $cfg->{'ip'}, $cfg->{'mask'} );
        if ( $current_network->contains($ip) ) {
            $cs->update($interface, { active_active_mysql_master => $obj->{mysql}}) if (defined($obj->{mysql}) && $obj->{mysql});
            $cs->update($interface, { active_active_dhcpd_master => '0'}) if $obj->{dhcpd};
            $cs->update($interface, { active_active_ip => $obj->{activeip}}) if $obj->{activeip};

            my @members = split(',',$cfg->{'active_active_members'});
            if (!( grep { $_ eq $obj->{ip} } @members ) || !( grep { $_ eq $cfg->{'ip'} } @members )) {
                push(@members, $obj->{ip});
                push(@members, $cfg->{'ip'});
                @members = uniq(@members);
                $cs->update($interface, { active_active_members => join(',',@members)});
            }
            my $priority;
            if (!defined($cfg->{'active_active_priority'})) {
                $priority = 120;
            } else {
                $priority = $cfg->{'active_active_priority'};
            }
            if ($cfg->{'type'} eq 'management') {
                my $pfcs = pf::ConfigStore::Pf->new();
                push(@members, $obj->{ip});
                push(@members, $cfg->{'ip'});
                my $local_members = $pfcs->read('active_active');
                push(@members,split(',',$local_members->{'members'}));
                $pfcs->update('active_active', { members =>  join(',',uniq(@members))});
                $pfcs->commit();
            }
            $cs->update($interface, { active_active_priority => $priority });
            $cs->commit();
            my $hash_ref = { active_active_members => $cfg->{'active_active_members'},
                             dhcpd_master => $cfg->{'active_active_dhcpd_master'},
                             member_ip => $cfg->{'ip'},
                             priority => $priority,
                           };
            $hash_ref->{'mysql_master'} = $cfg->{'active_active_mysql_master'} || $obj->{mysql} if (defined($obj->{mysql}) && $obj->{mysql});
            return $hash_ref;
        }
    }
    return;
}

=head2 sync_cluster

RPC Client that send his configuration and adapt his own

=cut

sub sync_cluster {
    my $logger = get_logger;
    pf::config::cached::ReloadConfigs();

    my $client = new JSON::RPC::Client;

    my @all_members;
    my $priority;
    my @priority;

    my $int = $management_network->{'Tint'};
    my @members = split(',',$Config{"active_active"}{'members'});

    my @ints = uniq(@listen_ints,@dhcplistener_ints);

    if ( (defined $Config{"interface $int"}{'active_active_mysql_master'}) && ($Config{"interface $int"}{'ip'} eq $Config{"interface $int"}{'active_active_mysql_master'}) ) {
        $priority = '150';
    } else {
        $priority = $Config{"interface $int"}{'active_active_priority'} || 0;
    }

    my $cs = pf::ConfigStore::Interface->new();

    foreach my $interface ( @ints ) {
        my $dhcpd_master = 0;
        my $mysql_master = 0;
        my $cfg = $Config{"interface $interface"};
        if (isenabled($cfg->{'active_active_enabled'})) {
            my @all_members;
            for my $member (@members) {
                my $uri = "http://$member:".$Config{'active_active'}{'syncport'}."/cluster";
                my $obj = {
                    method => 'active_active',
                    params => { ip => $cfg->{'ip'},
                                dhcpd => $cfg->{'active_active_dhcpd_master'},
                                activeip => $cfg->{'active_active_ip'},
                                mysql => $cfg->{'active_active_mysql_master'} || 0,
                                priority => $priority,
                    },
                };

                my $res = $client->call( $uri, $obj );
                if ($res){
                    if ($res->is_error) {
                        $logger->error($res->error_message);
                    } else {
                        my $result =  $res->result;
                        $dhcpd_master = $result->{'dhcpd_master'} if ($result->{'dhcpd_master'} && defined($cfg->{'active_active_dhcpd_master'}));
                        $mysql_master = $result->{'mysql_master'} if ($result->{'mysql_master'} && defined($cfg->{'active_active_mysql_master'}));
                        push(@all_members , split(',',$result->{'active_active_members'}));
                        push(@all_members , $result->{'member_ip'});
                        $logger->error("There is more than one dhcpd master, fix that") if ($result->{'dhcpd_master'} && $Config{"interface $int"}{'active_active_dhcpd_master'});
                        push(@priority, $result->{'priority'});
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
        if (grep { $_ eq $priority } @priority) {
            my $i = 100;
            while (grep { $_ eq $priority } @priority) {
                $priority = $i;
                $i++;
            }
            $cs->update($int, { active_active_priority => $priority});
        } else {
            $cs->update($int, { active_active_priority => $priority});
        }
        $cs->commit();
        #Reload configuration
        pf::config::cached::ReloadConfigs();
    }
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
