#!/usr/bin/perl
=head1 NAME

i18n.t

=head1 DESCRIPTION

Internalization-related tests

=cut

use strict;
use warnings;
use diagnostics;

use File::Find;
use Test::More;
BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

my @translations;

# find2perl /usr/local/pf/conf/locale -name "*.po"
File::Find::find({
    wanted => sub {
        /^.*\.po\z/s && push(@translations, $File::Find::name);
    }}, '/usr/local/pf/conf/locale'
);

plan tests => scalar @translations;

foreach my $translation (@translations) {
    is(
        system("/usr/bin/msgfmt -o - $translation 2>&1 >/dev/null"),
        0,
        "$translation is accepted by msgfmt"
    );
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

