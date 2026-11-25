#!/usr/bin/perl

use strict;
use warnings;

BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::More;
use Scalar::Util qw(refaddr weaken);
use Storable qw(dclone);
use pf::UnifiedApi::Controller::Config;

{
    package Form::Test::RepeatableReset;
    use HTML::FormHandler::Moose;
    extends 'HTML::FormHandler';

    has user_roles => (is => 'rw', default => sub { [] });
    has_field description => (type => 'Text', required => 1);
    has_field triggers => (type => 'Repeatable');
    has_field 'triggers.contains' => (type => 'Compound');
    has_field 'triggers.contains.type' => (type => 'Text', required => 1);
    has_field 'triggers.contains.value' => (type => 'Text', required => 1);
}

{
    package Form::Test::PlainReset;
    use HTML::FormHandler::Moose;
    extends 'HTML::FormHandler';
    has_field description => (type => 'Text', required => 1);
}

{
    package Controller::Test::FormReset;
    use Mojo::Base 'pf::UnifiedApi::Controller::Config';
    sub form_parameters { return []; }
}

my $controller = Controller::Test::FormReset->new;
$controller->stash(admin_roles => ['test-role']);
my $form = Form::Test::RepeatableReset->new;
my $params = {
    description => 'Repeated security-event form processing',
    triggers => [
        { type => 'internal', value => 'test-event' },
        { type => 'suricata_event', value => '1234567' },
    ],
};

$form->process(params => dclone($params), posted => 1);
ok(!$form->has_errors, 'initial repeatable form validates');
my $expected = dclone($form->value);
is($form->has_repeatable_fields, 1, 'initial registry has one repeatable field');

subtest 'cached resets release obsolete repeatable fields' => sub {
    for my $iteration (1 .. 25) {
        my $old_field = $form->field('triggers');
        weaken($old_field);

        $controller->reset_form($form, {});
        $form->process(params => dclone($params), posted => 1);

        is($form->has_repeatable_fields, 1, "reset $iteration keeps registry bounded");
        my @registered = $form->all_repeatable_fields;
        is(refaddr($registered[0]), refaddr($form->field('triggers')),
            "reset $iteration registers the current field");
        ok(!defined $old_field, "reset $iteration releases the obsolete field");
        ok(!$form->has_errors, "reset $iteration still validates");
        is_deeply($form->value, $expected, "reset $iteration preserves processed values");
    }
};

is_deeply($form->user_roles, ['test-role'], 'reset preserves controller role propagation');

subtest 'trigger counts can change between resets' => sub {
    for my $count (0, 1, 4, 1, 0) {
        my $input = dclone($params);
        $input->{triggers} = [map { { type => 'internal', value => "event-$_" } } 1 .. $count];
        $controller->reset_form($form, {});
        $form->process(params => $input, posted => 1);

        my $fresh = Form::Test::RepeatableReset->new;
        $fresh->process(params => dclone($input), posted => 1);
        is_deeply($form->value, $fresh->value, "$count triggers match a fresh form");
        is($form->has_repeatable_fields, 1, "$count triggers leave one registered repeatable");
    }
};

subtest 'validation still rejects incomplete triggers' => sub {
    $controller->reset_form($form, {});
    $form->process(params => {
        description => 'Invalid trigger',
        triggers => [{ type => 'internal' }],
    }, posted => 1);
    ok($form->has_errors, 'missing required trigger value is rejected');
};

subtest 'forms without repeatable fields still reset' => sub {
    my $plain = Form::Test::PlainReset->new;
    for (1 .. 3) {
        $controller->reset_form($plain, {});
        $plain->process(params => { description => 'Plain form' }, posted => 1);
        is($plain->has_repeatable_fields, 0, 'plain registry stays empty');
        ok(!$plain->has_errors, 'plain form validates');
        is_deeply($plain->value, { description => 'Plain form' }, 'plain form value is preserved');
    }
};

subtest 'fields removed between resets leave the index' => sub {
    my $cached = Form::Test::PlainReset->new;
    my @with_extra = (field_list => [extra => { type => 'Text' }]);
    my @without_extra = (field_list => []);

    $controller->reset_form($cached, {}, @with_extra);
    $cached->process(params => { description => 'With extra', extra => 'x' }, posted => 1);
    ok(defined $cached->field('extra'), 'extra field exists while it is in the field list');
    is_deeply($cached->value, { description => 'With extra', extra => 'x' }, 'extra field is processed');

    my $old_extra = $cached->field('extra');
    weaken($old_extra);

    $controller->reset_form($cached, {}, @without_extra);
    $cached->process(params => { description => 'Without extra', extra => 'x' }, posted => 1);
    ok(!defined $cached->field('extra'), 'removed field name no longer resolves');
    ok(!exists $cached->index->{extra}, 'removed field is not left in the index');
    ok(!defined $old_extra, 'removed field object is released');
    is_deeply([sort keys %{$cached->index}], ['description'], 'index holds only current fields');
    is_deeply($cached->value, { description => 'Without extra' }, 'removed field is not processed');

    $controller->reset_form($cached, {}, @with_extra);
    $cached->process(params => { description => 'Extra again', extra => 'y' }, posted => 1);
    ok(defined $cached->field('extra'), 'field resolves again once it is back in the field list');
    is_deeply($cached->value, { description => 'Extra again', extra => 'y' }, 'restored field is processed');
};

subtest 'nested fields are indexed by full name after a reset' => sub {
    $controller->reset_form($form, {});
    $form->process(params => dclone($params), posted => 1);
    my %index = %{$form->index};
    ok(exists $index{$_}, "$_ is indexed") for qw(description triggers triggers.contains triggers.contains.type triggers.contains.value);
    is(refaddr($index{triggers}), refaddr($form->field('triggers')), 'index points at the current triggers field');
};

done_testing;
