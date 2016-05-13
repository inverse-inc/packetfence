package pf::factory::condition::profile;
=head1 NAME

pf::factory::condition::profile

=cut

=head1 DESCRIPTION

pf::factory::condition::profile

=cut

use strict;
use warnings;
use Module::Pluggable search_path => 'pf::condition', sub_name => '_modules' , require => 1;
our $DEFAULT_TYPE = 'ssid';
our $PROFILE_FILTER_REGEX = qr/^(([^:]|::)+?):(.*)$/;
use List::MoreUtils qw(any);

our @MODULES;

__PACKAGE__->modules;

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
    'time'                => {type => 'time'},
    'switch_group'        => {type => 'switch_group',  key  => 'last_switch'},
);

sub modules {
    my ($class) = @_;
    unless(@MODULES) {
        @MODULES = $class->_modules;
    }
    return @MODULES;
}

sub instantiate {
    my ($class, @args) = @_;
    my $condition;
    my ($type,$data) = $class->getData(@args);
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
        else{
            my $subclass = $class->getModuleName($type);
            $condition = $subclass->new($data);
            return pf::condition::key->new(key => $data->{key}, condition => $condition);
        }
    }
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
    $args{value} = $value;
    return $condition_type, \%args;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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
