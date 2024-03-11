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
        nodecategory_view_by_names
        nodecategory_add
        nodecategory_modify
        nodecategory_exist
        nodecategory_lookup
    );
}

use pf::version;
use pf::config;
use pf::dal::node_category;
use pf::db;
use pf::error qw(is_error is_success);
use pf::util;

=head1 SUBROUTINES

=over

=cut

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
        my $msg = "Cannot reload roles when the database is in read only mode\n";
        print STDERR $msg;
        $logger->error($msg);
        return;
    }

    my @keep;
    my @entries = _order_nodecategory_config($config);
    for my $args (@entries) {
        my $id = $args->[0];
        nodecategory_upsert($id, %{$args->[1]});
        push @keep, $id;
    }
    _nodecategory_bulk_delete(\@keep);
}

sub _nodecategory_bulk_delete {
    my ($keep) = @_;
    pf::dal::node_category->remove_items(
        -ignore => 1,
        -where => {
            name => {
                -not_in => $keep,
            },
        }
    );
}

sub _order_nodecategory_config {
    my ($config) = @_;
    my %t;
    while (my ($id, $role) = each(%$config)) {
        my $parent = $role->{parent} // '';
        push @{$t{$parent}}, [$id, {%$role}];
    }

    return _flatten_nodecategory($t{''}, \%t);
}

sub _flatten_nodecategory {
    my ( $parents, $h ) = @_;
    return @$parents,
      map { _flatten_nodecategory( $h->{$_}, $h ) }
      grep { exists $h->{$_} } map { $_->[0] } @$parents;
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
        my $parent = $data{parent};
        my $obj = pf::dal::node_category->new({
            name => $id,
            max_nodes_per_pid => $data{max_nodes_per_pid},
            notes => $data{notes},
            parent_id => defined $parent ? \['(SELECT category_id FROM (SELECT category_id FROM node_category WHERE name = ?) x )', $parent] : undef,
            include_parent_acls => $data{include_parent_acls} // "disabled",
            fingerbank_dynamic_access_list => $data{fingerbank_dynamic_access_list} // "disabled",
            acls => join("\n", @{$data{acls} // []}),
            vlan => $data{vlan},
        });
        my ($status) = $obj->upsert;
        if (is_error($status)) {
            $logger->error("Cannot save nodecategory (role) in the database.");
        }
    };
    if($@) {
        $logger->error("Cannot upsert nodecategory (role) in the database. Error was: $@");
        return;
    }
}

=item nodecategory_view_all - view all categories, returns an hashref

=cut

sub nodecategory_view_all {
    my ($status, $iter) = pf::dal::node_category->search(-with_class => undef, -order_by => 'name');
    if (is_error($status)) {
        return;
    }

    return map { _cleanup($_)  } @{$iter->all() // []};
}

=item nodecategory_view - view a node category, returns an hashref

=cut

sub nodecategory_view {
    my ($cat_id) = @_;
    my ($status, $obj) = pf::dal::node_category->find({category_id => $cat_id});
    if (is_error($status)) {
        return (0);
    }
    return (_cleanup($obj->to_hash()));
}

=item nodecategory_view_by_name - view a node category by name. Returns an hashref

=cut

sub nodecategory_view_by_name {
    my ($name) = @_;
    my ($status, $iter) = pf::dal::node_category->search(
        -where => {
            name => $name,
        }
    );
    if (is_error($status)) {
        return (0);
    }
    return (_cleanup($iter->next(undef)));
}

sub _cleanup {
    my ($i) = @_;
    if (defined $i) {
        $i->{category_id} .= "";
        $i->{max_nodes_per_pid} .= "";
    }

    return $i;
}

=item nodecategory_view_by_names - view a list of node categories by name. Returns an array of nodecategories

=cut

sub nodecategory_view_by_names {
    my (@names) = @_;
    my ($status, $iter) = pf::dal::node_category->search(
        -where => {
            name => {-in => \@names},
        },
        -with_class => undef,
        -order_by => 'name',
    );
    if (is_error($status)) {
        return ();
    }

    return map { _cleanup($_) } @{$iter->all() // []};
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

    my $status = pf::dal::node_category->create({
        name => $data{'name'},
        max_nodes_per_pid => $data{'max_nodes_per_pid'},
        notes => $data{'notes'},
    });

    return;
}

=item nodecategory_modify - modify a node category

=cut

sub nodecategory_modify {
    my ($cat_id, %data) = @_;

    # overriding defaults
    my $existing = nodecategory_view($cat_id);
    unless ($existing) {
        return (0);
    }
    $existing->merge(\%data);
    my $status = $existing->save;
    return (is_success($status) ? 1 : 0);
}

=item nodecategory_exist - does a node category exists? returns 1 if so, 0 otherwise

=cut

sub nodecategory_exist {
    my ($cat_id) = @_;
    return (is_success(pf::dal::node_category->exists({category_id => $cat_id})));
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

Copyright (C) 2005-2024 Inverse inc.

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
