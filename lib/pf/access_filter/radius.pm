package pf::access_filter::radius;

=head1 NAME

pf::access_filter::radius - handle the answer of the radius request

=cut

=head1 DESCRIPTION

pf::access_filter::radius deny, rewrite radius answer based on rules.

=cut

use strict;
use warnings;

use pf::security_event qw (security_event_view_top);
use pf::locationlog qw(locationlog_set_session);
use pf::util qw(isenabled generate_session_id random_from_range extract);
use pf::mini_template qw(%FUNCS);
use List::MoreUtils qw(uniq);
use pf::CHI;
use pf::radius::constants;
use Scalar::Util qw(reftype);
use pf::log;

use base qw(pf::access_filter);
tie our %ConfigRadiusFilters, 'pfconfig::cached_hash', 'config::RadiusFilters';
tie our %RadiusFilterEngineScopes, 'pfconfig::cached_hash', 'FilterEngine::RadiusScopes';

our %LOOKUP = (
    session_id => \&setSession,
);

=head1 SUBROUTINES

=head2 test

Test all the rules

=cut

sub test {
    my ($self, $scope, $args) = @_;
    my $engine = $self->getEngineForScope($scope);
    $args = $self->adjustCommonParams($args);
    if ($engine) {
        $args->{'security_event'} =  security_event_view_top($args->{'mac'});
        my $answer = $engine->match_first($args);
        $self->logger->info("Match rule $answer->{_rule}") if defined $answer;
        return $answer;
    }
    return undef;
}

=head2 handleRoleInRule

Handles the role update

=cut

sub handleAnswerInRule {
    my ($self, $rule, $args, $radius_reply_ref) = @_;
    my $logger = $self->logger;
    my $radius_reply = {};
    my $status = $RADIUS::RLM_MODULE_OK;
    if (defined $rule) {
        $radius_reply = {'Reply-Message' => "Request processed by PacketFence"};
        $logger->info(evalParam($rule->{'log'},$args)) if defined($rule->{'log'});
        my $answers = $rule->{answers} // [];
        # the session_id must come from the setSession function
        delete $args->{session_id};
        pf::mini_template::update_variables_for_set($answers, \%LOOKUP, $args, $self, $args);
        for my $a (@$answers) {
            $self->addAnswer($rule, $radius_reply, $a, $args);
        }

        my $radius_status = $rule->{'radius_status'};
        if (defined($radius_status) && $radius_status ne '') {
            $status = '$RADIUS::'.$radius_status;
            $status = eval($status);
        }

        if (defined($rule->{'merge_answer'}) && !(isenabled($rule->{'merge_answer'}))) {
            return ($radius_reply, $status);
        }

        foreach my $key (keys %$radius_reply_ref) {
            if (exists($radius_reply->{$key})) {
                my $type = reftype($radius_reply->{$key});
                if (defined($type) && $type eq 'ARRAY') {
                    my @attribute;
                    push(@attribute,@{$radius_reply_ref->{$key}});
                    push(@attribute,@{$radius_reply->{$key}});
                    $radius_reply_ref->{$key} = \@attribute;
                    delete $radius_reply->{$key};
                }
            }
        }
        $radius_reply_ref = {%$radius_reply_ref, %$radius_reply} if (keys %$radius_reply);
        return ($radius_reply_ref, $status);
    }

    return ($radius_reply_ref, $status);
}

sub addAnswer {
    my ($self, $rule, $radius_reply, $a, $args) = @_;
    my $name = $a->{name};
    my $value = join('', $a->{tmpl}->pre_process($args, \%FUNCS));
    $self->updateAnswerNameValue($name, $value, $radius_reply);
    my @values = split(';', $value);
    if (exists($radius_reply->{$name})) {
        if ((reftype($radius_reply->{$name}) // '') eq 'ARRAY') {
            push @{$radius_reply->{$name}}, @values;
        } else {
            $radius_reply->{$name} = [$radius_reply->{$name}, @values];
        }
    } else {
        $radius_reply->{$name} = (@values > 1) ? \@values : $values[0];
    }
}

sub updateAnswerNameValue {
    my ($self, $name, $value, $radius_reply) = @_;
    my $logger = $self->logger;
    if ($name =~ /^([^:]+:)?Packetfence-Raw$/) {
        my $prefix = $1 // 'reply:';
        if (ref($value) eq 'ARRAY') {
            my $key;
            my @attributes;
            foreach my $response (@{$value}) {
                if ($response =~ /([\w\-:]*)\s?[:=]\s?([\w\-:]*)/) {
                    $key = $1;
                    $radius_reply->{"$prefix".$1} = $2;
                } else {
                    $logger->error("Packetfence-Raw: '$value' is not in a valid format");
                }
            }
        } elsif ($value =~ /([\w\-:]*)\s?[:=]\s?([\w\-:]*)/) {
            my ($new_name, $new_value) = ($1, $2);
            if (defined $new_value && length($new_value)) {
                $radius_reply->{"$prefix".$new_name} = $new_value;
            } else {
                $logger->error("Packetfence-Raw: '$value' is not in a valid format");
            }
        }
    }
}

sub setSession {
    my($self, $args) = @_;
    my $mac = $args->{'mac'};
    my $session_id = generate_session_id(6);
    my $chi = pf::CHI->new(namespace => 'httpd.portal');
    $chi->set($session_id,{
        client_mac => $mac,
        wlan => $args->{'ssid'},
        switch_id => $args->{'switch'}->{'_id'},
    });
    pf::locationlog::locationlog_set_session($mac, $session_id);
    return $session_id;
}

=head2 evalParam

evaluate all the variables

=cut

sub evalParam {
    my ($answer, $args) = @_;
    $answer = random_from_range($answer) if rangeValidator($answer);
    $answer =~ s/\$([a-zA-Z_0-9]+)/$args->{$1} \/\/ ''/ge;
    $answer =~ s/\$\{([a-zA-Z0-9_\-]+(?:\.[a-zA-Z0-9_\-]+)*)\}/&_replaceParamsDeep($1,$args)/ge;
    return $answer;
}

=head2 rangeValidator

Validate the range definition
Should be something like that 20..23 or 20..23,27..30

=cut

sub rangeValidator {
    my ($range) =@_;
    my $rangesep = qr/(?:\.\.)/;
    my $sectsep  = qr/(?:\s|,)/;
    my $validation = qr/(?:
         [^0-9,. -]|
         $rangesep$sectsep|
         $sectsep$rangesep|
         \d-\d|
         ^$sectsep|
         ^$rangesep|
         $sectsep$|
         $rangesep$|
         ^\d+$
         )/x;
    return 0 if ($range =~ m/$validation/g);
    return 1;
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
    if (exists $RadiusFilterEngineScopes{$scope}) {
        return $RadiusFilterEngineScopes{$scope};
    }
    return undef;
}

=head2 lookupSessionId

lookupSessionId

=cut

sub lookupSessionId {
    my ($self, $args) = @_;
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
