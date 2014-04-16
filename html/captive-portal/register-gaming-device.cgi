#!/usr/bin/perl

=head1 NAME

register-gaming-device.cgi

=head1 SYNOPSYS

Handles captive-portal gaming registration

=cut

use strict;
use warnings;

use lib '/usr/local/pf/lib';

use Log::Log4perl;

use pf::authentication;
use pf::Authentication::constants;
use pf::config;
use pf::Portal::Session;
use pf::util;
use pf::web;
use pf::web::gaming;
use pf::nodecategory qw(nodecategory_exist);

Log::Log4perl->init("$conf_dir/log.conf");
my $logger = Log::Log4perl->get_logger('register-gaming-device.cgi');
Log::Log4perl::MDC->put('proc', 'register-gaming-device.cgi');
Log::Log4perl::MDC->put('tid', 0);

my %params;
my $portalSession   = new pf::Portal::Session();
my $cgi             = $portalSession->cgi;
my $session         = $portalSession->session;

# This module is not enabled so return an error accordingly
if ( isdisabled($Config{'registration'}{'device_registration'}) ) {
    pf::web::generate_error_page($portalSession, i18n("This module is not enabled"));
    exit(0);
}

# Pull parameters from query string
foreach my $param  (grep {$_} $cgi->url_param()) {
    $params{$param} = $cgi->url_param($param);
}
foreach my $param($cgi->param()) {
    $params{$param} = $cgi->param($param);
}

#Using session param login to determine if user is logged in
my $pid = $session->param("login");

if(!$pid) { #User has not logged in yet
    user_not_logged_in($portalSession,$session,\%params);
} else { #User is Logged
    user_is_logged_in($portalSession,$session,\%params,$pid);
}

exit(0);


=item user_not_logged_in
When user is not logged in
=cut

sub user_not_logged_in {
    my ($portalSession,$session,$params) = @_;
    my $authenticated;
    my $msg;
    if(( $params->{'username'}  && $params->{'password'} )) {
      ($authenticated, $msg) = pf::web::web_user_authenticate($portalSession, $params->{"auth"});
    }
    if ($authenticated == $TRUE) {
        $session->param(login => $params->{'username'});
        pf::web::gaming::generate_registration_page($portalSession);
    } else {
        pf::web::gaming::generate_login_page($portalSession,$msg);
    }
}

=item user_is_logged_in
When user is logged in
=cut

sub user_is_logged_in {
    my ($portalSession,$session,$params,$pid) = @_;
    if(exists $params->{cancel} )  {
        user_cancel($portalSession,$session);
    } else {
        register_device($portalSession,$session,$params,$pid);
    }
}

=item register_device
 Registration of device
=cut

sub register_device {
    my ($portalSession,$session,$params,$pid) = @_;
    my (%info,$result);
    my $logger = Log::Log4perl->get_logger('register-gaming-device.cgi');
    $info{'pid'} = $pid;
    my $device_mac = clean_mac($params->{'device_mac'});
    if(pf::web::gaming::is_allowed_gaming_mac($device_mac)) {
        $portalSession->stash->{device_mac} = $device_mac;
        my $role = $Config{'registration'}{'device_registration_role'};
        if ($role) {
            $logger->trace("Gaming devices role is $role (from pf.conf)");
        } else {
            # Use role of user
            $role = &pf::authentication::match(&pf::authentication::getInternalAuthenticationSources(), {username => $pid}, $Actions::SET_ROLE);
            $logger->trace("Gaming devices role is $role (from username $pid)") if ($role);
        }
    # register gaming device
        $info{'category'} = $role if (defined $role);
        $info{'notes'} = $params->{'console_type'};
        $info{'mac'} = $device_mac;
        $info{'auto_registered'} = 1;
        $result = pf::web::web_node_register($portalSession, $pid, %info);
    }
    if($result) {
        $session->delete();
        my $msg = i18n_format("The MAC address %s has been successfully registered.",$device_mac);
        pf::web::gaming::generate_landing_page($portalSession,$msg);
    } else {
        my $msg = i18n_format("The MAC address %s provided is invalid please try again",$device_mac);
        pf::web::gaming::generate_registration_page($portalSession,$msg);
    }
}

=item user_cancel
Action done when the user cancels
=cut

sub user_cancel {
    my ($portalSession,$session) = @_;
    $session->delete();
    pf::web::gaming::generate_login_page($portalSession, 'Registration canceled please try again');
}

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
