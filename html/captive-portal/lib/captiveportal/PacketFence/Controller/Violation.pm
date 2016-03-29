package captiveportal::PacketFence::Controller::Violation;
use Moose;
use namespace::autoclean;
use pf::violation;
use pf::class;
use pf::constants::scan qw($SCAN_VID $POST_SCAN_VID $PRE_SCAN_VID);
use pf::log;
use pf::web;
use pf::node;
use pf::file_paths;
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
    my $violation = violation_view_top($mac);
    if ($violation) {

        $c->stash->{'user_agent'} = $c->request->user_agent;
        my $request = $c->req;

        # There is a violation, redirect the user
        # FIXME: there is not enough validation below
        my $vid      = $violation->{'vid'};
    
        if ($vid == $POST_SCAN_VID) {
            $c->response->redirect("/captive-portal");
        }

        # detect if a system scan is in progress, if so redirect to scan in progress page
        if ($vid == $SCAN_VID || $vid == $PRE_SCAN_VID) {
            if($violation->{'ticket_ref'} =~ /^Scan in progress, started at: (.*)$/ ){
                $logger->info("captive portal redirect to the scan in progress page");
                $c->detach( 'Remediation', 'scan_status', [$1] );
            }
            else {
                my $client = pf::client::getClient();
                $client->notify('start_scan', ip => $portalSession->clientIp, mac => $portalSession->clientMac);
                $c->stash(
                    template => "scan.html",
                    txt_message => "system scan in progress",
                    title => "scan: scan in progress",
                );
                $c->detach();
            }
        }
        my $class    = class_view($vid);

        # Retrieve violation template name
        my $subTemplate = $self->getSubTemplate( $c, $class->{'template'} );
        $logger->info("Showing the $subTemplate  remediation page.");
        my $node_info = node_view($mac);
        $c->stash(
            'auto_enable'  => ($class->{'auto_enable'} eq 'Y'),
            'enable_text'  => $class->{button_text},
            'title'        => 'violation: quarantine established',
            'template'     => 'remediation.html',
            'sub_template' => $subTemplate,
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

Get the subtemplate in the right portal profile

=cut

sub getSubTemplate :Private {
    my ( $self, $c, $template ) = @_;
    my $portalSession = $c->portalSession;
    return "violations/$template.html";
#    my $langs         = $portalSession->getRequestLanguages();
    my $langs         = [];
    my $paths         = $portalSession->templateIncludePath();
    my @subTemplates =
      map { "violations/$template" . ( $_ ? ".$_" : "" ) . ".html" } @$langs,
      '';
    return first { -f $_ } map {
        my $path = $_;
        map {"$path/$_"} @subTemplates
    } @$paths;
}


sub release :Local {
    my ($self, $c) = @_;
    my $mac = $c->portalSession->clientMac;
    my $violation = violation_view_top($mac);
    my $vid = $violation->{vid};
    get_logger->info("Will try to close violation $vid for $mac");
    my $grace = violation_close($mac,$vid);
    get_logger->info("Closing of violation $vid for $mac returned $grace");

    if ($grace != -1) {
        my $count = violation_count($mac);

        my $class = class_view($vid);
        $c->session->{destination_url} = $class->{'redirect_url'} if defined($class->{'redirect_url'});

        get_logger->info("$mac enabled for $grace minutes");
        if ($count == 0) {
            # we reevaluate the access so the user is release from isolation if needed
            pf::enforcement::reevaluate_access( $mac, "manage_vclose" );
        }
        
        $c->response->redirect("/captive-portal");
    } else {
        get_logger->info("$mac reached maximum violations");
        $self->showError($c, "error: max re-enables reached");
    }

}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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

__PACKAGE__->meta->make_immutable;

1;
