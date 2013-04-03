package pf::services::apache;

=head1 NAME

pf::services::apache - helper configuration module for apache

=head1 DESCRIPTION

This module contains some functions that generates Apache configuration
according to what PacketFence needs to accomplish.

=head1 CONFIGURATION AND ENVIRONMENT

Read the following configuration files: F<httpd.conf>.

Generates the following configuration files: F<httpd.conf>.

=cut

use strict;
use warnings;
use Log::Log4perl;
use POSIX;
use Readonly;

use pf::class qw(class_view_all);
use pf::config;
use pf::util;
use pf::util::apache qw(url_parser);
use pf::web::constants;

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    @EXPORT = qw(
        generate_httpd_conf
        generate_passthrough_rewrite_proxy_config
        generate_remediation_rewrite_proxy_config
    );
}

=head1 SUBROUTINES

=over

=item generate_httpd_conf

Generate proper F<httpd.conf> configuration file.

=cut

sub generate_httpd_conf {
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
    $tags{'allowed_from_all_urls'} = '';
    # signup and preregister if pre-registration is allowed
    my $guest_regist_allowed = $guest_self_registration{'enabled'};
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

    my ($pt_http, $pt_https, $remediation);
    if ( $Config{'trapping'}{'passthrough'} eq "proxy" ) {

        ($pt_http, $pt_https) = generate_passthrough_rewrite_proxy_config(%{ $Config{'passthroughs'} });

        # remediation passthrough (for violations.conf url=http:// or https://)
        $remediation = generate_remediation_rewrite_proxy_config(class_view_all());
    }

    # if config doesn't exist, replace it with empty array
    foreach my $template ($remediation, $pt_http, $pt_https) {
        if (!defined($template)) {
            $template = [ ];
        }
    }

    # associate config to templates
    $tags{'remediation-proxies'} = join( "\n", @{$remediation});
    $tags{'passthrough-http-proxies'} = join("\n", @{$pt_http});
    $tags{'passthrough-https-proxies'} = join("\n", @{$pt_https});

    #unuse since httpd.conf has been rewrite in perl
    #$logger->info("generating $generated_conf_dir/httpd.conf");
    #parse_template( \%tags, "$conf_dir/httpd.conf", "$generated_conf_dir/httpd.conf", "#" );

    $logger->info("generating $generated_conf_dir/ssl-certificates.conf");
    parse_template( \%tags, "$conf_dir/httpd.conf.d/ssl-certificates.conf", "$generated_conf_dir/ssl-certificates.conf", "#" );

    # TODO we *could* do something smarter and process all of conf/httpd.conf.d/
    my @config_files = ( 'block-unwanted.conf', 'captive-portal-common.conf', 'captive-portal-cleanurls.conf', 'ocsp-crl.conf');
    foreach my $config_file (@config_files) {
        $logger->info("generating $generated_conf_dir/$config_file");
        parse_template(\%tags, "$conf_dir/httpd.conf.d/$config_file", "$generated_conf_dir/$config_file");
    }

    return 1;
}

=item calculate_max_clients

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

=item calculate_min_spare_servers

Find out how much idle processes Apache should always have at hand.

See Apache's documentation for MinSpareServers.

=cut
sub calculate_min_spare_servers {
    my ($max_clients) = @_;

    # evaluated for Apache 2.x see ticket #1204 for details
    return ceil($max_clients / 4);
}

=item calculate_start_servers

Find out how much processes Apache should start.

See Apache's documentation for StartServers.

=cut
sub calculate_start_servers {
    my ($max_clients) = @_;

    # evaluated for Apache 2.x see ticket #1204 for details
    return ceil($max_clients / 2);
}

=item generate_passthrough_rewrite_proxy_config

Generate the proper mod_rewrite configuration so that a request matching the specified URL will be reversed proxied
through the captive portal. This is known as a passthrough URL.

Configured by the [passthroughs] section of the F<pf.conf> configuration file.
trapping.passthrough must be set to proxy for this to work.

Returns a list of two arrayref (one for http, one for https)

