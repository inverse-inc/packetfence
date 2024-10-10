package fingerbank::NullCache;

=head1 NAME

fingerbank::NullCache

=head1 DESCRIPTION

Default Fingerbank cache.

Will always miss.

=cut

use fingerbank::Constant qw($TRUE);

=head1 METHODS

=head2 new

Instantiate a new cache object

=cut

sub new {
    my ($class) = @_;
    my $self = bless {}, $class;
    $self->{dummy} = $TRUE;
    return $self;
}

=head2 get

Get a key from the cache
Always misses

=cut

sub get {return undef;}

=head2 set

Set a key in the cache

=cut

sub set {return undef;}

=head2 remove

Remove a key from the cache

=cut

sub remove {return undef;}

=head2 compute

Compute a value from the cache
Always misses and will always execute the computing method

=cut

sub compute {
    my ($self, $key, $fct) = @_;
    return $fct->();
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
