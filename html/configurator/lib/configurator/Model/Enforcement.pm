package configurator::Model::Enforcement;

=head1 NAME

configurator::Model::Enforcement - Catalyst Model

=head1 DESCRIPTION

Catalyst Model.

=cut

use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'Catalyst::Model';

# TODO: Should migrate theses into a database table with some flags for the mechanisms
my @mechanisms           = qw/vlan inline option/;
# TODO once we display option we should move 'other' over to there
my %types   = (
    vlan        => [ 'management', 'vlan-registration', 'vlan-isolation', 'other' ],
    inline      => [ 'management', 'inline', 'other'],
    option      => [ 'high-availability', 'dhcp-listener', 'monitor' ],
);

=head1 METHODS

=over

=item _getAvailableMechanisms

=cut
sub _getAvailableMechanisms {
    my ( $self ) = @_;

    return \@mechanisms;
}

=item getAvailableTypes

=cut
sub getAvailableTypes {
    my ( $self, $mechanism ) = @_;

    my @mechanisms;
    my @available_types;

    if (ref($mechanism)) {
        @mechanisms = @$mechanism;
    }
    elsif ($mechanism eq 'all') {
        @mechanisms = keys %types;
    }
    else {
        @mechanisms = ($mechanism);
    }

    foreach my $type ( @mechanisms ) {
        foreach ( @{$types{$type}} ) {
            unless ( $self->_isInArray(\@available_types, $_) ) {
                push( @available_types, $_ );
            }
        }
    }

    return \@available_types;
}

=item _isInArray

=cut
sub _isInArray {
    my ( $self, $array, $element ) = @_;

    if ( !grep {$_ eq $element} @$array ) {
        return;
    }

    return 1;
}

=back

=head1 AUTHORS

Derek Wuelfrath <dwuelfrath@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2012 Inverse inc.

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

__PACKAGE__->meta->make_immutable;

1;
