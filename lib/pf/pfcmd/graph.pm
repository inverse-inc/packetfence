package pf::pfcmd::graph;

=head1 NAME

pf::pfcmd::graph - module feeding data to generate the graphics

=cut


use strict;
use warnings;
use Log::Log4perl;

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
        graph_violations_all
        graph_wired
        graph_wireless

        graph_violations
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
    $graph_statements->{'graph_registered_sql'} = get_db_handle()->prepare(
         qq [ SELECT 'registered nodes' as series, DATE_FORMAT(regdate,"%Y/%m/%d") AS mydate, count(*) AS count FROM node WHERE status = 'reg' AND regdate BETWEEN ? AND ? GROUP BY mydate ORDER BY mydate]);

    $graph_statements->{'graph_registered_day_sql'} = get_db_handle()->prepare(
        qq [ SELECT 'registered nodes' as series, mydate, (SELECT COUNT(*) FROM node WHERE DATE_FORMAT(regdate,"%Y/%m/%d") <= mydate AND regdate!=0) as count FROM  (SELECT DISTINCT DATE_FORMAT(regdate,"%Y/%m/%d") AS mydate FROM node) as tmp order by mydate ]);

    $graph_statements->{'graph_registered_month_sql'} = get_db_handle()->prepare(
        qq [ SELECT 'registered nodes' as series, mydate, (SELECT COUNT(*) FROM node WHERE DATE_FORMAT(regdate,"%Y/%m") <= mydate AND regdate!=0) as count FROM  (SELECT DISTINCT DATE_FORMAT(regdate,"%Y/%m") AS mydate FROM node) as tmp order by mydate ]);

    $graph_statements->{'graph_registered_year_sql'} = get_db_handle()->prepare(
        qq [ SELECT 'registered nodes' as series, mydate, (SELECT COUNT(*) FROM node WHERE DATE_FORMAT(regdate,"%Y") <= mydate AND regdate!=0) as count FROM  (SELECT DISTINCT DATE_FORMAT(regdate,"%Y") AS mydate FROM node) as tmp order by mydate ]);

    $graph_statements->{'graph_unregistered_sql'} = get_db_handle()->prepare(
        qq [ SELECT 'unregistered nodes' as series, DATE_FORMAT(unregdate,"%Y/%m/%d") AS mydate, count(*) count FROM node WHERE status = 'unreg' AND unregdate BETWEEN ? AND ? GROUP BY mydate ORDER BY mydate]);

    $graph_statements->{'graph_unregistered_day_sql'} = get_db_handle()->prepare(
        qq [ SELECT 'unregistered nodes' as series, mydate, (SELECT COUNT(*) FROM node WHERE DATE_FORMAT(unregdate,"%Y/%m/%d") <= mydate AND (DATE_FORMAT(regdate,"%Y/%m/%d") >= mydate OR regdate=0) ) AS count FROM (SELECT DISTINCT DATE_FORMAT(unregdate,"%Y/%m/%d") AS mydate FROM node) as tmp group by mydate order by mydate ]);

    $graph_statements->{'graph_unregistered_month_sql'} = get_db_handle()->prepare(
        qq [ SELECT 'unregistered nodes' as series, mydate, (SELECT COUNT(*) FROM node WHERE DATE_FORMAT(unregdate,"%Y/%m") <= mydate AND (DATE_FORMAT(regdate,"%Y/%m") >= mydate OR regdate=0) ) AS count FROM (SELECT DISTINCT DATE_FORMAT(unregdate,"%Y/%m") AS mydate FROM node) as tmp group by mydate order by mydate ]);

    $graph_statements->{'graph_unregistered_year_sql'} = get_db_handle()->prepare(
        qq [ SELECT 'unregistered nodes' as series, mydate, (SELECT COUNT(*) FROM node WHERE DATE_FORMAT(unregdate,"%Y") <= mydate AND (DATE_FORMAT(regdate,"%Y") >= mydate OR regdate=0) ) AS count FROM (SELECT DISTINCT DATE_FORMAT(unregdate,"%Y") AS mydate FROM node) as tmp group by mydate order by mydate ]);

    $graph_statements->{'graph_detected_sql'} = get_db_handle()->prepare(
         qq [ SELECT 'detected nodes' as series, DATE_FORMAT(detect_date,"%Y/%m/%d") AS mydate, count(*) AS count FROM node WHERE detect_date BETWEEN ? AND ? GROUP BY mydate ORDER BY mydate]);

    $graph_statements->{'graph_violations_all_sql'} = get_db_handle()->prepare(qq[
         SELECT 'violations' AS series, DATE_FORMAT(start_date,'%Y/%m/%d') AS mydate, count(*) AS count
         FROM violation
         WHERE start_date BETWEEN ? AND ?
         GROUP BY mydate ORDER BY mydate
    ]);

    $graph_statements->{'graph_violations_sql'} = get_db_handle()->prepare(<<"    SQL");
        SELECT mydate, (
            SELECT COUNT(*) FROM violation
            WHERE vid = myvid
                AND DATE_FORMAT(start_date,'%Y/%m/%d') <= mydate
                AND (DATE_FORMAT(release_date, '%Y/%m/%d') >= mydate OR release_date = 0)
            ) AS count,
            description AS series
        FROM (
            SELECT DISTINCT DATE_FORMAT(start_date, '%Y/%m/%d') AS mydate, v.vid AS myvid, c.description
            FROM violation AS v
            LEFT JOIN class AS c USING (vid)
            WHERE v.start_date BETWEEN ? AND ?
        ) AS tmp
        GROUP BY myvid, mydate ORDER BY mydate
    SQL

    $graph_statements->{'graph_violations_day_sql'} = get_db_handle()->prepare(<<"    SQL");
        SELECT mydate, (
            SELECT COUNT(*) FROM violation 
            WHERE vid=myvid 
                AND DATE_FORMAT(start_date,"%Y/%m/%d") <= mydate 
                AND (DATE_FORMAT(release_date,"%Y/%m/%d") >= mydate OR release_date=0)
            ) AS count,
            description AS series 
        FROM (
            SELECT DISTINCT DATE_FORMAT(start_date, "%Y/%m/%d") AS mydate, v.vid AS myvid, c.description 
            FROM violation AS v LEFT JOIN class AS c USING (vid)
        ) AS tmp 
        GROUP BY myvid, mydate ORDER BY mydate
    SQL

    $graph_statements->{'graph_violations_month_sql'} = get_db_handle()->prepare(<<"    SQL");
        SELECT mydate, (
            SELECT COUNT(*) FROM violation 
            WHERE vid=myvid 
                AND DATE_FORMAT(start_date,"%Y/%m") <= mydate 
                AND (DATE_FORMAT(release_date,"%Y/%m") >= mydate OR release_date=0)
            ) AS count,
            description AS series 
        FROM (
            SELECT DISTINCT DATE_FORMAT(start_date, "%Y/%m") AS mydate, v.vid AS myvid, c.description 
            FROM violation AS v LEFT JOIN class AS c USING (vid)
        ) AS tmp 
        GROUP BY myvid, mydate ORDER BY mydate
    SQL

    $graph_statements->{'graph_violations_year_sql'} = get_db_handle()->prepare(<<"    SQL");
        SELECT mydate, (
            SELECT COUNT(*) FROM violation 
            WHERE vid=myvid 
                AND DATE_FORMAT(start_date,"%Y") <= mydate 
                AND (DATE_FORMAT(release_date,"%Y") >= mydate OR release_date=0)
            ) AS count,
            description AS series 
        FROM (
            SELECT DISTINCT DATE_FORMAT(start_date, "%Y") AS mydate, v.vid AS myvid, c.description 
            FROM violation AS v LEFT JOIN class AS c USING (vid)
        ) AS tmp 
        GROUP BY myvid, mydate ORDER BY mydate
    SQL

    $graph_statements->{'graph_wired_sql'} = get_db_handle()->prepare(<<"    SQL");
        SELECT 'wired' as series, start_day AS mydate, count(*) AS count FROM (
          SELECT mac, DATE_FORMAT(start_time,"%Y/%m/%d") AS start_day
          FROM locationlog
          WHERE start_time > ? AND start_time < ? AND connection_type NOT LIKE 'Wireless%'
          GROUP BY start_day, mac
        ) AS wired
        GROUP BY start_day
    SQL

    $graph_statements->{'graph_wireless_sql'} = get_db_handle()->prepare(<<"    SQL");
        SELECT 'wireless' as series, start_day AS mydate, count(*) AS count FROM (
          SELECT mac, DATE_FORMAT(start_time,"%Y/%m/%d") AS start_day
          FROM locationlog
          WHERE start_time > ? AND start_time < ? AND connection_type LIKE 'Wireless%'
          GROUP BY start_day, mac
        ) AS wireless
        GROUP BY start_day
    SQL

    # graph_activity_current
    # graph_nodes_current
    # graph_violations_current
    $graph_db_prepared = 1;
    return 1;
}

