package captive::portal::Controller::Remediation;
use Moose;
use namespace::autoclean;
use pf::web;
use pf::violation;
use pf::class;
use pf::node;
use List::Util qw(first);

BEGIN { extends 'captive::portal::Base::Controller'; }

=head1 NAME

captive::portal::Controller::Remediation - Catalyst Controller

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

    $c->stash->{'user_agent'} = $c->request->user_agent;
    my $request = $c->req;

    # check for open violations
    my $violation = $self->getViolation($c);

    if ($violation) {

        # There is a violation, redirect the user
        # FIXME: there is not enough validation below
        my $vid      = $violation->{'vid'};
        my $class = class_view($vid);

        # Retrieve violation template name
        my $template = $class->{'template'};
        my $subTemplate = "violations/$template.html";
        $logger->info("Showing the $subTemplate  remediation page.");
        my $node_info = node_view($mac);
        $c->stash(
            'template'     => 'remediation.html',
            'sub_template' => $subTemplate,
            map { $_ => $node_info->{$_} }
              qw(dhcp_fingerprint last_switch last_port
              last_vlan last_connection_type last_ssid username)
        );
    } else {
        $logger->info( "No open violation for " . $mac );

        # TODO - rework to not show "Your computer was not found in the PacketFence database. Please reboot to solve this issue."
        $self->showError( $c, "error: not found in the database" );
    }
}


sub scan_status : Private {
    my ( $self, $c, $scan_start_time ) = @_;
    my $portalSession = $c->portalSession;

    my $refresh_timer = 10;    # page will refresh each 10 seconds

    $c->stash(
        template    => 'scan-in-progress.html',
        txt_message => i18n_format(
            'scan in progress contact support if too long',
            $scan_start_time
        ),
        txt_auto_refresh =>
          i18n_format( 'automatically refresh', $refresh_timer ),
        refresh_timer => $refresh_timer,
    );
}

sub getViolation {
    my ( $self, $c ) = @_;
    my $violation     = $c->stash->{violation};
    unless($violation) {
        my $mac           = $c->portalSession->clientMac;
        $c->stash->{violation} = $violation = violation_view_top($mac);
    }
    return $violation;
}

=head1 AUTHOR

root

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
