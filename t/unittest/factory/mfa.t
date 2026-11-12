#!/usr/bin/perl

=head1 NAME

mfa

=head1 DESCRIPTION

unit test for pf::factory::mfa

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 13;

#This test will running last
use Test::NoWarnings;
use pf::config qw(%ConfigMfa);
use pf::factory::mfa;

{
    my $mfa = eval { pf::factory::mfa->new('no-such-mfa') };
    is($@, '', "an unknown MFA does not die");
    is($mfa, undef, "an unknown MFA is undef");
    ok(!exists $ConfigMfa{'no-such-mfa'}, "an unknown MFA is not added to the MFA config");
    is(pf::factory::mfa->new(undef), undef, "an undefined name is undef");
}

{
    # t/data has no mfa.conf: swap the MFA config
    my %config = (
        totp       => { type => 'TOTP', radius_mfa_method => 'strip-otp' },
        no_type    => { radius_mfa_method => 'strip-otp' },
        bad_type   => { type => 'NoSuchType' },
    );
    no warnings qw(once redefine);
    local *pf::factory::mfa::ConfigMfa = \%config;
    my $mfa = pf::factory::mfa->new('totp');
    isa_ok($mfa, 'pf::mfa::TOTP');
    is($mfa->id, 'totp', "a configured MFA gets its id");
    is($mfa->radius_mfa_method, 'strip-otp', "a configured MFA gets its config");
    ok(!exists $config{totp}{id}, "the id is not added to the shared MFA config");

    for my $name (qw(no_type bad_type)) {
        my $bad = eval { pf::factory::mfa->new($name) };
        is($@, '', "$name: does not die");
        is($bad, undef, "$name: is undef");
    }
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
