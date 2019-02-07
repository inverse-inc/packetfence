package pf::WebAPI::InitHandler::Admin;

=head1 NAME

pf::WebAPI::InitHandler::Admin

=cut

=head1 DESCRIPTION

pf::WebAPI::InitHandler::Admin

=cut

use strict;
use warnings;

use pf::SwitchFactory();

use base qw(pf::WebAPI::InitHandler);
use Apache2::Const -compile => 'OK';
use pf::db;

=head2 post_config_hook

Cleaning before forking child processes
Close connections to avoid any sharing of sockets

=cut

sub post_config_hook {
    my ($class, $conf_pool, $log_pool, $temp_pool, $s) = @_;
    db_set_max_statement_timeout(600); # Set the database statement timeout
    return Apache2::Const::OK;
}

=head2 preloadSwitches

Preload all the switches

=cut

sub preloadSwitches {
    pf::SwitchFactory->preloadAllModules();
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

