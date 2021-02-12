#!/usr/bin/perl

=head1 NAME

generator-unified-api-config.pl - Generate the stubs for the config api

=cut

=head1 DESCRIPTION

generator-unified-api-config.pl - Generate the stubs for the config api

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);
use DBI;
use Template;
use Data::Dumper;
use DateTime;
use Getopt::Long;
use Lingua::EN::Inflexion qw(noun);
use Module::Pluggable (
    search_path => [qw(pf::ConfigStore)],
    sub_name => 'stores',
);
use Mojo::Util qw(decamelize camelize);

my %SKIPABLE_CLASSES = (
    'pf::ConfigStore::Group'                => 1,
    'pf::ConfigStore::ApacheFilters'        => 1,
    'pf::ConfigStore::Survery'              => 1,
    'pf::ConfigStore::Report'               => 1,
    'pf::ConfigStore::DhcpFilters'          => 1,
    'pf::ConfigStore::DNS_Filters'          => 1,
    'pf::ConfigStore::RadiusFilters'        => 1,
    'pf::ConfigStore::SwitchFilters'        => 1,
    'pf::ConfigStore::VlanFilters'          => 1,
    'pf::ConfigStore::WMI'                  => 1,
    'pf::ConfigStore::Profile'              => 1,
    'pf::ConfigStore::Role::ValidGenericID' => 1,
);

my $PF_DIR = '/usr/local/pf';

my @stores;
my $now = DateTime->now;

if (@ARGV) {
    foreach my $store (@ARGV) {
        push @stores, store_info($store);
    }
} else {
    push @stores, stores_info();
}

my $output_path = "$PF_DIR";
my $class_output_path = "lib/pf/UnifiedApi/Controller/Config";
my $test_output_path = "t/unittest/UnifiedApi/Controller/Config";

my $tt = Template->new({
    OUTPUT_PATH  => $output_path,
    INCLUDE_PATH => "$PF_DIR/addons/dev-helpers/templates",
});

my $base_template = "pf-UnifiedApi-Controller-Config.pm.tt";
my $test_template = "unittest-UnifiedApi-Controller-Config.t.tt";

for my $store (@stores) {
    my $name = $store->{name};
    my $class = $store->{class};
    my $class_path = "${class_output_path}/${name}.pm";
    if (!-f "$PF_DIR/$class_path" ) {
        print "Generating module for $class\n";
        $tt->process($base_template, $store, $class_path) or die $tt->error();
    } else {
        print "Skipping module for $class\n";
    }
    my $test_path = "${test_output_path}/${name}.t";
    if (!-f "$PF_DIR/$test_path" ) {
        print "Generating test for $class\n";
        $tt->process($test_template, $store, $test_path) or die $tt->error();
        chmod(0755, "$PF_DIR/$test_path");
    } else {
        print "Skipping test for $class\n";
    }
}



sub is_skippable {
    my ($class) = @_;
    return exists $SKIPABLE_CLASSES{$class};
}

=head2 store_info

Get the Store Info

=cut

sub store_info {
    my ($store_class) = @_;
    return if is_skippable($store_class);
    my $store_name = $store_class;
    $store_name =~ s/pf::ConfigStore:://;
    my $name = $store_name;
    my $fixup = $name;
    $fixup =~ s/([A-Z])([A-Z]+)/$1 . lc($2)/e;
    my $decamelized = decamelize($fixup);
    $decamelized =~ s/[_]{2,}/_/g;
    my $noun = noun($name);
    my $decamelized_noun = noun($decamelized);
    my $url_param_key = $decamelized_noun->singular . "_id";
    if ($noun->is_singular) {
        $name = $noun->plural;
    }
    my $class = "pf::UnifiedApi::Controller::Config::${name}";
    my %info = (
        class => $class,
        now => $now,
        name => $name,
        fixup => $fixup,
        collection_path => $decamelized_noun->plural,
        resource_path => $decamelized_noun->singular,
        url_param_key => $url_param_key,
        config_store_class => $store_class,
        form_class => "pfappserver::Form::Config::$store_name",
    );

    ### Get a list of tables and views
    return \%info
}

sub stores_info {
    return map { store_info($_) } __PACKAGE__->stores; 
}


