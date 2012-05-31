package configurator::Model::Config::System;

=head1 NAME

configurator::Model::Config::System - Catalyst Model

=head1 DESCRIPTION

Catalyst Model.

=cut

use Moose;
use namespace::autoclean;

use Log::Log4perl;

extends 'Catalyst::Model';

=head2 NAME

configurator::Model::Config::SystemFactory

=head2 DESCRIPTION

=cut
package configurator::Model::Config::SystemFactory;
use Moose;

sub _check_os {

    # Default to undef
    my $os;

    # RedHat and derivatives
    $os = "RHEL" if ( -e "/etc/redhat-release" );
    # Debian and derivatives
    $os = "Debian" if ( -e "/etc/debian_version" );

    return $os;        
}

=item getSystem

Obtain a system object suited for your system.

=cut
sub getSystem {

    my $os = _check_os();
    if (defined($os)) {
        my $system = "configurator::Model::Config::System::$os";
        return $system->new();
    }

    # otherwise
    die("This OS not supported by PacketFence");
}

=head2 NAME

configurator::Model::Config::System::Role

=head2 DESCRIPTION

=cut
package configurator::Model::Config::System::Role;

use Moose::Role;
requires qw(test);

package configurator::Model::Config::System::RHEL;

use Moose;
with 'configurator::Model::Config::System::Role';

=head2 NAME

configurator::Model::Config::System::RHEL

=head2 DESCRIPTION

=cut
sub test {
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    $logger->info("logging from within RHEL the enterprisy operating system");
}

package configurator::Model::Config::System::Debian;

use Moose;
with 'configurator::Model::Config::System::Role';

=head2 NAME

configurator::Model::Config::System::Debian

=head2 DESCRIPTION

=cut
sub test {
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    $logger->info("logging from within debian the universal operating system");
}
=back

=head1 AUTHORS

Olivier Bilodeau <obilodeau@inverse.ca>

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
