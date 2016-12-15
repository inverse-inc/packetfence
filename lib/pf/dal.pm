package pf::dal;

=head1 NAME

pf::dal - PacketFence Data Access Layer

=cut

=head1 DESCRIPTION

pf::dal provides a thin data abstraction layer for the database tables.

This module work in conjunction with the addons/dev-helpers/bin/generator-data-access-layer.pl script

Which generates all the companion modules for table in the database.

=cut

use strict;
use warnings;
use pf::db;
use pf::log;
use SQL::Abstract::More;
use pf::dal::iterator;

use Class::XSAccessor {
    accessors => [qw(__from_table __old_data)],
    false => [qw(has_primary_key)],
};

=head2 new

Create a new pf::dal object

=cut

sub new {
    my ($proto, $args) = @_;
    my $class = ref($proto) || $proto;
    my $defaults = $class->_defaults;
    my %data = (%$defaults, %{$args // {}});
    return bless \%data, $class;
}

=head2 new_from_table

Create a new pf::dal object marking it that it came from the database

=cut

sub new_from_table {
    my ($proto, $args) = @_;
    my $class = ref($proto) || $proto;
    my %data = %{$args // {}};
    $data{__old_data} = {%data};
    $data{__from_table} = 1;
    return bless \%data, $class;
}

=head2 get_dbh

Get the database handle

=cut

sub get_dbh {
    get_db_handle();
}

=head2 _default

Return the default values for pf::dal object.
Should be overridden in sub class

=cut

sub _defaults {
    return {};
}

=head2 db_execute

Execute the sql query with it's bind parameters

=cut

sub db_execute {
    my ($self, $sql, @params) = @_;
    my $attempts = 3;
    my $logger = $self->logger;
    while ($attempts) {
        my $dbh = $self->get_dbh;
        unless ($dbh) {
            $logger->error("Cannot connect to database retrying connection");
            next;
        }
        $logger->trace(sub{"preparing statement query $sql"});
        my $sth = $dbh->prepare_cached($sql);
        unless ($sth && $sth->execute(@params)) {
            my $err = $dbh->err;
            my $errstr = $dbh->errstr;
            if ($err < 2000) {
                $logger->error("database query failed with non retryable error: $errstr (errno: $err)");
                last;
            }
            # retry client errors
            $logger->warn("database query failed with: $errstr (errno: $err), will try again");
            next;
        }
        return $sth;
    } continue {
        $attempts--;
    }
    return undef;
}

=head2 find

Find the pf::dal object by it's primaries keys

=cut

sub find {
    my ($proto, @ids) = @_;
    my $sql = $proto->_find_one_sql;
    my $sth = $proto->db_execute($sql, @ids);
    unless ($sth) {
        return undef;
    }
    my $row = $sth->fetchrow_hashref;
    unless ($row) {
        return undef;
    }
    my $dal = $proto->new_from_table($row);
    $sth->finish;
    return $dal;
}

=head2 search

Search for pf::dal using SQL::Abstract::More syntax

=cut

sub search {
    my ($proto, $where, $extra) = @_;
    my $class = ref($proto) || $proto;
    my $sqla = SQL::Abstract::More->new;
    my($stmt, @bind) = $sqla->select(
        -columns => $proto->field_names,
        -from    => $proto->table,
        -where   => $where // {},
        %{$extra // {}},
    );
    my $sth = $proto->db_execute($stmt, @bind);
    return undef unless defined $sth;
    return pf::dal::iterator->new({sth => $sth, class => $class});
}

=head2 save

Save the pf::dal object in the database

=cut

sub save {
    my ($self) = @_;
    return undef unless $self->has_primary_key;
    return $self->__from_table ? $self->update : $self->insert;
}

=head2 update

Update the pf::dal object

=cut

sub update {
    my ($self) = @_;
    return 0 unless $self->__from_table;
    my $where         = $self->primary_keys_where_clause;
    my $update_data = $self->_update_data;
    return 0 unless defined $update_data;
    if (keys %$update_data == 0 ) {
       return 1;
    }
    my $sqla          = SQL::Abstract::More->new;
    my ($stmt, @bind) = $sqla->update(
        -table => $self->table,
        -set   => $update_data,
        -where => $where,
    );
    my $sth = $self->db_execute($stmt, @bind);

    if ($sth) {
        return $sth->rows;
    }
    return 0;
}

=head2 _update_data

Return the data that needs to be updated

=cut

sub _update_data {
    my ($self) = @_;
    my $updateable_fields = $self->_updateable_fields;
    my $old_data = $self->__old_data;
    my %data;
    foreach my $field (@$updateable_fields) {
        my $new_value = $self->{$field};
        my $old_value = $old_data->{$field};
        next if (!defined $new_value && !$old_value);
        next if (defined $new_value && defined $old_value && $new_value eq $old_value);
        unless ($self->validate_field($field, $new_value)) {
            return undef;
        }
        $data{$field} = $new_value;
    }
    return \%data;
}

=head2 validate_field

Validate a field value

=cut

sub validate_field {
    my ($self, $field, $value) = @_;
    my $logger = $self->logger;
    my $is_nullable = $self->is_nullable($field);
    if (!$is_nullable) {
        if (!defined $value) {
            my $table = $self->table;
            $logger->error("Trying to save a NULL value in a non nullable field ${table}.${field}");
            return 0;
        }
    }
    if ($self->is_enum($field) && defined $value) {
        my $meta;
        return exists $meta->{$field} && exists $meta->{$field}{enums_values}{$value};
    }
    return 1;
}

=head2 is_enum

Checks to see if a field is enum

=cut

sub is_enum {
    my ($self, $field, $value) = @_;
    my $meta = $self->get_meta;
    if (exists $meta->{$field}) {
        return $meta->{$field}{type} eq 'ENUM';
    }
    return 0;
}

=head2 is_nullable

Checks to see if a field is nullable

=cut

sub is_nullable {
    my ($self, $field) = @_;
    my $meta = $self->get_meta;
    if (exists $meta->{$field}) {
        return $meta->{$field}{is_nullable};
    }
    return 0;
}

=head2 insert

Insert a pf::dal object into the database

=cut

sub insert {
    my ($self) = @_;
    my $sql = $self->_insert_sql;
    my $insert_data = $self->_insert_data;
    my $insert_fields = $self->_insert_fields;
    my $sth = $self->db_execute($sql, @{$insert_data}{@$insert_fields});
    if ($sth) {
        return $sth->rows;
    }
    return undef;
}

=head2 fields

Returns the list of fields for the pf::dal object

=cut

sub fields { [] }

=item logger

Return the current logger for the current pf::dal object

=cut

sub logger {
    my ($proto) = @_;
    return get_logger( ref($proto) || $proto );
}
 
=head2 primary_keys_where_clause

Create the primary key where clause

=cut

sub primary_keys_where_clause {
    my ($self) = @_;
    my $old_data = $self->__old_data;
    my %where;
    my $keys = $self->primary_keys;
    for my $key (@$keys) {
        $where{$key} = $old_data->{$key};
    }
    return \%where;
}

=head2 primary_keys

Primary keys

=cut

sub primary_keys { [] }

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

