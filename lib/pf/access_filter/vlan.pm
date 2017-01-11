package pf::access_filter::vlan;

=head1 NAME

pf::access_filter::vlan -

=head1 DESCRIPTION

pf::access_filter::vlan

=cut

use strict;
use warnings;
use pf::api::jsonrpcclient;

use base qw(pf::access_filter);
tie our %ConfigVlanFilters, 'pfconfig::cached_hash', 'config::VlanFilters';
tie our %VlanFilterEngineScopes, 'pfconfig::cached_hash', 'FilterEngine::VlanScopes';

=head2 filterRule

    Handle the role update

=cut

sub filterRule {
    my ($self, $rule, $args) = @_;
    if(defined $rule) {
        if (defined($rule->{'action'}) && $rule->{'action'} ne '') {
            $self->dispatchAction($rule, $args);
        }
        my $scope = $rule->{scope};
        if (defined($rule->{'role'}) && $rule->{'role'} ne '') {
            my $role = $rule->{'role'};
            $role =~ s/\$([a-zA-Z_]+)/$args->{$1} \/\/ ''/ge;
            return $role;
        }
    }
    return undef;
}

=head2 getEngineForScope

 gets the engine for the scope

=cut

sub getEngineForScope {
    my ($self, $scope) = @_;
    if (exists $VlanFilterEngineScopes{$scope}) {
        return $VlanFilterEngineScopes{$scope};
    }
    return undef;
}

=head2 dispatchAction

Return the reference to the function that call the api.

=cut

sub dispatchAction {
    my ($self, $rule, $args) = @_;

    my $param = $self->evalParam($rule->{'action_param'}, $args);
    my $apiclient = pf::api::jsonrpcclient->new;
    $apiclient->notify($rule->{'action'}, %{$param});
}

=head2 evalParam

evaluate action parameters

=cut

sub evalParam {
    my ($self, $action_param, $args) = @_;
    my @params = split(/\s*,\s*/, $action_param);
    my $return = {};
    foreach my $param (@params) {
        $param =~ s/\$([A-Za-z0-9_]+)/$args->{$1} \/\/ '' /ge;
        $param =~ s/^\s+|\s+$//g;
        my @param_unit = split(/\s*=\s*/, $param);
        $return = {%$return, @param_unit};
    }
    return $return;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

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
