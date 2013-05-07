package pf::savedsearch;
=head1 NAME

pf::savedsearch - module for savedsearch management

=cut

=head1 DESCRIPTION



=cut

use strict;
use warnings;
use Log::Log4perl;

use constant USERPREF => 'savedsearch';

BEGIN {
    our ( @ISA, @EXPORT, @EXPORT_OK );
    @ISA = qw(Exporter);
    @EXPORT = qw(
        $savedsearch_db_prepared
        savedsearch_db_prepare
        savedsearch_for_pid_and_namespace
        savedsearch_view
        savedsearch_view_all
        savedsearch_update
        savedsearch_delete
        savedsearch_count
        savedsearch_add
    );

}

our $savedsearch_db_prepared = 0;

our $savedsearch_statements = {};

use pf::db;

=head1 Subroutines

=over

=item savedsearch_db_prepare

Instantiate SQL statements to be prepared

=cut

sub savedsearch_db_prepare {
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    $logger->debug("Preparing pf::savedsearch database queries");
    my $dbh = get_db_handle();

    $savedsearch_statements->{'savedsearch_exist_sql'} = $dbh->prepare(
        qq[ select count(*) from savedsearch where id=?]
    );

    $savedsearch_statements->{'savedsearch_add_sql'} = $dbh->prepare(
        qq[ insert into savedsearch( pid,namespace,name,query,in_dashboard ) values (?,?,?,?,?) ]
    );

    $savedsearch_statements->{'savedsearch_count_sql'} = $dbh->prepare(
        qq[ select count(*) from savedsearch where]
    );

    $savedsearch_statements->{'savedsearch_view_sql'} = $dbh->prepare(
        qq[ select * from savedsearch where id=? ]
    );

    $savedsearch_statements->{'savedsearch_view_all_sql'} = $dbh->prepare(
        qq[ select * from savedsearch ]
    );

    $savedsearch_statements->{'savedsearch_delete_sql'} = $dbh->prepare(
        qq[ delete from savedsearch where id=? ]
    );

    $savedsearch_statements->{'savedsearch_update_sql'} = $dbh->prepare(
        qq[ update savedsearch set name=?,pid=?,namespace=?,query=?,in_dashboard=? where id=? ]
    );

    $savedsearch_statements->{'savedsearch_update_query_sql'} = $dbh->prepare(
        qq[ update savedsearch set query=? where id=? ]
    );

    $savedsearch_statements->{'savedsearch_for_pid_and_namespace_sql'} = $dbh->prepare(
        qq[ select id,name,query,in_dashboard from savedsearch where pid=? and namespace=? ]
    );

    $savedsearch_db_prepared = 1;
}

BEGIN {
    no strict qw(refs);
    #Results expected to return a single query
    for my $name (qw(for_pid_and_namespace view view_all)) {
        my $sub_name = __PACKAGE__ . "::_savedsearch_$name";
        my $statement_name = "savedsearch_${name}_sql";
        *{$sub_name} = sub {
            my (@args) = @_;
            my $logger = Log::Log4perl::get_logger(__PACKAGE__);
            $logger->debug("Executing $statement_name with " . join(" ",@args));
            return db_data(USERPREF, $savedsearch_statements, $statement_name, @args);
        }
    }
    #Return row count from non select statement
    for my $name (qw(update delete add)) {
        my $sub_name = __PACKAGE__ . "::_savedsearch_$name";
        my $statement_name = "savedsearch_${name}_sql";
        *{$sub_name} = sub {
            my (@args) = @_;
            my $logger = Log::Log4perl::get_logger(__PACKAGE__);
            $logger->debug("Executing $statement_name with " . join(" ",@args));
            my $sth = db_query_execute(USERPREF, $savedsearch_statements, $statement_name, @args);
            if($sth) {
                return $sth->rows;
            }
            return undef;
        }
    }
}


=item savedsearch_for_pid_and_namespace

Find all saved search for a user with in a namespace

=cut

sub savedsearch_for_pid_and_namespace {
    goto &_savedsearch_for_pid_and_namespace;
}

=item savedsearch_view

find a saved search by id

=cut

sub savedsearch_view {
    goto &_savedsearch_view;
}

=item savedsearch_view_all

find all saved searches

=cut

sub savedsearch_view_all {
    goto &_savedsearch_view;
}

=item savedsearch_update

updates saved searches

=cut

sub savedsearch_update {
    my ($savedsearch) = @_;
    return _savedsearch_update(@{$savedsearch}{qw(name pid namespace query in_dashboard id)});
}

=item savedsearch_delete

deletes saved searche by id

=cut

sub savedsearch_delete {
    goto &_savedsearch_delete;
}

=item savedsearch_count

counts all saved searche

=cut

sub savedsearch_count {
    my $sth = db_query_execute(USERPREF, $savedsearch_statements, "savedsearch_count_sql");
    return ($sth->fetchrow_array)[0];
}

=item savedsearch_add

adds a saved searche

=cut

sub savedsearch_add {
    my ($savedsearch) = @_;
    return _savedsearch_add(@{$savedsearch}{qw(pid namespace name query in_dashboard)});
}

=back

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

