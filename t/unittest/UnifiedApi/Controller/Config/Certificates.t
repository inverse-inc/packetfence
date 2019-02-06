#!/usr/bin/perl

=head1 NAME

Nodes

=cut

=head1 DESCRIPTION

unit test for Certificates

=cut

use strict;
use warnings;
#
use lib '/usr/local/pf/lib';
use File::Slurp qw(read_file);
use pf::file_paths qw(
    $server_cert
    $server_key
);

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;

    `cp $pf::file_paths::server_cert $pf::file_paths::server_cert.tmp`;
    $pf::file_paths::server_cert = "$pf::file_paths::server_cert.tmp";
    
    `cp $pf::file_paths::server_key $pf::file_paths::server_key.tmp`;
    $pf::file_paths::server_key = "$pf::file_paths::server_key.tmp";
}

END {
    `rm $pf::file_paths::server_cert`;
    `rm $pf::file_paths::server_key`;
}

#insert known data
#run tests
use Test::More tests => 57;
use Test::Mojo;
use Test::NoWarnings;
my $t = Test::Mojo->new('pf::UnifiedApi');

$t->get_ok('/api/v1/config/certificate/http')
  ->status_is(200)
  ->json_is('/certificate/subject', "C=CA, ST=Quebec, L=Montreal, O=Inverse Inc., CN=pf.inverse.ca")
  ->json_is('/certificate/issuer', "C=CA, ST=Quebec, L=Montreal, O=Inverse Inc., CN=pf.inverse.ca")
  ->json_is('/chain_is_valid/success', 1)
  ->json_is('/cert_key_match/success', 1)
  ->json_is('/certificate/not_before', "Feb  6 15:35:02 2019 GMT")
  ->json_is('/certificate/not_after', "Feb  6 15:35:02 2020 GMT");


my $cert = read_file($server_cert);
my $key = read_file($server_key);

# Replacing by the valid existing ones should work fine
$t->put_ok("/api/v1/config/certificate/http" => json => { certificate => $cert, private_key => $key })
  ->status_is(200);

my $new_cert = <<EOT;
-----BEGIN CERTIFICATE-----
MIIDVzCCAj+gAwIBAgIJAPU3hXnJhgNfMA0GCSqGSIb3DQEBCwUAMEIxCzAJBgNV
BAYTAlhYMRUwEwYDVQQHDAxEZWZhdWx0IENpdHkxHDAaBgNVBAoME0RlZmF1bHQg
Q29tcGFueSBMdGQwHhcNMTkwMjA2MjAzNTU3WhcNMjAwMjA2MjAzNTU3WjBCMQsw
CQYDVQQGEwJYWDEVMBMGA1UEBwwMRGVmYXVsdCBDaXR5MRwwGgYDVQQKDBNEZWZh
dWx0IENvbXBhbnkgTHRkMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA
wc2ju74NhGuW/tx91KGH93VT09ukC9zkoIef4tRzHcfrVPPl5j3Yk+9vb3kfPiMO
Sk+TivgihbJLVTg5ATxzU0DeCxOg/umG7gxrv5SmSA0yc/gJFbLsJItpHPmSL5Iy
aOnSEMFkSNE6dKxuSexYtT040wAmOcpz0JQPDkLig5Z3D7pOAEMKZofaN2NZgEFe
STECIUaBwfO9/TM9L9azJcv1n4SKxwqW38KGwZ6bSfRJBElWWxRXMI9/r2vTFjTM
+ltN3YrM3T4QMlGr3PTalG46qPh/92sIid4MS1ZukgRPCSLeSSL3Pmj0HyAHdK69
yj65BhuWk5Q+yCiole7STwIDAQABo1AwTjAdBgNVHQ4EFgQUg0R3WmuZOW5YnGHg
FYcg7OpQvdMwHwYDVR0jBBgwFoAUg0R3WmuZOW5YnGHgFYcg7OpQvdMwDAYDVR0T
BAUwAwEB/zANBgkqhkiG9w0BAQsFAAOCAQEAa/s98r0RPAoVmYZTdBrZOlbWkr/7
17eDE3Eg32I4dqnpJfNz8jrUSwSRFYITWT6nzS24GjZenrm63SLhXvNnGljtFLUZ
mTSR4uApImAyf7E/3w2nEfLiHkbEOB0XPxdoaTvptmmg7tomGbi7fC9Z+QjFiVzL
x3vGiHNmF4p0pCggYE95n3QXK/sbpF65cn7oJZ+bSlUfpqpMUYHGSccO38dm/OJx
wnNtcDy3e7pfFS2u6ouiEYzFx6jRpZedzxatGi/DzuFpHGX+C4tklriC0oLqbLfh
7mJOn4HYGAsn2bjUsZ4JMgJkmqM9n1bbUvwKYiy7girIIA59QGRN3KbqHA==
-----END CERTIFICATE-----
EOT

