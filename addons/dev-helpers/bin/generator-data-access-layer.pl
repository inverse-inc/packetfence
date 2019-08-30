#!/usr/bin/perl

=head1 NAME

generator-data-access-layer.pl - Generate the stubs for the data access layer

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
use List::MoreUtils qw(any);
my $PF_DIR = '/usr/local/pf';
our %OPTIONS = (
    dbpass => 'packet',
    dbuser => 'pf_smoke_tester',
    schema => "$PF_DIR/db/pf-schema-X.Y.Z.sql",
);

GetOptions(\%OPTIONS, 'dbpass=s', 'dbuser=s', 'schema=s');
my $db_name = "pf_smoke_test__dal_$$";
my $dbuser  = $OPTIONS{dbuser};
my $dbpass  = $OPTIONS{dbpass};
my $dbh     = DBI->connect( "DBI:mysql:host=localhost", $dbuser, $dbpass, { RaiseError => 1 } );
$dbh->do("DROP DATABASE IF EXISTS $db_name;") or die $dbh->errstr;
$dbh->do("CREATE DATABASE $db_name;")         or die $dbh->errstr;
my $schema = $OPTIONS{schema};
system("mysql -u\"$dbuser\" -p\"$dbpass\" $db_name < $schema");
$dbh->do("USE $db_name;") or $dbh->errstr;
my $tables = table_data($dbh, $db_name, @ARGV);
my $output_path = "$PF_DIR/lib/pf/dal";
my $tt = Template->new({
    OUTPUT_PATH  => "$PF_DIR/lib/pf/dal/",
    INCLUDE_PATH => "$PF_DIR/addons/dev-helpers/templates",
});

my $now = DateTime->now;
my $base_template = "pf-dal.pm.tt";
my $overload_template = "pf-dal-overload.pm.tt";

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
    if ($dbh) {
        $dbh->do("DROP DATABASE IF EXISTS $db_name") or die $dbh->errstr;
    }
}

sub table_data {
    my ($dbh, $db_name, @names) = @_;
    my $table_name_clause = '';
    if (@names) {
        $table_name_clause = " AND TABLE_NAME in (" . join(',', ("?") x scalar @names ) .  ")";
    }
    my $sql =
"SELECT TABLE_NAME, COLUMN_NAME, ORDINAL_POSITION, COLUMN_DEFAULT as COLUMN_DEF, IF(IS_NULLABLE = 'YES', 1, 0) AS NULLABLE, UPPER(DATA_TYPE) as TYPE_NAME, CHARACTER_MAXIMUM_LENGTH, CHARACTER_OCTET_LENGTH, NUMERIC_PRECISION as NUM_PREC_RADIX, NUMERIC_SCALE, DATETIME_PRECISION, COLUMN_TYPE, COLUMN_KEY, EXTRA, COLUMN_COMMENT, COLUMN_KEY LIKE '%PRI%' as mysql_is_pri_key, EXTRA LIKE '%auto_increment%' as mysql_is_auto_increment, IF(COLUMN_NAME = 'tenant_id', 1, NULL) as HAS_TENANT_ID FROM INFORMATION_SCHEMA.COLUMNS where TABLE_SCHEMA = '$db_name' $table_name_clause ORDER BY TABLE_NAME, ORDINAL_POSITION";
    my %tables;
    for my $row (@{ $dbh->selectall_arrayref($sql, { Slice => {} }, @names) }) {
        my $name = delete $row->{TABLE_NAME};
        push @{ ($tables{$name} //= { TABLE_NAME => $name, INDEXES => index_data($dbh, $name) })->{cols} }, format_col($row);
    }

    my $tables = [ sort { $a->{TABLE_NAME} cmp $b->{TABLE_NAME} } values %tables ];
    cleanup_table($dbh, $_) for @$tables;
    return $tables;
}

sub cleanup_table {
    my ($dbh, $table) = @_;
    local $_;
    add_additional_metadata_to_column($table, $_) for @{$table->{cols}};
    $table->{HAS_TENANT_ID} = any { $_->{HAS_TENANT_ID} } @{$table->{cols}};
    $table->{primary_keys} = [ map { { COLUMN_NAME => $_->{Column_name} } } grep { $_->{Key_name} eq 'PRIMARY' } @{$table->{INDEXES}} ];
}

sub index_data {
    my ($dbh, $name) = @_;
    my $sql  = "SHOW INDEX FROM ${db_name}.${name}";
    my $indexes = $dbh->selectall_arrayref( $sql, { Slice => {} } );
    delete $_->{TABLE} for @{ $indexes };
    return $indexes;
}

sub format_col {
    my ($col) = @_;
    if ( $col->{TYPE_NAME} eq 'ENUM' ) {
        my $enum = $col->{COLUMN_TYPE};
        $enum =~ s/enum\(//;
        $enum =~ s/\)//;
        $col->{mysql_values} =
          [ map { s/^'//; s/'$//; $_ } split( /\s*,\s*/, $enum ) ];
    }

    return $col;
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

=head2 add_additional_metadata_to_column

Add Additional Metadata To Column

=cut

sub add_additional_metadata_to_column {
    my ($table, $col) = @_;
    $col->{pf_default_value} = make_default_value($table, $col);
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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
