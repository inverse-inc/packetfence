package pf::mini_template;

=head1 NAME

pf::mini_template -

=head1 DESCRIPTION

pf::mini_template

=cut

use strict;
use warnings;
use Scalar::Util qw(reftype);
use List::MoreUtils qw(uniq);
use JSON::MaybeXS ();
use URI::Escape qw(uri_escape uri_escape_utf8);
use pf::util qw(random_from_range extract);
use pf::log;
use Data::Dumper;

# Returns characters rather than UTF-8 bytes, and keeps the result ASCII by
# escaping non-ASCII characters, so it can be embedded in a template body
# without mixing encodings.
my $JSON_STRING = JSON::MaybeXS->new->utf8(0)->ascii(1)->allow_nonref(1);

our %FUNCS = (
    uc => sub { return uc($_[0]) },
    lc => sub { return lc($_[0]) },
    join => sub { my $r = shift; return join($r, @_); },
    split => sub { return split($_[0], $_[1]) },
    substr => sub { return substr($_[0], $_[1], $_[2]) },
    macToEUI48 => sub { my $m = shift; $m =~ s/:/-/g; return uc($m) },
    random_from_range => \&random_from_range,
    log => sub { get_logger()->info("mini_template:" . Dumper(\@_)  ); ''},
    replace => \&replaceStr,
    BuildFromMatch => \&extract,
    if => sub { $_[0] ? $_[1] : $_[2] },
    json_quote => \&json_quote,
    url_quote  => \&url_quote,
);

sub replaceStr {
    my ($str, $old, $new) = @_;
    $str =~ s/\Q$old\E/$new/g;
    return $str;
};

=head2 json_quote

Quote a value as a JSON string, escapes included, for use where a JSON string
is expected. C<undef> becomes C<null>. The surrounding quotes are part of the
result, so a template writes C<${json_quote($node.pid)}> without quotes of its
own:

  {"user": ${json_quote($node.pid)}}

The result is kept ASCII: non-ASCII characters are escaped, so it can be
embedded in a template body without mixing character and byte strings.

=cut

sub json_quote {
    my ($value) = @_;
    return 'null' if !defined $value;
    $value = "$value";
    # A value read from the database or the configuration can be a UTF-8 byte
    # string; decode it so encode() sees characters rather than a Latin-1
    # string built from each byte.
    if (!utf8::is_utf8($value)) {
        my $decoded = $value;
        $value = $decoded if utf8::decode($decoded);
    }

    return $JSON_STRING->encode($value);
}

=head2 url_quote

Percent-encode a value for use as a URL path segment or query parameter.
Everything outside the RFC 3986 unreserved set is encoded; C<undef> becomes
the empty string.

=cut

sub url_quote {
    my ($value) = @_;
    return '' if !defined $value;
    $value = "$value";
    my $unreserved = '^A-Za-z0-9._~-';
    if (!utf8::is_utf8($value)) {
        my $decoded = $value;
        # Not valid UTF-8: escape the bytes as they are rather than encoding
        # each of them a second time.
        return uri_escape($value, $unreserved) if !utf8::decode($decoded);
        $value = $decoded;
    }

    return uri_escape_utf8($value, $unreserved);
}

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    @EXPORT = qw(
        %FUNCS
    );
}

