package pf::web::gaming;

=head1 NAME

pf::web::gaming

=cut

=head1 DESCRIPTION

Library for the gaming-device registration page

=cut

use strict;
use warnings;

use HTML::Entities;
use Readonly;

use pf::config;
use pf::enforcement qw(reevaluate_access);
use pf::node qw(node_register is_max_reg_nodes_reached);
use pf::util;
use pf::web;
use pf::web::custom;    # called last to allow redefinitions

use pf::authentication;
use pf::Authentication::constants;
use List::MoreUtils qw(any);

Readonly our $GAMING_LOGIN_TEMPLATE   => 'gaming-login.html';
Readonly our $GAMING_LANDING_TEMPLATE => 'gaming-landing.html';
Readonly our $GAMING_REGISTRATION_TEMPLATE => 'gaming-registration.html';
Readonly our @GAMING_OUI => _load_file_into_array($allowed_device_oui_file);
Readonly our @GAMING_CONSOLE_TYPES => _load_file_into_array($allowed_device_types_file);

=head1 SUBROUTINES

=over

=cut


sub generate_login_page {
    my ($portalSession, $err) = @_;
    pf::web::generate_generic_page(
        $portalSession, $GAMING_LOGIN_TEMPLATE, {
        txt_auth_error => ( (defined $err) ? i18n($err) : undef ),
        username => encode_entities($portalSession->cgi->param("username")),
        oauth2_google => is_in_list($SELFREG_MODE_GOOGLE, $portalSession->getProfile->getGuestModes),
        oauth2_facebook => is_in_list($SELFREG_MODE_FACEBOOK, $portalSession->getProfile->getGuestModes),
        oauth2_github => is_in_list($SELFREG_MODE_GITHUB, $portalSession->getProfile->getGuestModes),
        }
    );
}

=item _load_file_into_array

Loads each line of file into array
Trimming spaces and removing shell style comments from each line

=cut

sub _load_file_into_array {
    my ($file_name) = @_;
    my @items;
    if(-r $file_name) {
        local *FILE;
        open(FILE,$file_name);
        @items =
            grep {$_}
            map {
                #Getting rid of newlines, comments and trimming spaces
                chomp; s/#.*$//; s/^\s+//; s/\s+$//;
                $_;
            } <FILE>;
        close(FILE);
    }
    return @items;
}

=item generate_registration_page

Generate registration page

=cut

sub generate_registration_page {
    my ($portalSession, $err) = @_;
    pf::web::generate_generic_page(
        $portalSession,
        $GAMING_REGISTRATION_TEMPLATE, {
            console_types => \@GAMING_CONSOLE_TYPES,
            txt_auth_error => ( (defined $err) ? i18n($err) : undef),
        }
    );
}

=item generate_landing_page

Generates the landing page

=cut

sub generate_landing_page {
    my ($portalSession, $msg) = @_;
    pf::web::generate_generic_page(
        $portalSession,
        $GAMING_LANDING_TEMPLATE,
        {status_msg => ( (defined $msg) ? i18n($msg) : undef)}
    );
}


=item is_allowed_gaming_mac

Validate if mac address is an allowed gaming mac

=cut

sub is_allowed_gaming_mac {
    my ($mac) = @_;
    return 1 unless @GAMING_OUI;
    $mac =~ s/O/0/i;
    $mac = clean_mac($mac);
    return any { $mac =~ /^\Q$_\E/i } @GAMING_OUI;
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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
