package pf::access_filter::mdm;

=head1 NAME

pf::access_filter::mdm -

=head1 DESCRIPTION

pf::access_filter::mdm

=cut

use strict;
use warnings;
use pf::api::jsonrpcclient;

use base qw(pf::access_filter);
tie our %ConfigMdmFilters, 'pfconfig::cached_hash', 'config::MdmFilters';
tie our %MdmFilterEngineScopes, 'pfconfig::cached_hash', 'FilterEngine::MdmScopes';

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
        if (defined($rule->{'flag'}) && $rule->{'flag'} ne '') {
            my $flag = $rule->{'flag'};
            $flag =~ s/\$([a-zA-Z_]+)/$args->{$1} \/\/ ''/ge;
            return $flag;
        }
    }
    return undef;
}

=head2 filter

 Filter the arguements passed

=cut

sub filter {
    my ($self, $scope, $args) = @_;
    my @rules = $self->test($scope, $args);
    my @results;
    foreach my $rule (@rules){
        push @results, $self->filterRule($rule, $args);
    }
    return @results;
}

=head2 test

Test all the rules

=cut

sub test {
    my ($self, $scope, $args) = @_;
    my $logger = $self->logger;
    my $engine = $self->getEngineForScope($scope);
    if ($engine) {
        my @answers = $engine->match_all($args);
        if (@answers > 0) {
            $logger->info("Matched rules ".join(', ', map {$_->{_rule}} @answers));
        }
        else {
            $logger->debug(sub {"No rule matched for scope $scope"});
        }
        return @answers;
    }
    $logger->debug(sub {"No engine found for $scope"});
    return undef;
}

=head2 getEngineForScope

 gets the engine for the scope

=cut

sub getEngineForScope {
    my ($self, $scope) = @_;
    if (exists $MdmFilterEngineScopes{$scope}) {
        return $MdmFilterEngineScopes{$scope};
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
    $action_param =~ s/\s//g;
    my @params = split(',', $action_param);
    my $return = {};

    foreach my $param (@params) {
        $param =~ s/\$([A-Za-z0-9_]+)/$args->{$1} \/\/ '' /ge;
        my @param_unit = split('=', $param);
        $return = {%$return, @param_unit};
    }
    return $return;
}

=head2 evalLine

evaluate all the variables

=cut

sub evalLine {
    my ($answer, $args) = @_;
    $answer =~ s/\$([a-zA-Z_]+)/$args->{$1} \/\/ ''/ge;
    return $answer;
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
