package pfconfig::namespaces::resource;

=head1 NAME

pfconfig::namespaces:resource

=cut

=head1 DESCRIPTION

pfconfig::namespaces:resource

Abstract class representing a resource

=cut

=head1 USAGE

You can define a resource so it is accessible by the manager
by doing the following : 
- Subclass this class in pfconfig/namespaces/
- Add any additionnal initialization by overiding init
- Create the definition of the object using the build method

=cut

use strict;
use warnings;

sub new {
    my ( $class, $cache, @args ) = @_;
    my $self = bless {}, $class;

    $self->{cache} = $cache;

    $self->init(@args);

    return $self;
}

sub init {
}

sub build {
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

