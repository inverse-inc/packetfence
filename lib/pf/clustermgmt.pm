package pf::clustermgmt;

use strict;
use pf::config;
use pf::config::cached;
use pf::log(service => 'pfclustermgmt');
use pf::util;
use Data::Dumper;
use pf::ConfigStore::Interface;
use NetAddr::IP;
use List::MoreUtils qw(uniq);

use base qw(JSON::RPC::Procedure);  # for :Public and :Private attributes

sub sum : Public(a:num, b:num) {
    my ($s, $obj) = @_;
    return $obj->{a} + $obj->{b};
}

sub active_active : Public(ip:str, dhcpd:bool, activeip:str, mysql:str) {
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

            $logger->warn($interface.":".$obj->{mysql}.":".$obj->{mysql});
            $cs->update($interface, { active_active_mysql_master => $obj->{mysql}}) if (defined($obj->{mysql}) && $obj->{mysql});
            $cs->update($interface, { active_active_dhcpd_master => '0'}) if $obj->{dhcpd};
            $cs->update($interface, { active_active_ip => $obj->{activeip}}) if $obj->{activeip};

            my @members = split(',',$cfg->{'active_active_members'});
            if (!( my @found = grep { $_ eq $obj->{ip} } @members ) || !( my @found = grep { $_ eq $cfg->{'ip'} } @members )) {
                push(@members, $obj->{ip});
                push(@members, $cfg->{'ip'});
                @members = uniq(@members);
                $logger->warn(Dumper @members);
                $cs->update($interface, { active_active_members => join(',',@members)});
            }
            $cs->commit();
            my $hash_ref = { active_active_members => $cfg->{'active_active_members'},
                             dhcpd_master => $cfg->{'active_active_dhcpd_master'},
                           };
            $hash_ref->{'mysql_master'} = $cfg->{'active_active_mysql_master'} || $obj->{mysql} if (defined($obj->{mysql}) && $obj->{mysql});
            return $hash_ref;
        }
    }
    return;
}

1;
