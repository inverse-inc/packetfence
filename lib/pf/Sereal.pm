package pf::Sereal;

=head1 NAME

pf::Sereal - Global package for Sereal Encoder/Decoder

=cut

=head1 DESCRIPTION

pf::Sereal

=cut

use strict;
use warnings;
use Sereal::Encoder;
use Sereal::Decoder qw(sereal_decode_with_object);
use Scalar::Util qw(reftype);
use base qw(Exporter);

our @EXPORT_OK = qw($ENCODER $DECODER $ENCODER_FREEZER $DECODER_SAFE %ALLOWED_THAW sereal_decode_safe);

our $ENCODER = Sereal::Encoder->new();
our $ENCODER_FREEZER = Sereal::Encoder->new({ freeze_callbacks => 1});
our $DECODER = Sereal::Decoder->new;

=head2 $DECODER_SAFE

A restricted decoder used to deserialize data coming from a less-trusted
boundary (network sockets, the queue, the database).

It is created with C<no_thaw_objects> so it B<never> invokes an object's
C<THAW> method on its own. Instead, each frozen object is returned as a
C<Sereal::Decoder::THAW_args> placeholder (a blessed array ref whose leading
elements are the C<FREEZE> arguments and whose last element is the target
class name). L</sereal_decode_safe> walks the decoded structure and only
reconstructs the classes explicitly listed in L</%ALLOWED_THAW>, turning an
otherwise arbitrary C<< $class->THAW(...) >> gadget into an allow-listed
operation.

=cut

our $DECODER_SAFE = Sereal::Decoder->new({ no_thaw_objects => 1 });

=head2 %ALLOWED_THAW

The set of class names L</sereal_decode_safe> is willing to run C<THAW> on.
Anything not listed here throws instead of being deserialized into an object.

=cut

our %ALLOWED_THAW = (
    'pf::config::crypt::object' => 1,
);

=head2 CLONE

Reinitialize ENCODER/DECODER when a new thread is created

=cut

sub CLONE {
    $ENCODER = Sereal::Encoder->new;
    $DECODER = Sereal::Decoder->new;
    $ENCODER_FREEZER = Sereal::Encoder->new({ freeze_callbacks => 1});
    $DECODER_SAFE = Sereal::Decoder->new({ no_thaw_objects => 1 });
}

=head2 sereal_decode_safe($blob)

Decode a Sereal C<$blob> using L</$DECODER_SAFE> and reconstruct any frozen
objects, but only for the classes listed in L</%ALLOWED_THAW>. Encountering a
frozen object of any other class is fatal. Returns the decoded structure.

=cut

sub sereal_decode_safe {
    my ($blob) = @_;
    my $data;
    sereal_decode_with_object($DECODER_SAFE, $blob, $data);
    return _thaw_allowlisted($data, {});
}

# Recursively walk a structure decoded with $DECODER_SAFE, replacing every
# Sereal::Decoder::THAW_args placeholder with the real object -- but only when
# its target class is allow-listed. We descend into the guts of blessed
# objects too, because allow-listed frozen values (e.g. encrypted config
# fields) legitimately appear nested inside blessed config objects such as
# authentication sources.
sub _thaw_allowlisted {
    my ($node, $seen) = @_;
    return $node unless ref $node;
    return $node if $seen->{$node}++;    # guard against cycles

    if (ref($node) eq 'Sereal::Decoder::THAW_args') {
        my @args   = @$node;
        my $target = pop @args;
        unless ($ALLOWED_THAW{$target}) {
            die "pf::Sereal: refusing to THAW disallowed class '$target'\n";
        }
        # Thaw inner objects first (matches Sereal's LIFO thaw ordering).
        $_ = _thaw_allowlisted($_, $seen) for @args;
        return $target->THAW("Sereal", @args);
    }

    my $reftype = reftype($node);
    if ($reftype eq 'ARRAY') {
        $_ = _thaw_allowlisted($_, $seen) for @$node;
    }
    elsif ($reftype eq 'HASH') {
        $_ = _thaw_allowlisted($_, $seen) for values %$node;
    }
    elsif ($reftype eq 'SCALAR' || $reftype eq 'REF') {
        $$node = _thaw_allowlisted($$node, $seen);
    }
    return $node;
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
