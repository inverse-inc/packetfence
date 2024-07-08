package pf::cmd::pf::generatefirewalldconfig;

=head1 NAME

pf::cmd::pf::generatefirewalldconfig

=head1 SYNOPSIS

 pfcmd generatefirewalldconfig  [soft|hard]

  Commands:

    soft   | reload services configuration rules
    hard   | remove all configurations and restart all config

  defaults to soft

=head1 DESCRIPTION

Generates and apply firewalld rules

=cut

use strict;
use warnings;
use pf::firewalld;
use pf::constants::exit_code qw($EXIT_SUCCESS);

use base qw(pf::base::cmd::action_cmd);

sub default_action { 'soft' }

sub action_soft {
  my ($self) = @_;
  $self->configreload(0);
}

sub action_hard {
  my ($self) = @_;
  $self->configreload(1);
}

sub configreload {
  my ($self,$force)  = @_;
  pf::firewalld::fd_configreload($force);
  return $EXIT_SUCCESS;
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
