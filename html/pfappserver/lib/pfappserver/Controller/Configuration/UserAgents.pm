package pfappserver::Controller::Configuration::UserAgents;

=head1 NAME

pfappserver::Controller::Configuration::UserAgents - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=cut

use strict;
use warnings;

use HTTP::Status qw(:constants is_error is_success);
use Moose;
use namespace::autoclean;
use URI::Escape;

BEGIN { extends 'pfappserver::Base::Controller'; }

=head2 index

=cut

sub index :Path :Args(0) {
    my ($self, $c) = @_;
    $c->stash(template => 'configuration/useragents/simple_search.tt') ;
    $c->forward('simple_search');
}

=head2 simplesearch

=cut

sub simple_search :SimpleSearch('UserAgent') :Local :Args() { }

=head2 upload

=cut

sub upload :Local :Args(0) {
    my ( $self, $c ) = @_;
    $c->stash->{current_view} = 'JSON';
    require PHP::Serialization;
    require pf::pfcmd::report;
    import pf::pfcmd::report qw(report_unknownuseragents_all);
    my @fields = qw(browser os computername dhcp_fingerprint description);
    my %data   = map {
        my %ua;
        @ua{@fields} = @{$_}{@fields};
        $_->{user_agent} => \%ua
    } report_unknownuseragents_all();
    if (%data) {
        require IO::Compress::Gzip;
        import IO::Compress::Gzip qw(gzip);
        require MIME::Base64;
        import MIME::Base64 qw(encode_base64);
        my $content =
            encode_base64(
            gzip( PHP::Serialization::serialize( \%data ) ) );
        require LWP::UserAgent;
        my $browser  = LWP::UserAgent->new;
        my $response = $browser->post(
            'http://www.packetfence.org/useragents.php',
            {
                useragent_fingerprints => $content,
                'ref' => $c->uri_for($c->action)
            }
        );
    }
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
