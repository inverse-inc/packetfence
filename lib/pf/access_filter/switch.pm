package pf::access_filter::switch;

=head1 NAME

pf::access_filter::switch -

=head1 DESCRIPTION

pf::access_filter::switch

=cut

use strict;
use warnings;

use base qw(pf::access_filter);
tie our %ConfigSwitchFilters, 'pfconfig::cached_hash', 'config::SwitchFilters';
tie our %SwitchFilterEngineScopes, 'pfconfig::cached_hash', 'FilterEngine::SwitchScopes';

=head2 filterRule

    Handle the role update

=cut

sub filterRule {
    my ($self, $rule, $args) = @_;
    if(defined $rule) {
        if (defined($rule->{'switch'}) && $rule->{'switch'} ne '') {
            my $portal = $rule->{'switch'};
            return $portal;
        }
    }
    return undef;
}

=head2 getEngineForScope

 gets the engine for the scope

=cut

sub getEngineForScope {
    my ($self, $scope) = @_;
    if (exists $SwitchFilterEngineScopes{$scope}) {
        return $SwitchFilterEngineScopes{$scope};
    }
    return undef;
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
