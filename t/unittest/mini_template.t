#!/usr/bin/perl

=head1 NAME

mini_template

=head1 DESCRIPTION

unit test for mini_template

=cut

use strict;
use warnings;
#
use lib '/usr/local/pf/lib';

our (@VALID_TEMPLATES, @INVALID_TEMPLATES, @TEMPLATE_OUTPUT);
BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
    @VALID_TEMPLATES = (
        ['bob', ['S', 'bob'] ], 
        ['bob-jones', ['S', 'bob-jones'] ], 
        ['$$bob', ['S', '$bob']], 
        ['$$bob$$', ['S', '$bob$']], 
        ['$bob', ['V', 'bob'] ], 
        ['${bob}', ['V', 'bob'] ], 
        ['${bob()}', ['F', 'bob', []] ], 
        ['${bob.jones()}', ['F', 'bob.jones', []] ], 
        ['${bob}-kik', [['V', 'bob'], ['S', '-kik'] ]], 
        ['kik-$bob', [['S', 'kik-'], ['V', 'bob'] ]], 
        ['${bob($mac)}', ['F', 'bob', [['V', 'mac']]] ], 
        ['${bob($mac, f())}', ['F', 'bob', [['V', 'mac'], ['F', 'f', []]]]],
        ['${bob($mac, "james", f())}', ['F', 'bob', [['V', 'mac'], ['S', 'james'], ['F', 'f', []]]]],
        ["\${bob(\$mac, 'james', f())}", ['F', 'bob', [['V', 'mac'], ['S', 'james'], ['F', 'f', []]]]],
        ['$bob.jones', ['K', ['bob', 'jones']] ], 
        ['$bob.jones-jr.sike', ['K', ['bob', 'jones-jr', 'sike']] ], 
    );

    @TEMPLATE_OUTPUT = (
        {
            tmpl  => 'bob',
            input => {},
            out   => 'bob',
        },
        {
            tmpl  => '$bob',
            input => { bob => 'bobby' },
            out   => 'bobby',
        },
        {
            tmpl  => '$bob.lastname',
            input => { bob => { lastname => 'jones' } },
            out   => 'jones',
        },
        {
            tmpl => '${bob}-kik',
            input => { bob => 'bobby' },
            out   => 'bobby-kik',
        },
        {
            tmpl => 'kik-${bob}',
            input => { bob => 'bobby' },
            out   => 'kik-bobby',
        },
    );
}

use pf::mini_template;

use Test::More tests => (scalar @VALID_TEMPLATES) + (scalar @TEMPLATE_OUTPUT) + 1;

#This test will running last
use Test::NoWarnings;

for my $test (@VALID_TEMPLATES) {
    test_valid_string(@$test);
}

for my $test (@TEMPLATE_OUTPUT) {
    test_template_output($test);
}

sub test_valid_string {
    my ($string, $expected) = @_;
    my ($array, $msg) = pf::mini_template::parse_template($string);
    is_deeply($array, $expected, "Check if '$string' is valid");
    unless ($array){
        print "$msg\n";
    }
}

=head2 test_template_output

test_template_output

=cut

sub test_template_output {
    my ($test) = @_;
    my $tmpl = $test->{tmpl};
    my $template = pf::mini_template->new($tmpl);
    my $out = $template->process($test->{input});
    is ($out, $test->{out}, "testing '$tmpl'");
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

1;

