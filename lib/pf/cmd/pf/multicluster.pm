package pf::cmd::pf::multicluster;
=head1 NAME

pf::cmd::pf::multicluster

=head1 SYNOPSIS

 pfcmd multicluster <command> <scope>

 The scope parameter represents a region/cluster/server to apply the command to. 
 When scope is omited, the command applies to the ROOT region

  Commands:

   generateconfig [<scope>]  | generate the configuration to be pushed for a scope in /usr/local/pf/var/multi-cluster/
   generatedeltas [<scope>]  | generate the delta files for all regions/clusters/servers in /usr/local/pf/conf/multi-cluster/
   generateansibleconfig     | generate the ansible configuration and playbooks
   play <playbook> [<scope>] | play an ansible playbook on the desired scope
   run <command> [<scope>]   | run a command on the desired scope

  Creating a server from an existing deployment
   NOTE: Prior to executing this command, you need to copy the root's user key on the servers

   create <server|cluster> <hostname> <parent-region> [<object-name>]

   Where:
    - <server|cluster> is whether the server is a server or a cluster
    - <hostname> is the resolvable hostname of the current deployment (in case of a cluster, use the CLUSTER management IP address or DNS name)
    - <parent-region> is the parent region this new object will be in. Define new regions in multi-cluster.conf. By default, only the ROOT region exists
    - <object-name> is the name of the object that will be created in multi-master.conf. Only respected when importing a cluster as servers use their hostname

   Examples:
    create server pf-MTL-1.inverse.ca montreal pf-MTL-1
    create cluster 10.1.1.1 montreal pf-MTL


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
    $multi_cluster_conf_dir
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

sub lookup_confirm_scope {
    my ($self) = @_;
    my $result = $self->lookup_scope();

    return $result unless($result);

    my $scope = $self->{scope};
    my $scope_string;

    if($scope) {
        if($scope->isa("pf::multi_cluster::standalone_server")) {
            $scope_string = "the PacketFence server ".$scope->name;
        }
        elsif($scope->isa("pf::multi_cluster::cluster")) {
            $scope_string = "all the servers in the PacketFence cluster " . $scope->name;
        }
        elsif($scope->isa("pf::multi_cluster::region")) {
            $scope_string = "all the servers in region " . $scope->name;
        }
        else {
            $scope_string = $scope->name . " and all the PacketFence servers it contains";
        }
    }
    else {
        $scope_string = "**ALL** the managed PacketFence servers";
    }

    print "You are about to execute this command on $scope_string. Do you wish to continue (y/n)? ";
    my $confirm = <STDIN>;
    chomp $confirm;
    if($confirm eq "y") {
        return $TRUE;
    }
    else {
        print STDERR "Aborting from user input...\n";
        exit $EXIT_FAILURE;
    }
}

sub parse_scope_command {
    my ($self, @args) = @_;
    $self->{args} = \@args;
    return $self->lookup_confirm_scope();
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
    pf::multi_cluster::generateDeltas($self->{scope});
}

sub action_generateansibleconfig {
    my ($self) = @_;
    pf::multi_cluster::generateAnsibleConfig();
}

sub parse_run {
    my ($self, @args) = @_;
    
    $self->{args} = \@args;
    $self->{ansible_command} = shift @{$self->{args}};

    my $result = $self->lookup_confirm_scope();
    return $result unless($result);
}

sub action_run {
    my ($self) = @_;
    my $command = untaint_chain($self->{ansible_command});
    my $scope = $self->{scope} ? $self->{scope}->name : "ROOT";
    exec("/usr/bin/ansible $scope -a '$command'")
}

sub parse_play {
    my ($self, @args) = @_;
    
    $self->{args} = \@args;
    $self->{playbook} = pf::multi_cluster::findAnsiblePlaybook(shift @{$self->{args}});
    unless(defined($self->{playbook})) {
        print STDERR "Cannot find playbook to execute.\n";
        return 0;
    }

    my $result = $self->lookup_confirm_scope();
    return $result unless($result);
}

sub action_play {
    my ($self) = @_;
    my $playbook = $self->{playbook};
    my $scope = $self->{scope} ? $self->{scope}->name : "ROOT";
    pf::multi_cluster::_play($playbook, $scope);
}

sub parse_create {
    my ($self, @args) = @_;

    #<server|cluster> <hostname> <parent-region> <name>
    ($self->{object_type}, $self->{hostname}, $self->{parent_region_name}, $self->{name}) = @args;

    if($self->{object_type} eq "server") {
        $self->{name} = $self->{hostname};
        $self->{conf_object_type} = "standalone_servers";
    }
    elsif($self->{object_type} eq "cluster") {
        $self->{conf_object_type} = "clusters";
    }
    else {
        print STDERR "Invalid object type specified \n";
        return $FALSE;
    }

    unless($self->{parent_region} = pf::multi_cluster::findObject(pf::multi_cluster::rootRegion, $self->{parent_region_name})) {
        print STDERR "Invalid parent region ".$self->{parent_region_name}."\n";
        return $FALSE;
    }

    if(pf::multi_cluster::findObject(pf::multi_cluster::rootRegion, $self->{name})) {
        print STDERR "A cluster or server with this name already exists in the configuration\n";
        return $FALSE;
    }

    return $TRUE;
}

sub action_create {
    my ($self) = @_;

    pf::multi_cluster::addObject($self->{conf_object_type}, $self->{parent_region_name}, $self->{name});
    $self->{created_object} = pf::multi_cluster::findObject(pf::multi_cluster::rootRegion, $self->{name});

    if($self->{object_type} eq "cluster") {
        print "Importing cluster.conf from ".$self->{hostname}."\n";
        my $from = untaint_chain($self->{hostname}.":/usr/local/pf/conf/cluster.conf");
        my $to = untaint_chain($multi_cluster_conf_dir . "/" . $self->{created_object}->path);
        system("scp $from $to");
    }

    pf::multi_cluster::generateAnsibleConfig();

    pf::multi_cluster::play("pull-configuration", $self->{name});
    pf::multi_cluster::generateDeltas($self->{created_object});

    print "Imported $self->{object_type} into multi-cluster.conf \n";
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

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


