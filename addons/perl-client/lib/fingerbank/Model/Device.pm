package fingerbank::Model::Device;

=head1 NAME

fingerbank::Model::Device

=head1 DESCRIPTION

Handling 'Device' related stuff

=cut

use Moose;
use namespace::autoclean;

use fingerbank::Constant qw($TRUE $FALSE);
use fingerbank::Log;
use fingerbank::Util qw(is_error is_success);
use fingerbank::Constant;
use fingerbank::API;
use JSON::MaybeXS;
use List::MoreUtils qw(uniq);

extends 'fingerbank::Base::CRUD';

sub value_field { 'name' }

sub base_ids { map { $fingerbank::Constant::PARENT_IDS{$_} } keys %fingerbank::Constant::PARENT_IDS }

=head2 read

Override from L<fingerbank::Base::CRUD::read> because we want the device to be able to build his own parent on read time.

Defined '$with_parents' parameter will build parent, undef will simply return the device without parents.

=cut
sub read {
    my ( $self, $id, $with_parents ) = @_;
    my $logger = fingerbank::Log::get_logger;

    my ($status, $return) = $self->SUPER::read($id);

    # There was an 'error' during the read
    return ($status, $return) if ( is_error($status) );

    # If parents are requested, we build them
    if ( (defined($with_parents) && $with_parents) && defined($return->parent_id) ) {
        $logger->debug("Device ID '$id' have at least 1 parent. Building parent(s) list");

        my $parent_id = $return->parent_id;
        my $parent_exists = 1;  # We need to run at least once since we know parent(s) exists
        my @parents;            # Will keep the parent(s) attributes
        my @parents_ids;        # Will keep the ID(s) of parent(s) for easy access
        my $iteration = 0;      # Need to keep track of parent(s) in the parent(s) attributes array

        while ( $parent_exists ) {
            $logger->debug("Found parent ID '$parent_id' for device ID '$id'");
            push(@parents_ids, $parent_id);
            my $parent = $self->read($parent_id);
            foreach ( keys %$parent ) {
                $parents[$iteration] = $parent;
            }
            $iteration ++;
            $parent_id = $parent->parent_id if ( defined($parent->parent_id) );
            $parent_exists = 0 if ( !defined($parent->parent_id) );
        }

        $return->{parents} = \@parents;
        $return->{parents_ids} = \@parents_ids;
    }

    return ( $fingerbank::Status::OK, $return );
}

=head2 is_a

=cut

sub is_a {
    my ( $self, $arg, $condition ) = @_;
    my $logger = fingerbank::Log::get_logger;

    return $FALSE unless(defined($arg));

    my $status;

    if ( $arg !~ /^\d+$/ ) {
        $logger->debug("Finding device ID for $arg");
        my $query = {};
        $query->{'name'} = $arg;

        ( $status, my $query_result ) = $self->find([$query, { columns => ['id'] }]);
        if (is_error($status)) {
            $logger->error("Unable to find device ID for device name $arg");
            return $FALSE;
        }
    
        $arg = $query_result->id;
    }

    if ( $condition !~ /^\d+$/ ) {
        $logger->debug("Finding device ID for $condition");
        my $query = {};
        $query->{'name'} = $condition;

        ( $status, my $query_result ) = $self->find([$query, { columns => ['id'] }]);
        if (is_error($status)) {
            $logger->error("Unable to find device ID for device name $condition");
            return $FALSE;
        }
    
        $condition = $query_result->id;
    }


    my $api = fingerbank::API->new_from_config;
    my $result = $api->cache->compute("fingerbank::Model::Device::is_a($arg,$condition)", sub {
        my $req = $api->build_request("GET", "/api/v2/devices/$arg/is_a/$condition");

        my $res = $api->get_lwp_client->request($req);
        if ($res->is_success) {
            my $result = decode_json($res->decoded_content);
            $logger->debug("Device $arg is a $condition. ".$result->{message});
            return $result->{result};
        }
        else {
            $logger->error("Error while communicating with the Fingerbank API to check if device $arg is linked to device $condition. ".$res->status_line);
            return undef;
        }
    });

    return $result;
}

=head2 all_device_class_ids

Method to obtain all the device class IDs (top level from the DB and constant device classes)

=cut

sub all_device_class_ids {
    my ($class) = @_;
    my @db_classes = map{ $_->id } fingerbank::Model::Device->search([{parent_id => undef, approved => 1}, {columns => ["id"]}])->[0]->all;
    my @constant_classes = values(%fingerbank::Constant::DEVICE_CLASS_IDS);

    my @all_ids = uniq(@db_classes, @constant_classes);

    return [sort { $a <=> $b } @all_ids];
}

=head2 all_device_classes

Method to obtain all the device classes (top level from the DB and constant device classes)

=cut

sub all_device_classes {
    my ($class) = @_;
    my $logger = fingerbank::Log::get_logger;

    my @all_ids = @{fingerbank::Model::Device->all_device_class_ids};

    my @all_devices;
    for my $id (@all_ids) {
        my ($status, $device) = fingerbank::Model::Device->read($id);
        if(is_error($status)) {
            $logger->error("Unable to obtain information for device ID '$id'. Omitting it from the result.");
        }
        else {
            push @all_devices, $device;
        }
    }
    return \@all_devices;
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

__PACKAGE__->meta->make_immutable;

1;
