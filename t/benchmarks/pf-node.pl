#!/usr/bin/perl
=head1 NAME

pf-node.pl

=head1 DESCRIPTION

Some performance benchmarks on some pf::node functions

=cut
use strict;
use warnings;
use diagnostics;

use Benchmark qw(cmpthese timethese);

use lib '/usr/local/pf/lib';

use pf::db;
use pf::node;

# get the db layer started
my $ignored = node_view('f0:4d:a2:cb:d9:c5');

my @all_nodes = node_view_all();
#my @all_nodes = ({'mac' => 'f0:4d:a2:cb:d9:c5'});

my $results = timethese(1, {
    view_big_query => sub { 
        foreach my $node_info (@all_nodes) {
            pf::node::_node_view_old($node_info->{'mac'});
        }
    },
    view_with_view => sub { 
        foreach my $node_info (@all_nodes) {
            pf::node::_node_view_using_view($node_info->{'mac'});
        }
    },
    view_queries_then_perl => sub { 
        foreach my $node_info (@all_nodes) {
            node_view($node_info->{'mac'});
        }
    },
    attributes => sub { 
        foreach my $node_info (@all_nodes) {
            node_attributes($node_info->{'mac'});
        }
    }
});
cmpthese($results);

=head1 node_view improvements for 3.2.0

=head2 The test

In this test we compared: 

=over

=item the original node_view

With it's 3 JOINs plus GROUP BY on a large table and finally filtering with HAVING...

The SQL query:

    $node_statements->{'node_view_old_sql'} = get_db_handle()->prepare(qq[
        SELECT node.mac, node.pid, node.voip, node.bypass_vlan, node.status,
            IF(ISNULL(node_category.name), '', node_category.name) as category,
            node.detect_date, node.regdate, node.unregdate, node.lastskip,
            node.user_agent, node.computername, node.dhcp_fingerprint,
            node.last_arp, node.last_dhcp,
            locationlog.switch as last_switch, locationlog.port as last_port, locationlog.vlan as last_vlan,
            IF(ISNULL(locationlog.connection_type), '', locationlog.connection_type) as last_connection_type,
            locationlog.dot1x_username as last_dot1x_username, locationlog.ssid as last_ssid,
            COUNT(DISTINCT violation.id) as nbopenviolations,
            node.notes
        FROM node
            LEFT JOIN node_category USING (category_id)
            LEFT JOIN violation ON node.mac=violation.mac AND violation.status = 'open'
            LEFT JOIN locationlog ON node.mac=locationlog.mac AND end_time IS NULL
        GROUP BY node.mac
        HAVING node.mac=?
    ]);


Perl code

    sub _node_view_old {
        my ($mac) = @_;

        # Uncomment to log callers
        #my $logger = Log::Log4perl::get_logger('pf::node');
        #my $caller = ( caller(1) )[3] || basename($0);
        #$logger->trace("node_view called from $caller");

        # commented for performance reason and because the calling code is already defensive enough
        # remove comments if necessary (regressions) 
        #my $tmpMAC = Net::MAC->new( 'mac' => $mac );
        #$mac = $tmpMAC->as_IEEE();
        my $query = db_query_execute(NODE, $node_statements, 'node_view_old_sql', $mac) || return (0);
        my $ref = $query->fetchrow_hashref();

        # just get one row and finish
        $query->finish();
        return ($ref);
    }


=item node_attributes (for comparison purposes only)

Introduced in 2.2.1 to reduce node lookups in critical VLAN assignment code.

SQL statement

    $node_statements->{'node_attributes_sql'} = get_db_handle()->prepare(qq[
        SELECT mac, pid, voip, status, bypass_vlan,
            IF(ISNULL(node_category.name), '', node_category.name) as category,
            detect_date, regdate, unregdate, lastskip,
            user_agent, computername, dhcp_fingerprint,
            last_arp, last_dhcp,
            node.notes
        FROM node
            LEFT JOIN node_category USING (category_id)
        WHERE mac = ?
    ]);

Perl code

    sub node_attributes {
        my ($mac) = @_;

        # commented for performance reason and because the calling code is already defensive enough
        # remove comments if necessary (regressions)
        #my $tmpMAC = Net::MAC->new( 'mac' => $mac );
        #$mac = $tmpMAC->as_IEEE();
        my $query = db_query_execute(NODE, $node_statements, 'node_attributes_sql', $mac) || return (0);
        my $ref = $query->fetchrow_hashref();

        # just get one row and finish
        $query->finish();
        return ($ref);
    }


=item a new multi-query node_view

Doing 3 separate queries and then merging the hashes in perl.

SQL statements

    $node_statements->{'node_view_sql'} = get_db_handle()->prepare(<<'    SQL');
        SELECT node.mac, node.pid, node.voip, node.bypass_vlan, node.status,
            IF(ISNULL(node_category.name), '', node_category.name) as category,
            node.detect_date, node.regdate, node.unregdate, node.lastskip,
            node.user_agent, node.computername, node.dhcp_fingerprint,
            node.last_arp, node.last_dhcp,
            node.notes
        FROM node
            LEFT JOIN node_category USING (category_id)
        WHERE node.mac=?
    SQL

    $node_statements->{'node_last_locationlog_sql'} = get_db_handle()->prepare(<<'    SQL');
       SELECT 
           locationlog.switch as last_switch, locationlog.port as last_port, locationlog.vlan as last_vlan,
           IF(ISNULL(locationlog.connection_type), '', locationlog.connection_type) as last_connection_type,
           locationlog.dot1x_username as last_dot1x_username, locationlog.ssid as last_ssid
       FROM locationlog 
       WHERE mac = ? AND end_time IS NULL
    SQL

