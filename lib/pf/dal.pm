package pf::dal;

=head1 NAME

pf::dal -

=cut

=head1 DESCRIPTION

pf::dal

=cut

use strict;
use warnings;
use pf::db;
use pf::log;
use SQL::Abstract::More;
use pf::dal::iterator;

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
    my $dbh = $self->get_dbh;
    my $sql = $proto->_find_one_sql;
    my $sth = $dbh->prepare_cached($sql);
    my $results = $sth->execute(@ids);
    my $row = $sth->fetchrow_hashref;
    $sth->finish;
    return $proto->new($row);
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
    my $fields = $self->_fields_to_save;
    my $sql = $self->_update_

sub logger {
    my ($proto) = @_;
    return get_logger( ref($proto) || $proto );
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

