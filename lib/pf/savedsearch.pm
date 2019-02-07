package pf::savedsearch;
=head1 NAME

pf::savedsearch - module for savedsearch management

=cut

=head1 DESCRIPTION



=cut

use strict;
use warnings;
use pf::log;

use constant USERPREF => 'savedsearch';

BEGIN {
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    @EXPORT = qw(
        savedsearch_for_pid_and_namespace
        savedsearch_view
        savedsearch_view_all
        savedsearch_update
        savedsearch_delete
        savedsearch_count
        savedsearch_add
        savedsearch_name_taken
    );

}

use pf::dal::savedsearch;
use pf::error qw(is_error is_success);

=head1 Subroutines

=over

=item savedsearch_for_pid_and_namespace

Find all saved search for a user with in a namespace

=cut

sub savedsearch_for_pid_and_namespace {
    my ($pid, $namespace) = @_;
    my ($status, $iter) = pf::dal::savedsearch->search(
        -where => {
            pid => $pid,
            namespace => $namespace,
        },
    );
    if (is_error($status)) {
        return;
    }
    return @{$iter->all(undef) // []};
}

=item savedsearch_view

find a saved search by id

=cut

sub savedsearch_view {
    my ($id) = @_;
    my ($status, $item) = pf::dal::savedsearch->find({id => $id});
    if (is_error($status)) {
        return undef;
    }
    return $item->to_hash();
}

=item savedsearch_view_all

find all saved searches

=cut

sub savedsearch_view_all {
    my ($status, $iter) = pf::dal::savedsearch->search();
    if (is_error($status)) {
        return;
    }
    return @{$iter->all(undef) // []};
}

=item savedsearch_update

updates saved searches

=cut

sub savedsearch_update {
    my ($savedsearch) = @_;
    my %values = %$savedsearch;
    my ($status, $item) = pf::dal::savedsearch->find({id => delete $values{id}});
    if (is_error($status)) {
        return undef;
    }
    $item->merge(\%values);
    $status = $item->save;
    return is_success($status);
}

=item savedsearch_delete

deletes saved search by id

=cut

sub savedsearch_delete {
    my ($id) = @_;
    my $status = pf::dal::savedsearch->remove_by_id({id => $id});
    return is_success($status);
}

=item savedsearch_count

counts all saved search

=cut

sub savedsearch_count {
    my ($status, $count) = pf::dal::savedsearch->count();
    return $count;
}

=item savedsearch_add

adds a saved searche

=cut

sub savedsearch_add {
    my ($savedsearch) = @_;
    my $status = pf::dal::savedsearch->create($savedsearch);
    return is_success($status);
}

=item savedsearch_name_taken

checks if the name is taken

=cut

sub savedsearch_name_taken {
    my ($savedsearch) = @_;
    my ($status, $count) = pf::dal::savedsearch->count(
        -where => {
            pid => $savedsearch->{pid},
            namespace => $savedsearch->{namespace},
            name => $savedsearch->{name},
        },
        -limit => 1,
    );
    return $count;
}

=back

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

