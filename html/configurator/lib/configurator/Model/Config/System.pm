package configurator::Model::Config::System;

=head1 NAME

configurator::Model::Config::System - Catalyst Model

=head1 DESCRIPTION

Catalyst Model.

=cut

use Moose;
use namespace::autoclean;

extends 'Catalyst::Model';

has 'os' => ( is => 'ro', isa => 'Str', default => \&_check_os, );

sub _check_os {
    my $self = shift;

    # Default to unknown / non-supported    
    my $os = "ns";

    # RedHat and derivatives
    $os = "RHEL" if ( -e "/etc/redhat-release" );
    # Debian and derivatives
    $os = "Debian" if ( -e "/etc/debian_version" );

    return $os;        
}

sub get_os {
    my ( $self ) = @_;

    my $test = $self->new();
    return $test->os;
}

package configurator::Model::Config::System::RHEL;

=head2 NAME

configurator::Model::Config::System::RHEL

=head2 DESCRIPTION

Catalyst Model.

=cut

use Moose;
use namespace::autoclean;

extends 'configurator::Model::Config::System';


package configurator::Model::Config::System::Debian;

=head2 NAME

configurator::Model::Config::System::Debian

=head2 DESCRIPTION

Catalyst Model.

=cut

use Moose;
use namespace::autoclean;

extends 'configurator::Model::Config::System';


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
