package pf::access_filter::vlan;

=head1 NAME

pf::access_filter::vlan -

=head1 DESCRIPTION

pf::access_filter::vlan

=cut

use strict;
use warnings;
use pf::api::jsonrpcclient;
use Scalar::Util qw(reftype);

use base qw(pf::access_filter);
tie our %ConfigVlanFilters, 'pfconfig::cached_hash', 'config::VlanFilters';
tie our %VlanFilterEngineScopes, 'pfconfig::cached_hash', 'FilterEngine::VlanScopes';

=head2 filterRule

    Handle the role update

=cut

sub filterRule {
    my ($self, $rule, $args) = @_;
    if(defined $rule) {
        $self->dispatchActions($rule, $args);
        my $scope = $rule->{scope};
        if (defined($rule->{'role'}) && $rule->{'role'} ne '') {
            my $role = $rule->{'role'};
            $role = evalAnswer($role,$args);
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

=head2 evalAnswer

evaluate the radius answer

=cut

sub evalAnswer {
    my ($answer,$args) = @_;

    my $return = evalParam($answer,$args);
    return $return;

}

=head2 evalParam

evaluate all the variables

=cut

sub evalParam {
    my ($answer, $args) = @_;
    $answer =~ s/\$([a-zA-Z_0-9]+)/$args->{$1} \/\/ ''/ge;
    $answer =~ s/\$\{([a-zA-Z0-9_\-]+(?:\.[a-zA-Z0-9_\-]+)*)\}/&_replaceParamsDeep($1,$args)/ge;
    return $answer;
}


=head2 _replaceParamsDeep

evaluate all the variables deeply

=cut

sub _replaceParamsDeep {
    my ($param_string, $args) = @_;
    my @params = split /\./, $param_string;
    my $param  = pop @params;
    my $hash   = $args;
    foreach my $key (@params) {
        if (exists $hash->{$key} && reftype($hash->{$key}) eq 'HASH') {
            $hash = $hash->{$key};
            next;
        }
        return '';
    }
    return $hash->{$param} // '';
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

1;
