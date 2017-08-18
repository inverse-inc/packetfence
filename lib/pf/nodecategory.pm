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
use pf::log;

use constant NODECATEGORY => 'nodecategory';

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    @EXPORT = qw(
        nodecategory_db_prepare
        $nodecategory_db_prepared

        nodecategory_populate_from_config
        nodecategory_upsert
        nodecategory_view_all
        nodecategory_view
        nodecategory_view_by_name
        nodecategory_add
        nodecategory_modify
        nodecategory_exist
        nodecategory_lookup
    );
}

use pf::version;
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
    my $logger = get_logger();
    $logger->debug("Preparing pf::nodecategory database queries");

    $nodecategory_statements->{'nodecategory_upsert_sql'} = get_db_handle()->prepare(
        qq [ INSERT INTO node_category(name, max_nodes_per_pid, notes) VALUES(?, ?, ?) ON DUPLICATE KEY UPDATE max_nodes_per_pid=?, notes=? ]
    );

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

    $nodecategory_statements->{'nodecategory_exist_sql'} = get_db_handle()->prepare(
        qq [ SELECT category_id FROM node_category WHERE category_id = ? ]
    );

    $nodecategory_db_prepared = 1;
}

=item nodecategory_populate_from_config

Populates the nodecategory table from the data in the configuration passes via parameter
Note that this will not delete an existing DB role if it isn't in the configuration
It will simply do an upsert of all the roles in the configuration

=cut

sub nodecategory_populate_from_config {
    my ($config) = @_;
    my $logger = get_logger;

    unless(db_ping()){
        $logger->error("Can't connect to db");
        return;
    }

    if (db_readonly_mode()) {
        print STDERR "Cannot reload roles when the database is in read only mode\n";
        return;
    }
    while(my ($id, $role) = each(%$config)) {
        nodecategory_upsert($id, %$role);
    }
}

=item nodecategory_upsert

Insert of update a record given an ID

=cut

sub nodecategory_upsert {
    my ($id, %data) = @_;
    my $logger = get_logger;

    eval {
        if(pf::version::version_get_last_db_version() =~ /^[0-6]\./) {
            $logger->error("Cannot upsert a nodecategory in a database that is on a version below 7.0.0. Please upgrade your database schema.");
            return;
        }

        die "Missing ID for nodecategory_upsert" unless($id);

        $logger->info("Inserting/updating role with ID $id");
        return db_data(NODECATEGORY, $nodecategory_statements, 'nodecategory_upsert_sql', $id, @data{qw/max_nodes_per_pid notes/}, @data{qw/max_nodes_per_pid notes/});
    };
    if($@) {
        $logger->error("Cannot upsert nodecategory (role) in the database. Error was: $@");
        return;
    }
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

Copyright (C) 2005-2017 Inverse inc.

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
