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

sub factory_for {'pf::condition'};

my $DEFAULT_CONDITION = 'key';

our %PROFILE_FILTER_TYPE_TO_CONDITION_TYPE = (
    'network'         => {type => 'network',       key  => 'last_ip'},
    'node_role'       => {type => 'equals',        key  => 'category'},
    'connection_type' => {type => 'equals',        key  => 'last_connection_type'},
    'port'            => {type => 'equals',        key  => 'last_port'},
    'realm'           => {type => 'equals',        key  => 'realm'},
    'ssid'            => {type => 'equals',        key  => 'last_ssid'},
    'switch'          => {type => 'equals',        key  => 'last_switch'},
    'switch_port'     => {type => 'couple_equals', key1 => 'last_switch', key2 => 'last_port'},
    'uri'             => {type => 'equals',        key  => 'last_uri'},
    'vlan'            => {type => 'equals',        key  => 'last_vlan'},
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
    my ($type, $value);
    #Split parse the filter by type and value
    if ($filter =~ $PROFILE_FILTER_REGEX ) {
        $type  = $1;
        $value = $3;
    } else {
        #If there is no type defined to support older filters (3.5.0)
        $type  = $DEFAULT_TYPE;
        $value = $filter;
    }
    #make a copy to avoid modifing the orginal data
    die "Profile filter type '$type' is not supported" unless exists $PROFILE_FILTER_TYPE_TO_CONDITION_TYPE{$type};
    my %args = %{$PROFILE_FILTER_TYPE_TO_CONDITION_TYPE{$type}};
    my $condition_type = delete $args{type};
    $args{value} = $value;
    return $condition_type, \%args;
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
