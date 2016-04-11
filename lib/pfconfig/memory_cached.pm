package pfconfig::memory_cached;

=head1 NAME

pfconfig::memory_cached

=cut

=head1 DESCRIPTION

pfconfig::memory_cached

This module is used to compute values and tie them to a pfconfig namespace so they are only created when the pfconfig namespace gets updated

This stores the objects in memory (subcache) and flushes them whenever the pfconfig namespace its tied to expires

=cut

=head1 USAGE

=cut

use strict;
use warnings;

use pf::log;
use pfconfig::cached;
our @ISA = ( 'pfconfig::cached' );

=head2 init

Constructor

=cut

sub init {
    my ( $self, $namespace ) = @_;

    $self->{"_namespace"} = $namespace;
    $self->{"_control_file_path"} = pfconfig::util::control_file_path($namespace);

    return $self;
}

=head2 compute

Compute a key using the subcache
Should the pfconfig namespace have expired, the subcache will fail, meaning we will rebuild.

=cut

sub compute {
    my ( $self, $key, $sub ) = @_;
    my $logger = $self->logger;

    my $result = $self->compute_from_subcache($key, sub {
        return $sub->();
    });

    return $result;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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


