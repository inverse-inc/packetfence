#!/usr/bin/perl
=head1 NAME

squid-redirector.pl - a squid redirection helper to capture proxied requests to PacketFence's captive portal 

=cut

=head1 STATUS

Developed and tested with Squid 3.1.7.

=head1 CONFIGURATION AND ENVIRONMENT

Need configuration file: F<pf.conf> to find the fully qualified domain name used by the captive portal.

=cut

use constant INSTALL_DIR => '/usr/local/pf';
use constant CONFIG_FILE => '/conf/pf.conf';

use Config::IniFiles;

my %Config;
tie %Config, 'Config::IniFiles', (-file => INSTALL_DIR . CONFIG_FILE);

my @errors = @Config::IniFiles::errors;
if (scalar(@errors)) {
    print STDOUT join( "\n", @errors );
}

my $fqdn = $Config{'general'}{'hostname'} . "." . $Config{'general'}{'domain'};
my $captive_portal = qr|
    ^https?://     # HTTP or HTTPS
    \Q$fqdn\E/     # captive portal fully qualified domain name (meta-quoted to avoid regexp expansion)
|ix;

$|=1;
while (<>) {
    # parameters provided by Squid
    # http://wiki.squid-cache.org/Features/Redirectors
    my ($id, $url, $ip_fqdn, $ident, $method, %params) = split;

    # if we are already hitting the captive portal, don't do anything
    if ($url =~ /$captive_portal/) {
        print "$id ";
    } else {

        # in any other case, we redirect to captive portal
        print "$id 302:https://$fqdn/captive-portal?destination_url=$url";
    }
    # newline returns the response to squid
    print "\n";
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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
