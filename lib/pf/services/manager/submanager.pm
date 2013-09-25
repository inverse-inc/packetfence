package pf::services::manager::submanager;
=head1 NAME

pf::services::manager::submanager add documentation

=cut

=head1 DESCRIPTION

pf::services::manager::submanager

a subclass for handling a service the has multple sub services

=cut

use strict;
use warnings;
use Moo;
use List::MoreUtils qw(true any);

extends 'pf::services::manager';

=head2 managers

The list of sub managers

=cut

sub managers {
    my ($self) = @_;
    return ();
}

=head2 start

start all the sub managers

=cut

sub start {
    my ($self,$quick) = @_;
    my $count;
    my $pass = true {$count++; $_->start($quick) } $self->managers;
    return $pass == $count;
}

=head2 stop

stop all the sub managers

=cut

sub stop {
    my ($self,$quick) = @_;
    my $count;
    my $pass = true {$count++; $_->stop($quick) } $self->managers;
    return $pass == $count;
}

=head2 watch

watch all the sub managers

=cut

sub watch {
    my ($self,$quick) = @_;
    my $count;
    my $pass = true {$count++; $_->watch($quick) } $self->managers;
    return $pass == $count;
}

=head2 status

returns all the pids of the submanagers

=cut

sub status {
    my ($self,$quick) = @_;
    my @results = map {$_->status } $self->managers;
    if (@results == 0 || (!$quick && any { !defined($_) || $_ eq "0" } @results )) {
       @results = ("0");
    }
    return join(" ",@results);
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

