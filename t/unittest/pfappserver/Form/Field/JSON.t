#!/usr/bin/perl

=head1 NAME

JSON

=head1 DESCRIPTION

unit test for JSON

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

use Test::More tests => 3;
use pfappserver::Form::Field::JSON;

{
    package Form::Test;
    use HTML::FormHandler::Moose;
    extends 'HTML::FormHandler';
    has_field json => (
        type => '+pfappserver::Form::Field::JSON',
        required => 1,
    ); 
}

#This test will running last
use Test::NoWarnings;

{
    my $form = Form::Test->new;
    $form->process(params => {json => '{'}, posted => 1);
    ok($form->has_errors(), "Invalid JSON");
}

{
    my $form = Form::Test->new;
    $form->process(params => {json => '{}'}, posted => 1);
    ok(!$form->has_errors(), "Valid JSON");
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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

