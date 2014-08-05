package pf::services::manager::iptables;
=head1 NAME

pf::services::manager::iptables add documentation

=cut

=head1 DESCRIPTION

pf::services::manager::iptables

=cut

use strict;
use warnings;
use Moo;
use pf::file_paths;
use pf::config;
use pf::log;

extends 'pf::services::manager';

has '+isvirtual' => (default => sub { 1 } );

has '+name' => (default => sub { 'iptables' } );

has '+shouldCheckup' => ( default => sub { 0 }  );

has '+dependsOnServices' => (is => 'ro', default => sub { [] } );

has 'runningServices' => (is => 'rw', default => sub { 0 } );


=head2 start

start iptables

=cut

sub start {
    my ($self) = @_;
    my $technique;
    unless ($self->runningServices) {
        $technique = getIptablesTechnique();
        $technique->iptables_save($install_dir . '/var/iptables.bak');
    }
    $technique ||= getIptablesTechnique();
    $technique->iptables_generate();
    return 1;
}


=head2 getIptablesTechnique

getIptablesTechnique

=cut

sub getIptablesTechnique {
    require pf::inline::custom;
    my $iptables = pf::inline::custom->new();
    return $iptables->{_technique};
}


=head2 stop

stop iptables

=cut

sub stop {
    my ($self) = @_;
    my $count = $self->runningServices;
    unless ($self->runningServices) {
        getIptablesTechnique->iptables_restore( $install_dir . '/var/iptables.bak');
    } else {
        get_logger->error(
            "Even though 'service pf stop' was called, there are still $count services running. "
              . "Can't restore iptables from var/iptables.bak");
    }
    return 1;
}

=head2 pid

=cut

sub pid { 0 }

=head2 status

=cut

sub status { "0" }


=head1 AUTHOR

Inverse inc. <info@inverse.ca>


=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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

