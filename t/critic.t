#!/usr/bin/perl

=head1 NAME

critic.t

=head1 DESCRIPTION

run Perl Critic for automated worst-practices avoidance

=cut

use strict;
use warnings;
use diagnostics;

use Test::Perl::Critic ( -profile => 'perlcriticrc' );
use Test::More;
BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}
use Test::NoWarnings;

use TestUtils qw(get_all_perl_binaries get_all_perl_cgi get_all_perl_modules);


my @files = (
    '/usr/local/pf/addons/pfdetect_remote/sbin/pfdetect_remote',
);

push(@files, TestUtils::get_all_perl_binaries());
push(@files, TestUtils::get_all_perl_cgi());
push(@files, TestUtils::get_all_perl_modules());

# all files + no warnings
plan tests => scalar @files * 1 + 1;

foreach my $currentFile (@files) {
    critic_ok($currentFile);
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