sub supported_function { exists $FUNCS{$_[0] // ''} }

sub new {
    my ($proto, $text) = @_;
    my $class = ref($proto) || $proto;
    my ($tmpl, $info, $msg) = parse_template($text);
    return bless { text => $text, tmpl => $tmpl, info => $info }, $class;
}

sub process {
    my ($self, $vars, $funcs) = @_;
    return join('', $self->pre_process($vars, $funcs));
}

sub pre_process {
    my ($self, $vars, $funcs) = @_;
    $funcs //= \%FUNCS;
    return $self->process_tmpl($self->{tmpl}, $vars, $funcs);
}

sub process_tmpl {
    my ($self, $tmpl, $vars, $funcs) = @_;
    my $type = $tmpl->[0];
    if (!ref ($type)) {
        return $self->process_simple_tmpl($tmpl, $vars, $funcs);
    }

    return map {my $t = $_; $self->process_tmpl($t, $vars, $funcs)} @$tmpl;
}

sub process_simple_tmpl {
    my ($self, $tmpl, $vars, $funcs) = @_;
    my $type = $tmpl->[0];
    if ($type eq 'S') {
        return $tmpl->[1];
    } elsif ($type eq 'V') {
        return $vars->{$tmpl->[1]};
    } elsif ($type eq 'K') {
        my @keys = @{$tmpl->[1]};
        my $last = pop @keys;
        my $v = $vars;
        for my $k (@keys) {
            if (!exists $v->{$k}) {
                return '';
            }

            my $t = $v->{$k};
            if (reftype ($t) ne 'HASH') {
                return '';
            }

            $v = $t;
        }
        
        return $v->{$last};
    } elsif ($type eq 'F') {
        my $n = $tmpl->[1];
        if (!exists $funcs->{$n}) {
            die "func $n is not defined\n";
        }

        return $funcs->{$n}->(map {my $t = $_;$self->process_simple_tmpl($t, $vars, $funcs)} @{$tmpl->[2]});
    }

    return '';
}

our $MARKER  = '^';
our $HIGH_LIGHT = '~';

sub parse_template {
    local $_ = shift;
    if (!defined $_) {
        die "cannot parse an undefined value";
    }
    my $info = {};
    my $a = _optimize(_parse_text($info));
    return $a, $info, "";
}

sub _parse_text {
    if (/\G\z/gc) {
        return;
    }

    /\G([^\$]*)/gc;
    my $t = $1;
    if (!/\G\$/gc) {
        return ['S', $t];
    }

    if ($t ne '') {
        return [['S', $t], _parse_var($_[0])];
    }

    return _parse_var($_[0])
}

sub _is_string {
    ref ($_[0]) && $_[0][0] eq 'S';
}

sub _optimize {
    if (@_ == 0) {
        return;
    }

    my $nodes = $_[0];
    if (@$nodes == 1 ) {
        return $nodes->[0];
    }

   if (_is_string($nodes->[0])) {
       my @new = (shift @$nodes);
       for my $p (@{$nodes}) {
           if ( _is_string($p) && _is_string($new[-1])){
               $new[-1][1] .= $p->[1];
           } else {
               push @new, $p;
           }
       }

       return @new == 1 ? $new[0] : \@new;
   }

    return $nodes;
}

sub _parse_var {
    if (/\G\$/gc) {
        return _optimize([['S', '$'], _optimize( _parse_text($_[0]) )]);
    }
    
    if (/\G\{\s*/gc) {
        my @names = _parse_var_names();
        if (@names == 0) {
            die format_parse_error("Invalid variable name", $_, pos);
        }

        if (/\G\s*\(\s*/gc) {
            my $n = join('.', @names);
            $_[0]->{funcs}{$n} = undef;
            my $f = ['F', $n, _parse_func($_[0])];
            if (!/\G\s*\}/gc) {
                die format_parse_error("no matching }", $_, pos);
            }

            return _optimize([$f, _parse_text($_[0])]);
        }

        if (!/\G\s*\}/gc) {
            die format_parse_error("no matching }", $_, pos);
        }

        if (@names == 1) {
            $_[0]->{vars}{$names[0]} = undef;
            return [['V', @names], _parse_text($_[0])];
        }

        _add_keys_to_info($_[0], @names);
        return _optimize( [ ['K', \@names], _parse_text($_[0])]);
    }

    return _optimize([_parse_var_name($_[0]), _parse_text($_[0])]);
}

sub _parse_var_names {
    if (/\G([a-zA-Z-0-9_]+(-[a-zA-Z-0-9_]+)*(\.([a-zA-Z-0-9_]+(-[a-zA-Z-0-9_]+)*))*)/gc) {
        return split /\./, $1;
    }

    return;
}

sub _parse_var_name {
    my @names = _parse_var_names();
    if (@names == 0) {
        die format_parse_error("Invalid variable name", $_, pos);
    }

    if (@names == 1) {
        $_[0]->{vars}{$names[0]} = undef;
        return ['V', @names];
    }

    _add_keys_to_info($_[0], @names);
    return ['K', \@names];
}

sub _add_keys_to_info {
    my $info = shift;
    my $vars = $info->{vars} //= {};
    my $last = pop @_;
    for my $k (@_) {
        $vars = $vars->{$k} //= {};
    }

    $vars->{$last} = undef;
}

sub _parse_func {
    if (/\G\s*\)\s*/gc) {
        return [];
    }

    my @args;
    push @args, _parse_func_arg($_[0]);
    while (!/\G\s*\)\s*/gc) {
        if (!/\G\s*,\s*/gc) {
            die format_parse_error("No comma found", $_, pos);
        }

        push @args, _parse_func_arg($_[0]);
    }

    return \@args;
}


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
    my $post_len = $string_length - length($pre_hilight) - 2;
    $post_len = 0 if $post_len < 0;
    my $post_hilight = " " . $HIGH_LIGHT x $post_len;
    return "${msg}${pre_hilight}${MARKER}${post_hilight}\n";
}


sub _parse_func_arg {
    if (/\G\z/gc) {
        die format_parse_error("Missing ')' or ','", $_, pos);
    }
    
    if (/\G\$/gc) {
        return _parse_var_name($_[0]);
    }

    if (/\G"(([^"]|\\")*)"/gc) {
        return ['S', $1];
    }

    if (/\G'(([^']|\\')*)'/gc) {
        return ['S', $1];
    }

    if (/\G([0-9]+)/gc) {
        return ['S', $1];
    }

    if (/\G([-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?)/gc) {
        return ['S', $1];
    }

    my @names = _parse_var_names();
    if (@names) {
        if (/\G\s*\(\s*/gc) {
            my $n = join('.', @names);
            $_[0]->{funcs}{$n} = undef;
            return ['F', $n, _parse_func($_[0])];
        }
    }

    die format_parse_error("Invalid function arg", $_, pos);
}

sub update_variables_for_set {
    my ($set, $lookup, $vars, @args) = @_;
    return if !defined $set;
    my @vars;
    for my $s (@$set) {
        push @vars, keys %{$s->{tmpl}{info}{vars}//{}};
    }
    @vars = uniq @vars;
    for my $v (@vars) {
        if (!exists $vars->{$v} && exists $lookup->{$v}) {
            $vars->{$v} = $lookup->{$v}->(@args);
        }
    }
}

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
