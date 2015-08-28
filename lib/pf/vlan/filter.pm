package pf::vlan::filter;

=head1 NAME

pf::vlan::filter - handle the authorization rules on the vlan attribution

=cut

=head1 DESCRIPTION

pf::vlan::filter deny, rewrite role based on rules.

=cut

use strict;
use warnings;

use Log::Log4perl;
use pf::api::jsonrpcclient;
use pf::config qw(%connection_type_to_str);
use pf::person qw(person_view);
use pf::factory::condition::vlanfilter;
use pf::filter_engine;
use pf::filter;
tie our %ConfigVlanFilters, 'pfconfig::cached_hash', 'config::VlanFilters';
tie our %VlanFilterEngineScopes, 'pfconfig::cached_hash', 'resource::VlanFilterEngineScopes';


=head1 SUBROUTINES

=over

=item new

=cut

sub new {
   my $logger = Log::Log4perl::get_logger("pf::vlan::filter");
   $logger->debug("instantiating new pf::vlan::filter");
   my ( $class, %argv ) = @_;
   my $self = bless {}, $class;
   return $self;
}

=item test

Test all the rules

=cut

sub test {
    my ($self, $scope, $switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid, $radius_request) = @_;
    my $args = {
        node_info       => $node_info,
        switch          => $switch,
        ifIndex         => $ifIndex,
        mac             => $mac,
        connection_type => $connection_type,
        username        => $user_name,
        ssid            => $ssid,
        owner           => person_view($node_info->{'pid'}),
        radius_request  => $radius_request,
    };
    if (exists $VlanFilterEngineScopes{$scope}) {
        my $rule = $VlanFilterEngineScopes{$scope}->match_first($args);
        if (defined($rule->{'action'}) && $rule->{'action'} ne '') {
            $self->dispatchAction($rule, $switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid, $radius_request);
        }
        if (defined($rule->{'role'}) && $rule->{'role'} ne '') {
            my $role = $rule->{'role'};
            $role =~ s/(\$.*)/$1/gee;
            my $vlan = $switch->getVlanByName($role);
            return (1, $role) if ($scope eq 'AutoRegister');
            return ($vlan, $role);
        }
        return (0, 0);
    }

}

=item dispatchAction

Return the reference to the function that call the api.

=cut

sub dispatchAction {
    my ($self, $rule, $switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid, $radius_request) = @_;

    my $param = $self->evalParam($rule->{'action_param'},$switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid, $radius_request);
    my $apiclient = pf::api::jsonrpcclient->new;
    $apiclient->notify($rule->{'action'},%{$param});
}

=item evalParam

evaluate action parameters

=cut

sub evalParam {
    my ($self, $action_param, $switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid, $radius_request) = @_;
    $action_param =~ s/\s//g;
    my @params = split(',', $action_param);
    my $return = {};

    foreach my $param (@params) {
        $param =~ s/(\$.*)/$1/gee;
        my @param_unit = split('=',$param);
        $return = { %$return, @param_unit };
    }
    return $return;
}

=back

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
