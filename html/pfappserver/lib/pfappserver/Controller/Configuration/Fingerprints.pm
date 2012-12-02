package pfappserver::Controller::Configuration::Fingerprints;

=head1 NAME

pfappserver::Controller::Configuration::Fingerprints - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=cut

use strict;
use warnings;

use Date::Parse;
use HTTP::Status qw(:constants is_error is_success);
use Moose;
use namespace::autoclean;
use POSIX;
use URI::Escape;

use pf::authentication;
use pf::os;
use pf::util qw(load_oui download_oui);
# imported only for the $TIME_MODIFIER_RE regex. Ideally shouldn't be 
# imported but it's better than duplicating regex all over the place.
use pf::config;
use Data::Dumper;
use pfappserver::Form::Config::Pf;

BEGIN {extends 'pfappserver::Base::Controller::Base'; }

=head2 update

=cut
sub update : Local : Args(0) {
    my ( $self, $c ) = @_;
    $c->stash->{current_view} = 'JSON';
    my ( $status, $version_msg, $total ) =
        update_dhcp_fingerprints_conf();
    $c->stash->{status_message} =
        "DHCP fingerprints updated via $dhcp_fingerprints_url to $version_msg\n"
        . "$total DHCP fingerprints reloaded\n";
}

=head2 upload

=cut

my %FIELD_MAP = (
    dhcp_fingerprint => 'fprint[]',
    vendor => 'desc[]',
    computername => 'compname[]',
    user_agent => 'useragent[]'
);

sub upload : Local : Args(0) {
    my ( $self, $c ) = @_;
    $c->stash->{current_view} = 'JSON';
    require pf::pfcmd::report;
    import pf::pfcmd::report qw(report_unknownprints_all);
    my @field_name = qw(dhcp_fingerprint vendor computername user_agent);
    my $content = join(
        "&",
        (   map {
                    my $obj = $_;
                    map {
                        $FIELD_MAP{$_} . "=" . uri_escape( $obj->{$_}  )
                        }
                        qw(dhcp_fingerprint vendor computername user_agent)
                } report_unknownprints_all()
        )
    );
    if ($content) {
        $content  .= '&ref='. uri_escape($c->uri_for($c->action->name)) .
                     '&submit=Submit%20Fingerprints';
        require LWP::UserAgent;
        my $browser  = LWP::UserAgent->new;
        my $response = $browser->post(
            'http://www.packetfence.org/fingerprintsv2.php',
            Content => $content 
        );
        if($response->content =~ /Thank you for submitting the following fingerprints/) {
            $c->stash->{status_message} = "Thank you for submitting your fingerprints";
        }
        else {
            $c->stash->{status_message} = "No unknown fingerprints found";
        }
    }
    else {
        $c->stash->{status_message} = "No unknown fingerprints found";
    }
}

=head2 index

=cut

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;
    my $action = $c->request->params->{'action'} || "";
    if ( $action eq 'update' ) {
        my ( $status, $version_msg, $total ) =
            update_dhcp_fingerprints_conf();
        $c->stash->{status_message} =
            "DHCP fingerprints updated via $dhcp_fingerprints_url to $version_msg\n"
            . "$total DHCP fingerprints reloaded\n";
    }
    elsif ( $action eq 'upload' ) {
        require pf::pfcmd::report;
        import pf::pfcmd::report qw(report_unknownprints_all);
        my $content = join(
            "\n",
            (   map {
                    join(
                        ":",
                        @{$_}{
                            qw(dhcp_fingerprint vendor computername user_agent)
                            }
                        )
                    } report_unknownprints_all()
            ),
            ""
        );
        if ($content) {
            require LWP::UserAgent;
            my $browser  = LWP::UserAgent->new;
            my $response = $browser->post(
                'http://www.packetfence.org/fingerprintsv2.php?ref='
                    . uri_escape($c->uri_for($c->action->name)),
                { fingerprints => $content }
            );
        }
    }
    $self->_list_items( $c, 'OS' );
}

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

__PACKAGE__->meta->make_immutable;

1;