sub graph_unregistered {
    my ($start, $end) = @_;

    my $graph = "graph_unregistered_sql";
    return (db_data(GRAPH, $graph_statements, $graph, $start, $end));
}

sub graph_registered {
    my ($start, $end) = @_;

    my $graph = "graph_registered_sql";
    my @results = db_data(GRAPH, $graph_statements, $graph, $start, $end);

    return @results;
}

sub graph_detected {
    my ($start, $end) = @_;

    my $graph = "graph_detected_sql";
    return (db_data(GRAPH, $graph_statements, $graph, $start, $end));
}

sub graph_violations_all {
    my ($start, $end) = @_;

    my $graph = "graph_violations_all_sql";
    return (db_data(GRAPH, $graph_statements, $graph, $start, $end));
}

sub graph_violations {
    my ($start, $end) = @_;

    my $graph = "graph_violations_sql";
    return (db_data(GRAPH, $graph_statements, $graph, $start, $end));
}

sub graph_wired {
    my ($start, $end) = @_;

    my $graph = "graph_wired_sql";
    return (db_data(GRAPH, $graph_statements, $graph, $start, $end));
}

sub graph_wireless {
    my ($start, $end) = @_;

    my $graph = "graph_wireless_sql";
    return (db_data(GRAPH, $graph_statements, $graph, $start, $end));
}

sub graph_nodes {
    my ($start, $end) = @_;

    my $graph  = "graph_registered_sql";
    my @return = db_data(GRAPH, $graph_statements, $graph, $start, $end);
    $graph = "graph_unregistered_sql";
    push( @return, db_data(GRAPH, $graph_statements, $graph, $start, $end) );
    return ( sort { $a->{'mydate'} cmp $b->{'mydate'} } @return );
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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
