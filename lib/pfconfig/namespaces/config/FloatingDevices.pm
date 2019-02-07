package pfconfig::namespaces::config::FloatingDevices;

=head1 NAME

pfconfig::namespaces::config::template

=cut

=head1 DESCRIPTION

pfconfig::namespaces::config::template

This module creates the configuration hash associated to somefile.conf

=cut

use strict;
use warnings;

use pfconfig::namespaces::config;
use pf::file_paths qw($floating_devices_config_file);

use base 'pfconfig::namespaces::config';

sub init {
    my ($self) = @_;
    $self->{file} = $floating_devices_config_file;
}

sub build_child {
    my ($self) = @_;

    my %ConfigFloatingDevices = %{ $self->{cfg} };

    $self->cleanup_whitespaces( \%ConfigFloatingDevices );

    foreach my $section ( keys %ConfigFloatingDevices ) {
        if ( defined( $ConfigFloatingDevices{$section}{"trunkPort"} )
            && $ConfigFloatingDevices{$section}{"trunkPort"} =~ /^\s*(y|yes|true|enabled|1)\s*$/i )
        {
            $ConfigFloatingDevices{$section}{"trunkPort"} = '1';
        }
        else {
            $ConfigFloatingDevices{$section}{"trunkPort"} = '0';
        }
    }

    return \%ConfigFloatingDevices;

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

