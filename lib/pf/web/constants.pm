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

use pf::config;

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

=head2 URLs

See conf/httpd.conf.d/captive-portal-cleanurls.conf to see to which
CGI they map.

=cut
# normal flow
Readonly::Scalar our $URL_CAPTIVE_PORTAL => '/captive-portal';
Readonly::Scalar our $URL_AUP => '/aup';
Readonly::Scalar our $URL_AUTHENTICATE => '/authenticate';
Readonly::Scalar our $URL_ACCESS => '/access';
Readonly::Scalar our $URL_RELEASE => '/release';

# violation-related
Readonly::Scalar our $URL_ENABLER => '/enabler';

# guest related
Readonly::Scalar our $URL_SIGNUP => '/signup';
Readonly::Scalar our $URL_EMAIL_ACTIVATION => '/activate/email/';
Readonly::Scalar our $URL_SMS_ACTIVATION => '/activate/sms';
Readonly::Scalar our $URL_PREREGISTER => '/preregister';
Readonly::Scalar our $URL_SIGNUP_UGLY => '/guest-selfregistration.cgi';
Readonly::Scalar our $URL_ADMIN_MANAGE_GUESTS => '/guests/manage';

# billing engine
Readonly::Scalar our $URL_BILLING => '/pay';

# wireless auto-config
Readonly::Scalar our $URL_WIRELESS_PROFILE => '/wireless-profile.mobileconfig';

# required for specific Apache config ACL whitelisting
Readonly::Scalar our $ACL_EMAIL_ACTIVATION_CGI => '/cgi-perl/email_activation.cgi';
Readonly::Scalar our $ACL_SIGNUP_CGI => '/cgi-perl/guest-selfregistration.cgi';

=head2 Apache Config related

=over

=item Aliases for static content

URI => filesystem component

Filesystem portion is prefixed by $install_dir before installing into
Apache config.

=cut
Readonly::Hash our %STATIC_CONTENT_ALIASES => (
    '/common/' => '/html/common/',
    '/content/' => '/html/captive-portal/content/',
    '/favicon.ico' => '/html/common/favicon.ico',
);

=item ALLOWED_RESOURCES

Build a regex that will decide what is considered a local ressource
(allowed to Apache's further processing).

URL ending with / will only be anchored at the beginning (^/path/) otherwise
an ending anchor is also installed (^/file$).

Anything else should be redirected. This happens in L<pf::web::dispatcher>.

=cut
my @components = ( keys %STATIC_CONTENT_ALIASES, _clean_urls_match() );
# add $ to non-slash ending URLs
foreach (@components) { s{([^/])$}{$1\$} };
my $allow = join('|', @components);
Readonly::Scalar our $ALLOWED_RESOURCES => qr/ ^(?: $allow ) /xo; # eXtended pattern, compile Once

=item _clean_urls_match

Return a regex that would match all the captive portal allowed clean URLs

=cut
sub _clean_urls_match {
    my %consts = pf::web::constants::to_hash();
    my @urls;
    foreach (keys %consts) {
        # keep only constants matching ^URL
        push @urls, $consts{$_} if (/^URL/);
    }
    return (@urls);
}

=back

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2012 Inverse inc.

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
