package captiveportal::PacketFence::Controller::SecurityEvent;
use Moose;
use namespace::autoclean;
use pf::security_event;
use pf::class;
use pf::config qw(%Config);
use pf::constants::scan qw($SCAN_SECURITY_EVENT_ID $POST_SCAN_SECURITY_EVENT_ID $PRE_SCAN_SECURITY_EVENT_ID);
use pf::log;
use pf::web;
use pf::node;
use pf::util;

BEGIN { extends 'captiveportal::Base::Controller'; }

=head1 NAME

captiveportal::PacketFence::Controller::Enabler - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

=cut

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;
    my $portalSession = $c->portalSession;
    my $mac           = $portalSession->clientMac;
    my $logger        = $c->log;
    my $security_event = security_event_view_top($mac);
    if ($security_event) {

        $c->stash->{'user_agent'} = $c->request->user_agent;
        my $request = $c->req;

        # There is a security_event, redirect the user
        # FIXME: there is not enough validation below
        my $security_event_id      = $security_event->{'security_event_id'};

        if ($security_event_id == $POST_SCAN_SECURITY_EVENT_ID) {
            $c->response->redirect("/captive-portal");
        }

        # detect if a system scan is in progress, if so redirect to scan in progress page
        if ($security_event_id == $SCAN_SECURITY_EVENT_ID || $security_event_id == $PRE_SCAN_SECURITY_EVENT_ID) {
            if($security_event->{'ticket_ref'} =~ /^Scan in progress, started at: (.*)$/ ){
                $logger->info("captive portal redirect to the scan in progress page");
                $c->detach( 'Remediation', 'scan_status', [$1] );
            }
            else {
                my $client = pf::client::getClient();
                $client->notify('start_scan', ip => $portalSession->clientIP->normalizedIP, mac => $portalSession->clientMac);
                $c->stash(
                    template => "scan.html",
                    txt_message => "system scan in progress",
                    title => "scan: scan in progress",
                    timer => $Config{'captive_portal'}{'network_redirect_delay'},
                );
                $c->detach();
            }
        }
        my $class    = class_view($security_event_id);

        # Retrieve security_event template name
        my $subTemplate = $self->getSubTemplate( $c, $class->{'template'} );
        $logger->info("Showing the $subTemplate  remediation page.");
        my $node_info = node_view($mac);
        $c->stash(
            'auto_enable'  => ($class->{'auto_enable'} eq 'Y'),
            'enable_text'  => $class->{button_text},
            'title'        => 'security_event: quarantine established',
            'template'     => 'remediation.html',
            'sub_template' => $subTemplate,
            'redirect_url' => $class->{'redirect_url'},
            map { $_ => $node_info->{$_} }
              qw(dhcp_fingerprint last_switch last_port
              last_vlan last_connection_type last_ssid username)
        );
        $c->detach;
    }
    else {
        $c->response->redirect("/access");
    }
}

=head2 getSubTemplate

Get the subtemplate in the right connection profile

=cut

sub getSubTemplate : Private {
    my ($self, $c, $template) = @_;
    my $portalSession = $c->portalSession;
    my $langs = $c->forward(Root => 'getRequestLanguages');
    return $c->profile->findSecurityEventTemplate($template, $langs);
}


sub release :Local {
    my ($self, $c) = @_;
    my $mac = $c->portalSession->clientMac;
    my $security_event = security_event_view_top($mac);
    my $security_event_id = $security_event->{security_event_id};
    get_logger->info("Will try to close security_event $security_event_id for $mac");
    my $grace = security_event_close($mac,$security_event_id);
    get_logger->info("Closing of security_event $security_event_id for $mac returned $grace");

    if ($grace != -1) {
        my $count = security_event_count($mac);

        my $class = class_view($security_event_id);
        $c->session->{destination_url} = $class->{'redirect_url'} if defined($class->{'redirect_url'});

        get_logger->info("$mac enabled for $grace minutes");
        if ($count == 0) {
            # we reevaluate the access so the user is release from isolation if needed
            pf::enforcement::reevaluate_access( $mac, "manage_vclose" );
        }

        $c->response->redirect("/captive-portal");
    } else {
        get_logger->info("$mac reached maximum security_events");
        $self->showError($c, "error: max re-enables reached");
    }

}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

1;
