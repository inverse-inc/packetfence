#!/usr/bin/perl

=head1 NAME

validator

=head1 DESCRIPTION

unit test for validator

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 7;

#This test will running last
use Test::NoWarnings;
{
    package validator1;
    use pf::validator::Moose;
    extends qw(pf::validator);
    has_field id => (
        required => 1,
    );

    __PACKAGE__->meta->make_immutable;
}

#is(scalar @validator1::_FIELDS, 1);
my $validator = validator1->new;
isa_ok($validator, 'pf::validator');

my $fields = $validator->_FIELDS;
is(@$fields, 1, "returned the proper number of fields");
is(scalar @validator1::_FIELDS, 1);

{
    my $errors = $validator->validate({});
    ok (scalar @$errors, "Validation failed");
    is_deeply ($errors, [{ field => 'id', message => 'is required' }], "Has errors");
}

{
    my $errors = $validator->validate({ id => undef});
    ok (scalar @$errors, "Validation failed");
    is_deeply ($errors, [{ field => 'id', message => 'is required' }], "Has errors");
}

{
    my $errors = $validator->validate({ id => 1 });
    is_deeply ($errors, [], "Validation passed");
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2021 Inverse inc.

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
