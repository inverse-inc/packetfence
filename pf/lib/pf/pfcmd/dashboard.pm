package pf::pfcmd::dashboard;

use strict;
use warnings;
use Log::Log4perl;

use pf::db;
use pf::pfcmd::report;

our (
    $is_dashboard_db_prepared,

    $nugget_recent_violations_sql,
    $nugget_recent_violations_opened_sql,
    $nugget_current_grace_sql,
    $nugget_recent_violations_closed_sql,
    $nugget_recent_registrations_sql
);

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA    = qw(Exporter);
    @EXPORT = qw(
        $is_dashboard_db_prepared

        dashboard_db_prepare
        nugget_recent_violations
        nugget_recent_violations_opened
        nugget_recent_violations_closed
        nugget_recent_registrations
        nugget_current_grace
        nugget_current_activity
        nugget_current_node_status
    );
};

$is_dashboard_db_prepared = 0;

#dashboard_db_prepare($dbh);

sub dashboard_db_prepare {
    my ($dbh) = @_;
    db_connect($dbh);
    my $logger = Log::Log4perl::get_logger('pf::pfcmd::dashboard');
    $logger->debug("Preparing pf::pfcmd::dashboard database queries");
    $nugget_recent_violations_sql
        = $dbh->prepare(
        qq [ select v.mac,v.start_date,c.description as violation from violation v left join class c on v.vid=c.vid where unix_timestamp(start_date) > unix_timestamp(now()) - ? * 3600 order by start_date desc limit 10 ]
        );
    $nugget_recent_violations_opened_sql
        = $dbh->prepare(
        qq [ select v.mac,v.start_date,c.description as violation from violation v left join class c on v.vid=c.vid where unix_timestamp(start_date) > unix_timestamp(now()) - ? * 3600 and v.status="open" order by start_date desc limit 10 ]
        );
    $nugget_recent_violations_closed_sql
        = $dbh->prepare(
        qq [ select v.mac,v.start_date,c.description as violation from violation v left join class c on v.vid=c.vid where unix_timestamp(start_date) > unix_timestamp(now()) - ? * 3600 and v.status="closed" order by start_date desc limit 10 ]
        );

#$nugget_recent_registrations_sql = $dbh->prepare( qq [ select n.pid,n.mac,n.regdate from node n where n.status="unreg" limit 10 ]);
    $nugget_recent_registrations_sql
        = $dbh->prepare(
        qq [ select n.pid,n.mac,n.regdate from node n where n.status="reg" and unix_timestamp(regdate) > unix_timestamp(now()) - ? * 3600 order by regdate desc limit 10 ]
        );
    $nugget_current_grace_sql
        = $dbh->prepare(
        qq [ select n.pid,n.lastskip from node n where status="grace" order by n.lastskip desc limit 10 ]
        );
    $is_dashboard_db_prepared = 1;
    return 1;
}

sub nugget_recent_violations {
    my ($interval) = @_;
    dashboard_db_prepare($dbh) if ( !$is_dashboard_db_prepared );
    return db_data( $nugget_recent_violations_sql, $interval );
}

sub nugget_recent_violations_opened {
    my ($interval) = @_;
    dashboard_db_prepare($dbh) if ( !$is_dashboard_db_prepared );
    return db_data( $nugget_recent_violations_opened_sql, $interval );
}

sub nugget_recent_violations_closed {
    my ($interval) = @_;
    dashboard_db_prepare($dbh) if ( !$is_dashboard_db_prepared );
    return db_data( $nugget_recent_violations_closed_sql, $interval );
}

sub nugget_recent_registrations {
    my ($interval) = @_;
    dashboard_db_prepare($dbh) if ( !$is_dashboard_db_prepared );
    return db_data( $nugget_recent_registrations_sql, $interval );
}

sub nugget_current_grace {
    dashboard_db_prepare($dbh) if ( !$is_dashboard_db_prepared );
    return db_data($nugget_current_grace_sql);
}

sub nugget_current_activity {
    my @return;
    push(
        @return,
        {   "type"  => "Active Nodes",
            "total" => scalar( report_active_all() )
        }
    );
    push(
        @return,
        {   "type"  => "Inactive Nodes",
            "total" => scalar( report_inactive_all() )
        }
    );
    return (@return);
}

sub nugget_current_node_status {
    my @return;
    push(
        @return,
        {   "type"  => "Active Unregistered Nodes",
            "total" => scalar( report_unregistered_active() )
        }
    );
    push(
        @return,
        {   "type"  => "Active Registered Nodes",
            "total" => scalar( report_registered_active() )
        }
    );
    return (@return);
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
