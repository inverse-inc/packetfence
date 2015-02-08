package pfappserver::Model::Roles;

=head1 NAME

pfappserver::Model::Roles - Catalyst Model

=head1 DESCRIPTION

Catalyst Model.

=cut

use strict;
use warnings;

use Moose;
use namespace::autoclean;

use pf::error qw(is_error is_success);
use pf::nodecategory;

=head1 METHODS

=head2 exists

=cut

sub exists {
    my ( $self, $id ) = @_;

    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    my ($status, $status_msg);

    my $result = ();
    eval {
        $result = nodecategory_exist($id);
    };
    if ($@) {
        $status_msg = "Can't validate node category ($id) from database.";
        $logger->error($status_msg);
        return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
    }
    unless ($result) {
        $status_msg = "Node category $id was not found.";
        $logger->warn($status_msg);
        return ($STATUS::NOT_FOUND, $status_msg);
    }

    return ($STATUS::OK, $result);
}

=head2 list

=cut

sub list {
    my ( $self ) = @_;

    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    my ($status, $status_msg);

    my @categories;
    eval {
        @categories = nodecategory_view_all();
    };
    if ($@) {
        $status_msg = "Can't fetch node categories from database.";
        $logger->error($status_msg);
        return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
    }

    return ($STATUS::OK, \@categories);
}

=head2 read

=cut

sub read {
    my ($self, $role_id) = @_;

    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    my ($status, $status_msg) = ($STATUS::OK);

    eval {
        $status_msg = nodecategory_view($role_id);
        unless ($status_msg) {
            $status = $STATUS::NOT_FOUND;
            $status_msg = ["Role ([_1]) not found.",$role_id];
        }
    };
    if ($@) {
        $logger->error($@);
        $status = $STATUS::INTERNAL_SERVER_ERROR;
        $status_msg = "Can't fetch role from the database.";
    }

    return ($status, $status_msg);
}

=head2 create

=cut

sub create {
  my ($self, $name, $max_nodes_per_pid, $notes) = @_;

  my $logger = Log::Log4perl::get_logger(__PACKAGE__);
  my ($status, $status_msg) = ($STATUS::OK, 'The role was succesfully created.');

  eval {
    nodecategory_add((name => $name, max_nodes_per_pid => $max_nodes_per_pid, notes => $notes));
  };
  if ($@) {
    $logger->error($@);
    $status = $STATUS::INTERNAL_SERVER_ERROR;
    $status_msg = "Can't insert role in the database.";
  }

  return ($status, $status_msg);
}

=head2 delete

=cut

sub delete {
    my ($self, $role_ref) = @_;

    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    my ($status, $status_msg) = ($STATUS::OK);

    eval {
      nodecategory_delete($role_ref->{category_id});
    };
    if ($@) {
        $logger->error($@);
        $status = $STATUS::INTERNAL_SERVER_ERROR;
        $status_msg = "Some nodes are still associated to this role.";
    }

    return ($status, $status_msg);
}

=head2 update

=cut

sub update {
    my ($self, $role_ref, $name, $max_nodes_per_pid, $notes) = @_;

    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    my ($status, $status_msg) = ($STATUS::OK);
    $logger->debug("category: $role_ref->{category_id}");
    eval {
      nodecategory_modify($role_ref->{category_id}, (name => $name, max_nodes_per_pid => $max_nodes_per_pid, notes => $notes));
    };
    if ($@) {
        $logger->error($@);
        $status = $STATUS::INTERNAL_SERVER_ERROR;
        $status_msg = "Can't insert role in the database.";
    }

    return ($status, $status_msg);
}

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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
