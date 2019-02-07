package pf::services::manager::redis_ntlm_cache;

=head1 NAME

pf::services::manager::redis_ntlm_cache - Service manager for the redis NTLM cache

=cut

=head1 DESCRIPTION

pf::services::manager::redis_ntlm_cache

=cut

use strict;
use warnings;
use Moo;
use pf::file_paths qw(
    $generated_conf_dir
);

extends 'pf::services::manager::redis';

=head2 name

The name of the redis service

=cut

has '+name' => (default => sub { 'redis_ntlm_cache' } );

sub _cmdLine {
    my $self = shift;
    $self->executable . " $generated_conf_dir/" . $self->name . ".conf" . " --daemonize no";
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
