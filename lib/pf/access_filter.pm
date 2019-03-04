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
use pf::constants::config qw(%connection_type_to_str);
use pf::person qw(person_view);
use pf::factory::condition::access_filter;
use pf::filter_engine;
use pf::filter;
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
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
