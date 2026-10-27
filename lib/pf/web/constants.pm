package pf::web::constants;

=head1 NAME

pf::web::constants - Constants for the captive portal

=head1 DESCRIPTION

This file is splitted by packages and refering to the constant requires you to
specify the package.

=cut

use strict;
use warnings;

use Readonly;

=head1 SUBROUTINES

=over

=item to_hash

Return all the WEB constants in an hash. This is to ease consumption by
Template Toolkit.

=cut

sub to_hash {
    no strict 'refs';

    # Lists all the entries of the WEB package then for each of them:
    my %constants;
    foreach (keys %WEB::) {
        # don't keep non scalar (hashes, lists) because using $
        next if not defined ${"WEB::$_"};
        # don't keep regex
        next if ref(${"WEB::$_"}) eq 'Regexp';
        $constants{$_} = ${"WEB::$_"};
    }
    return %constants;
}

=back

=head1 WEB

=cut

package WEB;
use pfconfig::cached_array;

tie our @uri_filters, 'pfconfig::cached_array', 'resource::URI_Filters';

=head2 URLs

=cut

# normal flow
Readonly::Scalar our $URL_SLASH                       => '^/$';
Readonly::Scalar our $URL_ACCESS                      => '/access';
Readonly::Scalar our $URL_LOGOUT                      => '/logout';
Readonly::Scalar our $URL_BILLING                     => '/billing';
Readonly::Scalar our $URL_BILLING_CHILD               => '/billing/(.*)';
Readonly::Scalar our $URL_SSL_INSPECTION_CHILD        => '/ssl_inspection/(.*)';
Readonly::Scalar our $URL_CAPTIVE_PORTAL              => '/captive-portal';
Readonly::Scalar our $URL_SECURITY_EVENT              => '/security_event';
Readonly::Scalar our $URL_RELEASE                     => '/security_event/release';
Readonly::Scalar our $URL_REMEDIATION                 => '/remediation';
Readonly::Scalar our $URL_ENABLER                     => '/enabler';
Readonly::Scalar our $URL_WISPR                       => '/wispr';
Readonly::Scalar our $URL_OAUTH2                      => '/oauth2/(.+)';
Readonly::Scalar our $URL_LOST_STOLEN                 => '/loststolen/(.+)';
Readonly::Scalar our $URL_STATUS                      => '/status';
Readonly::Scalar our $URL_STATUS_RESETPW              => '/status/reset_pw';
Readonly::Scalar our $URL_STATUS_RESET_PASSWORD       => '/status/reset_password';
Readonly::Scalar our $URL_STATUS_FORGOT_PASSWORD      => '/status/forgot_password';
Readonly::Scalar our $URL_STATUS_RESET_PASSWORD_TOKEN => '/status/reset_password_token';
Readonly::Scalar our $URL_STATUS_LOGIN                => '/status/login';
Readonly::Scalar our $URL_STATUS_LOGOUT               => '/status/logout';
Readonly::Scalar our $URL_STATUS_BILLING              => '/status/billing';
Readonly::Scalar our $URL_STATUS_BILLING_CANCEL       => '/status/billing/cancel_subscription/(.+)';
Readonly::Scalar our $URL_STRIPE_CP                   => '/stripe-customer-portal(.*)';
Readonly::Scalar our $URL_NODE_MANAGER                => '/node/manager/(.+)';
Readonly::Scalar our $URL_SAML_REDIRECT               => '/saml/redirect';
Readonly::Scalar our $URL_SAML                        => '/saml/(.+)';
Readonly::Scalar our $URL_SPONSOR_CHECK               => '/sponsor/check';
Readonly::Scalar our $URL_EMAIL_CHECK                 => '/email/check';
Readonly::Scalar our $URL_SWITCH                      => '/switchto/(.+)';
Readonly::Scalar our $URL_RECORD_DESTINATION          => '/record_destination_url';
Readonly::Scalar our $URL_CHALLENGE                   => '/challenge';
Readonly::Scalar our $URL_NETWORK_LOGOFF              => '/networklogoff';
Readonly::Scalar our $URL_MFA                         => '/mfa';
Readonly::Scalar our $URL_PORTAL_TOKEN                => '/portaltoken';

# guest related
Readonly::Scalar our $URL_SIGNUP                      => '/signup';
Readonly::Scalar our $URL_EMAIL_ACTIVATION            => '/activate/email(.*)';
Readonly::Scalar our $URL_EMAIL_ACTIVATION_LINK       => '/activate/email';
Readonly::Scalar our $URL_SMS_ACTIVATION              => '/activate/sms';
Readonly::Scalar our $URL_ADMIN_MANAGE_GUESTS         => '/guests/manage';

Readonly::Scalar our $URL_GAMING_REGISTRATION         => '/gaming-registration';
Readonly::Scalar our $URL_DEVICE_REGISTRATION         => '/device-registration';
Readonly::Scalar our $URL_DEVICE_REG_LOGOUT           => '/device-registration/logout';

