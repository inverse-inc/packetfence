#!/usr/bin/perl

=head1 NAME

CIDR

=head1 DESCRIPTION

unit test for CIDR

=cut

use strict;
use warnings;
#
use lib '/usr/local/pf/lib';

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 12;
use pfappserver::Form::Field::CIDR;

{
    package Form::Test;
    use HTML::FormHandler::Moose;
    extends 'HTML::FormHandler';
    has_field cidr => (
        type => '+pfappserver::Form::Field::CIDR',
        required => 1,
    );
}

#This test will running last
use Test::NoWarnings;

my @valid = qw(
    192.168.1.0/24
    10.0.0.0/8
    0.0.0.0/0
    172.16.5.4/32
);

my @invalid = (
    '192.168.1.0',      # missing prefix
    '192.168.1.0/33',   # prefix out of range
    '999.168.1.0/33',   # prefix out of range
    '192.168.1.0/',     # empty prefix
    '2001:db8::/32',    # IPv6 not accepted
    'not-an-ip/24',     # invalid address
    '192.168.1.0/24/1', # more than one slash
);

for my $value (@valid) {
    my $form = Form::Test->new;
    $form->process(params => {cidr => $value}, posted => 1);
    ok(!$form->has_errors(), "Valid CIDR $value");
}

for my $value (@invalid) {
    my $form = Form::Test->new;
    $form->process(params => {cidr => $value}, posted => 1);
    ok($form->has_errors(), "Invalid CIDR $value");
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
