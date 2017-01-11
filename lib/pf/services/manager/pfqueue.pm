package pf::services::manager::pfqueue;

=head1 NAME

pf::services::manager::pfqueue - Manager for the pfqueue service

=cut

=head1 DESCRIPTION

pf::services::manager::pfqueue

=cut

use strict;
use warnings;
use Moo;

extends 'pf::services::manager';

=head2 name

The name of service of this manager

=cut

has '+name' => ( default => sub { 'pfqueue' } );

=head2 launcher

The sprintf string to launch service

=cut

has '+launcher' => (default => sub { '%1$s -d' } );

=head2 startDependsOnServices

Add redis_queue to the list of dependecies

=cut

around startDependsOnServices => sub {
    my ($orig, $self) = (shift, shift);
    my $startDependsOnServices = $self->$orig(@_);
    push @$startDependsOnServices,'redis_queue';
    return $startDependsOnServices;
};

=head1 AUTHOR

Inverse inc. <info@inverse.ca>


=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

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
