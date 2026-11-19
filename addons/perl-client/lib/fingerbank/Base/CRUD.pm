package fingerbank::Base::CRUD;

=head1 NAME

fingerbank::Base::CRUD

=head1 DESCRIPTION

Read-only methods to query the Fingerbank data of the Upstream database.

Stuff in this class is meant to be overridden on a class basis if there's need for it.

=cut

use strict;
use warnings;

use Moose;
use namespace::autoclean;

use fingerbank::DB_Factory;
use fingerbank::Util qw(is_error is_success);
use fingerbank::Log;
use fingerbank::Constant qw($UPSTREAM_SCHEMA);

=head1 HELPERS

=head2 _parseClassName

Parse the class name based on the caller package name

=cut

sub _parseClassName {
    my ( $self ) = @_;

    my $className = $self;
    $className =~ s#^.*:##;

    return $className;
}

=head2 value_field

Defines what should be used as the value field in the object

=cut

sub value_field { 'value' }

=head2 base_ids

Defines which IDs are generic enough to be displayed as base choices (used to display device choice)

=cut

sub base_ids { }

=head2 all

Get all the objects

=cut

sub all {
    my ( $self, $schema ) = @_;
    my $className = $self->_parseClassName;
    
    my @schemas = fingerbank::DB->get_schemas($schema);
    my @all_devices;
    foreach my $schema ( @schemas ) {
        my $db = fingerbank::DB_Factory->instantiate(schema => $schema);
        my @devices = $db->handle->resultset($className)->all;
        push @all_devices, @devices;
    }

    return @all_devices;
}

=head1 METHODS

=head2 read

Read a single entry by using his ID.

Expects the entry ID to be readed.

HTTP 200 OK status code is returned along with the requested entry in case of success.

HTTP 404 NOT FOUND status code is returned along with a status message in case of failure (non-existant entry).

=cut

sub read {
    my ( $self, $id ) = @_;
    my $logger = fingerbank::Log::get_logger;

    my $className = $self->_parseClassName;

    my $schema = $UPSTREAM_SCHEMA;

    $logger->debug("Looking for '$className' entry with ID '$id' in schema '$schema'");

    my $db = fingerbank::DB_Factory->instantiate(schema => $schema);
    if ( $db->isError ) {
        my $status_msg = "Cannot read from '$className' table in schema '$schema'";
        $logger->warn($status_msg . ". DB layer returned '" . $db->statusCode . " - " . $db->statusMsg . "'");
        return ( $fingerbank::Status::INTERNAL_SERVER_ERROR, $status_msg );
    }

    my $resultset = $db->handle->resultset($className)->find($id);

    # Query doesn't return any result
    if ( !defined($resultset) ) {
        my $status_msg = "Could not find any '$className' entry with ID '$id' in schema '$schema'";
        $logger->info($status_msg);
        return ( $fingerbank::Status::NOT_FOUND, $status_msg );
    }

    $logger->debug("Found '$className' entry with ID '$id' in schema '$schema'");

    return ( $fingerbank::Status::OK, $resultset );
}

=head2 read_hashref

Performs the same as read but instead of returning the result set, it returns a hashref of the record.

=cut

sub read_hashref {
    my ( $self, $id, @args ) = @_;
    
    # The extra arguments are given to read (ex: the parents of a device)
    my ($status, $resultset) = $self->read($id, @args);

    if(is_error($status)) {
        return ($status, $resultset);
    }

    my $return = _columns_hashref($resultset);
    if ( ref($resultset->{parents}) eq 'ARRAY' ) {
        $return->{parents} = [ map { _columns_hashref($_) } @{$resultset->{parents}} ];
    }
    return ($status, $return);
}

=head2 _columns_hashref

The columns of a database row as a hashref

=cut

sub _columns_hashref {
    my ( $row ) = @_;
    my $return = {};
    foreach my $column ( $row->result_source->columns ) {
        if($row->can($column)) {
            $return->{$column} = $row->$column;
        }
    }
    return $return;
}

=head2 search

Advanced search

=head3 Usage

First arguement is an array ref of the arguments expected by the L<DBIx::Class::ResultSet> search function

Followed by the schema you wish to search

    my ($status, $resultSets_or_errormsg) = $obj->search($arr_ref_of_search_option);

    my ($status, $resultSets_or_errormsg) = $obj->search($arr_ref_of_search_option, $optional_schema);

    my ($status, $resultSets_or_errormsg) = $obj->search([{ col1 => val1}], 'Upstream');

=head3 Return

Returns a fingerbank::Status code and an array ref of the result set or status message

If the status is not OK the results is a status message

    status code - fingerbank::Status

    array ref of result sets or error message

