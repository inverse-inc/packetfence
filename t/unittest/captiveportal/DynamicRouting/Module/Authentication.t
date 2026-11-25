#!/usr/bin/perl

=head1 NAME

Authentication

=head1 DESCRIPTION

Fields of the person saved by the portal authentication modules

=cut

use strict;
use warnings;
BEGIN {
    use lib qw(/usr/local/pf/t /usr/local/pf/html/captive-portal/lib);
    use setup_test_config;
}

use Test::More tests => 7;
use Test::NoWarnings;
use pf::person;

use_ok('captiveportal::PacketFence::DynamicRouting::Module::Authentication');

# A module whose collected fields are fixed
{
    package test_module;
    our @ISA = ('captiveportal::PacketFence::DynamicRouting::Module::Authentication');
    sub new { bless {}, shift }
    sub required_fields { [qw(aup email firstname)] }
    sub custom_fields { [qw(custom_field_1)] }
    sub fields_to_save { [qw(company)] }
}

my $module = test_module->new;

is_deeply(
    $module->person_fields(
        {
            email          => 'guest@example.com',
            firstname      => 'Guest',
            custom_field_1 => 'custom',
            company        => 'Company',
            lastname       => 'not collected',
            psk            => 'psk',
            potd           => 'yes',
            otp            => 'otp',
            sponsored_date => '2026-01-01 00:00:00',
            password       => 'password',
            aup            => 1,
        },
        1
    ),
    {
        email          => 'guest@example.com',
        firstname      => 'Guest',
        custom_field_1 => 'custom',
        company        => 'Company',
    },
    'only the collected person fields of the request are saved'
);

is_deeply(
    $module->person_fields({ lastname => 'Saved', otp => 'otp', mobileprovider => 1 }),
    { lastname => 'Saved' },
    'saved fields keep the person fields that can be prompted for'
);

ok(
    !(grep { exists $pf::person::ALLOWED_PROMPTABLE_FIELDS{$_} } qw(pid sponsor portal source psk potd otp sponsored_date)),
    'psk, potd, otp and sponsored_date cannot be prompted for'
);

ok(
    (scalar grep { exists $pf::person::ALLOWED_PROMPTABLE_FIELDS{$_} } qw(firstname email telephone custom_field_1 notes)) == 5,
    'the other person fields can still be prompted for'
);

# A module whose configuration still has fields that can't be prompted for in its custom fields
{
    package test_profile;
    sub reuseDot1xCredentials { 'disabled' }

    package test_app;
    sub new { bless { session => {} }, shift }
    sub profile { 'test_profile' }
    sub session { $_[0]{session} }

    package test_module_custom_fields;
    our @ISA = ('captiveportal::PacketFence::DynamicRouting::Module::Authentication');
    sub new { bless {}, shift }
    sub app { test_app->new }
    sub source { undef }
    sub pid_field { 'email' }
    sub with_aup { 0 }
    sub required_fields_child { [] }
    sub custom_fields { [qw(firstname psk otp potd sponsored_date)] }
}

is_deeply(
    test_module_custom_fields->new->_build_required_fields,
    [qw(email firstname)],
    'the custom fields that cannot be prompted for are ignored'
);

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
