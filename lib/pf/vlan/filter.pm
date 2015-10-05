package pf::vlan::filter;

=head1 NAME

pf::vlan::filter - handle the authorization rules on the vlan attribution

=cut

=head1 DESCRIPTION

pf::vlan::filter deny, rewrite role based on rules.

=cut

use strict;
use warnings;

use Log::Log4perl;
use pf::api::jsonrpcclient;
use pf::config qw(%connection_type_to_str);
use pf::person qw(person_view);
use pf::factory::condition::vlanfilter;
use pf::filter_engine;
use pf::filter;
tie our %ConfigVlanFilters, 'pfconfig::cached_hash', 'config::VlanFilters';
tie our %VlanFilterEngineScopes, 'pfconfig::cached_hash', 'resource::VlanFilterEngineScopes';


=head1 SUBROUTINES

=over

=item new

=cut

sub new {
   my $logger = Log::Log4perl::get_logger("pf::vlan::filter");
   $logger->debug("instantiating new pf::vlan::filter");
   my ( $class, %argv ) = @_;
   my $self = bless {}, $class;
   return $self;
}

=item test

Test all the rules

=cut

sub test {
    my ($self, $scope, $args) = @_;
    if (exists $VlanFilterEngineScopes{$scope}) {
       return $VlanFilterEngineScopes{$scope}->match_first($args);
    }
    return undef;
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
