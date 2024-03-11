package pf::access_filter::provisioner;

=head1 NAME

pf::access_filter::provisioner -

=head1 DESCRIPTION

pf::access_filter::provisioner

=cut

use strict;
use warnings;
use base qw(pf::access_filter);

tie our %ProvisioningScopes, 'pfconfig::cached_hash', 'FilterEngine::ProvisioningScopes';


sub filterRules {
    my ($self, $scope, $data, $ruleIds) = @_;
    my @rules = $self->_getRulesForScope($scope, $ruleIds);
    return (undef, 1) if @rules == 0;
    for my $rule (@rules) {
        my $answer = $rule->match_first($data);
        return ($answer, 0) if defined $answer;
    }

    return (undef, 0);
}

sub _getRulesForScope {
    my ($self, $scope, $ruleIds) = @_;
    return if @{$ruleIds} == 0;
    return if !exists $ProvisioningScopes{$scope};
    my $scopeLookup = $ProvisioningScopes{$scope};
    return if !defined $scopeLookup;
    my @rules;
    for my $id (@$ruleIds) {
        next if !exists $scopeLookup->{$id};
        my $rule = $scopeLookup->{$id};
        push @rules, $rule if defined $rule;
    }

    return @rules;
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

