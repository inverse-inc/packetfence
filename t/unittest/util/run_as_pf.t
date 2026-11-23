#!/usr/bin/perl

=head1 NAME

run_as_pf

=head1 DESCRIPTION

unit test for pf::util::run_as_pf

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
use pf::util qw(run_as_pf);

plan skip_all => "switching to the pf user requires root" if $< != 0;
plan tests => 4;

my (undef, undef, $pf_uid, $pf_gid) = getpwnam('pf');
my %expected_groups = ($pf_gid => 1);
setgrent();
while (my (undef, undef, $group_id, $members) = getgrent()) {
    $expected_groups{$group_id} = 1 if grep { $_ eq 'pf' } split / /, $members;
}
endgrent();

# Switch in a child so the test process keeps running as root
pipe(my $reader, my $writer) or die "pipe: $!";
my $pid = fork() // die "fork: $!";
if ($pid == 0) {
    close($reader);
    my $result = run_as_pf() ? 1 : 0;
    my (undef, @groups) = split / /, $);
    print $writer join("\n", $result, $<, (split / /, $()[0], join(' ', @groups)), "\n";
    close($writer);
    exit 0;
}
close($writer);
chomp(my @lines = <$reader>);
waitpid($pid, 0);
my ($result, $uid, $gid, $groups) = @lines;
my %groups = map { $_ => 1 } split / /, $groups // '';

ok($result, "run_as_pf succeeds");
is($uid, $pf_uid, "the process runs as the pf user");
is($gid, $pf_gid, "the process runs with the pf group");
is_deeply(\%groups, \%expected_groups, "the supplementary groups are the ones of pf, not the ones of root");

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
