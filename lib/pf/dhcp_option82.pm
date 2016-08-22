package pf::dhcp_option82;

=head1 NAME

pf::dhcp_option82 -

=cut

=head1 DESCRIPTION

pf::dhcp_option82

CRUD operations for dhcp_option82 table

=cut

use strict;
use warnings;
use constant DHCP_OPTION82 => 'dhcp_option82';
 
BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    @EXPORT = qw(
        $dhcp_option82_db_prepared
        dhcp_option82_db_prepare
        dhcp_option82_delete
        dhcp_option82_add
        dhcp_option82_insert_or_update
        dhcp_option82_view
        dhcp_option82_count_all
        dhcp_option82_view_all
        dhcp_option82_custom
        dhcp_option82_cleanup
    );
}

use pf::log;
use pf::db;

our $logger = get_logger();

# The next two variables and the _prepare sub are required for database handling magic (see pf::db)
our $dhcp_option82_db_prepared = 0;
# in this hash reference we hold the database statements. We pass it to the query handler and he will repopulate
# the hash if required
our $dhcp_option82_statements = {};

our @FIELDS = qw(
  mac
  created_at
  option82_switch
  switch_id
  port
  vlan
  circuit_id_string
  module
  host
);

our @ON_DUPLICATE_FIELDS = qw(
  mac
  created_at
  option82_switch
  switch_id
  port
  vlan
  circuit_id_string
  module
  host
);

our %HEADINGS = (
    mac               => 'mac',
    option82_switch   => 'option82_switch',
    switch_id         => 'switch_id',
    port              => 'port',
    vlan              => 'DHCP Option 82 Vlan',
    circuit_id_string => 'Circuit ID String',
    module            => 'module',
    host              => 'host',
    created_at        => 'created_at',
);

our $FIELD_LIST = join(", ",@FIELDS);

our $INSERT_LIST = join(", ", ("?") x @FIELDS);

our $ON_DUPLICATE_LIST = join(", ", map { "$_ = VALUES($_)"} @ON_DUPLICATE_FIELDS);

=head1 SUBROUTINES

=head2 dhcp_option82_db_prepare()

Prepare the sql statements for dhcp_option82 table

=cut

sub dhcp_option82_db_prepare {
    $logger->debug("Preparing pf::dhcp_option82 database queries");
    my $dbh = get_db_handle();

    $dhcp_option82_statements->{'dhcp_option82_add_sql'} = $dbh->prepare(
        qq[ INSERT INTO dhcp_option82 ( $FIELD_LIST ) VALUES ( $INSERT_LIST ) ]);

    $dhcp_option82_statements->{'dhcp_option82_insert_or_update_sql'} = $dbh->prepare(qq[
        INSERT INTO dhcp_option82 ( $FIELD_LIST ) VALUES ( $INSERT_LIST )
        ON DUPLICATE KEY UPDATE $ON_DUPLICATE_LIST;
    ]);

    $dhcp_option82_statements->{'dhcp_option82_view_sql'} = $dbh->prepare(
        qq[ SELECT created_at, $FIELD_LIST FROM dhcp_option82 WHERE mac = ? ]);

    $dhcp_option82_statements->{'dhcp_option82_view_all_sql'} = $dbh->prepare(
        qq[ SELECT created_at, $FIELD_LIST FROM dhcp_option82 ORDER BY created_at LIMIT ?, ? ]);

    $dhcp_option82_statements->{'dhcp_option82_count_all_sql'} = $dbh->prepare( qq[ SELECT count(*) as count FROM dhcp_option82 ]);

    $dhcp_option82_statements->{'dhcp_option82_delete_sql'} = $dbh->prepare(qq[ delete from dhcp_option82 where mac = ? ]);

    $dhcp_option82_statements->{'dhcp_option82_cleanup_sql'} = $dbh->prepare(
        qq [ delete from dhcp_option82 where created_at < DATE_SUB(?, INTERVAL ? SECOND) LIMIT ?]);

    $dhcp_option82_statements->{'dhcp_option82_history_cleanup_sql'} = $dbh->prepare(
        qq [ delete from dhcp_option82_history where created_at < DATE_SUB(?, INTERVAL ? SECOND) LIMIT ?]);

    $dhcp_option82_db_prepared = 1;
}

