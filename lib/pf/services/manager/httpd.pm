package pf::services::manager::httpd;
=head1 NAME

pf::services::manager::httpd add documentation

=cut

=head1 DESCRIPTION

pf::services::manager::httpd

=cut

use strict;
use warnings;
use pf::config;
use Moo;
use POSIX;
use pf::class qw(class_view_all);
use pf::util;
use pf::util::apache qw(url_parser);
use pf::web::constants;
use pf::authentication;
extends 'pf::services::manager';

has '+launcher' => ( builder => 1, lazy => 1 );

sub executable {
    my ($self) = @_;
    my $service = ( $Config{'services'}{"httpd_binary"} || "$install_dir/sbin/httpd" );
    return $service;
}

sub _build_launcher {
    my ($self) = @_;
    my $name = $self->name;
    return "%1\$s -f $conf_dir/httpd.conf.d/$name -D$OS"
}

=head2 generateConfig

TODO: documention

=cut

our $WAS_GENERATED;

sub generateConfig {
    my ($self) = @_;
    return 1 if $WAS_GENERATED;
    $WAS_GENERATED = 1;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    # injecting Web constants first
    my %tags = pf::web::constants::to_hash();

    $tags{'aliases'} = _generate_aliases();
    $tags{'template'} = "$conf_dir/httpd.conf";
    $tags{'internal-nets'} = join(" ", get_internal_nets() );
    $tags{'routed-nets'} = join(" ", get_routed_isolation_nets()) ." ". join(" ", get_routed_registration_nets()) ." ". join(" ", get_inline_nets());
    $tags{'load_balancers'} = join(" ", keys %{$CAPTIVE_PORTAL{'loadbalancers_ip'}});
    $tags{'hostname'} = $Config{'general'}{'hostname'};
    $tags{'domain'} = $Config{'general'}{'domain'};
    $tags{'timezone'} = $Config{'general'}{'timezone'};
    $tags{'admin_port'} = $Config{'ports'}{'admin'};
    $tags{'install_dir'} = $install_dir;
    $tags{'varconf_dir'} = $generated_conf_dir;
    $tags{'max_clients'} = calculate_max_clients(get_total_system_memory());
    $tags{'start_servers'} = calculate_start_servers($tags{'max_clients'});
    $tags{'min_spare_servers'} = calculate_min_spare_servers($tags{'max_clients'});

    my @proxies;
    my %proxy_configs = %{ $Config{'proxies'} };
    foreach my $proxy ( keys %proxy_configs ) {
        if ( $proxy =~ /^\// ) {
            if ( $proxy !~ /$WEB::ALLOWED_RESOURCES/ ) {
                push @proxies, "ProxyPassReverse $proxy $proxy_configs{$proxy}";
                push @proxies, "ProxyPass $proxy $proxy_configs{$proxy}";
                $logger->warn( "proxy $proxy is not relative - add path to apache rewrite exclude list!");
            } else {
                $logger->warn("proxy $proxy conflicts with PF paths!");
                next;
            }
        } else {
            push @proxies, "ProxyPassReverse /proxies/" . $proxy . " " . $proxy_configs{$proxy};
            push @proxies, "ProxyPass /proxies/" . $proxy . " " . $proxy_configs{$proxy};
        }
    }
    $tags{'proxies'} = join( "\n", @proxies );

    # Guest related URLs allowed through Apache ACL's
    $tags{'allowed_from_all_urls'} = "|$WEB::URL_STATUS";
    # signup and preregister if pre-registration is allowed
    my $guest_regist_allowed = scalar keys %guest_self_registration;
    if ($guest_regist_allowed && isenabled($Config{'guests_self_registration'}{'preregistration'})) {
        # | is for a regexp "or" as this is pulled from a 'Location ~' statement
        $tags{'allowed_from_all_urls'} .= "|$WEB::URL_SIGNUP|$WEB::CGI_SIGNUP|$WEB::URL_PREREGISTER";
    }
    # /activate/email allowed if sponsor or email mode enabled
    my $email_enabled = $guest_self_registration{$SELFREG_MODE_EMAIL};
    my $sponsor_enabled = $guest_self_registration{$SELFREG_MODE_SPONSOR};
    if ($guest_regist_allowed && ($email_enabled || $sponsor_enabled)) {
        # | is for a regexp "or" as this is pulled from a 'Location ~' statement
        $tags{'allowed_from_all_urls'} .= "|$WEB::URL_EMAIL_ACTIVATION|$WEB::CGI_EMAIL_ACTIVATION";
    }

    #unuse since httpd.conf has been rewrite in perl
    #$logger->info("generating $generated_conf_dir/httpd.conf");
    #parse_template( \%tags, "$conf_dir/httpd.conf", "$generated_conf_dir/httpd.conf", "#" );

    $logger->info("generating $generated_conf_dir/ssl-certificates.conf");
    parse_template( \%tags, "$conf_dir/httpd.conf.d/ssl-certificates.conf", "$generated_conf_dir/ssl-certificates.conf", "#" );

    # TODO we *could* do something smarter and process all of conf/httpd.conf.d/
    my @config_files = ( 'captive-portal-common.conf', 'captive-portal-cleanurls.conf');
    foreach my $config_file (@config_files) {
        $logger->info("generating $generated_conf_dir/$config_file");
        parse_template(\%tags, "$conf_dir/httpd.conf.d/$config_file", "$generated_conf_dir/$config_file");
    }

    return 1;
}

=head2 calculate_max_clients

Find out how much processes Apache should take based on system's characteristics.

See Apache's documentation for MaxClients.

=cut

sub calculate_max_clients {
    my ($total_ram) = @_;
    my $logger = Log::Log4perl::get_logger('pf::services::apache');

    if (!defined($total_ram)) {
        $logger->warn("Unable to find total system memory, will use 2Gb to determine Apache's MaxClients");
        $total_ram = 2097152;
    }

    # here's the magic metric we've come up with to determine Apache's MaxClients
    # evaluated for Apache 2.x see ticket #1204 for details
    # MaxClients = (total - ( total * 25% + 300Mb )) / 50Mb
    my $max_clients = ceil(($total_ram - ( $total_ram * 0.25 + (300 * 1024) )) / (50 * 1024));

    # hard ceiling of MaxClients at 256
    $max_clients = 256 if ($max_clients > 256);

    return $max_clients;
}

=head2 calculate_min_spare_servers

Find out how much idle processes Apache should always have at hand.

See Apache's documentation for MinSpareServers.

=cut

sub calculate_min_spare_servers {
    my ($max_clients) = @_;

    # evaluated for Apache 2.x see ticket #1204 for details
    return ceil($max_clients / 4);
}

=head2 calculate_start_servers

Find out how much processes Apache should start.

See Apache's documentation for StartServers.

=cut

sub calculate_start_servers {
    my ($max_clients) = @_;

    # evaluated for Apache 2.x see ticket #1204 for details
    return ceil($max_clients / 2);
}

=head2 _generate_aliases

Automatically generates Apache's Alias statements so the captive portal works.

=cut

sub _generate_aliases {
    my $aliases = "";
    my ($path, $filesystem);
    while (($path, $filesystem) = each %WEB::STATIC_CONTENT_ALIASES) {
        $aliases .= "Alias $path $install_dir$filesystem\n";
    }
    return $aliases;
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>


=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and::or
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

