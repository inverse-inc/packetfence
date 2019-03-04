package pf::pfmon::task::cluster_check;

=head1 NAME

pf::pfmon::task::cluster_check - class for pfmon task cluster check

=cut

=head1 DESCRIPTION

pf::pfmon::task::cluster_check

=cut

use strict;
use warnings;
use pf::config qw(%Config);
use pf::cluster;
use pf::CHI;
use pf::log;
use Moose;
extends qw(pf::pfmon::task);


=head2 run

Check the health state of the cluster and manage any configuration conflict between members

=cut

sub run {
    my ($self) = @_;
    my $cache = pf::CHI->new(namespace => 'clustering');
    my $now = time;
    my $last_conflict_at = $cache->get('last_config_healthy_timestamp');
    my $last_config_checked = $cache->get('last_config_checked_timestamp');

    my $conflict_resolution_threshold = $Config{active_active}{conflict_resolution_threshold};

    get_logger->info("Using $conflict_resolution_threshold resolution threshold");
    
    my ($servers_map, $version_map) = pf::cluster::get_all_config_version();

    # Making sure we have all available data for the decision and that there are multiple versions detected
    if(defined($last_conflict_at) && defined($last_config_checked) && keys(%$version_map) > 1) { 
        my $last_conflict_interval = $now - $last_conflict_at;
        my $last_config_checked_interval = $now - $last_config_checked;
        
        # If we haven't checked the state in the last 2 intervals, we'll ignore any conflicts and get the latest state
        if($last_config_checked_interval > 2* $self->interval) {
            get_logger->info("Cluster config state hasen't been checked for too long (last was : $last_config_checked_interval). Will consider config healthy for this iteration");
            $cache->set('last_config_healthy_timestamp', $now);
        }
        elsif($last_conflict_at > $conflict_resolution_threshold) {
            get_logger->info("Configuration is unhealthy since $conflict_resolution_threshold seconds. Will attempt to resolve the conflict");
            pf::cluster::handle_config_conflict();
        }
    }
    else {
        get_logger->info("All cluster members are running the same configuration version");
        $cache->set('last_config_healthy_timestamp', $now);
    }
    $cache->set('last_config_checked_timestamp', $now);
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