# External Captive Portal URL detection constant
Readonly::Scalar our $EXT_URL_AEROHIVE                => '^/AeroHIVE::AP';
Readonly::Scalar our $EXT_URL_AEROHIVE_SHORT          => '^/AeroHIVE';
Readonly::Scalar our $EXT_URL_ARUBA                   => '^/Aruba';
Readonly::Scalar our $EXT_URL_ARUBA_SWITCH            => '^/Aruba::2930M';
Readonly::Scalar our $EXT_URL_ARUBA_ARUBAOS_SWITCH_16_X => '^/Aruba::ArubaOS_Switch_16_x';
Readonly::Scalar our $EXT_URL_CISCO_CATALYST_2960     => '^/Cisco::Catalyst_2960';
Readonly::Scalar our $EXT_URL_CISCO_CISCO_IOS_15_0    => '^/Cisco::Cisco_IOS_15_0';
Readonly::Scalar our $EXT_URL_CISCO_CISCO_IOS_15_5    => '^/Cisco::Cisco_IOS_15_5';
Readonly::Scalar our $EXT_URL_CISCO_WLC               => '^/Cisco::WLC';
Readonly::Scalar our $EXT_URL_CISCO_WLC_AIREOS        => '^/Cisco::Cisco_WLC_AireOS';
Readonly::Scalar our $EXT_URL_CISCO_WLC_IOS_XE        => '^/Cisco::Cisco_WLC_IOS_XE';
Readonly::Scalar our $EXT_URL_CISCO_ASA               => '^/Cisco::ASA';
Readonly::Scalar our $EXT_URL_COOVACHILLI             => '^/CoovaChilli';
Readonly::Scalar our $EXT_URL_MERAKI                  => '^/Meraki::MR';
Readonly::Scalar our $EXT_URL_MERAKI_V2               => '^/Meraki::MR_v2';
Readonly::Scalar our $EXT_URL_RUCKUS                  => '^/Ruckus';
Readonly::Scalar our $EXT_URL_RUCKUS_SMARTZONE        => '^/RuckusSmartZone';
Readonly::Scalar our $EXT_URL_XIRRUS                  => '^/Xirrus';
Readonly::Scalar our $EXT_URL_MIKROTIK                => '^/Mikrotik';
Readonly::Scalar our $EXT_URL_FORTIGATE               => '^/Fortinet::FortiGate';
Readonly::Scalar our $EXT_URL_CAMBIUM                 => '^/Cambium';
Readonly::Scalar our $EXT_URL_MOJO                    => '^/Mojo';
Readonly::Scalar our $EXT_URL_DELL_N1500              => '^/Dell::N1500';
Readonly::Scalar our $EXT_URL_EXOS                    => '^/Extreme::EXOS';
Readonly::Scalar our $EXT_URL_EXTREME_AP              => '^/Extreme::AP';
Readonly::Scalar our $EXT_URL_F5                      => '^/F5';
Readonly::Scalar our $EXT_URL_MERAKI_MS               => '^/Meraki::MS';
Readonly::Scalar our $EXT_URL_RUCKUS_UNLEASHED        => '^/Ruckus::Unleashed';
Readonly::Scalar our $EXT_URL_MIST                    => '^/MistAP';

# Ubiquiti doesn't support setting the URL so we much detect it using this URL which will then map to the Ubiquiti module in pf::web::externalportal
Readonly::Scalar our $EXT_URL_UBIQUITI                => '^/guest/s/[a-zA-Z0-9]+/';

# Provisioning engine
Readonly::Scalar our $URL_WIRELESS_PROFILE            => '/wireless-profile.mobileconfig';
Readonly::Scalar our $URL_ANDROID_PROFILE             => '/profile.xml';
Readonly::Scalar our $URL_TLS_GENERATION              => '/tlsprofile';


=head2 Apache Config related

=over

=item Aliases for static content

URI => filesystem component

Filesystem portion is prefixed by $install_dir before installing into
Apache config.

=cut

Readonly::Hash our %CAPTIVE_PORTAL_STATIC_ALIASES => (
    '/common/'                => '/html/common/',
    '/content/'               => '/html/captive-portal/content/',
    '/profile-templates/'     => '/html/captive-portal/profile-templates/',
    '/favicon.ico'            => '/html/common/favicon.ico',
);

=item CAPTIVE_PORTAL_RESOURCES

Web portal resources that needs to be served by the captive-portal Catalyst Engine.

All URLs defined using constants starting with 'URL' are considered a web portal resource

=cut

my @captive_portal_resources = _captive_portal_resources_parser();
foreach ( @captive_portal_resources ) { s{([^/])$}{$1\$} }; # add $ to non-slash ending URLs
my $captive_portal_resources = join('|', @captive_portal_resources);
Readonly::Scalar our $CAPTIVE_PORTAL_RESOURCES => qr/ ^(?: $captive_portal_resources ) /xo; # eXtended pattern, compile Once