=head2 $success = dhcp_option82_delete($id)

Delete a dhcp_option82 entry

=cut

sub dhcp_option82_delete {
    my ($id) = @_;
    db_query_execute(DHCP_OPTION82, $dhcp_option82_statements, 'dhcp_option82_delete_sql', $id) || return (0);
    $logger->info("dhcp_option82 $id deleted");
    return (1);
}


=head2 $success = dhcp_option82_add(%args)

Add a dhcp_option82 entry

=cut

sub dhcp_option82_add {
    my %data = @_;
    db_query_execute(DHCP_OPTION82, $dhcp_option82_statements, 'dhcp_option82_add_sql', @data{@FIELDS}) || return (0);
    return (1);
}

=head2 $success = dhcp_option82_insert_or_update(%args)

Add a dhcp_option82 entry

=cut

sub dhcp_option82_insert_or_update {
    my %data = @_;
    db_query_execute(DHCP_OPTION82, $dhcp_option82_statements, 'dhcp_option82_insert_or_update_sql', @data{@FIELDS}) || return (0);
    return (1);
}

=head2 $entry = dhcp_option82_view($id)

View a dhcp_option82 entry by it's id

=cut

sub dhcp_option82_view {
    my ($id) = @_;
    my $query  = db_query_execute(DHCP_OPTION82, $dhcp_option82_statements, 'dhcp_option82_view_sql', $id)
        || return (0);
    my $ref = $query->fetchrow_hashref();
    # just get one row and finish
    $query->finish();
    return ($ref);
}

=head2 $count = dhcp_option82_count_all()

Count all the entries dhcp_option82

=cut

sub dhcp_option82_count_all {
    my $query = db_query_execute(DHCP_OPTION82, $dhcp_option82_statements, 'dhcp_option82_count_all_sql');
    my @row = $query->fetchrow_array;
    $query->finish;
    return $row[0];
}

=head2 @entries = dhcp_option82_view_all($offset, $limit)

View all the dhcp_option82 for an offset limit

=cut

sub dhcp_option82_view_all {
    my ($offset, $limit) = @_;
    $offset //= 0;
    $limit  //= 25;

    return db_data(DHCP_OPTION82, $dhcp_option82_statements, 'dhcp_option82_view_all_sql', $offset, $limit);
}

sub dhcp_option82_cleanup {
    my $timer = pf::StatsD::Timer->new({sample_rate => 0.2});
    my ($expire_seconds, $batch, $time_limit) = @_;
    my $logger = get_logger();
    $logger->debug(sub { "calling dhcp_option82_cleanup with time=$expire_seconds batch=$batch timelimit=$time_limit" });
    my $now = db_now();
    my $start_time = time;
    my $end_time;
    my $rows_deleted = 0;
    while (1) {
        my $query = db_query_execute(DHCP_OPTION82, $dhcp_option82_statements, 'dhcp_option82_cleanup_sql', $now, $expire_seconds, $batch)
        || return (0);
        my $rows = $query->rows;
        $query->finish;
        $end_time = time;
        $rows_deleted+=$rows if $rows > 0;
        $logger->trace( sub { "deleted $rows_deleted entries from dhcp_option82 during dhcp_option82 cleanup ($start_time $end_time) " });
        last if $rows == 0 || (( $end_time - $start_time) > $time_limit );
    }
    $logger->trace( "deleted $rows_deleted entries from dhcp_option82 during dhcp_option82 cleanup ($start_time $end_time) " );
    return (0);
}

=head2 @entries = dhcp_option82_custom($sql, @args)

Custom sql query for radius audit log

=cut

sub dhcp_option82_custom {
    my ($sql, @args) = @_;
    $dhcp_option82_statements->{'dhcp_option82_custom_sql'} = $sql;
    return db_data(DHCP_OPTION82, $dhcp_option82_statements, 'dhcp_option82_custom_sql', @args);
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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
