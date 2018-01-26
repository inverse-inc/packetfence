#!/usr/bin/perl

=head1 NAME

Provisioning

=cut

=head1 DESCRIPTION

unit test for Provisioning

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
our @INVALID_INPUT;

BEGIN {
    @INVALID_INPUT = (
        {
            in  => {},
            msg => "Empty input",
        },
        {
            in  => { id => 'bob' },
            msg => "Only ID",
        },
        {
            in  => { description => 'bob' },
            msg => "Only description",
        },
        {
            in  => { garbage => 'bob' },
            msg => "Garbage input",
        },
    );
}

use pfappserver::Form::Config::Provisioning;

use Test::More tests => 4 + scalar @INVALID_INPUT;

#This test will running last
use Test::NoWarnings;
my $form  = pfappserver::Form::Config::Provisioning->new();
#This is the first test
ok ($form, "Create a new form");

ok (ref $form->roles eq 'ARRAY', "Roles attribute is set");

ok (ref $form->violations eq 'ARRAY', "Violations attribute is set");

{

    for my $test (@INVALID_INPUT) {
        $form = pfappserver::Form::Config::Provisioning->new();
        $form->process(params => $test->{in}, posted => 1);
        ok($form->has_errors(), $test->{msg});
    }
}

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

