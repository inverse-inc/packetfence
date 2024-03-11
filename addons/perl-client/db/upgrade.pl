#!/usr/bin/perl

=head1 NAME

upgrade.pl

=head1 DESCRIPTION

Script that handles the upgrade of the Local schema

=head1 SYNOPSIS

upgrade.pl --database PATH_TO_DATABASE

=cut

use strict;
BEGIN {
    use lib qw ( /usr/local/fingerbank/lib/ /usr/local/pf/lib_perl/lib/perl5 );
    use fingerbank::Log;
    fingerbank::Log::init_logger;
}
use Pod::Usage;
use Getopt::Long;
use fingerbank::Schema::Local;

my $database_path;

unless(@ARGV){
    die pod2usage;
}

GetOptions(
    'database=s'  => \$database_path,
) or die pod2usage;

my $schema = fingerbank::Schema::Local->connect(
    "dbi:SQLite:$database_path"
);

if (!$schema->get_db_version()) {
    # We check if the combination table is there.
    # If it is, we deal with an existing non-versioned database (pre 2.0)
    # If its not, then we consider the database as empty
    eval { $schema->resultset("Combination")->count };
    my $db_exists = $@ ? 0 : 1;
    if($db_exists){
        fingerbank::Log::get_logger->info("Database $database_path already exists but no version is set. Setting it's version to 1.0");
        $schema->install("1.0");
    }
    else {
        fingerbank::Log::get_logger->info("Database $database_path doesn't exist. Deploying schema");
        `touch $database_path && sqlite3 $database_path < db/upgrade/fingerbank-Schema-Local-1.0-SQLite.sql`;
        $schema->install("1.0");
    }
}

# Now that we know the database exists to a certain version, we can upgrade
$schema->upgrade();

=back

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
