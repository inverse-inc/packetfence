#!/usr/bin/perl
=head1 NAME

pf-services-snmptrapd.pl

=head1 DESCRIPTION

Some performance benchmarks on pf::services::snmptrapd functions

=cut
use strict;
use warnings;
use diagnostics;

use Benchmark qw(cmpthese);

use lib '/usr/local/pf/lib';

=head1 original generate_snmptrapd_conf

From 3.1.0 (mtn rev 8417133ef12795d8cd8389b5a30df387190c9547)

=cut
use pf::services::snmptrapd;

use Log::Log4perl;

use pf::config;     
use pf::SwitchFactory;
use pf::util;

sub generate_snmptrapd_conf_orig {
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    my %tags;
    $tags{'authLines'} = '';
    $tags{'userLines'} = '';
    my %SNMPv3Users;
    my %SNMPCommunities;
    my $switchFactory = pf::SwitchFactory->getInstance();
    # TODO we can probably make this more performant if we use the hashref instead of re-creating a new one?
    my %switchConfig = %{ $switchFactory->{_config} };

    foreach my $key ( sort keys %switchConfig ) {
        # FIXME shouldn't we always add the default one?
        if ( $key ne 'default' ) {
            if (ref($switchConfig{$key}{'type'}) eq 'ARRAY') {
                $logger->warn("There is an error in your $conf_dir/switches.conf. "
                    . "I will skip $key from snmptrapd config");
                next;
            }
            # TODO we can probably make this more performant if we avoid object instantiation (can we?)
            my $switch = $switchFactory->instantiate($key);
            if (!$switch) {
                $logger->error("Can not instantiate switch $key!");
            } else {
                if ( $switch->{_SNMPVersionTrap} eq '3' ) {
                    $SNMPv3Users{ $switch->{_SNMPUserNameTrap} }
                        = '-e ' . $switch->{_SNMPEngineID} . ' '
                        . $switch->{_SNMPUserNameTrap} . ' '
                        . $switch->{_SNMPAuthProtocolTrap} . ' '
                        . $switch->{_SNMPAuthPasswordTrap} . ' '
                        . $switch->{_SNMPPrivProtocolTrap} . ' '
                        . $switch->{_SNMPPrivPasswordTrap};
                } else {
                    $SNMPCommunities{ $switch->{_SNMPCommunityTrap} } = 1;
                }
            }
        }
    }

    foreach my $userName ( sort keys %SNMPv3Users ) { 
        $tags{'userLines'} .= "createUser " . $SNMPv3Users{$userName} . "\n";
        $tags{'authLines'} .= "authUser log $userName priv\n";
    }
    foreach my $community ( sort keys %SNMPCommunities ) {
        $tags{'authLines'} .= "authCommunity log $community\n";
    }

    $tags{'template'} = "$conf_dir/snmptrapd.conf";
    $logger->info("generating $generated_conf_dir/snmptrapd.conf");
    parse_template( \%tags, "$conf_dir/snmptrapd.conf", "$generated_conf_dir/snmptrapd.conf" );
    return $TRUE;
}

cmpthese(300, {
    'current' => sub { pf::services::snmptrapd::generate_snmptrapd_conf() },
    'original' => sub { generate_snmptrapd_conf_orig() },
});

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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
