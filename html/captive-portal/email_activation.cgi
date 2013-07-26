#!/usr/bin/perl

=head1 NAME

email_activation.cgi - handles email activation links

=cut

use strict;
use warnings;

use lib "/usr/local/pf/lib";

use Log::Log4perl;
use POSIX;

use pf::config;
use pf::email_activation qw($GUEST_ACTIVATION $SPONSOR_ACTIVATION);
use pf::node;
use pf::Portal::Session;
use pf::util qw(valid_mac);
use pf::web;
use pf::web::guest 1.30;
# called last to allow redefinitions
use pf::web::custom;

use pf::authentication;
use pf::Authentication::constants;

Log::Log4perl->init("$conf_dir/log.conf");
my $logger = Log::Log4perl->get_logger('email_activation.cgi');
Log::Log4perl::MDC->put('proc', 'email_activation.cgi');
Log::Log4perl::MDC->put('tid', 0);

my $portalSession = pf::Portal::Session->new();
my $cgi = $portalSession->getCgi();
my $node_mac = undef;
my $email_type = pf::Authentication::Source::EmailSource->meta->get_attribute('type')->default;
my $source_id = $portalSession->getProfile->getSourceByType($email_type);

if ($source_id && defined($cgi->url_param('code'))) {

    # validate code
    my $activation_record = pf::email_activation::validate_code($cgi->url_param('code'));
    if (!defined($activation_record) || ref($activation_record) ne 'HASH' || !defined($activation_record->{'type'})) {

        pf::web::generate_error_page($portalSession, i18n("The activation code provided is invalid. "
            . "Reasons could be: it never existed, it was already used or has expired.")
        );
        exit(0);
    }

    # if we have a MAC, guest was on-site and we set that MAC in the session
    if ( defined($activation_record->{'mac'}) ) {
        $portalSession->setGuestNodeMac($activation_record->{'mac'});
        $node_mac = $portalSession->getGuestNodeMac();
    }

    my $pid = $activation_record->{'pid'};
    my $email = $activation_record->{'email'}; # either the user's email or the sponsor's email
    my $auth_params =
      {
       'username' => $pid,
       'user_email' => $email
      };

    #
    # Email activated guests only need to prove their email was valid by clicking on the link.
    #
    if ($activation_record->{'type'} eq $GUEST_ACTIVATION) {

        # if we have a MAC, guest was on-site and we need to proceed with registration
        if ( defined($node_mac) && valid_mac($node_mac) ) {

            # Setting access timeout and role (category) dynamically
            my $expiration = &pf::authentication::match($source_id, $auth_params, $Actions::SET_ACCESS_DURATION);

            if (defined $expiration) {
                $expiration = POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime(time + normalize_time($expiration)));
            }
            else {
                $expiration = &pf::authentication::match($source_id, $auth_params, $Actions::SET_UNREG_DATE);
            }

            my $category = &pf::authentication::match($source_id, $auth_params, $Actions::SET_ROLE);

            $logger->debug("Determined unregdate $expiration and category $category for email $email");

            # change the unregdate of the node associated with the submitted code
            # FIXME
            node_modify($node_mac, (
                'unregdate' => $expiration,
                'status' => 'reg',
                'category' => $category,
            ));

            # send to a success page
            pf::web::generate_generic_page(
                $portalSession, $pf::web::guest::EMAIL_CONFIRMED_TEMPLATE, { 'expiration' => $expiration }
            );
        }
        # if we don't have the MAC it means it's a preregistered guest
        # generate a password and send an email with an access code
        else {

            my %info =
              (
               'pid' => $pid,
               'email' => $email,
               'subject' => i18n("%s: Guest access confirmed!", $Config{'general'}{'domain'}),
               'currentdate' => POSIX::strftime( "%m/%d/%y %H:%M:%S", localtime )
              );

            # we create a temporary password using the actions from the email authentication source;
            my $actions = &pf::authentication::match($source_id, $auth_params);
            $info{'password'} = pf::temporary_password::generate($pid, undef, $actions);

            # send on-site guest credentials by email
            pf::web::guest::send_template_email(
                $pf::web::guest::TEMPLATE_EMAIL_EMAIL_PREREGISTRATION_CONFIRMED, $info{'subject'}, \%info
            );

            # send to a success page
            pf::web::generate_generic_page($portalSession, $pf::web::guest::EMAIL_PREREG_CONFIRMED_TEMPLATE, \%info);
        }

        # code has been consumed, deactivate
        pf::email_activation::set_status_verified($cgi->url_param('code'));
    }

    #
    # Sponsor activated guests. We need the sponsor to authenticate before allowing access
    #
    elsif ($activation_record->{'type'} eq $SPONSOR_ACTIVATION) {

        # if we have a username in session it means user has already authenticated
        # so we go ahead and allow the guest in
        if (!defined($portalSession->getSession->param("username"))) {

            # User is not logged and didn't provide username or password: show login form
            if (!($cgi->param("username") && $cgi->param("password"))) {
                $logger->info(
                    'Sponsor needs to authenticate in order to activate guest. '
                    . 'Guest token: ' . $cgi->url_param('code')
                );
                pf::web::guest::generate_custom_login_page($portalSession, undef, $pf::web::guest::SPONSOR_LOGIN_TEMPLATE);
                exit(0);
            }

            # User provided username and password: authenticate
            my ($auth_return, $error) = pf::web::web_user_authenticate($portalSession);

            if ($auth_return != $TRUE) {
                $logger->info("authentication failed for user ".$cgi->param("username"));
                pf::web::guest::generate_custom_login_page($portalSession, $error, $pf::web::guest::SPONSOR_LOGIN_TEMPLATE);
                exit(0);
            }

        }

        # handling log out (not exposed to the UI at this point)
        # TODO: if we ever expose it, we'll need to alter the form action to make sure to trim it
        # otherwise we'll submit our authentication but with ?action=logout so it'll delete the session right away
        if (defined($cgi->url_param("action")) && $cgi->url_param("action") eq "logout") {
            $portalSession->getSession->delete();

            pf::web::guest::generate_custom_login_page($portalSession, undef, $pf::web::guest::SPONSOR_LOGIN_TEMPLATE);
            exit(0);
        }

        # User is authenticated (session username exists OR auth_return == $TRUE above)
        $logger->debug($portalSession->getSession->param('username') . " successfully authenticated. Activating sponsored guest");

        my (%info, $template);

        if ( defined($node_mac) ) {
            # If MAC is defined, it's a guest already here that we need to register

            my $node_info = node_attributes($node_mac);
            $pid = $node_info->{'pid'};
            if (!defined($node_info) || ref($node_info) ne 'HASH') {

                $logger->warn("Problem finding more information about a MAC address ($node_mac) to enable guest access");
                pf::web::generate_error_page(
                    $portalSession,
                    i18n("There was a problem trying to find the computer to register. The problem has been logged.")
                );
                exit(0);
            }

            if ($node_info->{'status'} eq $pf::node::STATUS_REGISTERED) {

                $logger->warn("node mac: $node_mac has already been registered.");
                pf::web::generate_error_page($portalSession,
                    i18n_format("The device with MAC address %s has already been authorized to your network.", $node_mac),
                );
                exit(0);
            }

            # register the node
            %info = %{$node_info};
            pf::web::web_node_register($portalSession, $pid, %info);

            # populating variables used to send email
            $template = $pf::web::guest::TEMPLATE_EMAIL_GUEST_ON_REGISTRATION;
            $info{'subject'} = i18n_format("%s: Guest network access enabled", $Config{'general'}{'domain'});
        }

        elsif (defined($activation_record->{'pid'})) {
            # If pid is set in activation record then we are activating a guest who pre-registered

            $pid = $activation_record->{'pid'};

            # populating variables used to send email
            $template = $pf::web::guest::TEMPLATE_EMAIL_SPONSOR_PREREGISTRATION;
            $info{'subject'} = i18n_format("%s: Guest access request accepted", $Config{'general'}{'domain'});
        }

        # TO:
        $info{'email'} = $pid;
        # username
        $info{'pid'} = $pid;
        $info{'cc'} = $Config{'guests_self_registration'}{'sponsorship_cc'};

        # we create a temporary password using the actions from the email authentication source;
        # NOTE: When sponsoring a network access, the new user will be created (in the temporary_password table) using
        # the actions of the email authentication source of the portal profile on which the *sponsor* has landed.
        my $actions = &pf::authentication::match($source_id, { username => $pid, user_email => $pid });
        $info{'password'} = pf::temporary_password::generate($pid, undef, $actions);

        # prepare welcome email for a guest who registered locally
        $info{'currentdate'} = POSIX::strftime( "%m/%d/%y %H:%M:%S", localtime );

        pf::web::guest::send_template_email($template, $info{'subject'}, \%info);

        pf::email_activation::set_status_verified($cgi->url_param('code'));

        # send to a success page
        pf::web::generate_generic_page(
            $portalSession, $pf::web::guest::SPONSOR_CONFIRMED_TEMPLATE
        );
        exit(0);
    }

} else {

    $logger->info("User has nothing to do here, redirecting to ".$Config{'trapping'}{'redirecturl'});
    print $cgi->redirect($Config{'trapping'}{'redirecturl'});

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
