package pf::filter_engine::profile;

=head1 NAME

pf::filter_engine::profile add documentation

=cut

=head1 DESCRIPTION

pf::filter_engine::profile

=cut

use strict;
use warnings;
use Moose;
extends qw(pf::filter_engine);
use pf::node;
use pf::filter;
use pf::factory::condition::profile;
use pf::condition::any;
use pf::condition::all;
use pf::condition::true;

#has ordered_ids => (is => 'ro', isa => 'ArrayRef', required => 1);
#has config      => (is => 'ro', isa => 'HashRef',  required => 1);

sub BUILDARGS {
    my ($self,$args)      = @_;
    my $config      = $args->{config};
    my $ordered_ids = $args->{ordered_ids};
    my @filters;
    foreach my $id (@$ordered_ids) {

        #Skip the default profile since it will be last
        next if $id eq 'default';
        my $profile = $config->{$id};
        my @conditions = map {pf::factory::condition::profile->instantiate($_)} @{$profile->{'filter'}};
        my $condition;
        if ( defined( $profile->{filter_match_style} ) && $profile->{filter_match_style} eq 'all') {
            $condition = pf::condition::all->new({conditions => \@conditions});
        }
        else {
            $condition = pf::condition::any->new({conditions => \@conditions});
        }
        push @filters,pf::filter->new({answer => $id, condition => $condition});
    }

    #If all else fails use the default
    push @filters, pf::filter->new({answer => 'default', condition => pf::condition::true->new});
    return { filters => \@filters };
}

sub build_match_arg {
    my ($self, $mac, $options) = @_;
    my $node_info = node_view($mac) || {};
    $node_info = {%$node_info, %$options};
    return $node_info;
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
