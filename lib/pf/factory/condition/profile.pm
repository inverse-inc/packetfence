package pf::factory::condition::profile;

=head1 NAME

pf::factory::condition::profile

=cut

=head1 DESCRIPTION

pf::factory::condition::profile

=cut

use strict;
use warnings;
use Module::Pluggable
  search_path => 'pf::condition',
  sub_name    => '_modules',
  inner       => 0,
  require     => 1;
our $DEFAULT_TYPE = 'ssid';
our $PROFILE_FILTER_REGEX = qr/^(([^:]|::)+?):(.*)$/;
use List::MoreUtils qw(any);
use pf::condition_parser qw(parse_condition_string);
use pf::util qw(str_to_connection_type);
use pf::constants::eap_type qw(%RADIUS_EAP_TYPE_2_VALUES);
use pf::log;
use base qw(pf::factory::condition);

our %UNARY_OPS = (
    'NOT' => 'pf::condition::not',
);

our %LOGICAL_OPS = (
    'AND' => 'pf::condition::all',
    'OR'  => 'pf::condition::any',
);

our %CMP_OPS = (
    '=='  => 'pf::condition::equals',
    '!='  => 'pf::condition::not_equals',
    '=~'  => 'pf::condition::regex',
    '!~'  => 'pf::condition::regex_not',
);

our %OPS = (%LOGICAL_OPS, %CMP_OPS, %UNARY_OPS);

our %NULLABLE_OPS = (
    '==' => 'pf::condition::not_defined',
    '!=' => 'pf::condition::is_defined',
);


sub factory_for {'pf::condition'};

my $DEFAULT_CONDITION = 'key';

our %PROFILE_FILTER_TYPE_TO_CONDITION_TYPE = (
    'network'             => {type => 'network',       key  => 'last_ip'},
    'node_role'           => {type => 'equals',        key  => 'category'},
    'connection_type'     => {type => 'equals',        key  => 'last_connection_type'},
    'port'                => {type => 'equals',        key  => 'last_port'},
    'realm'               => {type => 'equals',        key  => 'realm'},
    'ssid'                => {type => 'equals',        key  => 'last_ssid'},
    'switch'              => {type => 'exists_in',     key  => 'last_switch'},
    'switch_mac'          => {type => 'exists_in',     key  => 'last_switch_mac'},
    'switch_port'         => {type => 'couple_equals', key1 => 'last_switch', key2 => 'last_port'},
    'uri'                 => {type => 'equals',        key  => 'last_uri'},
    'vlan'                => {type => 'equals',        key  => 'last_vlan'},
    'connection_sub_type' => {type => 'equals',        key  => 'last_connection_sub_type'},
    'tenant'              => {type => 'equals',        key  => 'tenant_id'},
    'time'                => {type => 'time'},
    'switch_group'        => {type => 'switch_group',  key  => 'last_switch'},
    'fqdn'                => {type => 'equals',        key  => 'fqdn'},
);

sub instantiate {
    my ($class, @args) = @_;
    my $condition;
    my ($type, $data) = $class->getData(@args);
    if ($data) {
        if($type eq 'couple_equals'){
            my ($value1, $value2) = split(/-/, $data->{value});
            my $cond1 = pf::condition::key->new(key => $data->{key1}, condition => pf::condition::equals->new(value => $value1));
            my $cond2 = pf::condition::key->new(key => $data->{key2}, condition => pf::condition::equals->new(value => $value2));
            my $cond_and = pf::condition::all->new(conditions => [$cond1, $cond2]);
            return $cond_and;
        }
        elsif($type eq 'exists_in'){
            my @values = split(/\s*;\s*/, $data->{value});
            my $condition;
            if (@values == 1) {
                $condition = pf::condition::equals->new({value => $data->{value}});
            }
            else {
                my %lookup = map { $_ => 1 } @values;
                $condition = pf::condition::exists_in->new({lookup => \%lookup});
            }
            return pf::condition::key->new(key => $data->{key}, condition => $condition);
        }
        elsif ($type eq 'time') {
            my $c = pf::condition::time_period->new({value => $data->{value}});
            return $c;
        }
        elsif ($type eq 'advanced') {
            return $class->instantiate_advanced($data->{value});
        }
        else {
            my $subclass = $class->getModuleName($type);
            $condition = $subclass->new($data);
            return pf::condition::key->new(key => $data->{key}, condition => $condition);
        }
    }
}

my %VALUE_FILTERS = (
    connection_sub_type => sub {
        return $RADIUS_EAP_TYPE_2_VALUES{$_[0]};
    },
);

sub instantiate_advanced {
    my ($class, $filter) = @_;
    my ($condition, $msg) = parse_condition_string($filter);
    die "$msg" unless defined $condition;
    return build_conditions($class, $condition);
}

sub getModuleName {
    my ($class, $type) = @_;
    my $mainClass = $class->factory_for;
    die "type is not defined" unless defined $type;
    my $subclass = "${mainClass}::${type}";
    die "$type is not a valid type of $mainClass" unless any {$_ eq $subclass} $class->modules;
    $subclass;
}

sub getData {
    my ($class, $filter) = @_;
    #Split parse the filter by type and value
    die "Filter '$filter' is invalid  please update to newer format 'type:data'"
        unless $filter =~ $PROFILE_FILTER_REGEX;
    my ($type, $value) = ($1, $3);
    die "Profile filter type '$type' is not supported" unless exists $PROFILE_FILTER_TYPE_TO_CONDITION_TYPE{$type};
    #make a copy to avoid modifing the original data
    my %args = %{$PROFILE_FILTER_TYPE_TO_CONDITION_TYPE{$type}};
    my $condition_type = delete $args{type};
    if (exists $VALUE_FILTERS{$type}) {
        $value = $VALUE_FILTERS{$type}->($value);
    }
    $args{value} = $value;
    return $condition_type, \%args;
}

sub build_conditions {
    my ($self, $condition) = @_;
    die "Invalid Condition provided\n" unless ref $condition;
    my ($op, @operands) = @$condition;
    die "Operator '$op' is not valid\n" unless exists $OPS{$op};
    my $class = $OPS{$op};
    if (exists $UNARY_OPS{$op}) {
        my $condition = build_conditions($self, $operands[0]);
        return $class->new({condition => $condition});
    }
    if (exists $LOGICAL_OPS{$op}) {
        my $conditions = [map { build_conditions($self, $_) } @operands];
        return $class->new({conditions => $conditions});
    }
    if (exists $NULLABLE_OPS{$op} && $operands[-1] eq '__NULL__' ) {
       $class = $NULLABLE_OPS{$op};
    }
    my ($first, @keys) = split /\./, $operands[0];
    my $sub_condition = $class->new({ value => $operands[1] });
    if ($first eq 'extended' ) {
        die "No sub fields provided for the extended key\n" unless @keys > 1;
        my $extened_namespace = shift @keys;
        return pf::condition::node_extended->new({
            key => $first,
            condition =>  pf::condition::node_extended_data->new({
                key => $extened_namespace,
                condition => _build_parent_condition($sub_condition, @keys),
            })
        });
    }

    $first = format_root_key($first);
    return _build_parent_condition($sub_condition, $first, @keys);
}

sub format_root_key {
    my ($first) = @_;
    return
         exists $PROFILE_FILTER_TYPE_TO_CONDITION_TYPE{$first}
      && exists $PROFILE_FILTER_TYPE_TO_CONDITION_TYPE{$first}{key}
      ? $PROFILE_FILTER_TYPE_TO_CONDITION_TYPE{$first}{key}
      : $first;
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
