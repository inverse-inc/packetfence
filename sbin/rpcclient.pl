#!/usr/bin/perl

BEGIN {
    # log4perl init
    use constant INSTALL_DIR => '/usr/local/pf';
    use lib INSTALL_DIR . "/lib";
    use pf::log(service => 'pfdhcplistener');
}

use pf::clustermgmt;
use pf::config;
use pf::config::cached;
use pf::util;
use JSON::RPC::Client;
use List::MoreUtils qw(uniq);
use pf::ConfigStore::Interface;
use Data::Dumper;

pf::config::cached::ReloadConfigs();

my $client = new JSON::RPC::Client;

my @members;
my @all_members;

my $int = $management_network->{'Tint'};
if ( ($Config{"interface $int"}{'type'} eq 'management') && (isenabled($Config{"interface $int"}{'active_active_enabled'}) ) ) {
    @members = split(',',$Config{"interface $int"}{'active_active_members'});
}

my @ints = uniq(@listen_ints,@dhcplistener_ints);

foreach my $interface ( @ints ) {
    my $dhcpd_master = 0;
    my $mysql_master = 0;
    my $cfg = $Config{"interface $interface"};
    if (isenabled($cfg->{'active_active_enabled'})) {
        print $cfg->{'ip'}."\n";
        print $cfg->{'active_active_dhcpd_master'}."\n";
        my @all_members;
        for my $member (@members) {
            my $uri = "http://$member:32274/cluster";
            my $obj = {
                method => 'active_active',
                params => { ip => $cfg->{'ip'},
                            dhcpd => $cfg->{'active_active_dhcpd_master'},
                            activeip => $cfg->{'active_active_ip'},
                            mysql => $cfg->{'active_active_mysql_master'},
                },
            };

            my $res = $client->call( $uri, $obj );
            if ($res){
                if ($res->is_error) {
                    #print "Error : ", $res->error_message;
                    push(@all_members ,$member);
                } else {
                    my $result =  $res->result;
                    print Dumper $result;
                    $dhcpd_master = $result->{'dhcpd_master'} if ($result->{'dhcpd_master'} && defined($cfg->{'active_active_dhcpd_master'}));
                    $mysql_master = $result->{'mysql_master'} if ($result->{'mysql_master'} && defined($cfg->{'active_active_mysql_master'}));
                    push(@all_members , split(',',$result->{'active_active_members'}));
                    $logger->error("There is more than one dhcpd master, fix that") if ($result->{'dhcpd_master'} && $Config{"interface $int"}{'active_active_dhcpd_master'});
                }
            } else {
                @all_members = grep { $_ ne $member } @all_members;
               # print $client->status_line;
            }
        }
        push (@all_members,$cfg->{'ip'});
        my @uniq_members = uniq(@all_members);

        my $cs = pf::ConfigStore::Interface->new();
        $cs->update($interface, { active_active_members => join(',',@uniq_members)});
        $cs->update($interface, { active_active_dhcpd_master => 0}) if ($dhcpd_master && defined($cfg->{'active_active_dhcpd_master'} ) );
        $cs->update($interface, { active_active_mysql_master => $mysql_master}) if ($mysql_master && defined($cfg->{'active_active_mysql_master'} ) );
        $cs->update($interface, { active_active_dhcpd_master => 1}) if (!$dhcpd_master && defined($cfg->{'active_active_dhcpd_master'} ) );
        $cs->update($interface, { active_active_mysql_master => $Config{"interface $int"}{ip}}) if (!$mysql_master && defined($cfg->{'active_active_mysql_master'} ) );
        $cs->commit();
        undef(@all_members);
    }
}
