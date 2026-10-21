#!/usr/bin/perl

=head1 NAME

SAMLSource

=head1 DESCRIPTION

unit test for SAMLSource

=cut

use strict;
use warnings;
#
BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 7;
use File::Temp qw(tempfile);
use pf::Authentication::Source::SAMLSource;

#This test will running last
use Test::NoWarnings;

my (undef, $readable) = tempfile(UNLINK => 1);

sub source {
    pf::Authentication::Source::SAMLSource->new({
        id => 'test',
        sp_entity_id => 'sp',
        idp_entity_id => 'idp',
        sp_key_path => $readable,
        sp_cert_path => $readable,
        idp_metadata_path => $readable,
        idp_cert_path => $readable,
        idp_ca_cert_path => '',
        username_attribute => 'urn:oid:0.9.2342.19200300.100.1.1',
        authorization_source_id => 'local',
        @_,
    });
}

ok(eval { source()->check_files_readable(); 1 }, "readable files and empty optional CA pass");

eval { source(sp_key_path => '/nonexistent/sp.key')->check_files_readable() };
like($@, qr{SAML source test: the Service Provider key file /nonexistent/sp\.key doesn't exist}, "missing SP key is reported");

eval { source(idp_metadata_path => '/nonexistent/idp.xml')->check_files_readable() };
like($@, qr{Identity Provider metadata file /nonexistent/idp\.xml}, "missing IdP metadata is reported");

eval { source(idp_cert_path => '/tmp')->check_files_readable() };
like($@, qr{Identity Provider certificate file /tmp }, "directory instead of a file is reported");

# Lasso::Server->new returns undef when the key can't be loaded
my $cert = '/usr/local/pf/t/data/server.crt';
my $key = '/usr/local/pf/t/data/server.key';
eval { source(sp_key_path => $cert, sp_cert_path => $cert)->lasso_server() };
like($@, qr{SAML source test: unable to load the Service Provider key \(\Q$cert\E\) and certificate}, "a certificate used as the SP key is reported");

eval { source(sp_key_path => $key, sp_cert_path => $cert)->lasso_server() };
like($@, qr{SAML source test: unable to load the Identity Provider metadata \(\Q$readable\E\)}, "invalid IdP metadata is reported");

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

#!/usr/bin/perl

=head1 NAME

SAMLSource

=head1 DESCRIPTION

unit test for the attributes of a SAML assertion in SAMLSource (#9371)

=cut

use strict;
use warnings;
#
BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 7;
use pf::Authentication::Source::SAMLSource;

#This test will running last
use Test::NoWarnings;

# The parts of a Lasso::Saml2Attribute that SAMLSource uses
{
    package FakeNode;
    sub new { my ($class, %args) = @_; bless {%args}, $class }
    sub Name { $_[0]{Name} }
    sub AttributeValue { $_[0]{AttributeValue} }
    sub any { $_[0]{any} }
    sub content { $_[0]{content} }
}

sub attribute {
    my ($name, $value) = @_;
    my $values;
    if (defined $value) {
        # <saml:AttributeValue/> has no content node
        $values = FakeNode->new(any => ($value eq '' ? undef : FakeNode->new(content => $value)));
    }
    return FakeNode->new(Name => $name, AttributeValue => $values);
}

my $source = pf::Authentication::Source::SAMLSource->new({
    id => 'saml_test',
    authorization_source_id => 'local',
    sp_key_path => '/dev/null',
    sp_cert_path => '/dev/null',
    sp_entity_id => 'sp',
    idp_cert_path => '/dev/null',
    idp_ca_cert_path => '/dev/null',
    idp_metadata_path => '/dev/null',
    idp_entity_id => 'idp',
    username_attribute => 'uid',
});

is($source->_attribute_value(attribute('uid', 'testuser')), 'testuser', "value of an attribute");
is($source->_attribute_value(attribute('mail', '')), undef, "empty AttributeValue");
is($source->_attribute_value(attribute('mail')), undef, "no AttributeValue");

is(
    $source->_username_from_attributes(attribute('mail', ''), attribute('department'), attribute('uid', 'testuser')),
    'testuser',
    "empty attributes do not prevent finding the username"
);
is($source->_username_from_attributes(attribute('mail', 'testuser@example.com')), undef, "no username attribute");
is($source->_username_from_attributes(attribute('uid', '')), undef, "empty username attribute");

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
