package pf::iplog;

=head1 NAME

pf::iplog - module to manage the DHCP information and history. 

=cut

=head1 DESCRIPTION

pf::iplog contains the functions necessary to read and manage the DHCP
information gathered by PacketFence on the network. 

=head1 CONFIGURATION AND ENVIRONMENT

Read the F<pf.conf> configuration file.

=cut

use strict;
use warnings;
use Net::MAC;
use Net::Netmask;
use Net::Ping;
use Date::Parse;
use Log::Log4perl;
use Log::Log4perl::Level;

use constant IPLOG => 'iplog';

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    @EXPORT = qw(
        iplog_db_prepare
        $iplog_db_prepared

        iplog_expire          iplog_shutdown
        iplog_history_ip      iplog_history_mac 
        iplog_view_open       iplog_view_open_ip
        iplog_view_open_mac   iplog_view_all 
        iplog_open            iplog_close 
        iplog_close_now       iplog_cleanup 

        mac2ip 
        mac2allips
        ip2mac
    );
}

use pf::config;
use pf::db;
use pf::node qw(node_add_simple node_exist);
use pf::util;

# The next two variables and the _prepare sub are required for database handling magic (see pf::db)
our $iplog_db_prepared = 0;
# in this hash reference we hold the database statements. We pass it to the query handler and he will repopulate
# the hash if required
our $iplog_statements = {};

sub iplog_db_prepare {
    my $logger = Log::Log4perl::get_logger('pf::iplog');
    $logger->debug("Preparing pf::iplog database queries");

    $iplog_statements->{'iplog_shutdown_sql'} = get_db_handle()->prepare(
        qq [ update iplog set end_time=now() where end_time=0 ]);

    $iplog_statements->{'iplog_view_open_sql'} = get_db_handle()->prepare(
        qq [ select mac,ip,start_time,end_time from iplog where end_time=0 or end_time > now() ]);

    $iplog_statements->{'iplog_view_open_ip_sql'} = get_db_handle()->prepare(
        qq [ select mac,ip,start_time,end_time from iplog where ip=? and (end_time=0 or end_time > now()) limit 1]);

    $iplog_statements->{'iplog_view_open_mac_sql'} = get_db_handle()->prepare(
        qq [ select mac,ip,start_time,end_time from iplog where mac=? and (end_time=0 or end_time > now()) order by start_time desc]);

    $iplog_statements->{'iplog_view_open_mac_sql'} = get_db_handle()->prepare(
        qq [select mac,ip,start_time,end_time from iplog where mac=? and (end_time=0 or end_time > now()) order by start_time desc]);

    $iplog_statements->{'iplog_view_all_sql'} = get_db_handle()->prepare(qq [ select mac,ip,start_time,end_time from iplog ]);

    $iplog_statements->{'iplog_history_ip_date_sql'} = get_db_handle()->prepare(
        qq [ select mac,ip,start_time,end_time from iplog where ip=? and start_time < from_unixtime(?) and (end_time > from_unixtime(?) or end_time=0) order by start_time desc ]);

    $iplog_statements->{'iplog_history_mac_date_sql'} = get_db_handle()->prepare(
        qq [ SELECT mac,ip,start_time,end_time,
               UNIX_TIMESTAMP(start_time) AS start_timestamp,
               UNIX_TIMESTAMP(end_time) AS end_timestamp
             FROM iplog
             WHERE mac=? AND start_time < from_unixtime(?) and (end_time > from_unixtime(?) or end_time=0)
             ORDER BY start_time ASC ]);

    $iplog_statements->{'iplog_history_ip_sql'} = get_db_handle()->prepare(
        qq [ select mac,ip,start_time,end_time from iplog where ip=? order by start_time desc ]);

    $iplog_statements->{'iplog_history_mac_sql'} = get_db_handle()->prepare(
        qq [ SELECT mac,ip,start_time,end_time,
               UNIX_TIMESTAMP(start_time) AS start_timestamp,
               UNIX_TIMESTAMP(end_time) AS end_timestamp
             FROM iplog WHERE mac=? ORDER BY start_time ASC ]);

    $iplog_statements->{'iplog_open_sql'} = get_db_handle()->prepare(
        qq [ insert into iplog(mac,ip,start_time) values(?,?,now()) ]);

    $iplog_statements->{'iplog_open_with_lease_length_sql'} = get_db_handle()->prepare(
        qq [ insert into iplog(mac,ip,start_time,end_time) values(?,?,now(),adddate(now(), interval ? second)) ]);

    $iplog_statements->{'iplog_open_update_end_time_sql'} = get_db_handle()->prepare(
        qq [ update iplog set end_time = adddate(now(), interval ? second) where mac=? and ip=? and (end_time = 0 or end_time > now()) ]);

    $iplog_statements->{'iplog_close_sql'} = get_db_handle()->prepare(
        qq [ update iplog set end_time=now() where ip=? and end_time=0 ]);

    $iplog_statements->{'iplog_close_now_sql'} = get_db_handle()->prepare(
        qq [ update iplog set end_time=now() where ip=? and (end_time=0 or end_time > now())]);

    $iplog_statements->{'iplog_cleanup_sql'} = get_db_handle()->prepare(
        qq [ delete from iplog where unix_timestamp(end_time) < (unix_timestamp(now()) - ?) and end_time!=0 ]);

    $iplog_db_prepared = 1;
}

