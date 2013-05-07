package pf::services::named;

=head1 NAME

pf::services::named - helper configuration module for bind (dns daemon)

=head1 DESCRIPTION

This module contains some functions that generates the bind configuration
according to what PacketFence needs to accomplish.

=head1 CONFIGURATION AND ENVIRONMENT

Read the following configuration files: F<conf/named.conf>.

Generates the following configuration files: F<var/conf/named.conf> and F<var/named/>.

=cut

use strict;
use warnings;
use Log::Log4perl;
use Net::Netmask;
use POSIX;
use Readonly;

use pf::config;
use pf::util;

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT_OK );
    @ISA = qw(Exporter);
    @EXPORT_OK = qw(
        generate_named_conf
    );
}

=head1 SUBROUTINES

=over


=item * generate_named_conf

=cut

sub generate_named_conf {
    my $logger = Log::Log4perl::get_logger('pf::services::named');

    my %tags;
    $tags{'template'}    = "$conf_dir/named.conf";
    $tags{'install_dir'} = $install_dir;

    # Used to trigger if the configuration file should be generated or not
    # depending on the presence of this type of interface
    my $generate_inline          = $FALSE;
    my $generate_isolation       = $FALSE;
    my $generate_registration    = $FALSE;

    my @routed_inline_nets_named;
    my @routed_isolation_nets_named;
    my @routed_registration_nets_named;
    my $inline_blackhole;
    my $isolation_blackhole;
    my $registration_blackhole;
    foreach my $network ( keys %ConfigNetworks ) {

        if ( $ConfigNetworks{$network}{'named'} eq 'enabled' ) {
            if ( pf::config::is_network_type_inline($network) ) {
                my $inline_obj = new Net::Netmask( $network, $ConfigNetworks{$network}{'netmask'} );
                push @routed_inline_nets_named, $inline_obj;
                $inline_blackhole = $ConfigNetworks{$network}{'gateway'};
                $generate_inline = $TRUE;

            } elsif ( pf::config::is_network_type_vlan_isol($network) ) {
                my $isolation_obj = new Net::Netmask( $network, $ConfigNetworks{$network}{'netmask'} );
                push @routed_isolation_nets_named, $isolation_obj;
                $isolation_blackhole = $ConfigNetworks{$network}{'dns'};
                $generate_isolation = $TRUE;

            } elsif ( pf::config::is_network_type_vlan_reg($network) ) {
                my $registration_obj = new Net::Netmask( $network, $ConfigNetworks{$network}{'netmask'} );
                push @routed_registration_nets_named, $registration_obj;
                $registration_blackhole = $ConfigNetworks{$network}{'dns'};
                $generate_registration = $TRUE;
            }
        }
    }

    $tags{'inline_clients'} = "";
    foreach my $net ( @routed_inline_nets_named ) {
        $tags{'inline_clients'} .= $net . "; ";
    }

    $tags{'isolation_clients'} = "";
    foreach my $net ( @routed_isolation_nets_named ) {
        $tags{'isolation_clients'} .= $net . "; ";
    }

    $tags{'registration_clients'} = "";
    foreach my $net ( @routed_registration_nets_named ) {
        $tags{'registration_clients'} .= $net . "; ";
    }

    #OAuth
    my $google_enabled = $guest_self_registration{$SELFREG_MODE_GOOGLE};
    my $facebook_enabled = $guest_self_registration{$SELFREG_MODE_FACEBOOK};
    my $github_enabled = $guest_self_registration{$SELFREG_MODE_GITHUB};

    $tags{'oauth_zones_vlan'} = "";
    $tags{'oauth_zones_inline'} ="";

    #If we have Google/Facebook enabled
    if ($google_enabled) {
        $tags{'oauth_zones_vlan'} .= "zone \"google.com\" IN {\n    type master;\n    file \"named-google.com\";\n    allow-update { none; };\n};\n\n";
        $tags{'oauth_zones_vlan'} .= "zone \"google.ca\" IN {\n    type master;\n    file \"named-google.ca\";\n    allow-update { none; };\n};\n\n";
        $tags{'oauth_zones_inline'} .= "zone \"google.com\" IN {\n    type master;\n    file \"named-inline-google.com\";\n    allow-update { none; };\n};\n\n";
        $tags{'oauth_zones_inline'} .= "zone \"google.ca\" IN {\n    type master;\n    file \"named-inline-google.ca\";\n    allow-update { none; };\n};\n\n";
    }

    if ($facebook_enabled) {
        $tags{'oauth_zones_vlan'} .= "zone \"facebook.com\" IN {\n    type master;\n    file \"named-facebook.com\";\n    allow-update { none; };\n};\n\n";
        $tags{'oauth_zones_vlan'} .= "zone \"fbcdn.net\" IN {\n    type master;\n    file \"named-fbcdn.net\";\n    allow-update { none; };\n};\n\n";
        $tags{'oauth_zones_inline'} .= "zone \"facebook.com\" IN {\n    type master;\n    file \"named-inline-facebook.com\";\n    allow-update { none; };\n};\n\n";
        $tags{'oauth_zones_inline'} .= "zone \"fbcdn.net\" IN {\n    type master;\n    file \"named-inline-fbcdn.net\";\n    allow-update { none; };\n};\n\n";
    }

    if ($github_enabled) {
        $tags{'oauth_zones_vlan'} .= "zone \"github.com\" IN {\n    type master;\n    file \"named-github.com\";\n    allow-update { none; };\n};\n\n";
        $tags{'oauth_zones_inline'} .= "zone \"github.com\" IN {\n    type master;\n    file \"named-inline-github.com\";\n    allow-update { none; };\n};\n\n";
        $tags{'oauth_zones_vlan'} .= "zone \"akamai.net\" IN {\n    type master;\n    file \"named-akamai.net\";\n    allow-update { none; };\n};\n\n";
        $tags{'oauth_zones_inline'} .= "zone \"akamai.net\" IN {\n    type master;\n    file \"named-inline-akamai.net\";\n    allow-update { none; };\n};\n\n";
    }

    parse_template( \%tags, "$conf_dir/named.conf", "$generated_conf_dir/named.conf" );

    if ( $generate_inline ) {
        my %tags_inline;
        $tags_inline{'template'} = "$conf_dir/named-inline.ca";
        $tags_inline{'hostname'} = $Config{'general'}{'hostname'};
        $tags_inline{'incharge'} = "pf." . $Config{'general'}{'hostname'} . "." . $Config{'general'}{'domain'};
        $tags_inline{'A_blackhole'} = $inline_blackhole;
        $tags_inline{'PTR_blackhole'} = reverse_ip($inline_blackhole) . ".in-addr.arpa.";
        parse_template(\%tags_inline, "$conf_dir/named-inline.ca", "$var_dir/named/named-inline.ca", ";");

        #If we have Google/Facebook Enabled
        if ($google_enabled) {
            parse_template(\%tags_inline, "$conf_dir/named-google.ca", "$var_dir/named/named-inline-google.ca",
                    ";");
            parse_template(\%tags_inline, "$conf_dir/named-google.com", "$var_dir/named/named-inline-google.com",
                    ";");
        }

        if ($facebook_enabled) {
            parse_template(\%tags_inline, "$conf_dir/named-facebook.com", "$var_dir/named/named-inline-facebook.com",
                    ";");
            parse_template(\%tags_inline, "$conf_dir/named-fbcdn.net", "$var_dir/named/named-inline-fbcdn.net",
                    ";");
        }

        if ($github_enabled) {
            parse_template(\%tags_inline, "$conf_dir/named-github.com", "$var_dir/named/named-inline-github.com",
                    ";");
            parse_template(\%tags_inline, "$conf_dir/named-akamai.net", "$var_dir/named/named-inline-akamai.net",
                    ";");
        }
    }

    if ( $generate_isolation ) {
        my %tags_isolation;
        $tags_isolation{'template'} = "$conf_dir/named-isolation.ca";
        $tags_isolation{'hostname'} = $Config{'general'}{'hostname'};
        $tags_isolation{'incharge'} = "pf." . $Config{'general'}{'hostname'} . "." . $Config{'general'}{'domain'};
        $tags_isolation{'A_blackhole'} = $isolation_blackhole;
        $tags_isolation{'PTR_blackhole'} = reverse_ip($isolation_blackhole) . ".in-addr.arpa.";
        parse_template(\%tags_isolation, "$conf_dir/named-isolation.ca", "$var_dir/named/named-isolation.ca", ";");
    }

    if ( $generate_registration ) {
        my %tags_registration;
        $tags_registration{'template'} = "$conf_dir/named-registration.ca";
        $tags_registration{'hostname'} = $Config{'general'}{'hostname'};
        $tags_registration{'incharge'} = "pf." . $Config{'general'}{'hostname'} . "." . $Config{'general'}{'domain'};
        $tags_registration{'A_blackhole'} = $registration_blackhole;
        $tags_registration{'PTR_blackhole'} = reverse_ip($registration_blackhole) . ".in-addr.arpa.";
        parse_template(\%tags_registration, "$conf_dir/named-registration.ca", "$var_dir/named/named-registration.ca", 
                ";");
        
        #If we have Google/Facebook Enabled
        if ($google_enabled) {
            parse_template(\%tags_registration, "$conf_dir/named-google.ca", "$var_dir/named/named-google.ca",
                    ";");
            parse_template(\%tags_registration, "$conf_dir/named-google.com", "$var_dir/named/named-google.com",
                    ";");
        }

        if ($facebook_enabled) {
            parse_template(\%tags_registration, "$conf_dir/named-facebook.com", "$var_dir/named/named-facebook.com",
                    ";");
            parse_template(\%tags_registration, "$conf_dir/named-fbcdn.net", "$var_dir/named/named-fbcdn.net",
                    ";");
        }

        if ($github_enabled) {
            parse_template(\%tags_registration, "$conf_dir/named-github.com", "$var_dir/named/named-github.com",
                    ";");
            parse_template(\%tags_registration, "$conf_dir/named-akamai.net", "$var_dir/named/named-akamai.net",
                    ";");
        }
    }

    return 1;
}

=back

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

1;
