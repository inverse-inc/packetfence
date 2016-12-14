#!/usr/bin/perl

=head1 NAME

generator-data-access-layer.pl - Generate the stubs for the data access layer

=cut

=head1 DESCRIPTION

generator-data-access-layer.pl - Generate the stubs for the data access layer

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);
use pf::db;
use Template;
use Data::Dumper;
use DateTime;

my $tables = [];

if (@ARGV) {
    foreach my $table (@ARGV) {
        my $infos = get_table_info($table);
        push @$tables, @$infos;
    }
} else {
    my $infos = get_table_info();
    push @$tables, @$infos;
}

my $output_path = "/usr/local/pf/lib/pf/dal";

my $tt = Template->new({
    OUTPUT_PATH  => '/usr/local/pf/lib/pf/dal/',
    INCLUDE_PATH => '/usr/local/pf/addons/dev-helpers/templates',
});

my $now = DateTime->now;
my $base_template = "pf-dal.pm.tt";
my $overload_template = "pf-dal-overload.pm.tt";

#print Dumper($tables);
for my $table (@$tables) {
    my $name = $table->{TABLE_NAME};
    my $class = "pf::dal::_${name}";
    my %vars = (%$table, class => $class, now => $now);
    print "Generating $vars{class}\n";
    unless (@{$table->{primary_keys}}) {
        print "There is no primary key for $class\n";
        next;
    }
    $tt->process($base_template, \%vars, "_${name}.pm") or die $tt->error();
    if (!-f "$output_path/${name}.pm" ) {
        $vars{parent_class} = $class;
        $vars{class} = "pf::dal::${name}";
        print "Generating $vars{class}\n";
        $tt->process($overload_template, \%vars, "${name}.pm") or die $tt->error();
    }
}


sub get_table_info {
    my ($table) = @_;
    my $dbh = db_connect();

    ### Get a list of tables and views
    my $tablesth = $dbh->table_info(undef, undef, $table);

    my @tables;
    while (my $row = $tablesth->fetchrow_hashref()) {
        push @tables, $row;
        {
            my @cols;
            my $sth = $dbh->column_info($row->{TABLE_CAT}, $row->{TABLE_SCHEM}, $row->{TABLE_NAME}, undef);
            while (my $col = $sth->fetchrow_hashref()) {
                push @cols, $col;
            }
            $row->{cols} = \@cols;
        }
        {
            my @keys;
            my $sth = $dbh->primary_key_info($row->{TABLE_CAT}, $row->{TABLE_SCHEM}, $row->{TABLE_NAME});
            while (my $key = $sth->fetchrow_hashref()) {
                push @keys, $key;
            }
            $row->{'primary_keys'} = \@keys;
        }
        {
            my @keys;
            my $sth =
              $dbh->foreign_key_info($row->{TABLE_CAT}, $row->{TABLE_SCHEM}, $row->{TABLE_NAME}, undef, undef, undef);
            while (my $key = $sth->fetchrow_hashref()) {
                push @keys, $key;
            }
            $row->{'foreign_key_info'} = \@keys;
        }
        if (0) {
            my @indexes;
            my $sth =
              $dbh->statistics_info($row->{TABLE_CAT}, $row->{TABLE_SCHEM}, $row->{TABLE_NAME}, undef, undef);
            while (my $index = $sth->fetchrow_hashref()) {
                push @indexes, $index;
            }
            $row->{'indexes'} = \@indexes;
        }
    }
    return \@tables;
}


