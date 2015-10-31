package pf::access_filter::radius;

=head1 NAME

pf::access_filter::radius - handle the answer of the radius request

=cut

=head1 DESCRIPTION

pf::access_filter::radius deny, rewrite radius answer based on rules.

=cut

use strict;
use warnings;

use Log::Log4perl;
use pf::api::jsonrpcclient;
use pf::violation qw (violation_view_top);
use pf::locationlog qw(locationlog_set_session);
use pf::log;
use pf::util qw(isenabled);

use base qw(pf::access_filter);
tie our %ConfigRadiusFilters, 'pfconfig::cached_hash', 'config::RadiusFilters';
tie our %RadiusFilterEngineScopes, 'pfconfig::cached_hash', 'FilterEngine::RadiusScopes';


=head1 SUBROUTINES

=over

=item new

=cut

sub new {
   my $logger = get_logger();
   $logger->debug("instantiating new pf::access_filter::radius");
   my ( $class, %argv ) = @_;
   my $self = bless {}, $class;
   return $self;
}

=item test

Test all the rules

=cut

sub test {
    my ($self, $scope, $args) = @_;
    if (exists $RadiusFilterEngineScopes{$scope}) {
       $args->{'violation'} = violation_view_top($args->{'mac'});
       return $RadiusFilterEngineScopes{$scope}->match_first($args);
    }
    return undef;
}

=head2 handleRoleInRule

Handles the role update

=cut

sub handleAnswerInRule {
    my ($self, $rule, $args, $radius_reply_ref) = @_;
    my $logger = get_logger();
    my $radius_reply = {};
    if (defined $rule) {
        $radius_reply = {'Reply-Message' => "PacketFence has proceed the request"};
        my $i = 1;
        $logger->info(evalParam($rule->{'log'},$args)) if defined($rule->{'log'});
        while (1) {
            if (defined($rule->{"answer$i"}) && $rule->{"answer$i"} ne '') {
                my @answer = split('=>',$rule->{"answer$i"});
                $args->{'session_id'} = setSession($args) if ($answer[1] =~ /\$session_id/);
                evalAnswer(\@answer,$args,\$radius_reply);
            } else {
                last;
            }
            $i++;
        }
        if (defined($rule->{'merge_answer'}) && !(isenabled($rule->{'merge_answer'}))) {
            return ($radius_reply);
        } else {
            $radius_reply_ref = {%$radius_reply_ref, %$radius_reply} if (keys %$radius_reply);
            return ($radius_reply_ref);
        }
    }
}

sub setSession {
    my($args) = @_;
    my (%session_id);
    pf::web::util::session(\%session_id,undef,6);
    $session_id{client_mac} = $args->{'mac'};
    $session_id{wlan} = $args->{'ssid'};
    $session_id{switch_id} = $args->{'switch'}{'_id'};
    locationlog_set_session($args->{'mac'}, $session_id{_session_id});
    return ($session_id{_session_id});
}

=head2 evalAnswer

evaluate the radius answer

=cut

sub evalAnswer {
    my ($answer,$args,$radius_reply_ref) = @_;

    my $return = evalParam(@{$answer}[1],$args);
    my @multi_value = split(';',$return);
    @{$answer}[0] =~ s/\s//g;
    if (scalar @multi_value > 1) {
        $$radius_reply_ref->{@{$answer}[0]} = \@multi_value;
    } else {
        $$radius_reply_ref->{@{$answer}[0]} = $return;
    }

}
    
=head2 evalParam

evaluate all the variables

=cut

sub evalParam {
    my ($answer, $args) = @_;
    $answer =~ s/\$([a-zA-Z_]+)/$args->{$1} \/\/ ''/ge;
    $answer =~ s/\${([a-zA-Z_\-]+)\.([a-zA-Z_\-]+)\.([a-zA-Z_\-]+)}/$args->{$1}->{$2}{$3} \/\/ ''/ge;
    $answer =~ s/\${([a-zA-Z_\-]+)\.([a-zA-Z_\-]+)}/$args->{$1}->{$2} \/\/ ''/ge;
    $answer =~ s/^\s//g;
    return $answer;
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
