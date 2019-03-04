package pf::pfmon::task;

=head1 NAME

pf::pfmon::task - The base class for pfmon tasks

=cut

=head1 DESCRIPTION

pf::pfmon::task

=cut

use strict;
use warnings;

use pf::util qw(isenabled);
use pf::Moose::Types;
use Moose;

has type => (is => 'ro', isa => 'Str', required => 1);

has id => (is => 'ro', isa => 'Str', required => 1);

has status => (is => 'ro', isa => 'Str', required => 1);

has interval => (is => 'ro', isa => 'PfInterval', required => 1, coerce => 1);

=head2 run

The method for the sub classes to override

=cut

sub run {
    my ($proto) = @_;
    my $class = ref ($proto) || $proto;
    die "${class}::run was not overridden";
}


=head2 is_enabled

checks if enabled is "true"

=cut

sub is_enabled {
    my ($self) = @_;
    return isenabled($self->status);
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
