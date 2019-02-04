package pf::pfcmd::dashboard;

=head1 NAME

pf::pfcmd::dashboard - module feeding data to the dashboard nuggets

=cut


use strict;
use warnings;
use pf::log;

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA    = qw(Exporter);
    @EXPORT = qw(
        $dashboard_db_prepared
        dashboard_db_prepare

        nugget_recent_security_events
        nugget_recent_security_events_opened
        nugget_recent_security_events_closed
        nugget_recent_registrations
        nugget_current_grace
        nugget_current_activity
        nugget_current_node_status
    );
};

use pf::dal;
use pf::error qw(is_error);
use pf::pfcmd::report;

our $nugget_recent_security_events_sql =
        qq [ select v.mac,v.start_date,c.description as security_event from security_event v left join class c on v.security_event_id=c.security_event_id where unix_timestamp(start_date) > unix_timestamp(now()) - ? * 3600 order by start_date desc limit 10 ];

our $nugget_recent_security_events_opened_sql =
        qq [ select v.mac,v.start_date,c.description as security_event from security_event v left join class c on v.security_event_id=c.security_event_id where unix_timestamp(start_date) > unix_timestamp(now()) - ? * 3600 and v.status="open" order by start_date desc limit 10 ];

our $nugget_recent_security_events_closed_sql =
        qq [ select v.mac,v.start_date,c.description as security_event from security_event v left join class c on v.security_event_id=c.security_event_id where unix_timestamp(start_date) > unix_timestamp(now()) - ? * 3600 and v.status="closed" order by start_date desc limit 10 ];

our $nugget_recent_registrations_sql =
        qq [ select n.pid,n.mac,n.regdate from node n where n.status="reg" and unix_timestamp(regdate) > unix_timestamp(now()) - ? * 3600 order by regdate desc limit 10 ];

our $nugget_current_grace_sql =
        qq [ select n.pid,n.lastskip from node n where status="grace" order by n.lastskip desc limit 10 ];


sub nugget_recent_security_events {
    my ($interval) = @_;
    return _db_data($nugget_recent_security_events_sql, $interval);
}

sub _db_data {
   my ($sql, @bind) = @_;
   my ($status, $sth) = pf::dal->db_execute($sql, @bind);
    if (is_error($status)) {
        return;
    }
    return @{$sth->fetchall_arrayref() // []};
}

sub nugget_recent_security_events_opened {
    my ($interval) = @_;
    return _db_data($nugget_recent_security_events_opened_sql, $interval);
}

sub nugget_recent_security_events_closed {
    my ($interval) = @_;
    return _db_data($nugget_recent_security_events_closed_sql, $interval);
}

sub nugget_recent_registrations {
    my ($interval) = @_;
    return _db_data($nugget_recent_registrations_sql, $interval);
}

sub nugget_current_grace {
    return _db_data($nugget_current_grace_sql);
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
