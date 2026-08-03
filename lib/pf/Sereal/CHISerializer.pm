package pf::Sereal::CHISerializer;

=head1 NAME

pf::Sereal::CHISerializer - CHI value serializer backed by pf::Sereal

=cut

=head1 DESCRIPTION

pf::Sereal::CHISerializer

A drop-in CHI serializer (an object exposing C<serialize>/C<deserialize>) that
encodes with the freeze-aware encoder and, crucially, decodes through
L<pf::Sereal/sereal_decode_safe> so a CHI backend will only ever run C<THAW>
on the classes listed in C<%pf::Sereal::ALLOWED_THAW>.

It exists because L<Data::Serializer::Sereal> insists on a bare
C<Sereal::Decoder> instance and calls C<THAW> unconditionally, which leaves no
seam to restrict which classes get deserialized.

=cut

use strict;
use warnings;
use Sereal::Encoder qw(sereal_encode_with_object);
use pf::Sereal qw($ENCODER_FREEZER sereal_decode_safe);

sub new {
    my ($proto) = @_;
    my $class = ref($proto) || $proto;
    return bless({}, $class);
}

=head2 serialize($value)

Encode a value the same way the rest of pfconfig does (freeze callbacks on).

=cut

sub serialize {
    my ($self, $value) = @_;
    return sereal_encode_with_object($ENCODER_FREEZER, $value);
}

=head2 deserialize($blob)

Decode using the restricted decoder, reconstructing only allow-listed classes.

=cut

sub deserialize {
    my ($self, $blob) = @_;
    return sereal_decode_safe($blob);
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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
