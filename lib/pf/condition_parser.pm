package pf::condition_parser;

=head1 NAME

pf::condition_parser - parser for filter logic

=cut

=head1 DESCRIPTION

pf::condition_parser

Parses the following BNF

EXPR = OR || OR
EXPR = OR
OR   = FACT && FACT
OR   = FACT
FACT = '(' EXPR ')'
FACT = ID
ID   = /a-zA-Z0-9_/+

=cut

use strict;
use warnings;

use base qw(Exporter);

BEGIN {
    our @EXPORT_OK = qw(parse_condition_string);
}


=head2 parse_condition_string

Parses a string to a structure for building filters and conditions

    my $array = parse_condition_string('(a || b) && (c || d)');

Where $array would be structure

    $array = [
              'AND',
              [
                'OR',
                'a',
                [
                  'AND',
                  'b',
                  'd'
                ]
              ],
              [
                'OR',
                'c',
                'd'
              ]
            ];

If an invalid string is passed then it will die

=cut

sub parse_condition_string {
    local $_ = shift;
    my $expr = _parse_expr();

    #Reduce whitespace
    /\G\s*/gc;

    #Check if there are any thing left
    die "Unexpected data at " . pos if /\G./gc;
    return $expr;
}

=head2 _parse_expr

Handle an 'expr' expression

=cut

sub _parse_expr {
    # EXPR = OR || OR
    # EXPR = OR
    my @expr;
    push @expr, _parse_or();
    while (/\G\s*\|{1,2}/gc) {
        push @expr, _parse_or();
    }

    #collapse into a single element if there is only one
    return $expr[0] if @expr == 1;
    return ['OR', @expr];
}

=head2 _parse_or

Handle an 'or' expression

=cut

sub _parse_or {
    # OR   = FACT && FACT
    # OR   = FACT
    my @expr;
    push @expr, _parse_fact();
    while (/\G\s*\&{1,2}/gc) {
        push @expr, _parse_fact();
    }

    #collapse into a single element if there is only one
    return $expr[0] if @expr == 1;
    return ['AND', @expr];
}

=head2 _parse_fact

Handle a 'fact' expression

=cut

sub _parse_fact {
    # FACT = '(' EXPR ')'
    # FACT = /a-zA-Z0-9_/+
    my $pos = pos();

    #Check if it is a sub expression ()
    if (/\G\s*\(/gc) {
        my $expr = _parse_expr();

        #Checking for )
        die "No ')' at " . pos unless /\G\s*\)/gc;
        return $expr;
    }

    #It is a simple id
    return $1 if (/\G\s*([a-zA-Z0-9_]+)/gc);
    die "Invalid characters";
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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
