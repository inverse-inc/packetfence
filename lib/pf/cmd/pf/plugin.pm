package pf::cmd::pf::plugin;

=head1 NAME

pf::cmd::pf::plugin

=head1 SYNOPSIS

 pfcmd plugin <command> [options]

  Commands:
   list                          | the plugins installed: versions, tables, registration, UI code
   install <name|package file>   | install the package of a plugin (packetfence-plugin-<name>)
   uninstall <name> [--purge]    | remove it; --purge also drops its tables
   schema                        | apply, check or drop the database tables of a plugin

Please view "pfcmd help plugin <command>" for details on each command

=head1 DESCRIPTION

Commands for the packages installed on top of PacketFence (the UI plugins)

=cut

use strict;
use warnings;
use base qw(pf::cmd::subcmd);
use pf::cmd;
use pf::constants::exit_code qw($EXIT_FAILURE);

=head2 _run

Every command but help is refused unless the caller of pfcmd is root:
bin/pfcmd is setuid root, and these commands install packages (their scripts
run as root) and change the database as its root user.

=cut

sub _run {
    my ($self) = @_;
    if ($self->{subcmd} ne $self->helpActionCmd && pf::cmd::caller_uid() != 0) {
        print STDERR "pfcmd plugin: only root can run this command\n";
        return $EXIT_FAILURE;
    }
    return $self->SUPER::_run();
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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
