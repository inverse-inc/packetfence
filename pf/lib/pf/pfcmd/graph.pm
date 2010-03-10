package pf::pfcmd::graph;

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
    $graph_statements->{'graph_registered_day_sql'} = get_db_handle()->prepare(
        qq [ SELECT 'registered nodes' as series, mydate, (SELECT COUNT(*) FROM node WHERE DATE_FORMAT(regdate,"%Y/%m/%d") <= mydate AND regdate!=0) as count FROM  (SELECT DISTINCT DATE_FORMAT(regdate,"%Y/%m/%d") AS mydate FROM node) as tmp order by mydate ]);

    $graph_statements->{'graph_registered_month_sql'} = get_db_handle()->prepare(
        qq [ SELECT 'registered nodes' as series, mydate, (SELECT COUNT(*) FROM node WHERE DATE_FORMAT(regdate,"%Y/%m") <= mydate AND regdate!=0) as count FROM  (SELECT DISTINCT DATE_FORMAT(regdate,"%Y/%m") AS mydate FROM node) as tmp order by mydate ]);

    $graph_statements->{'graph_registered_year_sql'} = get_db_handle()->prepare(
        qq [ SELECT 'registered nodes' as series, mydate, (SELECT COUNT(*) FROM node WHERE DATE_FORMAT(regdate,"%Y") <= mydate AND regdate!=0) as count FROM  (SELECT DISTINCT DATE_FORMAT(regdate,"%Y") AS mydate FROM node) as tmp order by mydate ]);

    $graph_statements->{'graph_unregistered_day_sql'} = get_db_handle()->prepare(
        qq [ SELECT 'unregistered nodes' as series, mydate, (SELECT COUNT(*) FROM node WHERE DATE_FORMAT(detect_date,"%Y/%m/%d") <= mydate AND (DATE_FORMAT(regdate,"%Y/%m/%d") >= mydate OR regdate=0) ) AS count FROM (SELECT DISTINCT DATE_FORMAT(detect_date,"%Y/%m/%d") AS mydate FROM node) as tmp group by mydate order by mydate ]);

    $graph_statements->{'graph_unregistered_month_sql'} = get_db_handle()->prepare(
        qq [ SELECT 'unregistered nodes' as series, mydate, (SELECT COUNT(*) FROM node WHERE DATE_FORMAT(detect_date,"%Y/%m") <= mydate AND (DATE_FORMAT(regdate,"%Y/%m") >= mydate OR regdate=0) ) AS count FROM (SELECT DISTINCT DATE_FORMAT(detect_date,"%Y/%m") AS mydate FROM node) as tmp group by mydate order by mydate ]);

    $graph_statements->{'graph_unregistered_year_sql'} = get_db_handle()->prepare(
        qq [ SELECT 'unregistered nodes' as series, mydate, (SELECT COUNT(*) FROM node WHERE DATE_FORMAT(detect_date,"%Y") <= mydate AND (DATE_FORMAT(regdate,"%Y") >= mydate OR regdate=0) ) AS count FROM (SELECT DISTINCT DATE_FORMAT(detect_date,"%Y") AS mydate FROM node) as tmp group by mydate order by mydate ]);

    $graph_statements->{'graph_violations_day_sql'} = get_db_handle()->prepare(
        qq [ SELECT mydate, (SELECT COUNT(*) FROM violation WHERE vid=myvid AND DATE_FORMAT(start_date,"%Y/%m/%d") <= mydate AND (DATE_FORMAT(release_date,"%Y/%m/%d") >= mydate OR release_date=0) ) AS count,description as series FROM (SELECT DISTINCT DATE_FORMAT(start_date,"%Y/%m/%d") AS mydate, v.vid as myvid,c.description FROM violation v,class c) as tmp group by myvid, mydate order by mydate ]);

    $graph_statements->{'graph_violations_month_sql'} = get_db_handle()->prepare(
        qq [ SELECT mydate, (SELECT COUNT(*) FROM violation WHERE vid=myvid AND DATE_FORMAT(start_date,"%Y/%m") <= mydate AND (DATE_FORMAT(release_date,"%Y/%m") >= mydate OR release_date=0) ) AS count,description as series FROM (SELECT DISTINCT DATE_FORMAT(start_date,"%Y/%m") AS mydate, v.vid as myvid,c.description FROM violation v,class c) as tmp group by myvid, mydate order by mydate ]);

    $graph_statements->{'graph_violations_year_sql'} = get_db_handle()->prepare(
        qq [ SELECT mydate, (SELECT COUNT(*) FROM violation WHERE vid=myvid AND DATE_FORMAT(start_date,"%Y") <= mydate AND (DATE_FORMAT(release_date,"%Y") >= mydate OR release_date=0) ) AS count,description as series FROM (SELECT DISTINCT DATE_FORMAT(start_date,"%Y") AS mydate, v.vid as myvid,c.description FROM violation v,class c) as tmp group by myvid, mydate order by mydate ]);

    # graph_activity_current
    # graph_nodes_current
    # graph_violations_current
    $graph_db_prepared = 1;
    return 1;
}

sub graph_unregistered {
    my ($interval) = @_;

    my $graph = "graph_unregistered_" . $interval . "_sql";
    no strict 'refs';
    return (db_data(GRAPH, $graph_statements, $$graph));
}

sub graph_registered {
    my ($interval) = @_;

    my $graph = "graph_registered_" . $interval . "_sql";
    no strict 'refs';
    return (db_data(GRAPH, $graph_statements, $$graph));
}

sub graph_violations {
    my ($interval) = @_;
    my $graph = "graph_violations_" . $interval . "_sql";
    no strict 'refs';
    return (db_data(GRAPH, $graph_statements, $$graph));
}

sub graph_nodes {
    my ($interval) = @_;

    no strict 'refs';
    my $graph  = "graph_registered_" . $interval . "_sql";
    my @return = db_data(GRAPH, $graph_statements, $$graph);
    $graph = "graph_unregistered_" . $interval . "_sql";
    push( @return, db_data(GRAPH, $graph_statements, $$graph) );
    return ( sort { $a->{'mydate'} cmp $b->{'mydate'} } @return );

}

=head1 AUTHOR

David LaPorte <david@davidlaporte.org>

Kevin Amorin <kev@amorin.org>

Olivier Bilodeau <obilodeau@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005 David LaPorte

Copyright (C) 2005 Kevin Amorin

Copyright (C) 2010 Inverse inc.

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
