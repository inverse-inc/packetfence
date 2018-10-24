package pf::factory::condition::access_filter;

=head1 NAME

pf::factory::condition::access_filter

=cut

=head1 DESCRIPTION

pf::factory::condition::access_filter

=cut

use strict;
use warnings;
use Module::Pluggable
  search_path => 'pf::condition',
  sub_name    => '_modules',
  inner       => 0,
  require     => 1;
use pf::util qw(str_to_connection_type);
use pf::constants::eap_type qw(%RADIUS_EAP_TYPE_2_VALUES %RADIUS_EAP_VALUES_2_TYPE);

our @MODULES;

sub factory_for {'pf::condition'}

our %FILTER_OP_TO_CONDITION = (
    'is'                        => 'pf::condition::equals',
    'is_not'                    => 'pf::condition::not_equals',
    'includes'                  => 'pf::condition::includes',
    'match'                     => 'pf::condition::matches',
    'regex'                     => 'pf::condition::regex',
    'match_not'                 => 'pf::condition::not_matches',
    'regex_not'                 => 'pf::condition::regex_not',
    'defined'                   => 'pf::condition::is_defined',
    'not_defined'               => 'pf::condition::not_defined',
    'date_is_before'            => 'pf::condition::date_before',
    'date_is_after'             => 'pf::condition::date_after',
    'greater'                   => 'pf::condition::greater',
    'greater_equals'            => 'pf::condition::greater_equals',
    'lower'                     => 'pf::condition::lower',
    'lower_equals'              => 'pf::condition::lower_equals',
    'fingerbank::device_is_a'   => 'pf::condition::fingerbank::device_is_a',
);

sub modules {
    my ($class) = @_;
    unless (@MODULES) {
        @MODULES = $class->_modules;
    }
    return @MODULES;
}

__PACKAGE__->modules;

sub instantiate {
    my ($class, $data) = @_;
    my $filter = $data->{filter};
    return unless defined $filter;

    if ($filter eq 'time') {
        my $c = pf::condition::time_period->new({value => $data->{value}});
        if ($data->{operator} eq 'is_not') {
            return pf::condition::not->new({condition => $c});
        }

        return $c;
    }

    my $attribute = $data->{attribute};
    $filter .= ".$attribute" if defined $attribute && length $attribute;
    my $sub_condition = _build_sub_condition($data);
    return _build_parent_condition($sub_condition, (split /\./, $filter));
}

sub _build_parent_condition {
    my ($child, $key, @parents) = @_;
    if (@parents == 0) {
        return pf::condition::key->new({
            key       => $key,
            condition => $child,
        });
    }

    return pf::condition::key->new({
        key       => $key,
        condition => _build_parent_condition($child, @parents),
    });
}

my %VALUE_FILTERS = (
    'connection_type'     => \&str_to_connection_type,
    'connection_sub_type' => \&normalize_connection_sub_type,
    'EAP-Type'            => \&normalize_eap_type,
);

sub normalize_connection_sub_type {
    return $RADIUS_EAP_TYPE_2_VALUES{$_[0]};
}

sub normalize_eap_type {
    my $v = $_[0];
    if (exists $RADIUS_EAP_VALUES_2_TYPE{$v}) {
        return $v;
    }

    if (exists $RADIUS_EAP_TYPE_2_VALUES{$v}) {
        return $RADIUS_EAP_TYPE_2_VALUES{$v};
    }

    return 0;
}

sub _build_sub_condition {
    my ($data) = @_;
    my $op = $data->{operator};
    my $condition_class = $FILTER_OP_TO_CONDITION{$op};
    unless ($condition_class) {
        die "Invalid operator : $op\n";
    }

    my $filter = $data->{filter};
    my $value = $data->{value};
    if (exists $VALUE_FILTERS{$filter}) {
        $value = $VALUE_FILTERS{$filter}->($value);
    }

    return $condition_class ? $condition_class->new({value => $value}) : undef;
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
