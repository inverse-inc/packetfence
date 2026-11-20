#!/usr/bin/perl

=head1 NAME

16.0-add-smsapi-source-to-portal-modules

=head1 DESCRIPTION

unit test for to-16.0-add-smsapi-source-to-portal-modules

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}
use pf::file_paths qw($install_dir);
require "$install_dir/addons/upgrade/to-16.0-add-smsapi-source-to-portal-modules.pl";
use Test::More tests => 11;

#This test will running last
use Test::NoWarnings;

{
    my ($cs, $updated) = addSMSApiSource("$install_dir/t/data/update-16.0/portal_modules.conf");
    ok($cs, "portal modules updated");
    is_deeply($updated, [qw(default_guest_policy sms_only twilio_clickatell)], "Only the sections listing an SMS source without SMSApi are updated");
    is(
        $cs->val('default_guest_policy', 'multi_source_object_classes'),
        'pf::Authentication::Source::ClickatellSource,pf::Authentication::Source::EmailSource,pf::Authentication::Source::SMSSource,pf::Authentication::Source::SMSApiSource,pf::Authentication::Source::TwilioSource,pf::Authentication::Source::SponsorEmailSource,pf::Authentication::Source::NullSource',
        "SMSApiSource is inserted right after SMSSource, like the shipped default"
    );
    is(
        $cs->val('twilio_clickatell', 'multi_source_object_classes'),
        'pf::Authentication::Source::TwilioSource,pf::Authentication::Source::ClickatellSource,pf::Authentication::Source::SMSApiSource,pf::Authentication::Source::EmailSource',
        "Without SMSSource, SMSApiSource is inserted after the last SMS source class"
    );
    is(
        $cs->val('sms_only', 'multi_source_object_classes'),
        'pf::Authentication::Source::SMSSource,pf::Authentication::Source::SMSApiSource',
        "SMSApiSource is appended after a lone SMS source class"
    );
    is(
        $cs->val('no_sms', 'multi_source_object_classes'),
        'pf::Authentication::Source::EmailSource,pf::Authentication::Source::NullSource',
        "A list without an SMS source class is left alone"
    );
}

{
    my ($cs, $updated) = addSMSApiSource("$install_dir/t/data/update-16.0/portal_modules_nothing_to_be_done.conf");
    is($cs, undef, "Nothing to do");
    is($updated, undef, "Nothing updated");
}

{
    my ($cs, $updated) = addSMSApiSource("$install_dir/t/data/update-16.0/does-not-exist.conf");
    is($cs, undef, "Missing file: nothing to do");
    is($updated, undef, "Missing file: nothing updated");
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
