#!/usr/bin/perl

=head1 NAME

upgrade_helpers

=head1 DESCRIPTION

The helper procedures that db/upgrade-helpers.sql (for the packages installed
on top of PacketFence) shares with db/upgrade-X.X-X.Y.sql stay the same.

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More;
use File::Slurp qw(read_file);

my $helpers = '/usr/local/pf/db/upgrade-helpers.sql';
my $upgrade = '/usr/local/pf/db/upgrade-X.X-X.Y.sql';
plan skip_all => "no $upgrade" if !-f $upgrade;

sub procedures {
    my ($file) = @_;
    my $sql = read_file($file);
    my %procedures;
    while ($sql =~ /^CREATE PROCEDURE (\w+)(.*?)^END$/msg) {
        my ($name, $body) = ($1, $2);
        $body =~ s/\s+/ /g;
        $procedures{$name} = $body;
    }
    return \%procedures;
}

my $shared = procedures($helpers);
my $core = procedures($upgrade);
for my $name (qw(AddColumnUnlessExists DropColumnIfExists AddIndexUnlessExists DropIndexIfExists)) {
    ok(exists $shared->{$name}, "$name is in $helpers");
    is($shared->{$name}, $core->{$name}, "$name is the same in both files") if exists $core->{$name};
}
ok(exists $shared->{$_}, "$_ is in $helpers") for qw(ValidatePluginVersion CopyRowsInBatches);

done_testing();

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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