my $new_key = <<EOT;
-----BEGIN PRIVATE KEY-----
MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQDBzaO7vg2Ea5b+
3H3UoYf3dVPT26QL3OSgh5/i1HMdx+tU8+XmPdiT729veR8+Iw5KT5OK+CKFsktV
ODkBPHNTQN4LE6D+6YbuDGu/lKZIDTJz+AkVsuwki2kc+ZIvkjJo6dIQwWRI0Tp0
rG5J7Fi1PTjTACY5ynPQlA8OQuKDlncPuk4AQwpmh9o3Y1mAQV5JMQIhRoHB8739
Mz0v1rMly/WfhIrHCpbfwobBnptJ9EkESVZbFFcwj3+va9MWNMz6W03diszdPhAy
Uavc9NqUbjqo+H/3awiJ3gxLVm6SBE8JIt5JIvc+aPQfIAd0rr3KPrkGG5aTlD7I
KKiV7tJPAgMBAAECggEAJ++5WtnKLUyCfBhxsZxryVmbIaA0SOGHF3F7SCHhavSk
kQgFixGZjLqdawo5nvNYYYXOcKe7bXOVRIVmcdPELBbE6uFrnrv+uxVCKuN19IkL
qYwmSxtowAseaQMg1b65tpbgW+WORdcfxaU2wPL8QLTR/eEc/3GxtfycsaKkzNqb
hkvqEj8KWYkYdMz8LV/SxLRgbP2yNoVbUHvHsyoM93bE5wLG24v44SOUNrUIt2SW
6oqizx8JGg7l7AwwAIFjzrf/2kx167fC6LIrZ3MZXkw6NaueB7MrAFXbbol9b29Q
bEw5V4ZOsdL5Ffgna8VdheeRUU7vGr5/ZPXogx0RKQKBgQD1sZm/gwT/vXVOnkky
jdYOkRIEQJgThd7sddpOsL8n1JLdaKff2IqtnRWH1INsvf6ilxaYpq5G38Hlod18
lI2ar8f+/WUQhN1iY1BDw2f/Z10BButw4lGMy4vJkULmOb8CPGnutRds49x+HXCm
b5/F7YzxU+E9aTBls/Wyjnk7NQKBgQDJ7s8/Yg6yhfn/XSyPC9H0gx4UUITk7sSo
K3wvqwSCjMTGI6WQtZ24hcpB0PiKkdlcqp+7JnWkK5LbkNLmjvjCCDu4h8TUK2Hc
fQnb7YZlSBF2QYyx6G+C16Yu2oLrEZuSOUVUlJBECyrgooWOBchom17c0MLcdeYq
3Xevs8ID8wKBgQCybToEtLeqqgJJB/aMeijcB0qYP/ixJOVRv/y8bOtFl8DYfip8
C5wanRuHuzN+gzQrC6JjVZj264S6qSRaVt/HWKTbb1Y3+uVzkEA4Fe6usnf+SPIu
1oz2vNNVnOKCo6ktjIY5ztWmRIxaIjMvC51ydiOHFq1alcuJ8HkcJQ+xiQKBgAJ0
qgaOTbl0Eac+XdVbgnEjyxDaLdOO58tXxAncXZCs35O9ST0qSEG/Nsd4IB2nSmpr
FMg03odhlEahSz9Mi8/oQ7mpxQYDhQwmZSFMkS7YIoY6o9hiCEEiGD5HoAH109uC
YMp3iA2bySi0MUWZ4mcLRKsQyt3dfTAWQ2dam0hrAoGBAL/cMrigwk99an9eFzHY
RmofafcxncWvDK+bZyknUkasN9VwQXQgIrszL0n4f1xoH8V7ikEnfmT7eDNqkBZa
R5Xt45s830Mhv+lEGaj2MZ9WapNKaA46CYVKPkHJo9X2YhCGZNLyoKouvL8vjMGR
CGIv2v3Q4mmh7woZMQeIKHwT
-----END PRIVATE KEY-----
EOT

# Replacing by a new cert for a different key shouldn't be valid
$t->put_ok("/api/v1/config/certificate/http" => json => { certificate => $new_cert, private_key => $key })
    ->status_is(422);

# Replacing by a new key that doesn't match the cert shouldn't be valid
$t->put_ok("/api/v1/config/certificate/http" => json => { certificate => $cert, private_key => $new_key })
    ->status_is(422);

# Replacing with a new self-signed should be valid
$t->put_ok("/api/v1/config/certificate/http" => json => { certificate => $new_cert, private_key => $new_key })
    ->status_is(200);

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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
