#!/usr/bin/perl

=head1 NAME

Sereal

=head1 DESCRIPTION

unit test for pf::Sereal, in particular the restricted decoder
(sereal_decode_safe) which only reconstructs allow-listed THAW classes.

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Adds lib and lib_perl to @INC (does not start pfconfig)
    use test_paths;
}

use Test::More;
use CHI;
use Sereal::Encoder qw(sereal_encode_with_object);
use pf::Sereal qw($ENCODER_FREEZER %ALLOWED_THAW sereal_decode_safe);
use pf::Sereal::CHISerializer;

# A class we explicitly allow to be thawed
{
    package t::Good;
    sub new   { my ($c, $v) = @_; bless \$v, $c }
    sub FREEZE { my $s = shift; return $$s }
    sub THAW   { my ($c, $ser, $data) = @_; return bless \$data, "t::Good::Reified" }
}

# A class that must never be thawed through the safe decoder
our $EVIL_THAW_RAN = 0;
{
    package t::Evil;
    sub new    { my ($c, $v) = @_; bless \$v, $c }
    sub FREEZE { my $s = shift; return $$s }
    sub THAW   { $main::EVIL_THAW_RAN = 1; die "EVIL THAW RAN!" }
}

# A plain blessed object with no FREEZE/THAW hook
{
    package t::Plain;
    sub new { bless { n => 5 }, shift }
}

$ALLOWED_THAW{'t::Good'} = 1;

# --- default allow-list -----------------------------------------------------
ok($ALLOWED_THAW{'pf::config::crypt::object'},
    "pf::config::crypt::object is allow-listed by default");

# --- plain data round-trips -------------------------------------------------
{
    my $in  = { a => [1, 2, 3], b => "str", c => { d => undef } };
    my $out = sereal_decode_safe(sereal_encode_with_object($ENCODER_FREEZER, $in));
    is_deeply($out, $in, "plain data round-trips through sereal_decode_safe");
}

# --- ordinary blessed object passes through untouched -----------------------
{
    my $out = sereal_decode_safe(
        sereal_encode_with_object($ENCODER_FREEZER, { o => t::Plain->new }));
    is(ref($out->{o}), "t::Plain", "non-FREEZE blessed object passes through");
    is($out->{o}{n}, 5, "  ... with its contents intact");
}

# --- allow-listed object is reconstructed, including when nested ------------
{
    my $in = {
        top  => t::Good->new("token"),
        list => [1, { deep => t::Good->new("z") }],
    };
    my $out = sereal_decode_safe(sereal_encode_with_object($ENCODER_FREEZER, $in));
    is(ref($out->{top}), "t::Good::Reified", "allow-listed object reconstructed");
    is(${ $out->{top} }, "token", "  ... with the right value");
    is(${ $out->{list}[1]{deep} }, "z", "nested allow-listed object reconstructed");
    is($out->{list}[0], 1, "sibling plain data preserved");
}

# --- allow-listed object nested inside a *blessed* object -------------------
# This mirrors real config: an encrypted value lives inside a blessed
# authentication source object. The walk must descend into blessed containers.
{
    my $source = t::Plain->new;
    $source->{password} = t::Good->new("hunter2");
    my $out = sereal_decode_safe(
        sereal_encode_with_object($ENCODER_FREEZER, { src => $source }));
    is(ref($out->{src}), "t::Plain", "blessed container stays blessed");
    is(ref($out->{src}{password}), "t::Good::Reified",
        "allow-listed object nested in blessed object is reconstructed");
    is(${ $out->{src}{password} }, "hunter2", "  ... with the right value");
}

# --- disallowed object is refused and its THAW never runs -------------------
{
    local $EVIL_THAW_RAN = 0;
    my $blob = sereal_encode_with_object($ENCODER_FREEZER, { bad => t::Evil->new("pwn") });
    my $ok = eval { sereal_decode_safe($blob); 1 };
    ok(!$ok, "disallowed class makes sereal_decode_safe die");
    like($@, qr/refusing to THAW disallowed class 't::Evil'/,
        "  ... with the expected error message");
    is($EVIL_THAW_RAN, 0, "disallowed class THAW was never invoked");
}

# --- CHISerializer enforces the same rules through a real CHI cache ---------
{
    my $cache = CHI->new(
        driver     => "Memory",
        datastore  => {},
        serializer => pf::Sereal::CHISerializer->new,
    );

    $cache->set("good", { admin => t::Good->new("secret"), meta => [1, 2] });
    my $v = $cache->get("good");
    is(ref($v->{admin}), "t::Good::Reified", "CHISerializer reconstructs allow-listed object on get");
    is(${ $v->{admin} }, "secret", "  ... with the right value");
    is_deeply($v->{meta}, [1, 2], "  ... and preserves sibling data");

    local $EVIL_THAW_RAN = 0;
    $cache->set("bad", { x => t::Evil->new("pwn") });
    my $ok = eval { $cache->get("bad"); 1 };
    ok(!$ok, "CHISerializer refuses disallowed class on get");
    is($EVIL_THAW_RAN, 0, "  ... without invoking its THAW");
}

done_testing();

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
