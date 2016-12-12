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
use SQL::Abstract::More;

sub new {
    my ($proto, $args) = @_;
    my $class = ref($proto) || $proto;
    my %data = %{$args // {}};
    $data{__old_data} = {%data};
    return bless \%data, $class;
}

sub get_dbh {
    db_connect();
}

sub db_execute {
    my ($self, $sql, @params) = @_;
    my $dbh = $self->get_dbh;
}

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

sub search {
    my ($proto, $where, $extra) = @_;
    my $fields = $proto->field_names;
    my $sqla = SQL::Abstract::More->new;
    my($stmt, @bind) = $sql->select(
        -columns => $fields,
        -from    => $self->table,
        -where   => $where,
        %{$extra // {}},
    );
    my $dbh = db_connect();
    my $sth = $dbh->prepare_cached($sql);
    my $results = $sth->execute(@ids);
    my $row = $sth->fetchrow_hashref;
}

sub save {
    my ($self) = @_;
    my $fields = $self->_fields_to_save;
    my $sql = $self->_update_

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

