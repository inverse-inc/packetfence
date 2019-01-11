package pf::condition_parser;

=head1 NAME

pf::condition_parser - parser for filter logic

=cut

=head1 DESCRIPTION

pf::condition_parser

Parses the following BNF

EXPR = OR || OR
EXPR = OR
OR   = CMP && CMP
OR   = CMP
CMP  = VAL OP ID
CMP  = VAL OP STRING
CMP  = FACT
OP   = '==' | '!=' | '=~' | '!~' | '>' | '>=' | '<' | '<='
VAL  = ID
VAL  = FUNC
FUNC = ID '(' PARAMS ')'
PARAMS = PARAM ',' PARAMS
PARAMS = PARAM
PARAM  = VAR
PARAM  = STRING
PARAM  = FUNC
VAR    = ID
FACT = ! FACT
FACT = '(' EXPR ')'
FACT = ID
FACT = FUNC
ID   = /a-zA-Z0-9_\./+

=cut

use strict;
use warnings;

use base qw(Exporter);

BEGIN {
    our @EXPORT_OK = qw(parse_condition_string);
}


=head2 parse_condition_string

Parses a string to a structure for building filters and conditions

    my ($array, $msg) = parse_condition_string('(a || b) && (c || d)');

On success

$array will be the following structure

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

$msg will be an empty string

If an invalid string is passed then the array will be undef and $msg will have have the error message

=cut

sub parse_condition_string {
    local $_ = shift;
    pos() = 0;
    #Reduce whitespace
    /\G\s*/gc;
    my $expr = eval {_parse_expr()};
    if ($@) {
        return (undef, $@);
    }

    #Reduce whitespace
    /\G\s*/gc;

    #Check if there are any thing left
    if (/\G./gc) {
        my $position = pos;
        return (undef,format_parse_error("Invalid character(s)",$_ , $position - 1));
    }
    return ($expr, '');
}

=head2 _parse_expr

 EXPR = OR || OR
 EXPR = OR

=cut

sub _parse_expr {
    my @expr;
    push @expr, _parse_or();
    while (_or_operator()) {
        push @expr, _parse_or();
    }

    #collapse into a single element if there is only one
    return $expr[0] if @expr == 1;
    return ['OR', @expr];
}

=head2 _or_operator

Consume the or operator

=cut

sub _or_operator { /\G\s*\|{1,2}/gc }

=head2 _parse_or

OR   = CMP && CMP
OR   = CMP

=cut

sub _parse_or {
    my @expr;
    push @expr, _parse_cmp();
    while (_and_operator()) {
        push @expr, _parse_cmp();
    }

    #collapse into a single element if there is only one
    return $expr[0] if @expr == 1;
    return ['AND', @expr];
}

=head2 _and_operator

Consume the and operator

=cut

sub _and_operator { /\G\s*\&{1,2}/gc }

=head2 _parse_cmp

CMP  = VAL OP ID
CMP  = VAL OP STRING
CMP  = FACT

=cut

sub _parse_cmp {
    my $old_pos = pos();
    if (/\G\s*([a-zA-Z0-9_\.]+)/gc) {
        my $a = $1;
        if (/\G\s*\(/gc) {
            $a = _parse_func($a);
        }

        if (/\G\s*(==|!=|=~|!~|\<\=|\<|\>\=|\>)/gc) {
            my $op = $1;
            my $b;
            if (/\G\s*([a-zA-Z0-9_\.]+)/gc) {
                $b = $1;
            } elsif (/\G\s*"((?:[^"\\]|\\"|\\\\)*?)"/gc) {
                $b = $1;
                $b =~ s/\\"/"/g;
                $b =~ s/\\\\/\\/g;
            } else {
                die format_parse_error("Invalid format", $_, pos);
            }
            return [$op,$a,$b];
        }
    }
    pos() = $old_pos;
    return _parse_fact();
}


=head2 _parse_func

_parse_func

=cut

sub _parse_func {
    my $f = shift;
    my @params;
    my $b;
    if (/\G\s*\)/gc) {
        return ['FUNC', $f, \@params];
    }

    push @params, _parse_param();
    while (/\G\s*,\s*/gc) {
        push @params, _parse_param();
    }

    if (!/\G\s*\)/gc) {
        die format_parse_error("Function $f is not closed ", $_, pos);
    }

    return ['FUNC', $f, \@params];
}

sub _parse_param {
    my $p;
    if (/\G\s*([a-zA-Z0-9_\.]+)/gc) {
        my $id = $1;
        if (/\G\s*\(/gc) {
            $p = _parse_func($id);
        } else {
            $p = ['VAR', $id];
        }
    } elsif (/\G\s*"((?:[^"\\]|\\"|\\\\)*?)"/gc) {
        $p = $1;
        $p =~ s/\\"/"/g;
        $p =~ s/\\\\/\\/g;
    } else {
        die format_parse_error("Invalid parameter", $_, pos);
    }

    return $p;
}

=head2 _parse_fact

FACT = ! FACT
FACT = '(' EXPR ')'
FACT = /a-zA-Z0-9_/+
FACT = FUNC

=cut

sub _parse_fact {
    my $pos = pos();

    #Check if it is a not expression !
    if (/\G\s*!/gc) {
        return ['NOT' ,_parse_fact()];
    }

    #Check if it is a sub expression ()
    if (/\G\s*\(/gc) {
        my $expr = _parse_expr();

        #Checking for )
        return $expr if /\G\s*\)/gc;
        #Reduce whitespace
        /\G\s*/gc;
        die format_parse_error("No closing ')' invalid character or end of line found", $_, pos);
    }

    #It is a simple id
    if (/\G\s*([a-zA-Z0-9_\.]+)/gc) {
        my $id = $1;
        if (/\G\s*\(/gc) {
            return _parse_func($id);
        }

        return $id;
    }
    #Reduce whitespace
    /\G\s*/gc;
    die format_parse_error("Invalid character(s)", $_, pos() );
}

our $MARKER  = '^';
our $HIGH_LIGHT = '~';


=head2 format_parse_error

format the parse to make easier to

=cut

sub format_parse_error {
    my ($error_msg, $string, $postion) = @_;
    my $msg = "parse error: $error_msg\n$string\n";
    my $string_length = length($string);
    if ($postion == 0 ) {
        return  $msg . "$MARKER " . $HIGH_LIGHT x ($string_length - 2) . "\n";
    }
    my $pre_hilight = $HIGH_LIGHT x ($postion - 1)  . " ";
    my $post_hilight = " " . $HIGH_LIGHT x ( $string_length - length($pre_hilight) - 2);
    return "${msg}${pre_hilight}${MARKER}${post_hilight}\n";
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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
