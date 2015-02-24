package pfappserver::PacketFence::Controller::Config::UserAgents;

=head1 NAME

pfappserver::PacketFence::Controller::Config::UserAgents - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=cut

use strict;
use warnings;

use HTTP::Status qw(:constants is_error is_success);
use Moose;
use namespace::autoclean;
use URI::Escape::XS;

use pf::config;

BEGIN { extends 'pfappserver::Base::Controller'; }

=head2 index

=cut

sub index :Path {
    my ( $self, $c ) = @_;
    $c->go('simple_search');
}

=head2 simple_search

=cut

sub simple_search :Local :Args() :SimpleSearch('UserAgent') :AdminRole('USERAGENTS_READ') {}

=head2 upload

=cut

sub upload :Local :Args(0) :AdminRole('USERAGENTS_READ') {
    my ( $self, $c ) = @_;
    $c->stash->{current_view} = 'JSON';

    require PHP::Serialization;
    require pf::pfcmd::report;
    import pf::pfcmd::report qw(report_unknownuseragents_all);

    my $status = HTTP_OK;
    my @fields = qw(browser os computername dhcp_fingerprint description);
    my %data   = map {
        my %ua;
        @ua{@fields} = @{$_}{@fields};
        $_->{user_agent} => \%ua
    } report_unknownuseragents_all();
    if (%data) {
        require IO::Compress::Gzip;
        import IO::Compress::Gzip qw(gzip $GzipError);
        require MIME::Base64;
        import MIME::Base64 qw(encode_base64);
        my $content = PHP::Serialization::serialize(\%data);
        my $gziped;
        if (gzip(\$content, \$gziped)) {
            my $release = $c->model('Admin')->pf_release();
            require LWP::UserAgent;
            my $browser  = LWP::UserAgent->new;
            my $response = $browser->post(
              'http://www.packetfence.org/useragentsv2.php',
              {
                useragent_fingerprints => encode_base64($gziped),
                'ref' => $c->uri_for($c->action),
                email => $Config{'alerting'}{'emailaddr'},
                pf_release => $release
              }
            );
            if ($response->content =~ /Thank you for submitting the following fingerprints/) {
                $c->stash->{status_msg} = "Thank you for submitting your fingerprints";
            }
            else {
                $c->stash->{status_msg} = "Error uploading user-agent fingerprints";
                $c->log->debug($response->content);
                $status = HTTP_INTERNAL_SERVER_ERROR;
            }
        }
        else {
            $c->stash->{status_msg} = "Error while compressing the data";
            $c->log->error("Error while compressing the data: ".$IO::Compress::Gzip::GzipError);
            $status = HTTP_INTERNAL_SERVER_ERROR;
        }
    }
    else {
        $c->stash->{status_msg} = "No unknown fingerprint found";
        $status = HTTP_NOT_FOUND;
    }
    $c->response->status($status);
}

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

__PACKAGE__->meta->make_immutable;

1;
