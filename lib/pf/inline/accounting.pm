package pf::inline::accounting;

# TODO
#  
#  provide function to get accounting data for a single ip.
#    Taking starttime, endtime as optional parameters

=head1 NAME

pf::inline::accounting - module to manage inline accounting generated
by ulogd

=cut

=head1 DESCRIPTION

pf::inline::accounting contains functions needed manage accounting data
produced by ulogd.

See the next section for detailed information on how to configure ulogd
and mysql.

The inline_accounting_import_ulogd_data function must be called at
regular intervals to import ulogd data from the mysql memory table
into the innodb backed inline accounting table. This import process is
currently handled by pfmon.

To work properly, the accounting_session_timeout configuration variable
_must_ be set higher tant the interval at which
inline_accounting_import_ulogd_data is called
(the interval at which pfmon runs)

=head1 CONFIGURATION AND ENVIRONMENT

First, conntrack accounting must be enabled in the kernel,
otherwise, ulogd would always report 0 bytes sessions:

 sysctl net.netfilter.nf_conntrack_acct=1
 echo net.netfilter.nf_conntrack_acct=1 >>/etc/sysctl.conf

ulogd is used to collect session 'destroy' events from nf_conntrack.
This is done by using the ulogd_inpflow_NFCT.so module.
These events contains accounting information such as sent/received bytes and packets,
along with source and destination ip.
Once the events reach ulogd, they are sent to a mysql MEMORY table using the ulogd_output_MYSQL.so module.
The actual insert into that table is carried out by a mysql stored procedure.
Some utility functions for ip address conversions must also be created in mysql.

ulogd2 >= 2.0.2 should be used when possible since it provides the ability to define accept filters.

To install ulogd2 along with its mysql module:
 apt-get install ulogd2 ulogd2-mysql>

=head2 CONNTRACK TIMEOUTS

Lowering the conntrack timewait timeout allows ulogd to get connection deletion
events a bit faster than the default.

For example:
 sysctl net.netfilter.nf_conntrack_tcp_timeout_time_wait=30

This should be put into F</etc/sysctl.conf> :
 echo net.netfilter.nf_conntrack_tcp_timeout_time_wait=30 >>/etc/sysctl.conf

=head2 NETLINK STATISTICS / BUFFER TUNING

When updating the real accounting table, C<inline_accounting_import_ulogd_data>
will lock the memory table. During this time, ulog/netlink will buffer its data.
To see if the defined buffer is big enough, look into /proc/net/netlink while
the table is locked. (See C<netlink_socket_buffer_maxsize> in F<ulogd.conf>)

=head2 ULOGD CONFIGURATION

Here's a sample ulogd configuration file:

 [global]                                                                                                                                                                                                                                    
 logfile="/var/log/ulogd/ulogd.log"
 loglevel=1
 plugin="/usr/lib64/ulogd/ulogd_inppkt_ULOG.so"
 plugin="/usr/lib64/ulogd/ulogd_inpflow_NFCT.so"
 plugin="/usr/lib64/ulogd/ulogd_filter_IFINDEX.so"
 plugin="/usr/lib64/ulogd/ulogd_filter_IP2STR.so"
 plugin="/usr/lib64/ulogd/ulogd_filter_IP2BIN.so"
 plugin="/usr/lib64/ulogd/ulogd_filter_PRINTPKT.so"
 plugin="/usr/lib64/ulogd/ulogd_filter_HWHDR.so"
 plugin="/usr/lib64/ulogd/ulogd_filter_PRINTFLOW.so"
 plugin="/usr/lib64/ulogd/ulogd_output_LOGEMU.so"
 plugin="/usr/lib64/ulogd/ulogd_output_SYSLOG.so"
 plugin="/usr/lib64/ulogd/ulogd_output_XML.so"
 plugin="/usr/lib64/ulogd/ulogd_output_GPRINT.so"
 plugin="/usr/lib64/ulogd/ulogd_output_MYSQL.so"
 plugin="/usr/lib64/ulogd/ulogd_raw2packet_BASE.so"
 plugin="/usr/lib64/ulogd/ulogd_inpflow_NFACCT.so"
 
 stack=ct1:NFCT,ip2bin1:IP2BIN,mysql2:MYSQL
 stack=ct1:NFCT,ip2str1:IP2STR,print1:PRINTFLOW,emu1:LOGEMU
 
 [ct1]
 event_mask=0x00000004 # only get destroy events
 # Big buffers are necessary to be able to keep packets around while the memory table is locked by pfmon
 # do NOT use the same buffer_size vs buffer_maxsize.
 # ulogd seems to think this means a zero length buffer...
 netlink_socket_buffer_size=25165820
 netlink_socket_buffer_maxsize=25165824
 
 [mysql2]
 db="pf"
 host="localhost"
 user="pf"
 table="inline_accounting_mem_ulogd_v"
 pass="password"
 procedure="INSERT_BYTES"
 
 [emu1]
 file="/var/log/ulog/syslogemu.log"
 sync=1

 
