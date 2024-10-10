#!/usr/bin/perl

=head1 NAME

security_event_maintenance

=head1 DESCRIPTION

unit test for security_event_maintenance

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 7;
use pf::factory::pfcron::task;
use pf::dal;
use pf::api;
use pf::client;
use pf::error qw(is_error);

#This test will running last
use Test::NoWarnings;

{
    runSql(
        'TRUNCATE security_event',
		'DROP TABLE IF EXISTS security_event_maintenance_test_mac_delay',
        q[
			CREATE TABLE security_event_maintenance_test_mac_delay
WITH RECURSIVE first_mac AS (
    (
    SELECT
      LOWER(CONCAT_WS( ':', LPAD(HEX(((cur + 1) >> 40) & 255), 2, '0'), LPAD(HEX(((cur + 1) >> 32) & 255), 2, '0'), LPAD(HEX(((cur + 1) >> 24) & 255), 2, '0'), LPAD(HEX(((cur + 1) >> 16) & 255), 2, '0'), LPAD(HEX(((cur + 1) >> 8) & 255), 2, '0'), LPAD(HEX((cur + 1) & 255), 2, '0') )) AS mac, cur + 1 as start_int
    FROM
      (
        SELECT
          mac as cur_mac,
          CONV(REPLACE(mac, ':', ''), 16, 10) cur,
          CONV( REPLACE(IFNULL(LEAD(mac) OVER (
        ORDER BY
          mac), "ff:ff:ff:ff:ff:ff"), ':' , ''), 16, 10 ) as next
        FROM
          node
      )
      as x
    WHERE
      next - cur >= 100 LIMIT 1
    )
    UNION ALL
    (
        SELECT "00:00:00:00:00:01", 1
    )
    LIMIT 1
),
seq_0_to_49 AS (SELECT 0 AS seq UNION ALL SELECT seq + 1 FROM  seq_0_to_49 where seq < 49)

SELECT
    LOWER(CONCAT_WS(
        ':',
        LPAD(HEX(((seq + start_int) >> 40) & 255), 2, '0'),
        LPAD(HEX(((seq + start_int) >> 32) & 255), 2, '0'),
        LPAD(HEX(((seq + start_int) >> 24) & 255), 2, '0'),
        LPAD(HEX(((seq + start_int) >> 16) & 255), 2, '0'),
        LPAD(HEX(((seq + start_int) >> 8) & 255), 2, '0'),
        LPAD(HEX((seq + start_int) & 255), 2, '0')
    )) AS mac

FROM first_mac JOIN seq_0_to_49;
    ],
'INSERT INTO node (mac) SELECT mac FROM security_event_maintenance_test_mac_delay',
        q[
			INSERT INTO security_event (
                mac,
                security_event_id,
                start_date,
                release_date,
                status
            )
           SELECT
            mac,
            '1100017',
            DATE_SUB(NOW(), INTERVAL 1 HOUR),
            DATE_SUB(NOW(), INTERVAL 30 MINUTE),
            'delayed'
           FROM security_event_maintenance_test_mac_delay
    ],
    );

    runTask();
    checkCount(
        {
            name => "delayed switch to open",
            sql =>
"SELECT COUNT(*) FROM security_event WHERE mac IN (SELECT mac from security_event_maintenance_test_mac_delay) AND status = 'open';",
            count => 50,
        },
    );
    runSql(
'DELETE from node WHERE mac IN (SELECT mac FROM security_event_maintenance_test_mac_delay)',
'DELETE from security_event WHERE mac IN (SELECT mac FROM security_event_maintenance_test_mac_delay)',
        'DROP TABLE IF EXISTS security_event_maintenance_test_mac_delay',
    );

}

