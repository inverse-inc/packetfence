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

use Data::Dumper;
print Dumper(\@stores);
exit 0;

my $output_path = "$PF_DIR/lib/pf/UnifiedApi/Controller/Config";

my $tt = Template->new({
    OUTPUT_PATH  => $output_path,
    INCLUDE_PATH => "$PF_DIR/addons/dev-helpers/templates",
});

my $base_template = "pf-UnifiedApi-Controller-Config.pm.tt";

for my $store (@stores) {
    my $name = $store->{name};
    my $class = $store->{class};
    if (!-f "$output_path/${name}.pm" ) {
        print "Generating $class\n";
        $tt->process($base_template, $store, "${name}.pm") or die $tt->error();
    } else {
        print "Skipping $class\n";
    }
}

sub is_skippable {

}

=head2 store_info

Get the Store Info

=cut

sub store_info {
    my ($store_class) = @_;
    return if is_skippable($store_class);
    my $name = $store_class;
    $name =~ s/pf::ConfigStore:://;
    my $class = "pf::UnifiedApi::Controller::Config::${name}";
    my %info = (
        class => $class,
        now => $now,
        name => $name
    );

    ### Get a list of tables and views
    return \%info
}

sub stores_info {
    return map { store_info($_) } __PACKAGE__->stores; 
}