=head2 MYSQL SETUP

The inline_accounting_mem mysql table will hold the raw data from ulogd.
This _has_to_be_ a MEMORY table since it will get a huge amount of updates (one per tcp connection close)
We use the binary representation of the source ip addr as a key.
This is done for quick lookups, it avoids doing a bin->string conversion + string compare operation on every update. 
We cannot use NOW() as a default value for DATETIME fields...

The table should be defined as follows:

 DROP TABLE `inline_accounting_mem`;
 CREATE TABLE `inline_accounting_mem` (
   `_ct_id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
   `orig_ip_saddr_bin` binary(16) NOT NULL COMMENT 'source IP',
   `reply_ip_saddr_bin` binary(16) DEFAULT NULL COMMENT 'destination ip',
   `outbytes` bigint unsigned NOT NULL DEFAULT '0' COMMENT 'orig_raw_pktlen',
   `inbytes` bigint unsigned NOT NULL DEFAULT '0' COMMENT 'reply_raw_pktlen',
   `src_ip` varchar(16) NOT NULL,
   `firstseen` DATETIME NOT NULL,
   `lastmodified` DATETIME NOT NULL,
   `nupdates` BIGINT UNSIGNED DEFAULT 0,
   PRIMARY KEY (`_ct_id`),
   UNIQUE KEY `orig_ip_saddr_bin` (`orig_ip_saddr_bin`)
 ) ENGINE=MEMORY;

The inline_accounting_mem_ulogd_v view is created so that ulogd is able figure out which fields to pass to the stored proc.
It is not actually used to update data.

 DROP VIEW IF EXISTS inline_accounting_mem_ulogd_v;
 CREATE VIEW inline_accounting_mem_ulogd_v
   AS SELECT _ct_id,
             orig_ip_saddr_bin,
             reply_ip_saddr_bin,
             outbytes AS orig_raw_pktlen,
             inbytes AS reply_raw_pktlen
   FROM inline_accounting_mem LIMIT 1;


We need this to be able to reset the auto_increment counter when emptying the table

 GRANT ALL ON pf.inline_accounting_mem to 'pf'@'localhost';


This is the actual accounting table. This module will import data from the memory table into it.

 CREATE TABLE `inline_accounting` (
   `outbytes` bigint unsigned NOT NULL DEFAULT '0' COMMENT 'orig_raw_pktlen',
   `inbytes` bigint unsigned NOT NULL DEFAULT '0' COMMENT 'reply_raw_pktlen',
   `src_ip` varchar(16) NOT NULL,
   `firstseen` DATETIME NOT NULL,
   `lastmodified` DATETIME NOT NULL,
   `status` int unsigned NOT NULL default 0, -- ACTIVE
   PRIMARY KEY (`src_ip`, `firstseen`),
   INDEX (`src_ip`)
 ) ENGINE=InnoDB;


These utility functions must also be created:

This one is used to convert the binary ip form to ipv4 string.
Binary like this 0x00000000000000000000ffffc0a83804 is converted to 192.168.56.4

 DELIMITER $$
 DROP FUNCTION IF EXISTS `BIN_TO_IPV4`$$
 CREATE FUNCTION `BIN_TO_IPV4`(
         _in binary(16)
                 ) RETURNS varchar(64)
     DETERMINISTIC
     SQL SECURITY INVOKER
     COMMENT 'Convert binary ip to printable string'
 BEGIN
     -- IPv4 address in IPv6 form
     IF HEX(SUBSTRING(_in, 1, 12)) = '00000000000000000000FFFF' THEN
         RETURN CONCAT(
             ASCII(SUBSTRING(_in, 13, 1)), '.',
             ASCII(SUBSTRING(_in, 14, 1)), '.',
             ASCII(SUBSTRING(_in, 15, 1)), '.',
             ASCII(SUBSTRING(_in, 16, 1))
         );
     END IF;
     -- return nothing
     RETURN NULL;
 END$$
 DELIMITER ; 

This stored procedure will be called by ulogd to update the clients' data
If the client isn't in the table already:
  adds it with the current data and does the binip -> str conversion
  add the current timestamp to 'firstseen' and current timestamp to lastmodified
If the client already exists, update the accounting data and lastmodified timestamp

It is possible to filter out some destination hosts by adding 'IF' clauses to the function.
To get the right string representation of the ip, use the following perl script:
  my $ip =  "your.dotted.quad.address";
  my @octets = split(/\./, $ip);
  printf("00000000000000000000FFFF%02X%02X%02X%02X\n", $octets[0],$octets[1],$octets[2],$octets[3]);

The VIP of the packetfence servers should be filtered out with this mechanism to avoid accounting traffic
against the captive portal

 DELIMITER $$
 DROP FUNCTION IF EXISTS `INSERT_BYTES`$$
 CREATE FUNCTION `INSERT_BYTES`(
     `_orig_ip_saddr_bin` binary(16),
     `_reply_ip_saddr_bin` binary(16),
     `_orig_bytes` bigint,
     `_reply_bytes` bigint
 ) RETURNS bigint(20) unsigned
 BEGIN
 # Use this to filter out some destination hosts
 #    DECLARE noaccthost1 binary(16);
 #    set noaccthost1 = 0x00000000000000000000FFFFAC14820B;
 #
 #    IF _reply_ip_saddr_bin = noaccthost1 THEN
 #      RETURN NULL;
 #    END IF;
     
     IF EXISTS (SELECT orig_ip_saddr_bin from inline_accounting_mem where orig_ip_saddr_bin = _orig_ip_saddr_bin) THEN
       UPDATE inline_accounting_mem SET
         outbytes=outbytes+_orig_bytes,
         inbytes=inbytes+_reply_bytes,
         lastmodified=NOW(),
         nupdates=nupdates+1
       WHERE orig_ip_saddr_bin = _orig_ip_saddr_bin;
     ELSE
       INSERT INTO inline_accounting_mem(orig_ip_saddr_bin, outbytes, inbytes, src_ip, firstseen, lastmodified, nupdates)
         VALUES (_orig_ip_saddr_bin, _orig_bytes, _reply_bytes, BIN_TO_IPV4(_orig_ip_saddr_bin), NOW(), NOW(), 1)
       ON DUPLICATE KEY UPDATE
         outbytes=outbytes+_orig_bytes,
         inbytes=inbytes+_reply_bytes,
         lastmodified=NOW(),
         nupdates=nupdates+1;
     END IF;
     RETURN LAST_INSERT_ID();
 END$$
 DELIMITER ;


Once the tables and procedures are created, ulogd should be able to start logging properly.

=cut

use strict;
use warnings;

use Carp;
use Log::Log4perl;
use Readonly;

my $mem_table = 'inline_accounting_mem';
my $accounting_table = 'inline_accounting';

my $ACTIVE = 0;
my $INACTIVE = 1;
my $ANALYZED = 3;

my $BANDWIDTH_VID = 1200003;

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    @EXPORT = qw(
        inline_accounting_db_prepare
        $inline_accounting_db_prepared

        inline_accounting_import_ulogd_data
    );
}

use pf::config;
use pf::config::cached;
use pf::db;

# The next two variables and the _prepare sub are required for database handling magic (see pf::db)
our $accounting_db_prepared = 0;
# in this hash reference we hold the database statements. We pass it to the query handler and he will repopulate
# the hash if required
our $accounting_statements = {};


=head1 SUBROUTINES

=over

=item inline_accounting_db_prepare

Prepares all the SQL statements related to this module

=cut

sub accounting_db_prepare {
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    $logger->debug("Preparing" . __PACKAGE__ . "database queries");

    $accounting_statements->{'accounting_select_all_ip_stats_mem_sql'} =
      get_db_handle()->prepare(qq[
        SELECT src_ip, inbytes, outbytes, firstseen, lastmodified,
          IF(lastmodified < NOW() - ?, $INACTIVE, $ACTIVE) as status
        FROM $mem_table
      ]);

    $accounting_statements->{'accounting_select_single_ip_stats_mem_sql'} =
      get_db_handle()->prepare(qq[
        SELECT src_ip, inbytes, outbytes, firstseen, lastmodified, $INACTIVE as status
        FROM $mem_table
        WHERE src_ip = ?
      ]);

    $accounting_statements->{'accounting_delete_all_mem_sql'} =
      get_db_handle()->prepare(qq[
        DELETE FROM $mem_table
      ]);

    $accounting_statements->{'accounting_drop_single_ip_stats_mem_sql'} = 
      get_db_handle()->prepare(qq[
        DELETE FROM $mem_table WHERE `src_ip` =  ?
      ]);

    $accounting_statements->{'accounting_drop_inactive_sessions_mem_sql'} = 
      get_db_handle()->prepare(qq[
        DELETE FROM $mem_table WHERE `lastmodified` < NOW() - ?
      ]);

    $accounting_statements->{'accounting_reset_autoincrement_mem_sql'} =
      get_db_handle()->prepare(qq[
        ALTER TABLE $mem_table AUTO_INCREMENT = 1
      ]);

    $accounting_statements->{'accounting_add_active_session_sql'} = 
      get_db_handle()->prepare(qq[
        INSERT into $accounting_table(src_ip, firstseen, lastmodified, outbytes, inbytes, status)
          VALUES (?, ?, ?, ?, ?, ?)
          ON DUPLICATE KEY UPDATE
            lastmodified = ?,
            outbytes = ?,
            inbytes = ?,
            status = ?
      ]);

    $accounting_statements->{'accounting_select_bandwidth_stats_sql'} =
      get_db_handle()->prepare(qq[
        SELECT a.src_ip, a.lastmodified, (a.outbytes+a.inbytes) as consumedbytes, (n.bandwidth_balance - totalbytes) as deltabytes
        FROM inline_accounting a, iplog i, node n
        WHERE a.src_ip = i.ip
          AND i.mac = n.mac
          AND n.bandwidth_balance IS NOT NULL
          AND a.status = $INACTIVE
      ]);

    $accounting_statements->{'accounting_update_node_bandwidth_balance_sql'} =
      get_db_handle()->prepare(qq[
        UPDATE node n SET n.bandwidth_balance = (
          SELECT n.bandwidth_balance - SUM(a.outbytes+a.inbytes)
          FROM $accounting_table a, iplog i
          WHERE a.src_ip = i.ip
            AND i.end_time = 0
            AND i.mac = n.mac
            AND a.status = $INACTIVE
        )
        WHERE n.bandwidth_balance > 0
      ]);

    $accounting_statements->{'accounting_update_status_analyzed_sql'} =
      get_db_handle()->prepare(qq[
        UPDATE $accounting_table
          SET status = $ANALYZED
          WHERE status = $INACTIVE
      ]);

    $accounting_statements->{'accounting_select_node_bandwidth_balance_sql'} =
      get_db_handle()->prepare(qq[
        SELECT n.mac
        FROM node n
        LEFT JOIN iplog i ON i.mac = n.mac AND i.end_time = 0
        LEFT JOIN $accounting_table a ON i.ip = a.src_ip AND a.status = $ACTIVE
        WHERE n.bandwidth_balance = 0
           OR ((n.bandwidth_balance - a.outbytes - a.inbytes) <= 0)
      ]);

    $accounting_statements->{'accounting_update_node_bandwidth_balance_sql'} =
      get_db_handle()->prepare(qq[
        UPDATE node n SET n.bandwidth_balance = (
          SELECT n.bandwidth_balance - SUM(a.outbytes+a.inbytes)
          FROM $accounting_table a, iplog i
          WHERE a.src_ip = i.ip
            AND i.end_time = 0
            AND i.mac = n.mac
            AND a.status = $INACTIVE
        )
        WHERE n.bandwidth_balance > 0
      ]);

    $accounting_statements->{'accounting_update_status_analyzed_sql'} =
      get_db_handle()->prepare(qq[
        UPDATE $accounting_table
          SET status = $ANALYZED
          WHERE status = $INACTIVE
      ]);

    $accounting_statements->{'accounting_select_node_bandwidth_balance_sql'} =
      get_db_handle()->prepare(qq[
        SELECT n.mac, i.ip
        FROM node n, iplog i
        LEFT JOIN $accounting_table a ON i.ip = a.src_ip AND a.status = $ACTIVE
        WHERE n.mac = i.mac
          AND i.end_time = 0
          AND (n.bandwidth_balance = 0
               OR ((n.bandwidth_balance - a.outbytes - a.inbytes) <= 0))
      ]);

    $accounting_db_prepared = 1;
}

sub inline_accounting_import_ulogd_data {
    # Session that haven't been updated for more than
    # $accounting_session_timeout seconds will be dropped from the mem table.
    # When reconnecting, the client will get a new entry in the accounting table.
    # Should be higher than the interval at which import_ulogd_data is called.
    # $ip is optional. When called with this parameter, this function will import
    # the stats for that ip only and then delete its row in the mem table.
    # This is done to ensure that new statistics will be part of a new
    # accounting session
    my ($accounting_session_timeout, $ip) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    $logger->debug("Importing ulogd data");

    my $dbh = get_db_handle();
    $dbh->do("LOCK TABLE $mem_table WRITE");

    # XXX if one of these statements fail it will reconnect. losing the table lock
    # some accounting data updates may be lost
    my $new_data_query;
    if (defined $ip) {
      $new_data_query = db_query_execute("inline::accounting",
                              $accounting_statements,
                              'accounting_select_single_ip_stats_mem_sql',
                              $ip) || return (0);
    } else {
      $new_data_query = db_query_execute("inline::accounting",
                              $accounting_statements,
                              'accounting_select_all_ip_stats_mem_sql',
                              $accounting_session_timeout) || return (0);
    }

    my $new_accounting_data = $new_data_query->fetchall_arrayref();
    my $dropall=0;

    if (defined $ip) {
        # This is done to ensure that new stats will create a new 'session'
        # in the accounting table.
        $logger->debug("Dropping stats from memory table for ip $ip");
        db_query_execute("inline::accounting", $accounting_statements,
                         'accounting_drop_single_ip_stats_mem_sql', $ip);
    } else {
        # This drop all logic must be done only when called for all ips
        for my $row (@$new_accounting_data) {
          # this is kind of crude, but should be good enough to detect day changes
          # 2013-10-25 10:01:02
            $$row[-1] =~ /\d+-\d+-(\d+) /;
            my $lastmodified_day = $1;
            $$row[-2] =~ /\d+-\d+-(\d+) /;
            my $firstseen_day = $1;
    
            if ($firstseen_day != $lastmodified_day) {
                $dropall=1;
                last;
            }
        }
        if ($dropall) {
            # Drop all data from mem table to get new accounting sessions every day
            $logger->debug("New day, dropping all rows from ulogd memory table");
            # Need to use DELETE FROM + reset AUTO_INCREMENT since a locked table cannot be truncated
            db_query_execute("inline::accounting", $accounting_statements, 'accounting_delete_all_mem_sql');
            db_query_execute("inline::accounting", $accounting_statements, 'accounting_reset_autoincrement_mem_sql');
        }
        else {
            db_query_execute("inline::accounting", $accounting_statements, 'accounting_drop_inactive_sessions_mem_sql', $accounting_session_timeout);
        }
    }
    $dbh->do("UNLOCK TABLES");

    foreach my $row (@$new_accounting_data) {
        my $src_ip = $$row[0];
        my $inbytes = $$row[1];
        my $outbytes = $$row[2];
        my $firstseen = $$row[3];
        my $lastmodified = $$row[4];
        my $status = $dropall? $INACTIVE : $$row[5];
        db_query_execute("inline::accounting", $accounting_statements, 'accounting_add_active_session_sql',
                         $src_ip, $firstseen, $lastmodified,
                         $outbytes, $inbytes,
                         $lastmodified, $outbytes, $inbytes, $status);
    }

}

sub inline_accounting_maintenance {
    my $accounting_session_timeout = shift;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    # Fetch violations that use the 'Accounting::BandwidthExpired' trigger
    my @tid = trigger_view_tid($ACCOUNTING_POLICY_BANDWIDTH);
    if (scalar(@tid) > 0) {
        my $violation_id = $tid[0]{'vid'}; # only consider the first violation
        $logger->debug("Violation $violation_id is of type $TRIGGER_TYPE_ACCOUNTING::$ACCOUNTING_POLICY_BANDWIDTH; analyzing inline accounting data");

        # Update the bandwidth balance of nodes by subtracting consumed bandwidth of inactive sessions
        db_query_execute('inline::acounting', $accounting_statements, 'accounting_update_node_bandwidth_balance_sql');

        # Extract nodes with no more bandwidth left (considering also active sessions)
        my $bandwidth_query = db_query_execute('inline::acounting', $accounting_statements, 'accounting_select_node_bandwidth_balance_sql');
        if ($bandwidth_query) {
            while (my $row = $bandwidth_query->fetrow_arrayref()) {
                my ($mac, $ip) = @$row;
                # Trigger violation
                violation_trigger($mac, $violation_id, $TRIGGER_TYPE_ACCOUNTING);

                # Stop counters of active network sessions for this node
                inline_accounting_import_ulogd_data($accounting_session_timeout, $ip);
            }

            # Update bandwidth balance with new inactive sessions
            db_query_execute('inline::acounting', $accounting_statements, 'accounting_update_node_bandwidth_balance_sql');
        }

        # UPDATE inline_accounting: Mark INACTIVE entries as ANALYZED
        db_query_execute('inline::acounting', $accounting_statements, 'accounting_update_status_analyzed_sql');
    }
}


=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2013 Inverse inc.

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

# vim: set shiftwidth=4:
# vim: set ts=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
