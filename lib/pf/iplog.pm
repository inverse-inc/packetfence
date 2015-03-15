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

use Date::Parse;
use Log::Log4perl;
use Log::Log4perl::Level;
use IO::Interface::Simple;
use Time::Local;

use constant IPLOG => 'iplog';
use constant IPLOG_CACHE_EXPIRE => 60;

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
        iplog_update          iplog_close_mac

        mac2ip
        mac2allips
        ip2mac
    );
}

use pf::config;
use pf::db;
use pf::node qw(node_add_simple node_exist);
use pf::util;
use pf::CHI;
use pf::OMAPI;
use pf::log;

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
             FROM iplog WHERE mac=? ORDER BY start_time DESC LIMIT 25 ]);

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
        qq [ delete from iplog where end_time < DATE_SUB(?, INTERVAL ? SECOND) and end_time != 0 LIMIT ?]);

    $iplog_statements->{'iplog_close_mac_sql'} = get_db_handle()->prepare(
        qq [ update iplog set end_time=now() where mac=? and (end_time=0 or end_time > now()) ]);

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
    $mac = clean_mac($mac);

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
    my ($expire_seconds, $batch, $time_limit) = @_;
    my $logger = Log::Log4perl::get_logger('pf::iplog');
    $logger->debug("calling iplog_cleanup with time=$expire_seconds batch=$batch timelimit=$time_limit");
    my $now = db_now();
    my $start_time = time;
    my $end_time;
    my $rows_deleted = 0;
    while (1) {
        my $query = db_query_execute(IPLOG, $iplog_statements, 'iplog_cleanup_sql', $now, $expire_seconds, $batch) || return (0);
        my $rows = $query->rows;
        $query->finish;
        $end_time = time;
        $rows_deleted+=$rows if $rows > 0;
        $logger->trace( sub { "deleted $rows_deleted entries from iplog during iplog cleanup ($start_time $end_time) " });
        last if $rows == 0 || (( $end_time - $start_time) > $time_limit );
    }
    $logger->info( "deleted $rows_deleted entries from iplog during iplog cleanup ($start_time $end_time) ");
    return (0);
}

sub iplog_expire {
    my ($time) = @_;
    return db_data(IPLOG, $iplog_statements, 'iplog_expire_sql', $time);
}

=head2 ip2mac

Lookup for the MAC address of a given IP address

Returns '0' if no match

=cut

sub ip2mac {
    my ( $ip ) = @_;
    my $logger = pf::log::get_logger();
    unless (valid_ip($ip)) {
        $logger->warn("invalid ip (" . ($ip // "undef") . ") ip2mac");
        return (0);
    }

    my $mac;

    # TODO: Special case that need to be documented
    if (ref($management_network) && $management_network->{'Tip'} eq $ip) {
        return ( clean_mac("00:11:22:33:44:55") );
    }

    # We first query OMAPI since it is the fastest way and more reliable source of info in most cases
    if ( isenabled($Config{omapi}{ip2mac_lookup}) ) {
        $logger->debug("Trying to match MAC address to IP '$ip' using OMAPI");
        $mac = ip2mac_omapi($ip);
        $logger->info("Matched IP '$ip' to MAC address '$mac' using OMAPI") if $mac;
    }

    # If we don't have a result from OMAPI, we use the SQL 'iplog' table
    unless ($mac) {
        $logger->debug("Trying to match MAC address to IP '$ip' using SQL 'iplog' table");
        $mac = ip2mac_sql($ip);
        $logger->info("Matched IP '$ip' to MAC address '$mac' using SQL 'iplog' table") if $mac;
    }

    if ( !$mac ) {
        $logger->warn("Unable to match MAC address to IP '$ip'");
        return (0);
    }

    return clean_mac($mac);
}

=head2 ip2mac_omapi

Look for the MAC address of a given IP address in the DHCP leases using OMAPI

=cut

sub ip2mac_omapi {
    my ($ip) = @_;
    my $data = _lookup_cached_omapi('ip-address' => $ip);
    return $data->{'obj'}{'hardware-address'} if defined $data;
}

=head2 ip2mac_sql

Look for the MAC address of a given IP address using the SQL 'iplog' table

=cut

sub ip2mac_sql {
    my ( $ip ) = @_;
    my $iplog = iplog_view_open_ip($ip);
    return $iplog->{'mac'};
}

=head2 iplogCache

Get the iplog cache

=cut

sub iplogCache { pf::CHI->new(namespace => 'iplog') }

=head2 mac2ip_omapi

Look for the ip in the dhcpd lease entry using omapi

=cut

sub mac2ip_omapi {
    my ($mac) = @_;
    my $data = _lookup_cached_omapi('hardware-address' => $mac);
    return $data->{'obj'}{'ip-address'} if defined $data;
}

=head2 _get_omapi_client

Get the omapi client
return undef if omapi is disabled

=cut

sub _get_omapi_client {
    my ($self) = @_;
    return unless isenabled($Config{omapi}{ip2mac_lookup});

    return pf::OMAPI->new( $Config{omapi} );
}

sub mac2ip {
    my ( $mac, $cache ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::iplog');
    my $ip;
    return () if ( !valid_mac($mac) );

    if ($cache) {
        $ip = $cache->{clean_mac($mac)};
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


=head2 _lookup_cached_omapi

Will retrieve the lease from the cache or from the dhcpd server using omapi

=cut

sub _lookup_cached_omapi {
    my ($type, $id) = @_;
    my $cache = iplogCache();
    return $cache->compute(
        $id,
        {expire_if => \&_expire_lease, expires_in => IPLOG_CACHE_EXPIRE},
        sub {
            my $data = _get_lease_from_omapi($type, $id);
            return unless $data && $data->{op} == 3;
            #Do not return if the lease is expired
            return if $data->{obj}->{ends} < timegm( localtime()  );
            return $data;
        }
    );
}

=head2 _get_lease_from_omapi

Get the lease information using omapi

=cut

sub _get_lease_from_omapi {
    my ($type,$id) = @_;
    my $omapi = _get_omapi_client();
    return unless $omapi;
    my $data;
    eval {
        $data = $omapi->lookup({type => 'lease'}, { $type => $id});
    };
    if($@) {
        get_logger->error("$@");
    }
    return $data;
}

=head2 _expire_lease

Check if the lease has expired

=cut

sub _expire_lease {
    my ($cache_object) = @_;
    my $lease = $cache_object->value;
    return 1 unless defined $lease && defined $lease->{obj}->{ends};
    return $lease->{obj}->{ends} < timegm( localtime()  );
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

sub iplog_close_mac {
    my ($mac) = @_;
    db_query_execute(IPLOG, $iplog_statements, 'iplog_close_mac_sql', $mac);
    return (0);
}

sub iplog_update {
    my ( $srcmac, $srcip, $lease_length ) = @_;
    my $logger = Log::Log4perl->get_logger('pf::WebAPI');

    # return if MAC or IP is not valid
    if ( !valid_mac($srcmac) || !valid_ip($srcip) ) {
        $logger->error("invalid MAC or IP: $srcmac $srcip");
        return;
    }

    $logger->debug(
        "closing iplog for mac ($srcmac) and ip $srcip - closing iplog entries"
    );

    iplog_close_mac($srcmac);
    iplog_close_now($srcip);

    iplog_open( $srcmac, $srcip, $lease_length );
    return (1);
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

Copyright (C) 2005 Kevin Amorin

Copyright (C) 2005 David LaPorte

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
