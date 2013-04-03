package pf::switchlocation;

=head1 NAME

pf::switchlocation - module for the switch location history.

=cut

=head1 DESCRIPTION

pf::switchlocation contains the functions necessary to manage the 
switch location history.

=cut

use strict;
use warnings;
use Log::Log4perl;

use constant SWITCHLOCATION => 'switchlocation';

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA    = qw(Exporter);
    @EXPORT = qw(
        $switchlocation_db_prepared
        switchlocation_db_prepare

        switchlocation_view_all
        switchlocation_view_open
        switchlocation_view_switchport
        switchlocation_view_open_switchport

        switchlocation_insert_start
        switchlocation_update_end
    );
}

use pf::db;

# The next two variables and the _prepare sub are required for database handling magic (see pf::db)
our $switchlocation_db_prepared = 0;
# in this hash reference we hold the database statements. We pass it to the query handler and he will repopulate
# the hash if required
our $switchlocation_statements = {};

sub switchlocation_db_prepare {
    my $logger = Log::Log4perl::get_logger('pf::switchlocation');
    $logger->debug("Preparing pf::switchlocation database queries");

    $switchlocation_statements->{'switchlocation_view_all_sql'} = get_db_handle()->prepare(
        qq [ select switch,port,start_time,end_time,location,description from switchlocation order by start_time desc, end_time desc]);

    $switchlocation_statements->{'switchlocation_view_switchport_sql'} = get_db_handle()->prepare(
        qq [ select switch,port,start_time,end_time,location,description from switchlocation where switch=? and port=? order by start_time desc, end_time desc ]);

    $switchlocation_statements->{'switchlocation_view_open_sql'} = get_db_handle()->prepare(
        qq [ select switch,port,start_time,end_time,location,description from switchlocation where isnull(end_time) or end_time=0 order by start_time desc ]);

    $switchlocation_statements->{'switchlocation_view_open_switchport_sql'} = get_db_handle()->prepare(
        qq [ select switch,port,start_time,end_time,location,description from switchlocation where switch=? and port=? and (isnull(end_time) or end_time=0) order by start_time desc ]);

    $switchlocation_statements->{'switchlocation_insert_start_sql'} = get_db_handle()->prepare(
        qq [ INSERT INTO switchlocation (switch, port, start_time,location,description) VALUES(?,?,NOW(),?,?)]);

    $switchlocation_statements->{'switchlocation_update_end_sql'} = get_db_handle()->prepare(
        qq [ UPDATE switchlocation SET end_time = now() WHERE switch = ? AND port = ? AND (ISNULL(end_time) or end_time = 0) ]);

    $switchlocation_db_prepared = 1;
}

sub switchlocation_view_all {
    return db_data(SWITCHLOCATION, $switchlocation_statements, 'switchlocation_view_all_sql');
}

sub switchlocation_view_open {
    return db_data(SWITCHLOCATION, $switchlocation_statements, 'switchlocation_view_open_sql');
}

sub switchlocation_view_switchport {
    my ( $switch, %params ) = @_;
    return db_data(SWITCHLOCATION, $switchlocation_statements, 'switchlocation_view_switchport_sql',
        $switch, $params{'ifIndex'});
}

sub switchlocation_view_open_switchport {
    my ( $switch, $ifIndex ) = @_;
    return db_data(SWITCHLOCATION, $switchlocation_statements, 'switchlocation_view_open_switchport_sql', 
        $switch, $ifIndex);
}

sub switchlocation_insert_start {
    my ( $switch, $ifIndex, $location, $description ) = @_;
    db_query_execute(SWITCHLOCATION, $switchlocation_statements, 'switchlocation_insert_start_sql', 
        $switch, $ifIndex, $location, $description)
        || return (0);
    return (1);
}

sub switchlocation_update_end {
    my ( $switch, $ifIndex ) = @_;
    db_query_execute(SWITCHLOCATION, $switchlocation_statements, 'switchlocation_update_end_sql', $switch, $ifIndex)
        || return (0);
    return (1);
}

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

1;
