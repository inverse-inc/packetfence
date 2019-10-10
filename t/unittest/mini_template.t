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
        {
            'tmpl' => [ 'S', 'bob' ],
            'in'   => 'bob',
            'info' => {},
        },
        {
            'tmpl' => [ 'S', 'bob-jones' ],
            'in'   => 'bob-jones',
            'info' => {},
        },
        {
            'tmpl' => [ 'S', '$bob' ],
            'in'   => '$$bob',
            'info' => {},
        },
        {
            'tmpl' => [ 'S', '$bob$' ],
            'in'   => '$$bob$$',
            'info' => {},
        },
        {
            'tmpl' => [ 'V', 'bob' ],
            'in'   => '$bob',
            'info' => {
                vars => {
                    bob => undef,
                },
            },
        },
        {
            'tmpl' => [ 'V', 'bob' ],
            'in'   => '${bob}',
            'info' => {
                vars => {
                    bob => undef,
                },
            },
        },
        {
            'tmpl' => [ 'F', 'bob', [] ],
            'in' => '${bob()}',
            'info' => {
                funcs => {
                    bob => undef,
                },
            },
        },
        {
            'tmpl' => [ 'F', 'bob.jones', [] ],
            'in' => '${bob.jones()}',
            'info' => {
                funcs => {
                    'bob.jones' => undef,
                },
            },
        },
        {
            'tmpl' => [ [ 'V', 'bob' ], [ 'S', '-kik' ] ],
            'in' => '${bob}-kik',
            'info' => {
                vars => {
                    'bob' => undef,
                },
            },
        },
        {
            'tmpl' => [ [ 'S', 'kik-' ], [ 'V', 'bob' ] ],
            'in' => 'kik-$bob',
            'info' => {
                vars => {
                    'bob' => undef,
                },
            },
        },
        {
            'tmpl' => [ 'F', 'bob', [ [ 'V', 'mac' ] ] ],
            'in' => '${bob($mac)}',
            'info' => {
                funcs => {
                    'bob' => undef,
                },
                vars => {
                    'mac' => undef,
                },
            },
        },
        {
            'tmpl' => [ 'F', 'bob', [ [ 'V', 'mac' ], [ 'F', 'f', [] ] ] ],
            'in' => '${bob($mac, f())}',
            'info' => {
                funcs => {
                    'bob' => undef,
                    'f' => undef,
                },
                vars => {
                    'mac' => undef,
                },
            },
        },
        {
            'tmpl' => [
                'F', 'bob',
                [ [ 'V', 'mac' ], [ 'S', 'james' ], [ 'F', 'f', [] ] ]
            ],
            'in' => '${bob($mac, "james", f())}',
            'info' => {
                funcs => {
                    'bob' => undef,
                    'f' => undef,
                },
                vars => {
                    'mac' => undef,
                },
            },
        },
        {
            'tmpl' => [
                'F', 'bob',
                [ [ 'V', 'mac' ], [ 'S', 'james' ], [ 'F', 'f', [] ] ]
            ],
            'in' => '${bob($mac, \'james\', f())}',
            'info' => {
                funcs => {
                    'bob' => undef,
                    'f' => undef,
                },
                vars => {
                    'mac' => undef,
                },
            },
        },
        {
            'tmpl' => [ 'K', [ 'bob', 'jones' ] ],
            'in' => '$bob.jones',
            'info' => {
                vars => {
                    'bob' => {
                        jones => undef,
                    },
                },
            },
        },
        {
            'tmpl' => [ 'K', [ 'bob', 'jones-jr', 'sike' ] ],
            'in' => '$bob.jones-jr.sike',
            'info' => {
                vars => {
                    'bob' => {
                        'jones-jr' => {
                            sike => undef,
                        },
                    },
                },
            },
        }
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
            tmpl  => '${bob.lastname}',
            input => { bob => { lastname => 'jones' } },
            out   => 'jones',
        },
        {
            tmpl  => '$bob.lastname',
            input => { bob => bless({ lastname => 'jones'}, "dummy") },
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
        {
            tmpl  => '${uc($bob)}',
            input => { bob => 'bobby' },
            out   => 'BOBBY',
        },
        {
            tmpl  => '${uc(join("-", split(":", $mac)))}',
            input => { mac => 'aa:bb:cc:dd:ee:ff' },
            out   => 'AA-BB-CC-DD-EE-FF',
        },
        {
            tmpl  => '${macToEUI48($mac)}',
            input => { mac => 'aa:bb:cc:dd:ee:ff' },
            out   => 'AA-BB-CC-DD-EE-FF',
        },
        {
            tmpl  => '${substr(uc(join("-", split(":", $mac))), 0, 8)}',
            input => { mac => 'aa:bb:cc:dd:ee:ff' },
            out   => 'AA-BB-CC',
        },
    );
}

use pf::mini_template;

use Test::More tests => (scalar @VALID_TEMPLATES) * 2 + (scalar @TEMPLATE_OUTPUT) + 1;

#This test will running last
use Test::NoWarnings;

for my $test (@VALID_TEMPLATES) {
    test_valid_string($test);
}

for my $test (@TEMPLATE_OUTPUT) {
    test_template_output($test);
}

sub test_valid_string {
    my ($test) = @_;
    my $string = $test->{in};
    my ($array, $info, $msg) = pf::mini_template::parse_template($string);
    is_deeply($array, $test->{tmpl}, "Expected tmpl for '$string' is valid");
    is_deeply($info, $test->{info}, "Expected info for '$string' is valid");
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

