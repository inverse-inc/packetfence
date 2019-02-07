package pf::cmd::pf::fingerbank;
=head1 NAME

pf::cmd::pf::fingerbank

=head1 SYNOPSIS

 pfcmd fingerbank <command>

  Commands:

   find_device_id <device_name> | Get a device ID by the name of the device

=head1 DESCRIPTION

Sub-commands to interact with fingerbank via pfcmd.

=cut

use strict;
use warnings;
use pf::constants::exit_code qw($EXIT_SUCCESS $EXIT_FAILURE);
use pf::fingerbank;
use base qw(pf::base::cmd::action_cmd);

=head2 action_find_device_id

Find a device ID using its name

=cut

sub action_find_device_id {
    my ($self) = @_;
    my ($device_name) = $self->action_args;
    my $device_id = pf::fingerbank::device_name_to_device_id($device_name);
    if(defined($device_id)) {
        print "Device ID of $device_name is : ".$device_id."\n"; 
        return $EXIT_SUCCESS;
    }
    else {
        print "Couldn't find ID for device $device_name\n";
        return $EXIT_FAILURE;
    }
}

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
