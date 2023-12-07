#!/usr/bin/perl -w

use strict;
use warnings;
use diagnostics;

use lib 'lib';
use lib 't';

use Test::More;

BEGIN {
    use setup_tests qw(-seed);
    use data::seed;
}

use fingerbank::Util qw(is_success);

use_ok('fingerbank::Model::Device');

my @objects = fingerbank::Model::Device->all();

ok(scalar(@objects) == 4,
    "Amount of objects is right when calling CRUD::all on all schemas.");

my $i = 0;
foreach my $all_device (@objects){
    ok(ref($all_device) eq "fingerbank::Base::Schema::Device",
        "Result $i returned by CRUD::all is of the proper type");
    $i++;
}

@objects = fingerbank::Model::Device->all('Local');

ok(scalar(@objects) == 3,
    "Amount of objects is right when calling CRUD::all on Local schema");

@objects = fingerbank::Model::Device->all('Upstream');

ok(scalar(@objects) == 1,
    "Amount of objects is right when calling CRUD::all on Upstream schema");

done_testing();