=item CAPTIVE_PORTAL_STATIC_RESOURCES

Web portal static resources that needs to be served by Apached without further processing.

All URLs matching one of the 'CAPTIVE_PORTAL_STATIC_ALIASES' path are considered a web portal static resource

=cut

my @captive_portal_static_ressources = keys %CAPTIVE_PORTAL_STATIC_ALIASES;
foreach ( @captive_portal_static_ressources ) { s{([^/])$}{$1\$} }; # add $ to non-slash ending URLs
my $captive_portal_static_resources = join('|', @captive_portal_static_ressources);
Readonly::Scalar our $CAPTIVE_PORTAL_STATIC_RESOURCES => qr/ ^(?: $captive_portal_static_resources ) /xo; # eXtended pattern, compile Once

=item LOCALES

Supported locales must be generated on the server and also have their binary catalog (.mo) under
/usr/local/pf/conf/locale/. Notice that a PacketFence translation generated for a two-letter language
code (ex: fr) will be used for any locale matching the language code (ex: fr_FR and fr_CA).

=cut

Readonly::Array our @LOCALES =>
  (
   qw(en_US es_ES fr_FR fr_CA de_DE he_IL it_IT nb_NO nl_NL pl_PL pt_BR tr_TR)
  );

=item allowed_resources_profile_filter

Returns a regex that will decide what is considered a local ressource
(allowed to Apache's further processing), or undef when no connection profile
has a URI filter.

URL ending with / will only be anchored at the beginning (^/path/) otherwise
an ending anchor is also installed (^/file$).

Anything else should be redirected. This happens in L<pf::web::dispatcher>.

The regex is built from the current URI filters of the connection profiles
(pfconfig) and only recompiled when they change, so a change to a profile
filter is applied without restarting the portal.

=cut

my ($profile_filter_source, $profile_filter_regex) = ('', undef);

sub allowed_resources_profile_filter {
    my $allow_profile = join('|', map { profile_filter_pattern($_) } _clean_urls_match_filter());
    if ($allow_profile ne $profile_filter_source) {
        my ($regex, $error) = compile_profile_filter($allow_profile);
        if (defined $error) {
            # Keep the previous regex, the error is logged once per change of the filters
            require pf::log;
            pf::log::get_logger()->error("Invalid connection profile URI filter, keeping the previous ones: $error");
        } else {
            $profile_filter_regex = $regex;
        }
        $profile_filter_source = $allow_profile;
    }
    return $profile_filter_regex;
}

=item profile_filter_pattern

The pattern of a connection profile URI filter: a URL ending with / is only
anchored at the beginning, an ending anchor is added otherwise

=cut

sub profile_filter_pattern {
    my ($filter) = @_;
    $filter =~ s{([^/])$}{$1\$};
    return $filter;
}

=item compile_profile_filter

Compile the alternation of URI filter patterns, returns the regex (undef when
there is no filter) and the error message if it doesn't compile

=cut

sub compile_profile_filter {
    my ($allow_profile) = @_;
    return (undef, undef) if $allow_profile eq '';
    my $regex = eval { qr/ ^(?: $allow_profile ) /x }; # eXtended pattern
    if (!defined $regex) {
        my $error = $@ || 'unknown error';
        $error =~ s/\s+$//;
        return (undef, $error);
    }
    return ($regex, undef);
}

=item EXTERNAL_PORTAL_URL

Build a regex that will decide what is considered as a external portal URL.

This URL should point to a module in pf::Switch that can extract the mac or ip of the switch from the URL.

=cut

my @components_url =  _clean_urls_match_ext_url();
foreach (@components_url) { s{([^/])$}{$1(?:\$|\/)} };
my $allow_url = join('|', @components_url);
Readonly::Scalar our $EXTERNAL_PORTAL_URL => qr/ ^(?: $allow_url ) /xo; # eXtended pattern, compile Once

=item _captive_portal_resources_parser

Return a regex that would match all the captive portal allowed clean URLs

=cut

sub _captive_portal_resources_parser {
    my %consts = pf::web::constants::to_hash();
    my @urls;
    foreach (keys %consts) {
        # keep only constants matching ^URL
        push @urls, $consts{$_} if (/^URL/);
    }
    return (@urls);
}

=item _clean_urls_match_filter

Return a regex that would match all the connection profile uri: filter

=cut

sub _clean_urls_match_filter {
    return @uri_filters;
}

=item _clean_urls_match_ext_url

Return a regex that would match all the captive portal allowed clean URLs

=cut

sub _clean_urls_match_ext_url {
    my %consts = pf::web::constants::to_hash();
    my @urls;
    foreach (keys %consts) {
        # keep only constants matching ^URL
        push @urls, $consts{$_} if (/^EXT_URL/);
    }
    return (@urls);
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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
