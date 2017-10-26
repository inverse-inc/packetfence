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
use DBI;
use Template;
use Data::Dumper;
use DateTime;
use Getopt::Long;

my $PF_DIR = '/usr/local/pf';

our %OPTIONS = (
    dbpass => '',,
    dbuser => 'root',
    schema => "$PF_DIR/db/pf-schema-X.Y.Z.sql",
);

GetOptions(\%OPTIONS, 'dbpass=s', 'dbuser=s', 'schema=s');

my $output_path = "$PF_DIR/lib/pf/dal";

my $db_name = "_pf_generated_$$";

my $dbh = DBI->connect("DBI:mysql:host=localhost", $OPTIONS{dbuser}, $OPTIONS{dbpass}, {RaiseError => 1});

$dbh->do("DROP DATABASE IF EXISTS $db_name");

$dbh->do("CREATE DATABASE $db_name");

my $schema = $OPTIONS{schema};

system("mysql -u$OPTIONS{dbuser} -p$OPTIONS{dbpass} $db_name < $schema");

# Check if there was an error running the command
if ($?) {
    print "Problem Created the schema from $schema\n";
    exit $?;
}

$dbh->do("USE $db_name");

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

my $tt = Template->new({
    OUTPUT_PATH  => "$PF_DIR/lib/pf/dal/",
    INCLUDE_PATH => "$PF_DIR/addons/dev-helpers/templates",
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

END {
    $dbh->do("DROP DATABASE IF EXISTS $db_name") if $dbh;
}



=head2 get_table_info

Get the Table Info

=cut

sub get_table_info {
    my ($table) = @_;

    ### Get a list of tables and views
    my $tablesth = $dbh->table_info(undef, undef, $table);

    my @tables;
    while (my $table = $tablesth->fetchrow_hashref()) {
        push @tables, $table;
        {
            my @cols;
            my $sth = $dbh->column_info($table->{TABLE_CAT}, $table->{TABLE_SCHEM}, $table->{TABLE_NAME}, undef);
            while (my $col = $sth->fetchrow_hashref()) {
                if ($col->{COLUMN_NAME} eq 'tenant_id') {
                    $table->{HAS_TENANT_ID} = 1;
                }
                add_additional_metadata_to_column($table, $col);
                push @cols, $col;
            }
            @cols = sort { $a->{ORDINAL_POSITION} <=> $b->{ORDINAL_POSITION} } @cols;
            $table->{cols} = \@cols;
        }
        {
            my @keys;
            my $sth = $dbh->primary_key_info($table->{TABLE_CAT}, $table->{TABLE_SCHEM}, $table->{TABLE_NAME});
            while (my $key = $sth->fetchrow_hashref()) {
                push @keys, $key;
            }
            @keys = sort { $a->{KEY_SEQ} <=> $b->{KEY_SEQ} } @keys;
            $table->{'primary_keys'} = \@keys;
        }
        {
            my @keys;
            my $sth =
              $dbh->foreign_key_info($table->{TABLE_CAT}, $table->{TABLE_SCHEM}, $table->{TABLE_NAME}, undef, undef, undef);
            while (my $key = $sth->fetchrow_hashref()) {
                push @keys, $key;
            }
            $table->{'foreign_key_info'} = \@keys;
        }
        if (0) {
            my @indexes;
            my $sth =
              $dbh->statistics_info($table->{TABLE_CAT}, $table->{TABLE_SCHEM}, $table->{TABLE_NAME}, undef, undef);
            while (my $index = $sth->fetchrow_hashref()) {
                push @indexes, $index;
            }
            $table->{'indexes'} = \@indexes;
        }
    }
    return \@tables;
}

=head2 add_additional_metadata_to_column

Add Additional Metadata To Column

=cut

sub add_additional_metadata_to_column {
    my ($table, $col) = @_;
    $col->{pf_default_value} = make_default_value($table, $col);
}

our %DEFAULT_VALUE_MAKERS = (
    CHAR    => \&make_string_default_value,
    TEXT    => \&make_string_default_value,
    VARCHAR => \&make_string_default_value,
    INT     => \&make_int_default_value,
    BIGINT  => \&make_int_default_value,
    TINYINT => \&make_int_default_value,
);

=head2 make_default_value

Make Default Value for a column

=cut

sub make_default_value {
    my ($table, $col) = @_;
    my $type = $col->{TYPE_NAME};
    if (exists $DEFAULT_VALUE_MAKERS{$type} ) {
        return $DEFAULT_VALUE_MAKERS{$type}->($table, $col);
    }
    return make_string_default_value($table, $col);
}

=head2 make_int_default_value

Make Integer Default Value

=cut

sub make_int_default_value {
    my ($table, $col) = @_;
    if (defined $col->{COLUMN_DEF}) {
        return $col->{COLUMN_DEF};
    }
    unless ($col->{NULLABLE}) {
        return "0";
    }
    return "undef";
}

=head2 make_string_default_value

Make String Default Value

=cut

sub make_string_default_value {
    my ($table, $col) = @_;
    if (defined $col->{COLUMN_DEF}) {
        return "'$col->{COLUMN_DEF}'";
    }
    unless ($col->{NULLABLE}) {
        return "''";
    }
    return "undef";
}