{
    runSql(
        'TRUNCATE security_event',
        q[DROP TABLE IF EXISTS security_event_maintenance_test_mac_open],
        q[CREATE TABLE security_event_maintenance_test_mac_open
WITH RECURSIVE first_mac AS (
    (
    SELECT
      LOWER(CONCAT_WS( ':', LPAD(HEX(((cur + 1) >> 40) & 255), 2, '0'), LPAD(HEX(((cur + 1) >> 32) & 255), 2, '0'), LPAD(HEX(((cur + 1) >> 24) & 255), 2, '0'), LPAD(HEX(((cur + 1) >> 16) & 255), 2, '0'), LPAD(HEX(((cur + 1) >> 8) & 255), 2, '0'), LPAD(HEX((cur + 1) & 255), 2, '0') )) AS mac, cur + 1 as start_int
    FROM
      (
        SELECT
          mac as cur_mac,
          CONV(REPLACE(mac, ':', ''), 16, 10) cur,
          CONV( REPLACE(IFNULL(LEAD(mac) OVER (
        ORDER BY
          mac), "ff:ff:ff:ff:ff:ff"), ':' , ''), 16, 10 ) as next
        FROM
          node
      )
      as x
    WHERE
      next - cur >= 100 LIMIT 1
    )
    UNION ALL
    (
        SELECT "00:00:00:00:00:01", 1
    )
    LIMIT 1
),
seq_0_to_99 AS (SELECT 0 AS seq UNION ALL SELECT seq + 1 FROM  seq_0_to_99 where seq < 99)

SELECT
    LOWER(CONCAT_WS(
        ':',
        LPAD(HEX(((seq + start_int) >> 40) & 255), 2, '0'),
        LPAD(HEX(((seq + start_int) >> 32) & 255), 2, '0'),
        LPAD(HEX(((seq + start_int) >> 24) & 255), 2, '0'),
        LPAD(HEX(((seq + start_int) >> 16) & 255), 2, '0'),
        LPAD(HEX(((seq + start_int) >> 8) & 255), 2, '0'),
        LPAD(HEX((seq + start_int) & 255), 2, '0')
    )) AS mac

FROM first_mac JOIN seq_0_to_99;],
'INSERT INTO node (mac) SELECT mac FROM security_event_maintenance_test_mac_open',
        q[INSERT INTO security_event (
                mac,
                security_event_id,
                start_date,
                release_date,
                status
            )
           SELECT
            mac,
            '1100017',
            DATE_SUB(NOW(), INTERVAL 1 HOUR),
            DATE_SUB(NOW(), INTERVAL 30 MINUTE),
            'open'
           FROM security_event_maintenance_test_mac_open
            ],
    );

    runTask();
    checkCount(
        {
            name => "delayed open to closed",
            sql =>
q[SELECT COUNT(*) FROM security_event WHERE mac IN (SELECT mac from security_event_maintenance_test_mac_open) AND status = 'closed';],
            count => 100,
        },
    );
    runSql(
'DELETE from node WHERE mac IN (SELECT mac FROM security_event_maintenance_test_mac_open)',
'DELETE from security_event WHERE mac IN (SELECT mac FROM security_event_maintenance_test_mac_open)',
        'DROP TABLE IF EXISTS security_event_maintenance_test_mac_open',
    );

}

