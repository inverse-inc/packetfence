package pf::task;
=head1 NAME

pf::task - Parent class for pfqueue worker

=head1 DESCRIPTION

pf::task

=cut

use strict;
use warnings;
use Data::UUID;

my $GENERATOR = Data::UUID->new;

=head2 new

The constructor

=cut

sub new {
    my ($proto, @args) = @_;
    my $class = ref($proto) || $proto;
    return bless {args => \@args}, $class;
}

=head2 doTask

The function to override to perform a task

=cut

sub doTask {
    die "Unimplemented doTask";
}

=head2 generateId

Generate the task id

=cut

sub generateId {
    my ($self, $metadata) = @_;
   "Task:" . $GENERATOR->create_str . ":$metadata";
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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

