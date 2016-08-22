package pf::cmd::pf::violation;
=head1 NAME

pf::cmd::pf::violation

=head1 SYNOPSIS

 pfcmd violation add <mac> <vid>
 pfcmd violation close <mac> <vid>
 pfcmd violation trigger <mac> <trigger-type> <trigger-id>

 mac - the MAC address of the device
 vid - the violation identifier (section header in violations.conf)
 trigger-type - the type of the violation trigger (user_agent, dhcp_fingerprint, internal, suricata_event, etc)
 trigger-id - the ID of the violation trigger

 examples:
  pfcmd violation add 00:11:22:33:44:55 1100007
  pfcmd violation close 00:11:22:33:44:55 1100007
  pfcmd violation trigger 00:11:22:33:44:55 suricata_event 'ET P2P'

=head1 DESCRIPTION

Add/Delete violations

=cut

use strict;
use warnings;

use base qw(pf::base::cmd::action_cmd);
use pf::util;
use pf::class;
use pf::violation;
use pf::constants::exit_code qw($EXIT_SUCCESS $EXIT_FAILURE);
use pf::cmd::help;

sub validate_mac {
    my ($self, $mac) = @_;
    unless(valid_mac($mac)) {
        print STDERR "MAC address is invalid\n";
        $self->showHelp();
    }
}

sub validate_vid {
    my ($self, $vid) = @_;
    unless(defined(class_view($vid))) {
        print STDERR "Invalid violation ID\n";
        $self->showHelp();
    }
}

=head2 action_close

handles 'pfcmd violation close' command

=cut

sub action_close {
    my ($self) = @_;
    my @params = $self->action_args;
    if( @params >= 2 && $self->validate_mac($params[0]) && $self->validate_vid($params[1]) ) {
        violation_force_close(@params);
    }
    else {
        print STDERR "Insuficent or invalid parameters supplied.\n";
        $self->showHelp;
    }
    return $EXIT_SUCCESS;
}

=head2 action_trigger

handles 'pfcmd violation trigger' command

=cut

sub action_trigger {
    my ($self) = @_;
    my @params = $self->action_args;
    if( @params >= 3 && $self->validate_mac($params[0]) ) {
        violation_trigger({mac => $params[0], type => $params[1], tid => $params[2]});
    }
    else {
        print STDERR "Insuficent or invalid parameters supplied.\n";
        $self->showHelp;
    }
    return $EXIT_SUCCESS;
}

=head2 action_add

handles 'pfcmd violation add' command

=cut

sub action_add {
    my ($self) = @_;
    my @params = $self->action_args;
    if( @params >= 2 && $self->validate_mac($params[0]) && $self->validate_vid($params[1]) ) {
        violation_add(@params);
    }
    else {
        print STDERR "Insuficent or invalid parameters supplied.\n";
        $self->showHelp;
    }
    return $EXIT_SUCCESS;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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


