package pfconfig::backend::bdb;

=head1 NAME

pfconfig::backend::bdb;

=cut

=head1 DESCRIPTION

pfconfig::backend::bdb;

Defines the BDB backend to use as a layer 2 cache

=cut

use strict;
use warnings;

use base 'pfconfig::backend';
use Cache::BDB;
use pfconfig::empty_string;
use pf::file_paths qw($pfconfig_cache_dir);

sub init {
    my ($self) = @_;
    my %options = (
        cache_root         => $pfconfig_cache_dir,
        namespace          => "pfconfig",
        default_expires_in => 86400,
    );
    $self->{cache} = Cache::BDB->new(%options);
}

sub set {
    my ( $self, $key, $value ) = @_;

    # BDB doesn't write empty strings
    # We workaround it using a class that represents an empty string
    if ( defined($value) && "$value" eq '' ) {
        $value = pfconfig::empty_string->new;
    }
    $self->SUPER::set( $key, $value );
}

sub get {
    my ( $self, $key ) = @_;
    my $value = $self->SUPER::get($key);

    # BDB doesn't write empty strings
    # We workaround it using a class that represents an empty string
    if ( ref($value) eq "pfconfig::empty_string" && $value->isa("pfconfig::empty_string") ) {
        $value = '';
    }
    return $value;
}

=head2 list

List all the keys in the backend

=cut

sub list {
    my ( $self ) = @_;
    return keys %{ $self->{cache}->get_bulk() };
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

