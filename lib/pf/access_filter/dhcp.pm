package pf::access_filter::dhcp;

=head1 NAME

pf::access_filter::dhcp -

=head1 DESCRIPTION

pf::access_filter::dhcp

=cut

use strict;
use warnings;

use pf::violation qw (violation_view_top);
use pf::util qw(isenabled generate_session_id);
use pf::CHI;
use Scalar::Util qw(reftype);
use pf::log;

use base qw(pf::access_filter);
tie our %ConfigDhcpFilters, 'pfconfig::cached_hash', 'config::DhcpFilters';
tie our %DhcpFilterEngineScopes, 'pfconfig::cached_hash', 'FilterEngine::DhcpScopes';


=head1 SUBROUTINES

=head2 test

Test all the rules

=cut

sub test {
    my ($self, $scope, $args) = @_;
    my $logger = $self->logger;
    my $engine = $self->getEngineForScope($scope);
    if ($engine) {
        $args->{'violation'} =  violation_view_top($args->{'mac'});
        $args->{'fingerbank_info'} = pf::node::fingerbank_info($args->{mac});
        $args->{'node_info'} = pf::node::node_view($args->{mac});
	my $answer = $engine->match_first($args);
        $self->logger->info("Match rule $answer->{_rule}") if defined $answer;
        return $answer;
    }
    return undef;
}


=head2 filterRule

    Handle the role update

=cut

sub filterRule {
    my ($self, $rule, $args) = @_;
    my $logger = $self->logger;
    my $dhcp_reply = {};
    if(defined $rule) {
        $logger->info(evalParam($rule->{'log'},$args)) if defined($rule->{'log'});
        if (defined($rule->{'action'}) && $rule->{'action'} ne '') {
            $self->dispatchAction($rule, $args);
        }
        my $i = 1;
        while (1) {
            if (defined($rule->{"answer$i"}) && $rule->{"answer$i"} ne '') {
                my @answer = $rule->{"answer$i"} =~ /([.0-9a-zA-Z_-]*)\s*=>\s*(.*)/;
                evalAnswer(\@answer,$args,\$dhcp_reply);
            } else {
                last;
            }
            $i++;
        }

    }
    return $dhcp_reply;
}



=head2 evalAnswer

evaluate the radius answer

=cut

sub evalAnswer {
    my ($answer,$args,$dhcp_reply_ref) = @_;

    my $return = evalParam(@{$answer}[1],$args);
    my @multi_value = split(';',$return);
    @{$answer}[0] =~ s/\s//g;
    if (scalar @multi_value > 1) {
        $$dhcp_reply_ref->{@{$answer}[0]} = \@multi_value;
    } else {
        $$dhcp_reply_ref->{@{$answer}[0]} = $return;
    }

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

=head2 getEngineForScope

 gets the engine for the scope

=cut

sub getEngineForScope {
    my ($self, $scope) = @_;
    if (exists $DhcpFilterEngineScopes{$scope}) {
        return $DhcpFilterEngineScopes{$scope};
    }
    return undef;
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

# vim: set shiftwidth=4:
# # vim: set expandtab:
# # vim: set backspace=indent,eol,start:
