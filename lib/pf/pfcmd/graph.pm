package pf::pfcmd::graph;

=head1 NAME

pf::pfcmd::graph - module feeding data to generate the graphics

=cut


use strict;
use warnings;

use constant GRAPH => 'pfcmd::graph';

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA    = qw(Exporter);
    @EXPORT = qw(
        $graph_db_prepared
        graph_db_prepare

        graph_unregistered
        graph_registered
        graph_detected
        graph_security_events_all
        graph_wired
        graph_wireless

        graph_security_events
        graph_nodes
    );
}

use pf::db;

# The next two variables and the _prepare sub are required for database handling magic (see pf::db)
our $graph_db_prepared = 0;
# in this hash reference we hold the database statements. We pass it to the query handler and he will repopulate
# the hash if required
our $graph_statements = {};

sub graph_db_prepare {
    $graph_statements->{'graph_registered_day_sql'} = get_db_handle()->prepare(
         qq [ SELECT 'Registered Nodes' as series, DATE_FORMAT(regdate,"%Y/%m/%d") AS mydate, count(*) AS count FROM node WHERE status = 'reg' AND regdate BETWEEN ? AND ? GROUP BY mydate ORDER BY mydate]);

    $graph_statements->{'graph_registered_month_sql'} = get_db_handle()->prepare(
         qq [ SELECT 'Registered Nodes' as series, DATE_FORMAT(regdate,"%Y/%m") AS mydate, count(*) AS count FROM node WHERE status = 'reg' AND regdate BETWEEN ? AND ? GROUP BY mydate ORDER BY mydate]);

    $graph_statements->{'graph_registered_year_sql'} = get_db_handle()->prepare(
        qq [ SELECT 'Registered Nodes' as series, mydate, (SELECT COUNT(*) FROM node WHERE DATE_FORMAT(regdate,"%Y") <= mydate AND regdate!=0) as count FROM  (SELECT DISTINCT DATE_FORMAT(regdate,"%Y") AS mydate FROM node) as tmp order by mydate ]);

    $graph_statements->{'graph_unregistered_day_sql'} = get_db_handle()->prepare(
        qq [ SELECT 'Unregistered Nodes' as series, DATE_FORMAT(unregdate,"%Y/%m/%d") AS mydate, count(*) count FROM node WHERE status = 'unreg' AND unregdate BETWEEN ? AND ? GROUP BY mydate ORDER BY mydate]);

    $graph_statements->{'graph_unregistered_month_sql'} = get_db_handle()->prepare(
        qq [ SELECT 'Unregistered Nodes' as series, DATE_FORMAT(unregdate,"%Y/%m") AS mydate, count(*) count FROM node WHERE status = 'unreg' AND unregdate BETWEEN ? AND ? GROUP BY mydate ORDER BY mydate]);

    $graph_statements->{'graph_unregistered_year_sql'} = get_db_handle()->prepare(
        qq [ SELECT 'Unregistered Nodes' as series, mydate, (SELECT COUNT(*) FROM node WHERE DATE_FORMAT(unregdate,"%Y") <= mydate AND (DATE_FORMAT(regdate,"%Y") >= mydate OR regdate=0) ) AS count FROM (SELECT DISTINCT DATE_FORMAT(unregdate,"%Y") AS mydate FROM node) as tmp group by mydate order by mydate ]);

    $graph_statements->{'graph_detected_day_sql'} = get_db_handle()->prepare(
         qq [ SELECT 'Detected Nodes' as series, DATE_FORMAT(detect_date,"%Y/%m/%d") AS mydate, count(*) AS count FROM node WHERE detect_date BETWEEN ? AND ? GROUP BY mydate ORDER BY mydate]);

    $graph_statements->{'graph_detected_month_sql'} = get_db_handle()->prepare(
         qq [ SELECT 'Detected Nodes' as series, DATE_FORMAT(detect_date,"%Y/%m") AS mydate, count(*) AS count FROM node WHERE detect_date BETWEEN ? AND ? GROUP BY mydate ORDER BY mydate]);

    $graph_statements->{'graph_security_events_all_day_sql'} = get_db_handle()->prepare(qq[
         SELECT 'SecurityEvents' AS series, DATE_FORMAT(start_date,'%Y/%m/%d') AS mydate, count(*) AS count
         FROM security_event
         WHERE start_date BETWEEN ? AND ?
         GROUP BY mydate ORDER BY mydate
    ]);

    $graph_statements->{'graph_security_events_all_month_sql'} = get_db_handle()->prepare(qq[
         SELECT 'SecurityEvents' AS series, DATE_FORMAT(start_date,'%Y/%m') AS mydate, count(*) AS count
         FROM security_event
         WHERE start_date BETWEEN ? AND ?
         GROUP BY mydate ORDER BY mydate
    ]);

    $graph_statements->{'graph_security_events_day_sql'} = get_db_handle()->prepare(<<"    SQL");
        SELECT mydate, (
            SELECT COUNT(*) FROM security_event
            WHERE security_event_id = my_security_event_id
                AND DATE_FORMAT(start_date,'%Y/%m/%d') = mydate
            ) AS count,
            description AS series
        FROM (
            SELECT DISTINCT DATE_FORMAT(start_date, '%Y/%m/%d') AS mydate, v.security_event_id AS my_security_event_id, c.description
            FROM security_event AS v
            LEFT JOIN class AS c USING (security_event_id)
            WHERE v.start_date BETWEEN ? AND ?
        ) AS tmp
        GROUP BY my_security_event_id, mydate ORDER BY mydate
    SQL

    $graph_statements->{'graph_security_events_month_sql'} = get_db_handle()->prepare(<<"    SQL");
        SELECT mydate, (
            SELECT COUNT(*) FROM security_event
            WHERE security_event_id = my_security_event_id
                AND DATE_FORMAT(start_date,'%Y/%m') = mydate
            ) AS count,
            description AS series
        FROM (
            SELECT DISTINCT DATE_FORMAT(start_date, '%Y/%m') AS mydate, v.security_event_id AS my_security_event_id, c.description
            FROM security_event AS v
            LEFT JOIN class AS c USING (security_event_id)
            WHERE v.start_date BETWEEN ? AND ?
        ) AS tmp
        GROUP BY my_security_event_id, mydate ORDER BY mydate
    SQL

    $graph_statements->{'graph_security_events_year_sql'} = get_db_handle()->prepare(<<"    SQL");
        SELECT mydate, (
            SELECT COUNT(*) FROM security_event 
            WHERE security_event_id=my_security_event_id 
                AND DATE_FORMAT(start_date,"%Y") <= mydate 
                AND (DATE_FORMAT(release_date,"%Y") >= mydate OR release_date=0)
            ) AS count,
            description AS series 
        FROM (
            SELECT DISTINCT DATE_FORMAT(start_date, "%Y") AS mydate, v.security_event_id AS my_security_event_id, c.description 
            FROM security_event AS v LEFT JOIN class AS c USING (security_event_id)
        ) AS tmp 
        GROUP BY my_security_event_id, mydate ORDER BY mydate
    SQL

    $graph_statements->{'graph_wired_day_sql'} = get_db_handle()->prepare(<<"    SQL");
        SELECT 'Wired Connections' as series, start_day AS mydate, count(*) AS count FROM (
          SELECT mac, DATE_FORMAT(start_time,"%Y/%m/%d") AS start_day
          FROM locationlog
          WHERE start_time > ? AND start_time < ? AND connection_type NOT LIKE 'Wireless%'
          GROUP BY start_day, mac
        ) AS wired
        GROUP BY start_day
    SQL

    $graph_statements->{'graph_wired_month_sql'} = get_db_handle()->prepare(<<"    SQL");
        SELECT 'Wired Connections' as series, start_day AS mydate, count(*) AS count FROM (
          SELECT mac, DATE_FORMAT(start_time,"%Y/%m") AS start_day
          FROM locationlog
          WHERE start_time > ? AND start_time < ? AND connection_type NOT LIKE 'Wireless%'
          GROUP BY start_day, mac
        ) AS wired
        GROUP BY start_day
    SQL

    $graph_statements->{'graph_wireless_day_sql'} = get_db_handle()->prepare(<<"    SQL");
        SELECT 'Wireless Connections' as series, start_day AS mydate, count(*) AS count FROM (
          SELECT mac, DATE_FORMAT(start_time,"%Y/%m/%d") AS start_day
          FROM locationlog
          WHERE start_time > ? AND start_time < ? AND connection_type LIKE 'Wireless%'
          GROUP BY start_day, mac
        ) AS wireless
        GROUP BY start_day
    SQL

    $graph_statements->{'graph_wireless_month_sql'} = get_db_handle()->prepare(<<"    SQL");
        SELECT 'Wireless Connections' as series, start_day AS mydate, count(*) AS count FROM (
          SELECT mac, DATE_FORMAT(start_time,"%Y/%m") AS start_day
          FROM locationlog
          WHERE start_time > ? AND start_time < ? AND connection_type LIKE 'Wireless%'
          GROUP BY start_day, mac
        ) AS wireless
        GROUP BY start_day
    SQL

    # graph_activity_current
    # graph_nodes_current
    # graph_security_events_current
    $graph_db_prepared = 1;
    return 1;
}