sub iplog_shutdown {
    my $logger = Log::Log4perl::get_logger('pf::iplog');
    $logger->info("closing open iplogs");

    db_query_execute(IPLOG, $iplog_statements, 'iplog_shutdown_sql') || return (0);
    return (1);
}

sub iplog_history_ip {
    my ( $ip, %params ) = @_;

    if ( defined( $params{'start_time'} ) && defined( $params{'end_time'} ) )
    {
        return db_data(IPLOG, $iplog_statements, 'iplog_history_ip_date_sql', 
            $ip, $params{'end_time'}, $params{'start_time'});

    } elsif (defined($params{'date'})) {
        return db_data(IPLOG, $iplog_statements, 'iplog_history_ip_date_sql', $ip, $params{'date'}, $params{'date'});

    } else {
        return db_data(IPLOG, $iplog_statements, 'iplog_history_ip_sql', $ip);
    }
}

sub iplog_history_mac {
    my ( $mac, %params ) = @_;

    my $tmpMAC = Net::MAC->new( 'mac' => $mac );
    $mac = $tmpMAC->as_IEEE();

    if ( defined( $params{'start_time'} ) && defined( $params{'end_time'} ) )
    {
        return db_data(IPLOG, $iplog_statements, 'iplog_history_mac_date_sql', $mac, 
            $params{'end_time'}, $params{'start_time'});

    } elsif ( defined( $params{'date'} ) ) {
        return db_data(IPLOG, $iplog_statements, 'iplog_history_mac_date_sql', $mac, 
            $params{'date'}, $params{'date'});

    } else {
        return db_data(IPLOG, $iplog_statements, 'iplog_history_mac_sql', $mac);
    }
}

sub iplog_view_open {
    return db_data(IPLOG, $iplog_statements, 'iplog_view_open_sql');
}

sub iplog_view_open_ip {
    my ($ip) = @_;

    my $query = db_query_execute(IPLOG, $iplog_statements, 'iplog_view_open_ip_sql', $ip) || return (0);
    my $ref = $query->fetchrow_hashref();

    # just get one row and finish
    $query->finish();
    return ($ref);
}

sub iplog_view_open_mac {
    my ($mac) = @_;

    my $query = db_query_execute(IPLOG, $iplog_statements, 'iplog_view_open_mac_sql', $mac) || return (0);
    my $ref = $query->fetchrow_hashref();

    # just get one row and finish
    $query->finish();
    return ($ref);
}

sub iplog_view_all_open_mac {
    my ($mac) = @_;
    return db_data(IPLOG, $iplog_statements, 'iplog_view_open_mac_sql', $mac);
}

sub iplog_view_all {
    return db_data(IPLOG, $iplog_statements, 'iplog_view_all_sql');
}

