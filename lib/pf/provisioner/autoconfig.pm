package pf::provisioner::autoconfig;
=head1 NAME

pf::provisioner::autoconfig add documentation

=cut

=head1 DESCRIPTION

pf::provisioner::autoconfig

=cut

use strict;
use warnings;
use List::MoreUtils qw(any);
use Moo;
extends 'pf::provisioner';

=head2 oses

The Oses that is support by this provisioner

=cut

has oses => (is => 'rw', default => sub { [] });

=head2 autoconfig

Is auto config enabled 

=cut

has autoconfig => (is => 'rw', default => sub { 0 } );

=head2 template

The template to use for autoconfig

=cut

has template => (is => 'rw', required => 1);

=head1 METHODS

=head2 matchCategory

=cut

sub matchCategory {
    my ($self, $node_attributes) = @_;
    my $category = $self->category;
    my $node_cat = $node_attributes->{'category'};

    # validating that the node is under the proper category for provisioner
    return 1 if ( $category eq 'any' || (defined($node_cat) && $node_cat eq $category));
    return 0;
}

=head2 matchOS

=cut

sub matchOS {
    my ($self, $os) = @_;
    my @oses = @{$self->oses || []};
    #if if no oses are defined then it will match all the oses
    return 1 unless @oses;
    local $/;
    return 0 unless any { $os =~ $_ } @oses;
}

=head2 match

=cut

sub match {
    my ($self, $os, $node_attributes) = @_;
    return $self->matchOS($os) && $self->matchCategory($node_attributes);
}

=head2 allow

=cut

sub allow { 1 };

 
=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2014 Inverse inc.

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

