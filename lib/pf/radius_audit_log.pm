package pf::radius_audit_log;

=head1 NAME

pf::radius_audit_log - module for radius_audit_log management.

=cut

=head1 DESCRIPTION

pf::radius_audit_log contains the functions necessary to manage a radius_audit_log: creation,
deletion, read info, ...

=cut

use strict;
use warnings;
use constant RADIUS_AUDIT_LOG => 'radius_audit_log';

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    @EXPORT = qw(
        $radius_audit_log_db_prepared
        radius_audit_log_db_prepare
        radius_audit_log_delete
        radius_audit_log_add
        radius_audit_log_view
        radius_audit_log_count_all
        radius_audit_log_view_all
        radius_audit_log_cleanup
    );
}

use pf::log;
use pf::error qw(is_success is_error);
use pf::dal::radius_audit_log;
use pf::db;

our $logger = get_logger();

our @FIELDS = qw(
    mac
    ip
    computer_name
    user_name
    stripped_user_name
    realm
    event_type
    switch_id
    switch_mac
    switch_ip_address
    radius_source_ip_address
    called_station_id
    calling_station_id
    nas_port_type
    ssid
    nas_port_id
    ifindex
    nas_port
    connection_type
    nas_ip_address
    nas_identifier
    auth_status
    reason
    auth_type
    eap_type
    role
    node_status
    profile
    source
    auto_reg
    is_phone
    pf_domain
    uuid
    radius_request
    radius_reply
    request_time
);

our @NODE_FIELDS = qw(
    mac
    auth_status
    auth_type
    auto_reg
    calling_station_id
    computer_name
    eap_type
    event_type
    ip
    is_phone
    node_status
    pf_domain
    profile
    realm
    reason
    role
    source
    stripped_user_name
    user_name
    uuid
    created_at
);

our @RADIUS_FIELDS = qw(request_time radius_request radius_reply);

our %RADIUS_FIELDS = map { $_ => 1 } @RADIUS_FIELDS;

our @SWITCH_FIELDS = qw(
    switch_id
    switch_mac
    switch_ip_address

    called_station_id
    connection_type
    ifindex
    nas_identifier
    nas_ip_address
    nas_port
    nas_port_id
    nas_port_type
    radius_source_ip_address
    ssid
);

=head1 SUBROUTINES

=head2 $success = radius_audit_log_delete($id)

Delete a radius_audit_log entry

=cut

sub radius_audit_log_delete {
    my ($id) = @_;
    my $status = pf::dal::radius_audit_log->remove_by_id({id => $id});
    return (is_success($status));
}


=head2 $success = radius_audit_log_add(%args)

Add a radius_audit_log entry

=cut

sub radius_audit_log_add {
    my %data = @_;
    my $item = pf::dal::radius_audit_log->new(\%data);
    my $status = $item->insert;
    return (is_success($status));
}

=head2 $entry = radius_audit_log_view($id)

View a radius_audit_log entry by it's id

=cut

sub radius_audit_log_view {
    my ($id) = @_;
    my ($status, $item) = pf::dal::radius_audit_log->find({id=>$id});
    if (is_error($status)) {
        return (0);
    }
    return ($item->to_hash());
}

=head2 $count = radius_audit_log_count_all()

Count all the entries radius_audit_log

=cut

sub radius_audit_log_count_all {
    my ($status, $count) = pf::dal::radius_audit_log->count;
    return $count;
}

=head2 @entries = radius_audit_log_view_all($offset, $limit)

View all the radius_audit_log for an offset limit

=cut

sub radius_audit_log_view_all {
    my ($offset, $limit) = @_;
    $offset //= 0;
    $limit  //= 25;
    my ($status, $iter) = pf::dal::radius_audit_log->search(
        -offset => $offset,
        -limit => $limit,
    );
    return if is_error($status);
    my $items = $iter->all();
    return @$items;
}

=head2 radius_audit_log_cleanup($expire_seconds, $batch, $time_limit)

Cleans up the radius_audit_log_cleanup table

=cut

sub radius_audit_log_cleanup {
    my $timer = pf::StatsD::Timer->new( { sample_rate => 0.2 } );
    my ( $expire_seconds, $batch, $time_limit ) = @_;
    my $logger = get_logger();
    $logger->debug( sub { "calling radius_audit_log_cleanup with time=$expire_seconds batch=$batch timelimit=$time_limit"; });

    if ( $expire_seconds eq "0" ) {
        $logger->debug("Not deleting because the window is 0");
        return;
    }
    my $now        = pf::dal->now();
    my %search = (
        -where => {
            created_at => {
                "<" => \[ 'DATE_SUB(?, INTERVAL ? SECOND)', $now, $expire_seconds ]
            },
        },
        -limit => $batch,
        -no_auto_tenant_id => 1,
    );
    pf::dal::radius_audit_log->batch_remove(\%search, $time_limit);
    return;
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
