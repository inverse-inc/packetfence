package pf::dal::node;

=head1 NAME

pf::dal::node - pf::dal module to override for the table node

=cut

=head1 DESCRIPTION

pf::dal::node

pf::dal implementation for the table node

=cut

use strict;
use warnings;

use pf::error qw(is_error is_success);
use pf::api::queue;
use pf::log;
use pf::constants::node qw($NODE_DISCOVERED_TRIGGER_DELAY);
use pf::constants qw($ZERO_DATE);
use base qw(pf::dal::_node);

our @LOCATION_LOG_GETTERS = qw(
  last_switch
  last_port
  last_ifDesc
  last_vlan
  last_connection_type
  last_connection_sub_type
  last_dot1x_username
  last_ssid
  stripped_user_name
  realm
  last_switch_mac
  last_start_time
  last_role
  last_start_timestamp
);

use Class::XSAccessor {
    accessors => [qw(category bypass_role)],
# The getters for current location log entries
    getters   => \@LOCATION_LOG_GETTERS,
};

our @COLUMN_NAMES = (
    (map {"node.$_|$_"} @pf::dal::_node::FIELD_NAMES),
    'nc.name|category',
    'nr.name|bypass_role',
);

=head2 find_from_tables

Join the node_category table information in the node results

=cut

sub find_from_tables {
    [-join => qw(node =>{node.category_id=nc.category_id} node_category|nc =>{node.bypass_role_id=nr.category_id} node_category|nr)],
}

=head2 find_columns

Override the standard field names for node

=cut

sub find_columns {
    [@COLUMN_NAMES]
}
 
=head2 pre_save

pre_save

=cut

sub pre_save {
    my ($self) = @_;
    my $voip = $self->voip;
    $self->{voip} = 'no' if !defined ($voip) || $voip ne 'yes';
    return $self->_update_category_ids;
}

=head2 after_create_hook

=cut

sub after_create_hook {
    my ($self) = @_;
    my $apiclient = pf::api::queue->new(queue => 'general');
    eval {
        $apiclient->notify_delayed($NODE_DISCOVERED_TRIGGER_DELAY, "trigger_security_event", mac => $self->{mac}, type => "internal", tid => "node_discovered");
    };
    if ($@) {
        $self->logger->error("Error submitting to the queue: $@");
    }
    return ;
}

=head2 _update_category_ids

_update_category_ids

=cut

sub _update_category_ids {
    my ($self) = @_;
    my $old_data = $self->__old_data // {};
    my $category = $self->category;
    my $old_category = $old_data->{category};
    my $bypass_role = $self->bypass_role;
    my $old_bypass_role = $old_data->{bypass_role};
    my @names;
    if (defined $category && (!defined $old_category || $old_category ne $category)) {
        push @names, $category if defined $category ;
    } else {
        $category = undef;
    }
    if (defined $bypass_role && (!defined $old_bypass_role || $old_bypass_role ne $bypass_role)) {
        push @names, $bypass_role if defined $bypass_role;
    } else {
        $bypass_role = undef;
    }
    return $STATUS::OK unless @names;
    my ($status, $sth) = $self->do_select(
        -columns => [qw(category_id name)],
        -from => 'node_category',
        -where   => {name => { -in => \@names}},
        -no_auto_tenant_id => 1,
    );
    return $status if is_error($status);
    my $lookup = $sth->fetchall_hashref('name');
    if (defined $bypass_role) {
        $self->{bypass_role_id} = $lookup->{$bypass_role}{category_id};
    }

    if (defined $category) {
        $self->{category_id} = $lookup->{$category}{category_id};
    }
    return $STATUS::OK;
}

=head2 _insert_data

_insert_data

=cut

sub _insert_data {
    my ($self) = @_;
    my ($status, $data) = $self->SUPER::_insert_data;
    if (is_error($status)) {
        return $status, $data;
    }
    if ($data->{detect_date} eq '0000-00-00 00:00:00') {
       $data->{detect_date} = $self->now;
    }
    return $status, $data;
}

=head2 update_last_seen

update_last_seen

=cut

sub update_last_seen {
    my ($self) = @_;
    $self->last_seen(\['NOW()']);
    return ;
}

=head2 _load_locationlog

load the locationlog entries into the node object

=cut

sub _load_locationlog {
    my ($self) = @_;
    my ($status, $sth) = $self->do_select(
        -columns => [
            "locationlog.switch|last_switch",
            "locationlog.port|last_port",
            "locationlog.ifDesc|last_ifDesc",
            "locationlog.vlan|last_vlan",
            "IF(ISNULL(`locationlog`.`connection_type`), '', `locationlog`.`connection_type`)|last_connection_type",
            "IF(ISNULL(`locationlog`.`connection_sub_type`), '', `locationlog`.`connection_sub_type`)|last_connection_sub_type",
            "locationlog.dot1x_username|last_dot1x_username",
            "locationlog.ssid|last_ssid",
            "locationlog.stripped_user_name|stripped_user_name",
            "locationlog.realm|realm",
            "locationlog.switch_mac|last_switch_mac",
            "locationlog.start_time|last_start_time",
            "locationlog.role|last_role",
            "UNIX_TIMESTAMP(`locationlog`.`start_time`)|last_start_timestamp",
          ],
        -from => 'locationlog',
        -where => { mac => $self->mac, tenant_id => $self->tenant_id, end_time => $ZERO_DATE},
        -no_auto_tenant_id => 1,
    );
    return $status, undef if is_error($status);
    my $row = $sth->fetchrow_hashref;
    $sth->finish;
    unless ($row) {
        return $STATUS::NOT_FOUND;
    }
    @{$self}{@LOCATION_LOG_GETTERS} = @{$row}{@LOCATION_LOG_GETTERS};

    return $STATUS::OK;
}

=head2 merge

merge fields into object

=cut

sub merge {
    my ($self, $vals) = @_;
    return unless defined $vals && ref($vals) eq 'HASH';
    while (my ($k, $v) = each %$vals) {
        next if $k =~ /^__/;
        $self->{$k} = $v;
    }
    return ;
}

=head2 to_hash_fields

to_hash_fields

=cut

sub to_hash_fields {
    return [@pf::dal::_node::FIELD_NAMES, qw(category bypass_role), @LOCATION_LOG_GETTERS];
}

=head2 _insert_data

Create the hash for inserting into a table
Overriding so that we can clean the MAC

=cut

sub _insert_data {
    my ($self) = @_;
    $self->{mac} = clean_mac($self->{mac});
    return $self->SUPER::_insert_data();
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