Perl code

    sub node_view {
        my ($mac) = @_;

        # Uncomment to log callers
        #my $logger = Log::Log4perl::get_logger('pf::node');
        #my $caller = ( caller(1) )[3] || basename($0);
        #$logger->trace("node_view called from $caller");

        my $query = db_query_execute(NODE, $node_statements, 'node_view_sql', $mac) || return (0);
        my $node_info_ref = $query->fetchrow_hashref();
        $query->finish();

        # if no node info returned we exit
        return if (!defined($node_info_ref));

        $query = db_query_execute(NODE, $node_statements, 'node_last_locationlog_sql', $mac) || return (0);
        my $locationlog_info_ref = $query->fetchrow_hashref();
        $query->finish();

        # merge hash references
        # set locationlog info to empty hashref in case result from query was nothing
        $locationlog_info_ref = {} if (!defined($locationlog_info_ref));
        $node_info_ref = {
            %$node_info_ref,
            %$locationlog_info_ref,
            'nbopenviolations' => violation_count($mac),
        };

        return ($node_info_ref);
    }


=item a node_view with a view

Using an SQL View to create something we can easily do a SELECT on and filter with a WHERE.

The view was created with:

    CREATE VIEW node_view
        AS
        SELECT node.mac, node.pid, node.voip, node.bypass_vlan, node.status,
            IF(ISNULL(node_category.name), '', node_category.name) as category,
            node.detect_date, node.regdate, node.unregdate, node.lastskip,
            node.user_agent, node.computername, node.dhcp_fingerprint,
            node.last_arp, node.last_dhcp,
            locationlog.switch as last_switch, locationlog.port as last_port, locationlog.vlan as last_vlan,
            IF(ISNULL(locationlog.connection_type), '', locationlog.connection_type) as last_connection_type,
            locationlog.dot1x_username as last_dot1x_username, locationlog.ssid as last_ssid,
            COUNT(DISTINCT violation.id) as nbopenviolations,
            node.notes        FROM node
            LEFT JOIN node_category USING (category_id)
            LEFT JOIN violation ON node.mac=violation.mac AND violation.status = 'open'
            LEFT JOIN locationlog ON node.mac=locationlog.mac AND end_time IS NULL
        GROUP BY node.mac

The view was queried with:

    $node_statements->{'node_view_sql_view'} = get_db_handle()->prepare(<<'    SQL');
        SELECT mac, pid, voip, bypass_vlan, status, category,
            detect_date, regdate, unregdate, lastskip, user_agent, computername, dhcp_fingerprint,
            last_arp, last_dhcp,
            last_switch, last_port, last_vlan, last_connection_type, last_dot1x_username, last_ssid,
            nbopenviolations,
            notes
        FROM node_view
        WHERE mac=?
    SQL 

The code:

    sub _node_view_using_view {
        my ($mac) = @_;

        # Uncomment to log callers
        #my $logger = Log::Log4perl::get_logger('pf::node');
        #my $caller = ( caller(1) )[3] || basename($0);
        #$logger->trace("node_view called from $caller");

        my $query = db_query_execute(NODE, $node_statements, 'node_view_sql_view', $mac) || return (0);
        my $ref = $query->fetchrow_hashref();

        # just get one row and finish
        $query->finish();
        return ($ref);
    }

=back

=head2 Result of benchmarks

Because of SQL processing occuring out of Perl's scope, it's important to look at the wallclock seconds diff and not
the actual table below which account for CPU seconds only.

    # benchmarks/pf-node.pl
    Benchmark: timing 1 iterations of attributes, view_big_query, view_queries_then_perl, view_with_view...
    attributes: 13 wallclock secs ( 7.51 usr +  0.47 sys =  7.98 CPU) @  0.13/s (n=1)
                (warning: too few iterations for a reliable count)
    view_big_query: 2145 wallclock secs (10.92 usr +  0.28 sys = 11.20 CPU) @  0.09/s (n=1)
                (warning: too few iterations for a reliable count)
    view_queries_then_perl: 16 wallclock secs ( 4.94 usr +  1.56 sys =  6.50 CPU) @  0.15/s (n=1)
                (warning: too few iterations for a reliable count)
    view_with_view: 4538 wallclock secs ( 4.29 usr +  0.30 sys =  4.59 CPU) @  0.22/s (n=1)
                (warning: too few iterations for a reliable count)
                           s/iter view_big_query attributes view_queries_then_perl view_with_view
    view_big_query           11.2             --       -29%                   -42%           -59%
    attributes               7.98            40%         --                   -19%           -42%
    view_queries_then_perl   6.50            72%        23%                     --           -29%
    view_with_view           4.59           144%        74%                    42%             --
    You have new mail in /var/spool/mail/root

=head2 Conclusion

With the above note in mind, the view and the big query are insanely slow 
compared to attributes or the complete view merged in perl (queries then perl).

Because we don't rely on transactional features and are updates are focused on per-table updates, we will go with
the view_queries_then_perl as our node_view replacement.

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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