sub iplog_open {
    my ( $mac, $ip, $lease_length ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::iplog');

    if ( !node_exist($mac) ) {
        node_add_simple($mac);
    }

    if ($lease_length) {
        if ( !defined( iplog_view_open_mac($mac) ) ) {
            $logger->debug("creating new entry for ($mac - $ip)");
            db_query_execute(IPLOG, $iplog_statements, 'iplog_open_with_lease_length_sql', $mac, $ip, $lease_length);

        } else {
            $logger->debug("updating end_time for ($mac - $ip)");
            db_query_execute(IPLOG, $iplog_statements, 'iplog_open_update_end_time_sql', $lease_length, $mac, $ip);
        }

    } elsif ( !defined( iplog_view_open_mac($mac) ) ) {
        $logger->debug("creating new entry for ($mac - $ip) with empty end_time");
        db_query_execute(IPLOG, $iplog_statements, 'iplog_open_sql', $mac, $ip) || return (0);
    }
    return (0);
}

sub iplog_close {
    my ($ip) = @_;

    db_query_execute(IPLOG, $iplog_statements, 'iplog_close_sql', $ip);
    return (0);
}

sub iplog_close_now {
    my ($ip) = @_;

    db_query_execute(IPLOG, $iplog_statements, 'iplog_close_now_sql', $ip);
    return (0);
}

sub iplog_cleanup {
    my ($time) = @_;
    my $logger = Log::Log4perl::get_logger('pf::iplog');

    $logger->debug("calling iplog_cleanup with time=$time");
    my $query = db_query_execute(IPLOG, $iplog_statements, 'iplog_cleanup_sql', $time) || return (0);
    my $rows = $query->rows;
    $logger->log((($rows > 0) ? $INFO : $DEBUG), "deleted $rows entries from iplog during iplog cleanup");
    return (0);
}

sub iplog_expire {
    my ($time) = @_;
    return db_data(IPLOG, $iplog_statements, 'iplog_expire_sql', $time);
}

sub ip2mac {
    my ( $ip, $date ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::iplog');
    my $mac;
    return (0) if ( !valid_ip($ip) );

    if ($date) {
        return if ( !valid_date($date) );
        my @iplog = iplog_history_ip( $ip, ( 'date' => str2time($date) ) );
        $mac = $iplog[0]->{'mac'};
    } else {
        my $iplog = iplog_view_open_ip($ip);
        $mac = $iplog->{'mac'};
        if ( !$mac ) {
            $logger->debug("could not resolve $ip to mac in iplog table");
            $mac = ip2macinarp($ip);
            if ( !$mac ) {
                $logger->debug("trying to resolve $ip to mac using ping");
                my @lines  = pf_run("/sbin/ip address show");
                my $lineNb = 0;
                my $src_ip = undef;
                while (( $lineNb < scalar(@lines) )
                    && ( !defined($src_ip) ) )
                {
                    my $line = $lines[$lineNb];
                    if ( $line
                        =~ /inet ([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})\/([0-9]+)/
                        )
                    {
                        my $tmp_src_ip   = $1;
                        my $tmp_src_bits = $2;
                        my $block
                            = new Net::Netmask("$tmp_src_ip/$tmp_src_bits");
                        if ( $block->match($ip) ) {
                            $src_ip = $tmp_src_ip;
                            $logger->debug(
                                "found $ip in Network $tmp_src_ip/$tmp_src_bits"
                            );
                        }
                    }
                    $lineNb++;
                }
                if ( defined($src_ip) ) {
                    my $ping = Net::Ping->new();
                    $logger->debug("binding ping src IP to $src_ip for ping");
                    $ping->bind($src_ip);
                    $ip = clean_ip($ip);
                    $ping->ping( $ip, 2 );
                    $ping->close();
                    $mac = ip2macinarp($ip);
                } else {
                    $logger->debug("unable to find an IP address on PF host in the same broadcast domain than $ip "
                        . "-> won't send ping");
                }
            }
            if ($mac) {
                iplog_open( $mac, $ip );
            }
        }
    }
    if ( !$mac ) {
        $logger->warn("could not resolve $ip to mac");
        return (0);
    } else {
        return ( clean_mac($mac) );
    }
}

sub ip2macinarp {
    my ($ip) = @_;
    my $logger = Log::Log4perl::get_logger('pf::iplog');
    return (0) if ( !valid_ip($ip) );
    my $mac;
    $ip = clean_ip($ip);
    my @arpList = pf_run("$Config{services}{arp_binary} -n -a $ip");
    my $lineNb  = 0;
    while ( ( $lineNb < scalar(@arpList) ) && ( !$mac ) ) {
        if ( $arpList[$lineNb]
            =~ /\($ip\) at ([0-9a-z]{2}:[0-9a-z]{2}:[0-9a-z]{2}:[0-9a-z]{2}:[0-9a-z]{2}:[0-9a-z]{2})/i
            )
        {
            $mac = $1;
            $mac = clean_mac($mac);
            $logger->info("resolved $ip to mac ($mac) in ARP table");
        }
        $lineNb++;
    }
    if ( !$mac ) {
        $logger->info("could not resolve $ip to mac in ARP table");
        return (0);
    }
    return $mac;
}

sub mac2ip {
    my ( $mac, $date ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::iplog');
    my $ip;
    return (0) if ( !valid_mac($mac) );

    if ($date) {
        return if ( !valid_date($date) );
        my @iplog = iplog_history_mac( $mac, ( 'date' => str2time($date) ) );
        $ip = $iplog[0]->{'ip'};
    } else {
        my $iplog = iplog_view_open_mac($mac);
        $ip = $iplog->{'ip'} || 0;
    }
    if ( !$ip ) {
        $logger->warn("unable to resolve $mac to ip");
        return ();
    } else {
        return ($ip);
    }
}

sub mac2allips {
    my ($mac) = @_;
    my $logger = Log::Log4perl::get_logger('pf::iplog');
    return (0) if ( !valid_mac($mac) );
    my @all_ips = ();
    foreach my $iplog_entry ( iplog_view_all_open_mac($mac) ) {
        push @all_ips, $iplog_entry->{'ip'};
    }
    if ( scalar(@all_ips) == 0 ) {
        $logger->warn("unable to resolve $mac to ip");
    }
    return @all_ips;
}


=head1 AUTHOR

David LaPorte <david@davidlaporte.org>

Kevin Amorin <kev@amorin.org>

Dominik Gehl <dgehl@inverse.ca>

Olivier Bilodeau <obilodeau@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005 David LaPorte

Copyright (C) 2005 Kevin Amorin

Copyright (C) 2008,2010 Inverse inc.

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
