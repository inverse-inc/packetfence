package pf::nodecategory;

=head1 NAME

pf::nodecategory - module to view, query and manage the node categories.

=cut

=head1 DESCRIPTION

pf::nodecategories contains the functions necessary to manage all aspects
of node categories: creation, deletion, updates, etc. It also includes utility
methods to get information about node categories.

=head1 CONFIGURATION AND ENVIRONMENT

Read the F<pf.conf> configuration file.

=cut

use strict;
use warnings;
use Log::Log4perl;

use constant NODECATEGORY => 'nodecategory';

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    @EXPORT = qw(
        nodecategory_db_prepare
        $nodecategory_db_prepared

        nodecategory_view_all
        nodecategory_view
        nodecategory_view_by_name
        nodecategory_add
        nodecategory_modify
        nodecategory_delete
        nodecategory_exist
        nodecategory_lookup
    );
}

use pf::config;
use pf::db;
use pf::util;

# The next two variables and the _prepare sub are required for database handling magic (see pf::db)
our $nodecategory_db_prepared = 0;
# in this hash reference we hold the database statements. We pass it to the query handler and he will repopulate
# the hash if required
our $nodecategory_statements = {};

=head1 SUBROUTINES

=over

=cut

sub nodecategory_db_prepare {
    my $logger = Log::Log4perl::get_logger('pf::nodecategory');
    $logger->debug("Preparing pf::nodecategory database queries");

    $nodecategory_statements->{'nodecategory_view_all_sql'} = get_db_handle()->prepare(
        qq [ SELECT category_id, name, max_nodes_per_pid, notes FROM node_category ]
    );

    $nodecategory_statements->{'nodecategory_view_sql'} = get_db_handle()->prepare(
        qq [ SELECT category_id, name, max_nodes_per_pid, notes FROM node_category WHERE category_id = ? ]
    );

    $nodecategory_statements->{'nodecategory_view_by_name_sql'} = get_db_handle()->prepare(
        qq [ SELECT category_id, name, max_nodes_per_pid, notes FROM node_category WHERE name = ? ]
    );

    $nodecategory_statements->{'nodecategory_add_sql'} = get_db_handle()->prepare(
        qq [ INSERT INTO node_category (name, max_nodes_per_pid, notes) VALUES (?, ?, ?) ]
    );

    $nodecategory_statements->{'nodecategory_modify_sql'} = get_db_handle()->prepare(
        qq [ UPDATE node_category SET name=?, max_nodes_per_pid=?, notes=? WHERE category_id = ? ]
    );

    $nodecategory_statements->{'nodecategory_delete_sql'} = get_db_handle()->prepare(
        qq [ DELETE FROM node_category WHERE category_id = ? ]
    );

    $nodecategory_statements->{'nodecategory_exist_sql'} = get_db_handle()->prepare(
        qq [ SELECT category_id FROM node_category WHERE category_id = ? ]
    );

    $nodecategory_db_prepared = 1;
}

=item nodecategory_view_all - view all categories, returns an hashref

=cut
sub nodecategory_view_all {
    return db_data(NODECATEGORY, $nodecategory_statements, 'nodecategory_view_all_sql');
}

=item nodecategory_view - view a node category, returns an hashref

=cut
sub nodecategory_view {
    my ($cat_id) = @_;
    my $query = db_query_execute(NODECATEGORY, $nodecategory_statements, 'nodecategory_view_sql', $cat_id);
    my $ref = $query->fetchrow_hashref();

    # just get one row and finish
    $query->finish();
    return ($ref);
}

=item nodecategory_view_by_name - view a node category by name. Returns an hashref

=cut
sub nodecategory_view_by_name {
    my ($name) = @_;
    my $query = db_query_execute(NODECATEGORY, $nodecategory_statements, 'nodecategory_view_by_name_sql', $name);
    my $ref = $query->fetchrow_hashref();

    # just get one row and finish
    $query->finish();
    return ($ref);
}

=item nodecategory_add - add a node category

=cut
sub nodecategory_add {
    my (%data) = @_;

    if (!defined($data{'name'})) {
        die("name missing: Category name is mandatory when adding a category.");
    }

    # default values
    $data{'max_nodes_per_pid'} = 0 if (!defined($data{'max_nodes_per_pid'}));

    return(
        db_data(
            NODECATEGORY, $nodecategory_statements, 'nodecategory_add_sql', 
            @data{qw/name max_nodes_per_pid notes/} # hash-slice assigning values to a list
        )
    );
}

=item nodecategory_modify - modify a node category

=cut
sub nodecategory_modify {
    my ($cat_id, %data) = @_;

    # overriding defaults
    my $existing = nodecategory_view($cat_id);
    foreach my $item ( keys(%data) ) {
        $existing->{$item} = $data{$item};
    }

    return(
        db_data(
            NODECATEGORY, $nodecategory_statements, 'nodecategory_modify_sql', 
            @{$existing}{qw/name max_nodes_per_pid notes/},  # hashref-slice assigning values to a list
            $cat_id
        )
    );
}

=item nodecategory_delete - delete a node category

=cut
sub nodecategory_delete {
    my ($id) = @_;

    my $result = db_query_execute(NODECATEGORY, $nodecategory_statements, 'nodecategory_delete_sql', $id);
    if (!defined($result)) {
        die("database query failed! Are you trying to delete a category with nodes in it? See logs for details.");
    }
    return (0);
}

=item nodecategory_exist - does a node category exists? returns 1 if so, 0 otherwise

=cut
sub nodecategory_exist {
    my ($cat_id) = @_;
    my $query = db_query_execute(NODECATEGORY, $nodecategory_statements, 'nodecategory_exist_sql', $cat_id);
    my ($val) = $query->fetchrow_array();
    $query->finish();
    return ($val);
}

=item nodecategory_lookup - returns category_id from a category name if it exists, undef otherwise

Just a small convenience wrapper

=cut
sub nodecategory_lookup {
    my ($category_name) = @_;

    my $nodecategory = nodecategory_view_by_name($category_name);
    my $valid_db_result = (defined($nodecategory) && ref($nodecategory) eq 'HASH');

    if ($valid_db_result && defined($nodecategory->{'category_id'})) {
        return $nodecategory->{'category_id'};
    } else {
        return;
    }
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
