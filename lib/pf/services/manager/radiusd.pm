package pf::services::manager::radiusd;

=head1 NAME

pf::services::manager::radiusd add documentation

=cut

=head1 DESCRIPTION

pf::services::manager::radiusd

=cut

use strict;
use warnings;
use List::MoreUtils qw(any);
use pf::file_paths qw(
    $var_dir
    $conf_dir
    $install_dir
);
use pf::util;
use Moo;
use pf::cluster;
use pf::services::manager::radiusd_child;

extends 'pf::services::manager::submanager';

has radiusdManagers => (is => 'rw', builder => 1, lazy => 1);

has '+name' => ( default => sub { 'radiusd' } );

has '+launcher' => ( default => sub { "sudo %1\$s -d $install_dir/raddb/"} );

sub _build_radiusdManagers {
    my ($self) = @_;

    my $listens = {};
    if($cluster_enabled){
        my $cluster_ip = pf::cluster::management_cluster_ip();
        $listens->{load_balancer} = {
          launcher => $self->launcher . " -n load_balancer"
        };
    }
    $listens->{auth} = {
      launcher => $self->launcher . " -n auth"
    };
    $listens->{acct} = {
      launcher => $self->launcher . " -n acct"
    };
    if (any { exists $_->{cliAccess} && isenabled($_->{cliAccess}) } values %pf::SwitchFactory::SwitchConfig) {
        $listens->{cli} = {
          launcher => $self->launcher . " -n cli"
        };
    }

    my @managers = map {
        my $id = $_;
        my $launcher = $self->launcher;
        my $name = $id eq "auth" ? $self->name : untaint_chain($self->name . "-" . $id);

        pf::services::manager::radiusd_child->new ({
            executable => $self->executable,
            name => $name,
            launcher => $listens->{$id}->{launcher},
            forceManaged => $self->isManaged,
            options => $listens->{$id},
            orderIndex => $self->orderIndex,
        })
    } keys %$listens;

    return \@managers;
}


sub managers {
    my ($self) = @_;
    return @{$self->radiusdManagers};
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

