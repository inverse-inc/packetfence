package pf::filter_engine::profile;

=head1 NAME

pf::filter_engine::profile

=cut

=head1 DESCRIPTION

pf::filter_engine::profile

=cut

use strict;
use warnings;
use Moose;
extends qw(pf::filter_engine);
use pf::filter;
use pf::factory::condition::profile;
use pf::condition::any;
use pf::condition::all;
use pf::condition::true;
use pf::constants::Connection::Profile qw($DEFAULT_PROFILE $MATCH_STYLE_ALL);
use pf::util qw(isdisabled);

sub BUILDARGS {
    my ($self,$args)      = @_;
    my $config      = $args->{config};
    my $ordered_ids = $args->{ordered_ids};
    my @filters;
    foreach my $id (@$ordered_ids) {

        #Skip the default profile since it will be last
        next if $id eq $DEFAULT_PROFILE;
        my $profile = $config->{$id};
        next if isdisabled($profile->{status} // 'enabled');
        my @conditions = map {pf::factory::condition::profile->instantiate($_)} @{$profile->{'filter'}};
        if ($profile->{'advanced_filter'} ) {
            push @conditions, pf::factory::condition::profile->instantiate_advanced($profile->{'advanced_filter'});
        }

        my $condition;
        #If there is only one condition no need to wrap it in an any or all condition
        if (@conditions == 1) {
            $condition = $conditions[0];
        }
        elsif (defined($profile->{filter_match_style}) && $profile->{filter_match_style} eq $MATCH_STYLE_ALL) {
            $condition = pf::condition::all->new({conditions => \@conditions});
        }
        else {
            $condition = pf::condition::any->new({conditions => \@conditions});
        }
        push @filters, pf::filter->new({answer => $id, condition => $condition});
    }

    #If all else fails use the default
    push @filters, pf::filter->new({answer => $DEFAULT_PROFILE, condition => pf::condition::true->new});
    return { filters => \@filters };
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
