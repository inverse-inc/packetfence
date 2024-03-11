package pf::access_filter;

=head1 NAME

pf::access_filter - handle the authorization rules on the vlan attribution

=head1 DESCRIPTION

pf::access_filter deny, rewrite role based on rules.

=cut

use strict;
use warnings;

use pf::log;
use pf::api::jsonrpcclient;
use pf::person qw(person_view);
use pf::util qw(isenabled connection_type_to_str);
use Scalar::Util qw(looks_like_number reftype);
use pf::factory::condition::access_filter;
use pf::filter_engine;
use pf::filter;
use pf::action_spec;

=head1 SUBROUTINES

=head2 new

=cut

sub new {
   my ( $proto, %argv ) = @_;
   my $class = ref($proto) || $proto;
   $class->logger->debug("instantiating new $class");
   my $self = bless {}, $class;
   return $self;
}

=head2 test

Test all the rules

=cut

sub test {
    my ($self, $scope, $args) = @_;
    my $logger = $self->logger;
    my $engine = $self->getEngineForScope($scope);
    if ($engine) {
        my $answer = $engine->match_first($args);
        if (defined $answer) {
            $logger->info("Match rule $answer->{_rule}");
        }
        else {
            $logger->debug(sub {"No rule matched for scope $scope"});
        }
        return $answer;
    }
    $logger->debug(sub {"No engine found for $scope"});
    return undef;
}


=head2 filter

 Filter the arguments passed

=cut

sub filter {
    my ($self, $scope, $args) = @_;
    $args = $self->adjustCommonParams($args);
    my $rule = $self->test($scope, $args);
    return $self->filterRule($rule, $args);
}


=head2 getEngineForScope

 get the filter engine for the scope provided

=cut

sub getEngineForScope {
    my ($self, $scope) = @_;
    return undef;
}

=head2 logger

Return the current logger for the object

=cut

sub logger {
    my ($proto) = @_;
    return get_logger( ref($proto) || $proto );
}

=head2 dispatchActions

dispatch the array of actions

=cut

sub dispatchActions {
    my ($self, $rule, $args) = @_;
    my $apiclient = $self->api_client();
    my $run_actions = $rule->{run_actions} // "enabled";
    if (isenabled($run_actions)) {
        for my $action (@{$rule->{actions}//[]}) {
            my $param = $self->evalActionParams($action->{'api_parameters'}, $args);
            if(isenabled($rule->{actions_synchronous})) {
                $apiclient->call($action->{'api_method'}, @{$param});
            }
            else {
                $apiclient->notify($action->{'api_method'}, @{$param});
            }
        }
    }
}

sub api_client {
    return pf::api::jsonrpcclient->new;
}

=head2 evalParam

evaluate action parameters

=cut

sub evalParamAction {
    my ($self, $action_param, $args) = @_;
    return $self->evalParams($action_param, $args);
}

sub evalActionParams {
    my ($self, $action_params, $args) = @_;
    my @return;
    my @params = split(/\s*[,=]\s*/, $action_params);
    foreach my $param (@params) {
        push @return, $self->evalActionParam($param, $args);
    }

    return \@return;
}

sub evalActionParam {
    my ($self, $answer, $args) = @_;
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

sub adjustCommonParams {
    my ($self, $args) = @_;
    if(exists($args->{connection_type}) && looks_like_number($args->{connection_type})) {
        $args = { %$args, connection_type => connection_type_to_str($args->{connection_type}) };
    }

    return $args;
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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
