package pf::cmd::pf::configreload;
=head1 NAME

pf::cmd::pf::configreload add documentation

=head1 SYNOPSIS

 pfcmd configreload [soft|hard]

reloads the configuration

  soft   | reload changed configuration files
  hard   | reload all configuration files

  defaults to soft

=head1 DESCRIPTION

pf::cmd::pf::configreload

=cut

use strict;
use warnings;
use pf::constants::exit_code qw($EXIT_SUCCESS);

use base qw(pf::base::cmd::action_cmd);

sub parseArgs {
    my ($self) = @_;
    my ($action,@args) = $self->args;
    $action = 'soft' unless defined $action;
    if($self->is_valid_action($action)) {
        $self->{action} = $action;
        return $self->_parseArgs(@args);
    }
    return 0;
}

sub action_soft {
    my ($self) = @_;
    $self->configreload();
}

sub action_hard {
    my ($self) = @_;
    $self->configreload(1);
}


sub configreload {
    my ($self,$force)  = @_;
    require pf::config;
    pf::config::configreload($force);
    return 0;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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

