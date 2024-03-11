#!/usr/bin/perl

=head1 NAME

to-10-filter_engines.pl

=head1 DESCRIPTION

Upgrades the filter engines format

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib /usr/local/pf/lib_perl/lib/perl5);
use pf::IniFiles;
use File::Copy;
use pf::condition_parser qw(parse_condition_string ast_to_object);
use pf::util::console;

my $COLORS = pf::util::console::colors();
my $old_ext = "old_pre_v10";
our $indent = "  ";

use pf::file_paths qw(
    $vlan_filters_config_file
    $radius_filters_config_file
    $dhcp_filters_config_file
    $dns_filters_config_file
    $switch_filters_config_file
);

my %rename = (
    scope => 'scopes',
    status => 'radius_status',
);

my %new_fields = (
    status => 'enabled',
);

my %skipped = (
    action_param => undef,
);

my %operator = (
    regex => '=~',
    regex_not => '!~',
    is => '==',
    is_not => '!=',
    greater => '>',
    greater_equals => '>=',
    lower => '<',
    lower_equals => '<=',
);

my %functions = (
    'fingerbank::device_is_a' => 'fingerbank_device_is_a',
    match                     => 'contains',
    match_not                 => 'not_contains',
    (
        map { $_ => $_ }
          qw(
          includes
          defined
          not_defined
          date_is_before
          date_is_after
          )
    )
);

sub upgrade_filter {
    my ($name) = @_;
    if (!-e $name) {
        return ( { file => $name, message => "file '$name' does not exists" }, undef );
    }

    my $cs = pf::IniFiles->new( -file => $name, -allowempty => 1, );
    if (!defined $cs) {
        return (
            {
                file    => $name,
                message => join( " ", @Config::IniFiles::errors )
            },
            undef
        );
    }

    my $ctx = {
        file => $name,
        rules => [],
        conditions => {},
        already_migrated => [],
    };

    my $res = prep_ctx($cs, $ctx);

    return ({message => "Detected a condition that was already migrated by this script for $name. Will not process this file..."}, ()) unless($res);

    my $new_file = pf::IniFiles->new();
    my @warnings = populate($new_file, $ctx);
    copy($name, "$name.$old_ext");
    $new_file->WriteConfig($name);
    return (undef, \@warnings);
}

sub prep_ctx {
    my ($cs, $ctx) = @_;
    
    for my $s ($cs->Sections) {
        my $data = make_hash($cs, $s);

        if($data->{condition}) {
            return 0;
        }

        if ($s =~ /^(.*?):(.*)$/) {
            my $id = $1;
            $data->{condition} = $2;
            $data->{id} = $id;
            push @{$ctx->{rules}}, $data;
        } else {
            $ctx->{conditions}{$s} = $data;
        }
    }
    return 1;
}

sub populate {
    my ($new_file, $ctx) = @_;
    my @errors;
    for my $rule (@{$ctx->{rules}}) {
        my $id = delete $rule->{id};
        my $condition = delete $rule->{condition};
        my ($ast, $err) = parse_condition_string($condition);
        if ($err) {
            delete $err->{message};
            push @errors,
              make_error(
                $ctx, $err, delete $err->{highlighted_error},
                rule => $id,
                %$err
              );
            next;
        }
        my $top_op;
        if (!ref $ast) {
            $top_op = 'and';
        }

        $condition = eval {new_condition($ctx, $ast)};

        if ($@) {
            push @errors, make_error($ctx, $@, rule => $id);
            next;
        }

        if ($new_file->SectionExists($id)) {
            return;
        }

        $new_file->AddSection($id);
        while (my ($k, $v) = each %new_fields) {
            $new_file->newval($id, $k, $v);
        }

        $new_file->newval($id, 'description', "Rule $id");
        $new_file->newval($id, 'condition', $condition);
        if ($top_op) {
            $new_file->newval($id, 'top_op', $top_op);
        }

        while (my ($k, $v) = each %$rule) {
            if (exists $skipped{$k}) {
                next;
            }

            if (exists $rename{$k}) {
                $k = $rename{$k};
            }

            if ($k =~ qr/(answer|param)(\d+)/) {
                my $i = $2 - 1;
                $k = "$1.$i";
                $v =~ s/\s*=>\s*/ = /;
            }

            if ($k eq 'action') {
                $k = 'action.0';
                $v = "${v}:$rule->{action_param}";
            }

            $new_file->newval($id, $k, $v);
        }

        $new_file->newval($id, "description", $id);

    }
    return @errors;
}

sub new_condition {
    my ($ctx, $ast) = @_;
    my $condition = _new_condition($ctx, $ast);
    $condition =~ s/^\((.*)\)$/$1/;
    return $condition;
}

sub _new_condition {
    my ($ctx, $ast) = @_;
    if (ref $ast) {
        my ($op, @rest) = @$ast;
        if ($op eq 'OR') {
            return '(' . join(" || ", map { _new_condition($ctx, $_) } @rest) . ')';
        } elsif ($op eq 'AND') {
            return '(' . join(" && ", map { _new_condition($ctx, $_) } @rest) . ')';
        } else {
            return "!(" . new_condition($ctx, @rest) . ")";
        }

        die "Invalid syntax\n"
    }

    return build_condition($ctx, $ast);
}

sub make_error {
    my ($ctx, $message, @args) = @_;
    return { file => $ctx->{file}, message => $message, @args };
}

sub build_condition {
    my ($ctx, $name) = @_;
    if (!exists $ctx->{conditions}{$name}) {
        die "condition '$name' not found\n";
    }

    my $condition = $ctx->{conditions}{$name};
    my $op = $condition->{operator};
    my $filter = $condition->{filter};
    my $attribute = $condition->{attribute};
    if (defined $attribute && length $attribute) {
        $filter .= ".$attribute";
    }

    my $val = $condition->{value} // '';
    $val =~ s/(["\\])/\\$1/g;
    if ($filter eq 'time') {
        if ($op eq 'is') {
            return "time_period(time, \"$val\")"
        } elsif ($op eq 'is_not') {
            return "!(time_period(time, \"$val\"))"
        }
    }
    if (exists $operator{$op}) {
        return "$filter $operator{$op} \"$val\"";
    } elsif (exists $functions{$op}) {
        return "$functions{$op}($filter, \"$val\")";
    }

    die "operator '$op' is unknown\n";
}

sub make_hash {
    my ($cs, $sect) = @_;
    my %hash = (
        id => $sect,
    );
    for my $p ($cs->Parameters($sect)) {
        $hash{$p} = $cs->val($sect, $p);
    }
    return \%hash;
}

my @files = (
    $vlan_filters_config_file,
    $radius_filters_config_file,
    $dhcp_filters_config_file,
    $dns_filters_config_file,
    $switch_filters_config_file,
);

if (@ARGV) {
    @files = @ARGV;
}

sub display_error {
    my ($err) = @_;
    print $COLORS->{error}, $indent, $err->{message}, $COLORS->{reset}, "\n";
}

sub display_warning {
    my ($err) = @_;
    print $indent, $indent, $COLORS->{warning}, $err->{rule}, ": ", $err->{message}, $COLORS->{reset}, "\n";
}

for my $file (@files) {
    print "Upgrading $file to the new format\n";
    my ($err, $warnings) = upgrade_filter($file);
    if ($err) {
        display_error($err);
        print $indent, "Skipping\n";
    } else {
        print "${indent}Old config is located $file.$old_ext\n\n";
        if (@$warnings) {
            print "${indent}Problems converting some rules \n";
            for my $w (@$warnings) {
                display_warning($w);
            }
        }
    }
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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