=cut
sub generate_passthrough_rewrite_proxy_config {
    my (%passthroughs) = @_;
    my $logger = Log::Log4perl::get_logger('pf::services::apache');

    my (@passthrough_http_proxies, @passthrough_https_proxies);

    foreach my $key ( keys %passthroughs ) {
        my ($domainonly_url, $proto, $host, $query) = url_parser($passthroughs{$key});
        # test that URL was parsed properly
        if (!defined($domainonly_url) || !defined($proto) || !defined($host) || !defined($query)) {
            $logger->warn("passthrough $key: unrecognized content URL: " .$passthroughs{$key}. ". "
                . "This passthrough will not be activated."
            );
            next;
        }

        if ($proto eq $HTTP) {
            push @passthrough_http_proxies, "  # Rewrite rules generated for passthrough $key";
            push @passthrough_http_proxies, "  RewriteCond %{HTTP_HOST} ^$host\$";
            push @passthrough_http_proxies, "  RewriteCond %{REQUEST_URI} ^$query";
            push @passthrough_http_proxies, "  RewriteRule ^/(.*)\$ $domainonly_url/\$1 [P]";
        } elsif ($proto eq $HTTPS) {
            push @passthrough_http_proxies, "  # Rewrite rules generated for passthrough $key";
            push @passthrough_https_proxies, "  RewriteCond %{HTTP_HOST} ^$host\$";
            push @passthrough_https_proxies, "  RewriteCond %{REQUEST_URI} ^$query";
            push @passthrough_https_proxies, "  RewriteRule ^/(.*)\$ $domainonly_url/\$1 [P]";
        }
    }

    # Adding some comments to the generated config
    if (@passthrough_http_proxies) {
        unshift @passthrough_http_proxies, "  # AUTO-GENERATED mod_rewrite rules for PacketFence Passthroughs";
        push @passthrough_http_proxies, "  # End of AUTO-GENERATED mod_rewrite rules for PacketFence Passthroughs";
    } else {
        push @passthrough_http_proxies, "  # NO auto-generated mod_rewrite rules for PacketFence Passthroughs";
    }
    if (@passthrough_https_proxies) {
        unshift @passthrough_https_proxies, "  # AUTO-GENERATED mod_rewrite rules for PacketFence Passthroughs";
        push @passthrough_https_proxies, "  # End of AUTO-GENERATED mod_rewrite rules for PacketFence Passthroughs";
    } else {
        push @passthrough_https_proxies, "  # NO auto-generated mod_rewrite rules for PacketFence Passthroughs";
    }

    return (\@passthrough_http_proxies, \@passthrough_https_proxies);
}

=item generate_remediation_rewrite_proxy_config

Generate the proper mod_rewrite configuration so that URLs specified in violations.conf are allowed
through the captive portal. Doing so allows people to be redirected to such URL on violations.

Configured by the F<violations.conf> configuration file.
trapping.passthrough must be set to proxy for this to work.

Returns an arrayref

=cut
sub generate_remediation_rewrite_proxy_config {
    my (@proxies) = @_;
    my $logger = Log::Log4perl::get_logger('pf::services::apache');

    # remediation passthrough (for violations.conf url=http:// or https://)
    my @remediation_proxies;
    foreach my $row (@proxies) {
        my $url = $row->{'url'};
        my $vid = $row->{'vid'};
        next if ( ( !defined($url) ) || ( $url =~ /^\// ) );
        my ($domainonly_url, $proto, $host, $query) = url_parser($url);
        # test that URL was parsed properly
        if (!defined($domainonly_url) || !defined($proto) || !defined($host) || !defined($query)) {
            $logger->warn("vid " . $vid . ": unrecognized content URL: " . $url . ". "
                . "No reverse proxying done for URL."
            );
            next;
        }

        push @remediation_proxies, "  # Rewrite rules generated for violation $vid external's URL";
        push @remediation_proxies, "  RewriteCond %{HTTP_HOST} ^$host\$";
        push @remediation_proxies, "  RewriteCond %{REQUEST_URI} ^$query";
        push @remediation_proxies, "  RewriteRule ^/(.*)\$ $domainonly_url/\$1 [P]";

        # old behavior: see http://www.apachetutor.org/admin/reverseproxies if we are ever willing to re-enable
        # requires mod_proxy_html and AFAIK below is broken by default
        # see #1024
        #push @remediation_proxies, "ProxyPass                /content/$vid/ $url";
        #push @remediation_proxies, "ProxyPassReverse        /content/$vid/ $url";
        #push @remediation_proxies, "ProxyPass       /content/$vid $url";
        #push @remediation_proxies, "<Location /content/$vid>";
        #push @remediation_proxies, "  SetOutputFilter        proxy-html";
        #push @remediation_proxies, "  ProxyHTMLDoctype        HTML";
        #push @remediation_proxies, "  ProxyHTMLURLMap        / /content/$vid/";
        #push @remediation_proxies, "  ProxyHTMLURLMap        /content/$vid /content/$vid";
        #push @remediation_proxies, "  RequestHeader        unset        Accept-Encoding";
        #push @remediation_proxies, "</Location>";
    }

    # Adding some comments to the generated config
    if (@remediation_proxies) {
        unshift @remediation_proxies, "  # AUTO-GENERATED mod_rewrite rules for PacketFence Remediation";
        push @remediation_proxies, "  # End of AUTO-GENERATED mod_rewrite rules for PacketFence Remediation";
    } else {
        push @remediation_proxies, "  # NO auto-generated mod_rewrite rules for PacketFence Remediation";
    }

    return \@remediation_proxies;
}

=item _generate_aliases

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
