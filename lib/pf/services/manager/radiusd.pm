package pf::services::manager::radiusd;
=head1 NAME

pf::services::manager::radiusd add documentation

=cut

=head1 DESCRIPTION

pf::services::manager::radiusd

=cut

use strict;
use warnings;
use pf::services::radiusd qw(generate_radiusd_conf);
use pf::file_paths;
use Moo;

extends 'pf::services::manager';
with 'pf::services::manager::roles::pf_conf_service_managed';

has '+name' => ( default => sub { 'radiusd' } );

has '+launcher' => ( default => sub { "sudo %1\$s -d $install_dir/raddb/"} );

sub preStartSetup {
    my ($self,$quick) = @_;
    require pf::freeradius;
    pf::freeradius::freeradius_populate_nas_config();
    $self->SUPER::preStartSetup($quick);
}

sub generateConfig {
    my ($self,$quick) = @_;
    generate_radiusd_conf();
}

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

