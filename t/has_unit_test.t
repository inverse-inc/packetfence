#!/usr/bin/perl -w

package pf;
use strict;
use warnings;
use Module::Pluggable
  search_path => 'pf',
  except      => [qw(pf::WebAPI)],
  inner       => 0,
  sub_name    => 'modules';

=head1 NAME

has_test

=cut

=head1 DESCRIPTION

has_test

=cut

package main;
use strict;
use warnings;
use diagnostics;
use File::Spec::Functions;
# pf core libs
use lib '/usr/local/pf/lib';
use Test::More;

for my $module ( pf->modules ) {
    my $test = "${module}.t";
    my @parts = split(/::/,$test);
    shift @parts;
    $test = join('/',@parts);
    my $file = catfile('/usr/local/pf/t/unittest',@parts);
    ok -e $file,"$module has a test $file";
}

done_testing();

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

1;


