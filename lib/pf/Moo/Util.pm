package pf::Moo::Util;
=head1 NAME

pf::Moo::Isa add documentation

=cut

=head1 DESCRIPTION

pf::Moo::Isa

=cut

use strict;
use warnings;
use Scalar::Util();
use List::MoreUtils();
use base qw(Exporter);

our @EXPORT = qw(Str Num Class Bool ArrayRef Val Maybe HashRef Int);

=head2 _new_array

=cut

sub _new_array { [] }

=head2 NewArray

=cut

sub NewArray { \&_new_array }

=head2 Num

=cut

sub Num { \&Scalar::Util::looks_like_number }

=head2 _isa_int

=cut

sub _isa_int {
    my $num = $_[0];
    return Scalar::Util::looks_like_number($num) && $num =~ /[+-]?\d+/;
}

=head2 Int

=cut

sub Int { \&_isa_int }

=head2 _isa_string

=cut

sub _isa_string { ref($_[0]) eq '' }

=head2 Str

=cut

sub Str { \&_isa_string  }

=head2 Class

=cut

sub Class { my $class = $_[0]; sub { $class->isa($_[0]) } }

=head2 _isa_boolean

=cut

sub _isa_boolean { my $b = $_[0]; ! $b || $b == 1 }

=head2 Bool

=cut

sub Bool { \&_isa_boolean }

=head2 _isa_array_ref

=cut

sub _isa_array_ref { ref($_[0]) eq 'ARRAY' }

=head2 ArrayRef

=cut

sub ArrayRef(;$) {
    if (@_) {
        my $code = $_[0];
        return sub { ref($_[0]) eq 'ARRAY' && List::MoreUtils::all { &$code($_) } @{$_[0]}  };
    } else {
        return \&_isa_array_ref;
    }
}

=head2 _isa_hash_ref

=cut

sub _isa_hash_ref { ref($_[0]) eq 'HASH' }

=head2 HashRef

=cut

sub HashRef(;$) {
    if (@_) {
        my $code = $_[0];
        return sub { ref($_[0]) eq 'HASH' && List::MoreUtils::all { &$code($_) } values %{$_[0]} };
    } else {
        return \&_isa_hash_ref;
    }
}

=head2 Val

=cut

sub Val { my $val = $_[0]; sub {$val} }

=head2 Maybe

=cut

sub Maybe($) { my $checker = $_[0];  sub { !defined $_[0] || $checker->($_[0])  } }

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and::or
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

