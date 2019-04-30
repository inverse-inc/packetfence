package pf::factory::condition::security_event;
=head1 NAME

pf::factory::condition::security_event

=cut

=head1 DESCRIPTION

pf::factory::condition::security_event

Create the list of conditions for the filter engine based on the triggers of a security_event

=cut

use strict;
use warnings;
use Module::Pluggable
  search_path => 'pf::condition',
  sub_name    => '_modules',
  inner       => 0,
  require     => 1;
use List::MoreUtils qw(any);
use pf::constants;

our @MODULES;

sub factory_for {'pf::condition'};

my $DEFAULT_CONDITION = 'key';

our %TRIGGER_TYPE_TO_CONDITION_TYPE = (
    'accounting'                => {type => 'equals',                   key  => 'last_accounting_id'},
    'recorded_accounting'       => {type => 'includes',                 key  => 'last_accounting_events'},
    'detect'                    => {type => 'equals',                   key  => 'last_detect_id',          event => $TRUE},
    'device'                    => {type => 'fingerbank::device_is_a',  key  => 'device_id'},
    'dhcp_fingerprint'          => {type => 'equals',                   key  => 'dhcp_fingerprint_id'},
    'dhcp_vendor'               => {type => 'equals',                   key  => 'dhcp_vendor_id'},
    'dhcp6_fingerprint'         => {type => 'equals',                   key  => 'dhcp6_fingerprint_id'},
    'dhcp6_enterprise'          => {type => 'equals',                   key  => 'dhcp6_enterprise_id'},
    'internal'                  => {type => 'equals',                   key  => 'last_internal_id',        event => $TRUE},
    'custom'                    => {type => 'equals',                   key  => 'last_custom_id',        event => $TRUE},
    'mac'                       => {type => 'regex',                    key  => 'mac'},
    'mac_vendor'                => {type => 'equals',                   key  => 'mac_vendor_id'},
    'nessus'                    => {type => 'equals',                   key  => 'last_nessus_id',          event => $TRUE},
    'nessus6'                   => {type => 'equals',                   key  => 'last_nessus6_id',         event => $TRUE},
    'openvas'                   => {type => 'equals',                   key  => 'last_openvas_id',         event => $TRUE},
    'provisioner'               => {type => 'equals',                   key  => 'last_provisioner_id',     event => $TRUE},
    'suricata_event'            => {type => 'starts_with',              key  => 'last_suricata_event',     event => $TRUE},
    'suricata_md5'              => {type => 'equals',                   key  => 'last_suricata_md5',       event => $TRUE},
    'useragent'                 => {type => 'equals',                   key  => 'user_agent_id'},
    'role'                      => {type => 'equals',                   key  => 'role'},
    'switch'                    => {type => 'equals',                   key  => 'last_switch'},
    'switch_group'              => {type => 'switch_group',             key  => 'last_switch'},
    'nexpose_event_contains'    => {type => 'matches',                  key  => 'last_nexpose_event',      event => $TRUE},
    'nexpose_event_starts_with' => {type => 'starts_with',              key  => 'last_nexpose_event',      event => $TRUE},
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
    my ($type, $data);
    my $trigger = $args[0];
    if($trigger =~ /\((.+)\)/){
        my @triggers = split(/\s*&\s*/,$1);
        my @conditions;
        foreach my $sub_trigger (@triggers){
            # In multi-trigger context, we use the recorded accounting triggers
            if($sub_trigger =~ /^accounting::(.*)/) {
                $sub_trigger = "recorded_accounting::$1";
            }

            ($type,$data) = $class->getData($sub_trigger);
            my $subclass = $class->getModuleName($type);
            my $condition = $subclass->new($data);
            push @conditions, pf::condition::key->new(key => $data->{key}, condition => $condition);
        }
        return pf::condition::all->new(conditions => \@conditions);
    }
    else {
        ($type,$data) = $class->getData(@args);
        if ($data) {
            my $subclass = $class->getModuleName($type);
            my $condition = $subclass->new($data);
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
    my ($class, $trigger) = @_;
    my ($type, $value);
    #Split parse the filter by type and value
    if ($trigger =~ /(.+)::(.+)/ ) {
        $type  = lc($1);
        $value = $2;
    } else {
        die "'$trigger' is invalid";
    }
    #make a copy to avoid modifing the orginal data
    die "Trigger type '$type' is not supported" unless $type && exists $TRIGGER_TYPE_TO_CONDITION_TYPE{$type};
    my %args = %{$TRIGGER_TYPE_TO_CONDITION_TYPE{$type}};
    my $condition_type = delete $args{type};
    $args{value} = $value;
    return $condition_type, \%args;
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
