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
 
BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    @EXPORT = qw(
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
use pf::dal::dhcp_option82;
use pf::error qw(is_error is_success);

our $logger = get_logger();

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

=head1 SUBROUTINES

=head2 dhcp_option82_db_prepare()

Prepare the sql statements for dhcp_option82 table

=cut

=head2 $success = dhcp_option82_delete($id)

Delete a dhcp_option82 entry

=cut

sub dhcp_option82_delete {
    my ($id) = @_;
    my $status = pf::dal::dhcp_option82->remove_by_id({mac => $id});
    return (is_success($status));
}


=head2 $success = dhcp_option82_add(%args)

Add a dhcp_option82 entry

=cut

sub dhcp_option82_add {
    my %data = @_;
    my $status = pf::dal::dhcp_option82->create(\%data);
    return (is_success($status));
}

=head2 $success = dhcp_option82_insert_or_update(%args)

Add a dhcp_option82 entry

=cut

sub dhcp_option82_insert_or_update {
    my %data = @_;
    my $item = pf::dal::dhcp_option82->new(\%data);
    my $status = $item->save();
    return (is_success($status));
}

=head2 $entry = dhcp_option82_view($id)

View a dhcp_option82 entry by it's id

=cut

sub dhcp_option82_view {
    my ($id) = @_;
    my ($status, $item) = pf::dal::dhcp_option82->find({mac => $id});
    if (is_error($status)) {
        return (0);
    }
    return ($item->to_hash());
}

=head2 $count = dhcp_option82_count_all()

Count all the entries dhcp_option82

=cut

sub dhcp_option82_count_all {
    my ($status, $count) = pf::dal::dhcp_option82->count;
    return $count;
}

=head2 @entries = dhcp_option82_view_all($offset, $limit)

View all the dhcp_option82 for an offset limit

=cut

sub dhcp_option82_view_all {
    my ($offset, $limit) = @_;
    $offset //= 0;
    $limit  //= 25;
    my ($status, $iter) = pf::dal::dhcp_option82->search(
        -offset => $offset,
        -limit => $limit,
    );
    return if is_error($status);
    my $items = $iter->all();
    return @$items;
}

sub dhcp_option82_cleanup {
    my $timer = pf::StatsD::Timer->new({sample_rate => 0.2});
    my ($expire_seconds, $batch, $time_limit) = @_;
    my $logger = get_logger();
    $logger->debug(sub { "calling dhcp_option82_cleanup with time=$expire_seconds batch=$batch timelimit=$time_limit" });
    if ($expire_seconds eq "0") {
        $logger->debug("Not deleting because the window is 0");
        return;
    }
    my $now = pf::dal->now();
    my ($status, $rows_deleted) = pf::dal::dhcp_option82->batch_remove(
        {
            -where => {
                created_at => {
                    "<" => \[ 'DATE_SUB(?, INTERVAL ? SECOND)', $now, $expire_seconds ]
                },
            },
            -limit => $batch,
        },
        $time_limit
    );
    return ($rows_deleted);
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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
