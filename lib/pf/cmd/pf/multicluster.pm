package pf::cmd::pf::multicluster;
=head1 NAME

pf::cmd::pf::multicluster

=head1 SYNOPSIS

 pfcmd pfconfig <command> <scope>

 The scope parameter represents a region/cluster/server to apply the command to. 
 When scope is omited, the command applies to the ROOT region

  Commands:

   generateconfig <scope>  | generate the configuration to be pushed for a scope in /usr/local/pf/var/multi-cluster/
   generatedeltas <scope>  | generate the delta files for all regions/clusters/servers in /usr/local/pf/conf/multi-cluster/

=head1 DESCRIPTION

pf::cmd::pf::multicluster

=cut

use strict;
use warnings;
use base qw(pf::cmd);
use pf::constants::exit_code qw($EXIT_SUCCESS);
use pf::multi_cluster;

=head1 METHODS

=head2 parseArgs

parsing the arguments for the multicluster command

=cut

sub parseArgs {
    my ($self) = @_;
    my @args = $self->args;
    if (@args < 1 || @args > 3 ) {
        print STDERR  "invalid arguments\n";
        return 0;
    }

    my $action = shift @args;
    my $action_method = "action_$action";
    unless ($self->can($action_method)) {
        print STDERR "invalid option '$action'\n";
        return 0;
    }
    $self->{action_method} = $action_method;
    $self->{key} = shift @args;

    unless($self->{region} = pf::multi_cluster::findObject(pf::multi_cluster::rootRegion, $self->{key})) {
        print STDERR  "invalid scope $self->{key}\n";
        return 0;
    }

    return 1;
}

=head2 action_expire

Handles the remove action

=cut

sub action_generateconfig {
    my ($self) = @_;
    pf::multi_cluster::generateConfig($self->{region});
}

sub action_generatedeltas {
    my ($self) = @_;
    pf::multi_cluster::generateDeltas($self->{region});
}

=head2 _run

performs the action of the command

=cut

sub _run {
    my ($self) = @_;
    my $action_method = $self->{action_method};
    $self->$action_method();
    return 0;
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and::or
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


