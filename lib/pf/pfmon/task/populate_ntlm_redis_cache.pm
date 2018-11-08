package pf::pfmon::task::populate_ntlm_redis_cache;

=head1 NAME

pf::pfmon::task::populate_ntlm_redis_cache - class for pfmon task populate ntlm redis cache

=cut

=head1 DESCRIPTION

pf::pfmon::task::populate_ntlm_redis_cache

=cut

use strict;
use warnings;
use Moose;
extends qw(pf::pfmon::task);
use pf::client;
use pf::config qw(%ConfigDomain);
use pf::cluster;
use pf::constants qw($FALSE);
use pf::log;
use pf::util qw(isenabled);

my $logger = get_logger;


=head2 run

run the populate ntlm redis cache task

=cut

sub run {
    get_logger->debug("Calling populate_ntlm_redis_cache");
    foreach my $domain (keys(%ConfigDomain)) {
        $logger->trace("Checking if $domain has NTLM cache enabled");
        if(isenabled($ConfigDomain{$domain}{ntlm_cache}) && isenabled($ConfigDomain{$domain}{ntlm_cache_batch})) {
            $logger->info("Synchronizing NTLM cache for domain $domain");
            my @args = ('queue_job', 'general', 'populate_ntlm_cache', $domain);
            # Call method on this server
            pf::client::getClient()->call(@args);

            # Call method on peer servers if in cluster
            if($cluster_enabled) {
                $logger->info("Calling populate_ntlm_cache on each cluster member.");
                my $failed = pf::cluster::api_call_each_server($FALSE, @args);
                if(@$failed > 0) {
                    $logger->error("Couldn't contact ".join(',', @$failed)." to dispatch job for domain $domain.");
                }
            }
        }
    }
}

=head1 AUTHOR


Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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
