package pf::services::manager::httpd_admin;
=head1 NAME

pf::services::manager::httpd_admin add documentation

=cut

=head1 DESCRIPTION

pf::services::manager::httpd_admin

=cut

use strict;
use warnings;
use Moo;
use List::MoreUtils qw(uniq);
use pf::config qw(
    @internal_nets
    @portal_ints
);
use pf::file_paths qw(
    $install_dir
);

extends 'pf::services::manager::httpd';

has '+name' => (default => sub { 'httpd.admin' } );

has '+shouldCheckup' => ( default => sub { 0 }  );

use pf::config qw(
    %Config
    $management_network
    $OS
);
use pf::cluster;

=head2 _buildSystemdVars 

Return a hashref with the variables requied to populate the systemd Unit File template in generateUnitFile. 
We add the X_PORTAL=default variable to prevent warnings on CentOS/RHEL.

=cut

sub _build_SystemdVars {
    my $self    = shift;
    my $cmdLine
        = defined $self->_cmdLineArgs
        ? $self->_cmdLine . " " . $self->_cmdLineArgs
        : $self->_cmdLine;
    return {
        header_warning => "#This file is generated dynamically based on the PacketFence configuration. 
# Look under " . $self->systemdTemplateFilePath . " for the template used to generate it.",
        cmdLine => $cmdLine,
        pidFile => $self->pidFile,
        environment => "X_PORTAL=default",
    };
}

=head2 vhosts

The list of IP addresses on which the process should listen

=cut

sub vhosts {
    my ($self) = @_;
    my @vhosts;
    if ( $management_network && defined($management_network->{'Tip'}) && $management_network->{'Tip'} ne '') {
        if (defined($management_network->{'Tvip'}) && $management_network->{'Tvip'} ne '') {
            push @vhosts, $management_network->{'Tvip'};
        } elsif ( $cluster_enabled ){
            push @vhosts, pf::cluster::current_server->{management_ip};
            push @vhosts, $ConfigCluster{'CLUSTER'}{'management_ip'};
        } else {
            push @vhosts, $management_network->{'Tip'};
       }
    } else {
        push @vhosts, "0.0.0.0";
    }
    return \@vhosts;
}


=head2 additionalVars

=cut

sub additionalVars {
    my ($self) = @_;
    return (preview_ip => $self->portal_preview_ip);
}

=head2 portal_preview_ip

The creates the portal preview ip addresss

=cut

sub portal_preview_ip {
    my ($self) = @_;
    my  @ints = uniq (@internal_nets, @portal_ints);
    return $ints[0]->{Tvip} ? $ints[0]->{Tvip} : $ints[0]->{Tip};
}


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
