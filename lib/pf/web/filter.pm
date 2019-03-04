package pf::web::filter;

=head1 NAME

pf::web::filter - handle the authorization rules on the portal

=cut

=head1 DESCRIPTION

pf::web::filter allow, deny, redirect client based on rules.

=cut

use strict;
use warnings;

use Apache2::Const -compile => qw(:http);
use Apache2::Request;
use Apache2::Connection;
use pf::log;
use pf::config;
use pfconfig::cached_hash;
our (%ConfigApacheFilters);
tie %ConfigApacheFilters, 'pfconfig::cached_hash', 'config::ApacheFilters';

=head1 SUBROUTINES

=over

=item new

=cut

sub new {
   my $logger = get_logger();
   $logger->debug("instantiating new pf::web::filter");
   my ( $class, %argv ) = @_;
   my $self = bless {}, $class;
   return $self;
}


=item test

Test all the rules

=cut

sub test {
    my ($self, $r) = @_;
    my $logger = $self->logger;

    my $c = $r->connection();
    foreach my $rule  ( sort keys %ConfigApacheFilters ) {
        if ($rule =~ /^\w+:(.*)$/) {
            my $test = $1;
            $test =~ s/(\w+)/$self->dispatch_rule($r,$ConfigApacheFilters{$1},$1)/gee;
            $test =~ s/\|/ \|\| /g;
            $test =~ s/\&/ \&\& /g;
            if (eval $test) {
                $logger->debug($c->remote_ip." match Apache rule: $rule");
                my $action = $self->dispatch_action($ConfigApacheFilters{$rule});
                return ($action->($self,$r,$ConfigApacheFilters{$rule}));
            }
        }
    }
}

=item dispatch_rules

Return the reference to the function that parses the rule.

=cut

sub dispatch_rule {
    my ($self, $r, $rule, $name) = @_;
    my $logger = $self->logger;

    if (!defined($rule)) {
        $logger->error("The rule $name you try to test doesn´t exist");
        return 0;
    }
    my $key = {
        uri => \&uri_parser,
        user_agent  => \&user_agent_parser,
    };
    return $key->{$rule->{'filter'}}->($self, $r, $rule);
}

=item dispatch_action

Return the reference to the function that performs the action.

=cut

sub dispatch_action {
    my ($self, $rule) = @_;

    if ($rule->{'action'} =~ /30\d/) {
        return \&redirect;
    } else {
        return \&code;
    }
}

=item uri_parser

Parse the uri parameter and compare to the rule. If it matches then perform the action.

=cut

sub uri_parser {
    my ($self, $r, $rule) = @_;

    my $action;
    if ($rule->{'operator'} eq 'is') {
        if (($r->unparsed_uri eq $rule->{'value'}) && ($r->method eq $rule->{'method'})) {
            return 1;
        } else  {
            return 0;
        }
    } elsif ($rule->{'operator'} eq 'is_not') {
        if (($r->unparsed_uri ne $rule->{'value'}) && ($r->method eq $rule->{'method'})) {
           return 1;
        } else {
            return 0;
        }
    } elsif ($rule->{'operator'} eq 'match') {
        if (($r->unparsed_uri =~ /$rule->{'value'}/) && ($r->method eq $rule->{'method'})) {
            return 1;
        } else  {
            return 0;
        }
    } elsif ($rule->{'operator'} eq 'match_not') {
        if (($r->unparsed_uri !~ /$rule->{'value'}/) && ($r->method eq $rule->{'method'})) {
           return 1;
        } else {
            return 0;
        }
    } else {
        return 0;
    }
}

=item user_agent_parser

Parse user_agent parameter and compare to the rule. If it matches then perform the action.

=cut

sub user_agent_parser {
    my ($self,$r,$rule) = @_;

    my $action;
    my $user_agent;
    if (defined($r->headers_in->{'User-Agent'})) {
        $user_agent = $r->headers_in->{'User-Agent'};
    } else {
        $user_agent = '';
    }
    if ($rule->{'operator'} eq 'is') {
        if (($user_agent eq $rule->{'value'}) && ($r->method eq $rule->{'method'})) {
            return 1;
        } else {
            return 0;
        }
    } elsif ($rule->{'operator'} eq 'is_not') {
        if (($user_agent ne $rule->{'value'}) && ($r->method eq $rule->{'method'})) {
            return 1;
        } else {
            return 0;
        }
    } elsif ($rule->{'operator'} eq 'match') {
        if (($user_agent =~ /$rule->{'value'}/) && ($r->method eq $rule->{'method'})) {
            return 1;
        } else {
            return 0;
        }
    } elsif ($rule->{'operator'} eq 'match_not') {
        if (($user_agent !~ /$rule->{'value'}/) && ($r->method eq $rule->{'method'})) {
            return 1;
        } else {
            return 0;
        }
    } else {
            return 0;
    }
}

=item redirect

Redirect the user based on the code

=cut

sub redirect {
    my ($self,$r,$rule) = @_;

    if ($rule->{'action'}) {
        $r->status(200);
        $r->headers_out->set('Location' => $rule->{'redirect_url'});
        return $rule->{'action'};
    } else {
        return 1;
    }
}

=item code

Return HTTP code

=cut

sub code {
    my ($self,$r,$rule)= @_;

    if ($rule->{'action'}) {
        return $rule->{'action'};
    } else {
        return 1;
    }
}

=item logger

Return the current logger for the switch

=cut

sub logger {
    my ($proto) = @_;
    return get_logger( ref($proto) || $proto );
}


=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

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
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
