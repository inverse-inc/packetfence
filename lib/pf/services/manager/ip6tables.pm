package pf::services::manager::ip6tables;

=head1 NAME

pf::services::manager::ip6tables add documentation

=cut

=head1 DESCRIPTION

pf::services::manager::ip6tables

=cut

use strict;
use warnings;
use Moo;
use pf::file_paths qw($install_dir);
use pf::log;
use pf::util;
use pf::ip6tables;
use pf::config qw(%Config);
use pf::constants;
use pf::constants::exit_code qw($EXIT_SUCCESS);

extends 'pf::services::manager';

has '+name' => (default => sub { 'ip6tables' } );

has '+shouldCheckup' => ( default => sub { 1 }  );

has 'runningServices' => (is => 'rw', default => sub { 0 } );


=head2 start

start ip6tables

=cut

sub startService {
    my ($self) = @_;
    unless ($self->isAlive()) {
        pf::ip6tables->save($install_dir . '/var/ip6tables.bak');
    }
    pf::ip6tables->generate();
    return $TRUE;
}

=head2

generateConfig

=cut

sub generateConfig {
    pf::ip6tables->generate();
    return $TRUE;
}

=head2 start

Wrapper around systemctl. systemctl should in turn call the actuall _start.

=cut

sub start {
    my ($self,$quick) = @_;
    system('sudo systemctl start packetfence-ip6tables');
    return $? == $EXIT_SUCCESS;
}

=head2 _start

start the service (called from systemd)

=cut

sub _start {
    my ($self) = @_;
    my $result = 0;
    unless ( $self->isAlive() ) {
        $result = $self->startService();
    }
    return $result;
}

sub startAndCheck {
    my ($self) = @_;

    while($TRUE) {
        $self->_start() unless($self->isAlive());
        sleep 60;
    }
}

=head2 stop

Wrapper around systemctl. systemctl should in turn call the actual _stop.

=cut

sub stop {
    my ($self) = @_;
    system('sudo systemctl stop packetfence-ip6tables');
    return $TRUE;
}

=head2 _stop

stop ip6tables (called from systemd)

=cut

sub _stop {
    my ($self) = @_;
    my $logger = get_logger();
    pf::ip6tables->restore( $install_dir . '/var/ip6tables.bak' );
    return $TRUE;
}

=head2 isAlive

Check if ip6tables is alive.
Since it's never really stopped then we check if the fake PID exists

=cut

sub isAlive {
    my ($self) = @_;
    my $logger = get_logger();
    my $result;
    my $pid = $self->pid;
    my $_EXIT_CODE_EXISTS = "$EXIT_SUCCESS";
    my $rules = safe_pf_run('sudo', $Config{'services'}{"ip6tables_binary"}, '-S') // '';
    return ($pid && $rules =~ /\Q$pf::ip6tables::FW_FILTER_INPUT_MGMT\E/m) ? $TRUE : $FALSE;
}

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

