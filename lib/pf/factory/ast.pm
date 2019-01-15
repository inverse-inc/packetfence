package pf::factory::ast;

=head1 NAME

pf::factory::ast -

=head1 DESCRIPTION

pf::factory::ast

=cut

use strict;
use warnings;
use pf::ast::eq;
use pf::ast::func;
use pf::ast::functions;
use pf::ast::ge;
use pf::ast::gt;
use pf::ast::le;
use pf::ast::lt;
use pf::ast::not;
use pf::ast::ne;
use pf::ast::re;
use pf::ast::not_re;
use pf::ast::val;
use pf::ast::var;
use pf::condition_parser qw(parse_condition_string);

our %BINARY_AST = (
    '==' => 'pf::ast::eq',
    '!=' => 'pf::ast::ne',
    '<'  => 'pf::ast::lt',
    '<=' => 'pf::ast::le',
    '>'  => 'pf::ast::gt',
    '>=' => 'pf::ast::ge',
);

our %AST_BUILDER = (
    FUNC => \&build_func_ast,
    'VAR' => \&build_var_ast,
    'NOT' => \&build_not_ast,
    '=~'  => \&build_re_ast,
    '!~'  => \&build_re_ast,
    ( map { $_ => \&build_binary_ast } qw(== != <=  < >= >) ),
);


sub build {
    my ($str) = @_;
    my ($ast, $err) = parse_condition_string($str);
    if ($err) {
        die $err;
    }

    return build_ast($ast);
}

sub build_re_ast {
    my ($ast) = @_;
    my ($t, $left, $re) = @$ast;
    my $class = $t eq '=~' ? "pf::ast::re" : "pf::ast::not_re";
    return $class->new(build_ast(ref($left) ? $left : ['VAR', $left ]), $re);
}

sub build_var_ast {
    my ($ast) = @_;
    my ($t, $key) = @$ast;
    my @keys = split(/\./, $key);
    return pf::ast::var->new(\@keys);
}

=head2 build_binary_ast

build_binary_ast

=cut

sub build_binary_ast {
    my ($ast) = @_;
    my ($type, $left, $right) = @$ast;
    if (!$BINARY_AST{$type}) {
        die "invalid binary ast $type";
    }

    return $BINARY_AST{$type}->new(build_ast(ref($left) ? $left : ['VAR', $left] ), build_ast($right));
}

sub build_ast {
    my ($ast) = @_;
    my $ref = ref($ast);
    if ($ref eq 'ARRAY') {
        my $t = $ast->[0];    
        if (!exists $AST_BUILDER{$t}) {
            die "Invalid AST type '$t'"
        }

        return $AST_BUILDER{$t}->($ast);
    }

    if ($ref) {
        die "Invalid AST value";
    }

    return pf::ast::val->new($ast);
}

sub build_not_ast {
    my ($ast) = @_;
    my ($t, $nast) = @$ast;
    return pf::ast::not->new(build_ast($nast));
}

sub build_func_ast {
    my ($ast) = @_;
    my ($t, $func, $args) = @$ast;
    if (!exists $pf::ast::functions::FUNCS{$func}) {
        die "$func is not a valid function";
    }

    local $_;
    return pf::ast::func->new($pf::ast::functions::FUNCS{$func}, map { build_ast($_) } @$args);
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
