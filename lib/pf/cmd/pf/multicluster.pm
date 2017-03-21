package pf::cmd::pf::multicluster;
=head1 NAME

pf::cmd::pf::multicluster

=head1 SYNOPSIS

 pfcmd pfconfig <command> <scope>

 The scope parameter represents a region/cluster/server to apply the command to. 
 When scope is omited, the command applies to the ROOT region

  Commands:

   generateconfig [<scope>]  | generate the configuration to be pushed for a scope in /usr/local/pf/var/multi-cluster/
   generatedeltas [<scope>]  | generate the delta files for all regions/clusters/servers in /usr/local/pf/conf/multi-cluster/
   generateansibleconfig     | generate the ansible configuration and playbooks
   play <playbook> [<scope>] | play an ansible playbook on the desired scope

=head1 DESCRIPTION

pf::cmd::pf::multicluster

=cut

use strict;
use warnings;
use base qw(pf::base::cmd::action_cmd);
use pf::constants::exit_code qw($EXIT_SUCCESS $EXIT_FAILURE);
use pf::multi_cluster;
use pf::constants;
use pf::file_paths qw(
    $ansible_hosts_file
);
use pf::util;

=head1 METHODS

=cut

sub lookup_scope {
    my ($self) = @_;
    $self->{key} = shift @{$self->{args}};
    if($self->{key} && !($self->{scope} = pf::multi_cluster::findObject(pf::multi_cluster::rootRegion, $self->{key}))) {
        print STDERR  "invalid scope $self->{key}\n";
        return $FALSE;
    }
    return $TRUE;
}

sub parse_scope_command {
    my ($self, @args) = @_;
    $self->{args} = \@args;
    return $self->lookup_scope();
}

sub parse_generateconfig {
    return parse_scope_command(@_);
}

sub action_generateconfig {
    my ($self) = @_;
    pf::multi_cluster::generateConfig($self->{scope});
}

sub parse_generatedeltas {
    return parse_scope_command(@_);
}

sub action_generatedeltas {
    my ($self) = @_;
    exit $EXIT_FAILURE unless($self->lookup_scope);
    pf::multi_cluster::generateDeltas($self->{scope});
}

sub action_generateansibleconfig {
    my ($self) = @_;
    pf::multi_cluster::generateAnsibleConfig();
}

sub parse_play {
    my ($self, @args) = @_;
    
    $self->{args} = \@args;
    $self->{playbook} = pf::multi_cluster::findAnsiblePlaybook(shift @{$self->{args}});
    unless(defined($self->{playbook})) {
        print STDERR "Cannot find playbook to execute.\n";
        return 0;
    }

    my $result = $self->lookup_scope();
    return $result unless($result);
}

sub action_play {
    my ($self) = @_;
    my $playbook = untaint_chain($self->{playbook});
    my $scope = $self->{scope} ? $self->{scope}->name : "ROOT";
    exec("/usr/bin/ansible-playbook $playbook --extra-vars \"target=$scope\"");
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