{
    runSql(
			'TRUNCATE security_event',
            'DROP TABLE IF EXISTS security_event_maintenance_test_mac_mixed',
		q[	
CREATE TABLE security_event_maintenance_test_mac_mixed
WITH RECURSIVE first_mac AS (
    (
    SELECT
      LOWER(CONCAT_WS( ':', LPAD(HEX(((cur + 1) >> 40) & 255), 2, '0'), LPAD(HEX(((cur + 1) >> 32) & 255), 2, '0'), LPAD(HEX(((cur + 1) >> 24) & 255), 2, '0'), LPAD(HEX(((cur + 1) >> 16) & 255), 2, '0'), LPAD(HEX(((cur + 1) >> 8) & 255), 2, '0'), LPAD(HEX((cur + 1) & 255), 2, '0') )) AS mac, cur + 1 as start_int
    FROM
      (
        SELECT
          mac as cur_mac,
          CONV(REPLACE(mac, ':', ''), 16, 10) cur,
          CONV( REPLACE(IFNULL(LEAD(mac) OVER (
        ORDER BY
          mac), "ff:ff:ff:ff:ff:ff"), ':' , ''), 16, 10 ) as next
        FROM
          node
      )
      as x
    WHERE
      next - cur >= 100 LIMIT 1
    )
    UNION ALL
    (
        SELECT "00:00:00:00:00:01", 1
    )
    LIMIT 1
),
seq_0_to_99 AS (SELECT 0 AS seq UNION ALL SELECT seq + 1 FROM  seq_0_to_99 where seq < 99)

SELECT
    LOWER(CONCAT_WS(
        ':',
        LPAD(HEX(((seq + start_int) >> 40) & 255), 2, '0'),
        LPAD(HEX(((seq + start_int) >> 32) & 255), 2, '0'),
        LPAD(HEX(((seq + start_int) >> 24) & 255), 2, '0'),
        LPAD(HEX(((seq + start_int) >> 16) & 255), 2, '0'),
        LPAD(HEX(((seq + start_int) >> 8) & 255), 2, '0'),
        LPAD(HEX((seq + start_int) & 255), 2, '0')
    )) AS mac,
    ntile(4) over (order by mac) type

FROM first_mac JOIN seq_0_to_99;
            ],
			'INSERT INTO node (mac) SELECT mac FROM security_event_maintenance_test_mac_mixed',
			q[INSERT INTO security_event (
                mac,
                security_event_id,
                start_date,
                release_date,
                status
            )
           SELECT
            mac,
            '1100017',
            DATE_SUB(NOW(), INTERVAL 1 HOUR),
            CASE type
            WHEN 1 THEN DATE_ADD(NOW(), INTERVAL 30 MINUTE)
            WHEN 3 THEN DATE_ADD(NOW(), INTERVAL 30 MINUTE)
            ELSE DATE_SUB(NOW(), INTERVAL 30 MINUTE)
            END,
            CASE type
            WHEN 1 THEN "delayed"
            WHEN 2 THEN "delayed"
            ELSE "open"
            END
           FROM security_event_maintenance_test_mac_mixed
            ],
    );
    runTask();
    checkCount(
			{
				name  => "open to close",
				sql   => "SELECT COUNT(*) FROM security_event WHERE mac IN (SELECT mac from security_event_maintenance_test_mac_mixed WHERE type = 4) AND status = 'closed';",
				count => 25,
			},
			{
				name  => "stayed open",
				sql   => "SELECT COUNT(*) FROM security_event WHERE mac IN (SELECT mac from security_event_maintenance_test_mac_mixed WHERE type = 3) AND status = 'open';",
				count => 25,
			},
			{
				name  => "delay to open",
				sql   => "SELECT COUNT(*) FROM security_event WHERE mac IN (SELECT mac from security_event_maintenance_test_mac_mixed WHERE type = 2) AND status = 'open';",
				count => 25,
			},
			{
				name  => "stayed delayed",
				sql   => "SELECT COUNT(*) FROM security_event WHERE mac IN (SELECT mac from security_event_maintenance_test_mac_mixed WHERE type = 1) AND status = 'delayed';",
				count => 25,
			},
    );
    runSql(
			'DELETE from node WHERE mac IN (SELECT mac FROM security_event_maintenance_test_mac_mixed)',
			'DELETE from security_event WHERE mac IN (SELECT mac FROM security_event_maintenance_test_mac_mixed)',
			'DROP TABLE IF EXISTS security_event_maintenance_test_mac_mixed',
    );
}

sub runSql {
    my @stmts = @_;
    for my $sql (@stmts) {
        my ($status, $sth) = pf::dal->db_execute($sql);
        if (is_error($status)) {
            BAIL_OUT("$sql: $sth");
        }
        $sth->finish;
    }
}

sub checkCount {
    my @checks = @_;
    for my $check (@checks) {
        my $sql = $check->{sql};
        my ($status, $sth) = pf::dal->db_execute($sql);
        if (is_error($status)) {
            BAIL_OUT("$sql: $sth");
        }
        my $expectCount = $check->{count};
        my ($gotCount) = $sth->fetchrow_array;
        is($expectCount, $gotCount, $check->{name});
        $sth->finish;
    }
}

sub runTask {
    local $pf::client::CURRENT_CLIENT = "pf::api::local";
    my $task = pf::factory::pfcron::task->new("security_event_maintenance");
    $task->run();
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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

