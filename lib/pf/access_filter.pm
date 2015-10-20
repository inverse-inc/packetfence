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
use pf::config qw(%connection_type_to_str);
use pf::person qw(person_view);
use pf::factory::condition::access_filter;
use pf::filter_engine;
use pf::filter;
our $logger = get_logger();

=head1 SUBROUTINES

=head2 new

=cut

sub new {
   my ( $class, %argv ) = @_;
   $logger->debug("instantiating new pf::access_filter");
   my $self = bless {}, $class;
   return $self;
}

=head2 test

Test all the rules

=cut

sub test {
    my ($self, $scope, $args) = @_;
    my $engine = $self->getEngineForScope($scope);
    if ($engine) {
       return $engine->match_first($args);
    }
    return undef;
}


=head2 filter

 Filter the arguements passed

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