sub graph_unregistered {
    my ($start, $end, $interval) = @_;

    $interval ||= 'day';
    my $graph = "graph_unregistered_${interval}_sql";
    return (db_data(GRAPH, $graph_statements, $graph, $start, $end));
}

sub graph_registered {
    my ($start, $end, $interval) = @_;

    $interval ||= 'day';
    my $graph = "graph_registered_${interval}_sql";
    my @results = db_data(GRAPH, $graph_statements, $graph, $start, $end);

    return @results;
}

sub graph_detected {
    my ($start, $end, $interval) = @_;

    $interval ||= 'day';
    my $graph = "graph_detected_${interval}_sql";
    return (db_data(GRAPH, $graph_statements, $graph, $start, $end));
}

sub graph_security_events_all {
    my ($start, $end, $interval) = @_;

    $interval ||= 'day';
    my $graph = "graph_security_events_all_${interval}_sql";
    return (db_data(GRAPH, $graph_statements, $graph, $start, $end));
}

sub graph_security_events {
    my ($start, $end, $interval) = @_;

    $interval ||= 'day';
    my $graph = "graph_security_events_${interval}_sql";
    return (db_data(GRAPH, $graph_statements, $graph, $start, $end));
}

sub graph_wired {
    my ($start, $end, $interval) = @_;

    $interval ||= 'day';
    my $graph = "graph_wired_${interval}_sql";
    return (db_data(GRAPH, $graph_statements, $graph, $start, $end));
}

sub graph_wireless {
    my ($start, $end, $interval) = @_;

    $interval ||= 'day';
    my $graph = "graph_wireless_${interval}_sql";
    return (db_data(GRAPH, $graph_statements, $graph, $start, $end));
}

sub graph_nodes {
    my ($start, $end, $interval) = @_;

    $interval ||= 'day';
    my $graph  = "graph_registered_${interval}_sql";
    my @return = db_data(GRAPH, $graph_statements, $graph, $start, $end);
    $graph = "graph_unregistered_${interval}_sql";
    push( @return, db_data(GRAPH, $graph_statements, $graph, $start, $end) );
    return ( sort { $a->{'mydate'} cmp $b->{'mydate'} } @return );
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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
