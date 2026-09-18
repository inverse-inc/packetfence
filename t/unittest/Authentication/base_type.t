#!/usr/bin/perl

=head1 NAME

base_type

=head1 DESCRIPTION

Unit test for pf::Authentication::Source::base_type.

`type` is the concrete source: FacebookSource is 'Facebook'. `base_type` is the
family it belongs to, taken from the class hierarchy rather than from a list
anyone has to maintain. That is the whole point -- a new OAuth provider is
classified the moment it is written, with nothing else to update.

=cut

use strict;
use warnings;

BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::More tests => 22;
use pf::authentication;

#This test will running last
use Test::NoWarnings;

my %EXPECTED = (
    # every OAuth provider collapses to the parent -- the case that matters
    Facebook            => 'OAuth',
    Github              => 'OAuth',
    Google              => 'OAuth',
    LinkedIn            => 'OAuth',
    OpenID              => 'OAuth',
    WindowsLive         => 'OAuth',
    # directory sources collapse to LDAP
    AD                  => 'LDAP',
    EDIR                => 'LDAP',
    GoogleWorkspaceLDAP => 'LDAP',
    # payment sources collapse to Billing
    Paypal              => 'Billing',
    Stripe              => 'Billing',
    # Kickbox is a NullSource subclass
    Kickbox             => 'Null',
    # sources with no intermediate parent report themselves
    Email               => 'Email',
    SMS                 => 'SMS',
    SponsorEmail        => 'SponsorEmail',
    Null                => 'Null',
    Potd                => 'Potd',
    SAML                => 'SAML',
    LDAP                => 'LDAP',
    # Twilio and Clickatell extend Source directly rather than SMSSource, even
    # though SMS.pm accepts all three interchangeably. Asserted as-is so that
    # re-parenting them later shows up here as a deliberate change.
    Twilio              => 'Twilio',
    Clickatell          => 'Clickatell',
);

for my $type (sort keys %EXPECTED) {
    my $module = $pf::authentication::TYPE_TO_SOURCE{ lc $type };
    is( $module && $module->base_type, $EXPECTED{$type},
        "$type has base type $EXPECTED{$type}" );
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

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA.

=cut

1;
