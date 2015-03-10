package pfconfig::backend::memcached;

=head1 NAME

pfconfig::backend::memcached;

=cut

=head1 DESCRIPTION

pfconfig::backend::memcached;

Defines the Memcached backend to use as a layer 2 cache

=cut

use strict;
use warnings;

use base 'pfconfig::backend';
use Cache::Memcached;

sub init {
    my ($self) = @_;
    $self->{cache} = new Cache::Memcached { 'servers' => ['127.0.0.1:11211'] };
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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

