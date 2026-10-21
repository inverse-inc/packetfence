#!/usr/bin/perl

=head1 NAME

crypt

=head1 DESCRIPTION

unit test for crypt

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 4;

#This test will running last
use Test::NoWarnings;
use pf::config::crypt;
use Devel::Peek ();
use File::Temp ();
my $str = qq[~`qwertyuiop[]asdfghjkl;'\\zxcvbnm,./1234567890-=!@#$%^&*()_+] x 3;
ok ($str eq pf::config::crypt::pf_decrypt(pf::config::crypt::pf_encrypt($str)), "Checking $str");
$str = '0123456789ABCDEF' x 3;
ok ($str eq pf::config::crypt::pf_decrypt(pf::config::crypt::pf_encrypt($str)), "Checking $str");

# gcm_decrypt_verify returns a buffer without a NUL terminator. Comparing with
# eq does not catch it, since that uses the length. Consumers handing the value
# to a C API expecting a C string do read past the end, so check the buffer
# itself.
ok (pv_is_nul_terminated(pf::config::crypt::pf_decrypt(pf::config::crypt::pf_encrypt('0123456789abcdef'))),
    "Decrypted value is NUL terminated");

sub pv_is_nul_terminated {
    my ($sv) = @_;
    my $tmp = File::Temp->new();
    open(my $olderr, '>&', \*STDERR) or die "dup STDERR: $!";
    open(STDERR, '>&', $tmp) or die "redirect STDERR: $!";
    Devel::Peek::Dump($sv);
    open(STDERR, '>&', $olderr) or die "restore STDERR: $!";
    open(my $fh, '<', $tmp->filename) or die "read dump: $!";
    local $/ = undef;
    my $dump = <$fh>;
    close($fh);
    return scalar($dump =~ /^\s*PV = 0x[0-9a-f]+ ".*"\\0\s*$/m);
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
