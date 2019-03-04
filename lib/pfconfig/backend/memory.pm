package pfconfig::backend::memory;

=head1 NAME

pfconfig::backend::memory;

=cut

=head1 DESCRIPTION

pfconfig::backend::memory;

Defines a CHI Memory backend to use as a layer 2 cache

=cut

use strict;
use warnings;

use base 'pfconfig::backend';
use CHI;
use pfconfig::empty_string;

my $empty_string = pfconfig::empty_string->new;

=head2 init

initialize the cache

=cut

sub init {
    my ($self) = @_;
    $self->{cache} = CHI->new(driver => 'Memory', datastore => {},'serializer' => 'Sereal');
}

=head2 set

Set value in the CHI cache

=cut

sub set {
    my ( $self, $key, $value ) = @_;

    # There is an issue writing empty strings with CHI Memory driver
    # We workaround it using a class that represents an empty string
    if ( defined($value) && "$value" eq '' ) {
        $value = $empty_string;
    }
    $self->SUPER::set( $key, $value );
}

=head2 get

Get value from the CHI cache

=cut

sub get {
    my ( $self, $key ) = @_;
    my $value = $self->SUPER::get($key);

    # There is an issue writing empty strings with CHI Memory driver
    # We workaround it using a class that represents an empty string
    if ( ref($value) eq "pfconfig::empty_string" && $value->isa("pfconfig::empty_string") ) {
        $value = '';
    }
    return $value;
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

