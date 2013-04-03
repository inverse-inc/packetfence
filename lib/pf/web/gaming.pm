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

Readonly our $GAMING_LOGIN_TEMPLATE   => 'gaming-login.html';
Readonly our $GAMING_LANDING_TEMPLATE => 'gaming-landing.html';
Readonly our $GAMING_REGISTRATION_TEMPLATE => 'gaming-registration.html';
Readonly our @GAMING_OUI => (
    '00:12:5A:' ,  #          Microsoft-Xbox
    '00:0D:3A:' ,  #          Microsoft-Xbox
    '00:50:F2:' ,  #          Microsoft-Xbox
    '00:01:4A:' ,  #          Sony-PS2-PSP
    '00:02:C7:' ,  #          Sony-PS2-PSP
    '00:04:1F:' ,  #          Sony-PS2-PSP
    '00:13:15:' ,  #          Sony-PS2-PSP
    '00:09:BF:' ,  #          Nintendo-Wii
    '00:17:AB:' ,  #          Nintendo-Wii
    '00:17:FA:' ,  #          Microsoft-Xbox
    '00:15:C1:' ,  #          Sony-PS3
    '00:19:C5:' ,  #          Sony-PS3
    '00:1D:D8:' ,  #          Microsoft-Xbox
    '00:0B:E6:' ,  #          Nintendo-Wii
    '00:16:56:' ,  #          Nintendo-Wii
    '00:1A:E9:' ,  #          Nintendo-Wii
    '00:1D:0D:' ,  #          Sony-PS3
    '00:19:1D:' ,  #          Nintendo-Wii
    '00:19:FD:' ,  #          Nintendo-Wii
    '00:1F:32:' ,  #          Nintendo-Wii
    '00:1C:BE:' ,  #          Nintendo-Wii
    '00:1B:EA:' ,  #          Nintendo-Wii
    '00:1E:35:' ,  #          Nintendo-Wii
    '00:1B:7A:' ,  #          Ninetndo-Wii
    '00:22:48:' ,  #          Microsoft-Xbox
);

=head1 SUBROUTINES

=over

=cut


sub authenticate {
    my ($portalSession,$cgi, $session, $info,$logger) = @_;
    my ($auth_return,$err) = pf::web::web_user_authenticate($portalSession, $cgi->param("auth"));
    if ($auth_return == 1) {
        $info->{'category'} = $portalSession->getProfile->getGuestCategory;
        $session->param(login => $cgi->param('username'));
    }
    return ( $auth_return, $err );
}

sub generate_login_page {
    my ( $portalSession, $err ) = @_;
    _generate_page($portalSession,$GAMING_LOGIN_TEMPLATE,
        txt_auth_error => ( (defined $err) ? i18n($err) : undef)  ,
        username => encode_entities($portalSession->cgi->param("username")),
        selected_auth => ( encode_entities($portalSession->cgi->param("auth")) || $portalSession->getProfile->getDefaultAuth),
        list_authentications => pf::web::auth::list_enabled_auth_types(),
        oauth2_google => $guest_self_registration{$SELFREG_MODE_GOOGLE},
        oauth2_facebook => $guest_self_registration{$SELFREG_MODE_FACEBOOK},
        oauth2_github => $guest_self_registration{$SELFREG_MODE_GITHUB},
    );
}

sub generate_landing_page {
    my ($portalSession, $msg) = @_;
    _generate_page($portalSession,$GAMING_LANDING_TEMPLATE, status_msg => ( (defined $msg ) ? i18n($msg) : undef));
}

sub generate_registration_page {
    my ($portalSession, $err) = @_;
    _generate_page($portalSession,$GAMING_REGISTRATION_TEMPLATE, txt_auth_error => ( (defined $err) ? i18n($err) : undef));
}

sub _generate_page {
    my ($portalSession, $template,%args) = @_;
    my @keys = keys %args;
    @{$portalSession->stash}{@keys} = @args{@keys};
    render_template($portalSession, $template);
}

sub register_node {
    my ( $portalSession, $pid, $mac, %info ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    my ($result,$msg);
    if(!valid_mac($mac) || !is_gaming_mac($mac)) {
        $msg = "Please verify MAC address provided";
    }
    elsif ( is_max_reg_nodes_reached($mac, $pid, $info{'category'}) ) {
        $msg = "You have reached the maximum number of devices you are able to register with this username.";
    }
    else {
        ($result,$msg) = _sanitize_and_register($portalSession->session, $mac, $pid, %info);
    }
    return ($result,$msg);
}

sub is_gaming_mac {
    my ($mac) = @_;
    foreach my $oui (@GAMING_OUI) {
        return 1 if $mac =~ /^\Q$oui\E/i;
    }
    return 0;
}

sub _sanitize_and_register {
    my ( $session, $mac, $pid, %info ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    my ($result,$msg);
    if(valid_mac($mac)) {
        $logger->info("performing node registration MAC: $mac pid: $pid");
        node_register( $mac, $pid, %info );
        $result = $TRUE;
        $msg = "The MAC address %s has been successfully registered.";
    }
    else {
        $msg = "The MAC address %s provided is invalid please try again";
    }
    $msg = i18n_format($msg,$mac);
    return ($result,$msg);
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