=cut

sub search {
    my ( $self, $search_args, $schema ) = @_;
    my $logger = fingerbank::Log::get_logger;

    my $className = $self->_parseClassName;
    my @resultSets;

    my @schemas = fingerbank::DB->get_schemas($schema);

    foreach my $schema ( @schemas ) {
        $logger->debug("Searching '$className' entries in schema '$schema'");

        my $db = fingerbank::DB_Factory->instantiate(schema => $schema);
        if ( $db->isError ) {
            my $status_msg = "Cannot read from '$className' table in schema '$schema'. Cannot search";
            $logger->warn($status_msg . ". DB layer returned '" . $db->statusCode . " - " . $db->statusMsg . "'");
            return ( $fingerbank::Status::INTERNAL_SERVER_ERROR, $status_msg );
        }

        my $resultset = $db->handle->resultset($className)->search(@$search_args);

        # Empty resultset should not be pushed into the result array
        next if $resultset eq 0;

        push @resultSets,$resultset;
    }

    # Query doesn't return any result on any of the schema(s)
    unless ( @resultSets ) {
        my $status_msg = "Searching for '$className' entries in schema(s) returned an empty set";
        $logger->info($status_msg);
        return ( $fingerbank::Status::NOT_FOUND, $status_msg );
    }

    return ( $fingerbank::Status::OK, \@resultSets );
}

=head2 find

=cut

sub find {
    my ( $self, $search_args, $schema ) = @_;
    my $logger = fingerbank::Log::get_logger;

    my $className = $self->_parseClassName;
    my $return;

    my ($status, $result) = $self->search($search_args, $schema);

    # There was an 'error' in the search.
    return ($status, $result) if ( is_error($status) );

    foreach my $resultset ( @$result ) {
        $return = $resultset->first;
        last if defined $return;
    }

    return ( $fingerbank::Status::OK, $return );
}

=head2 list

=cut

sub list {
    my ( $self, $schema ) = @_;
    my $logger = fingerbank::Log::get_logger;

    my $className = $self->_parseClassName;
    my $return = {};

    my ($status, $result) = $self->search([], $schema);

    # There was an 'error' in the search.
    return ($status, $result) if ( is_error($status) );

    # Building the resultset to be returned
    foreach my $resultset ( @$result ) {
        while ( my $row = $resultset->next ) {
            $return->{$row->id} = $row->value;
        }
    }

    return ($fingerbank::Status::OK, $return);
}

=head2 list_paginated

Handing out a parameterized list of results.

Query optionnal parameters:

- offset: Where to being the listing from (I want 10 result starting after the sixth one). Don't forget that DBIx offset is zero based.

- nb_of_rows: The number of results

- order: asc or desc

- order_by: The field on which we should order the results

- schema: From which schema we want the results. Only 'Upstream' exists. Default to all

=cut

sub list_paginated {
    my ( $self, $query ) = @_;
    my $logger = fingerbank::Log::get_logger;

    my $className = $self->_parseClassName;
    my @return;

    my ($status, $result) = $self->search([{},
        { offset => $query->{offset}, rows => $query->{nb_of_rows}, order_by => { -$query->{order} => $query->{order_by} } }], 
        $query->{schema});

    # There was an 'error' in the search.
    return ($status, $result) if ( is_error($status) );

    # Building the resultset to be returned
    foreach my $resultset ( @$result ) {
        while ( my $row = $resultset->next ) {
            # TODO: Handle the 'value' since it is for "compatibility" with PacketFence
            my %array_row = ( %{$row->{'_column_data'}}, 'value' => $row->value );
            push ( @return, \%array_row );
        }
    }

    return ($fingerbank::Status::OK, \@return);
}

=head2 count

=cut

sub count {
    my ( $self, $schema ) = @_;
    my $logger = fingerbank::Log::get_logger;

    my $className = $self->_parseClassName;
    my $count;

    my @schemas = fingerbank::DB->get_schemas($schema);

    foreach my $schema ( @schemas ) {
        my $db = fingerbank::DB_Factory->instantiate(schema => $schema);
        if ( $db->isError ) {
            my $status_msg = "Cannot read from '$className' table in schema '$schema'. Cannot search";
            $logger->warn($status_msg . ". DB layer returned '" . $db->statusCode . " - " . $db->statusMsg . "'");
            return ( $fingerbank::Status::INTERNAL_SERVER_ERROR, $status_msg );
        }

        my $nb_of_rows = $db->handle->resultset($className)->search->count;
        $count += $nb_of_rows;
    }

    return ( $fingerbank::Status::OK, $count );
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
