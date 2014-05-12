package pf::provisioner::symantec;
=head1 NAME

pf::provisioner::symantec add documentation

=cut

=head1 DESCRIPTION

pf::provisioner::symantec

=cut

use strict;
use warnings;
use pf::log;
use LWP::UserAgent;
use HTTP::Request;
use Moo;
use pf::config qw($TRUE $FALSE);
use List::MoreUtils qw(any);
use pf::util qw(clean_mac);
    # SOAP global error handler (mostly transport or server errors)
    # here we only log, the or on soap method calls will take care of returning

=head1 Atrributes

=head2 id

The id of the MDM

=cut

has id => (is => 'rw');

=head2 username

Username for MDM

=cut

has username => (is => 'rw');

=head2 password

Password for MDM

=cut

has password => (is => 'rw');

=head2 host

host of the symantec

=cut

has host => (is => 'rw');

=head2 port

Username for MDM

=cut

has port => (is => 'rw', default => sub { 443 });

=head2 username

Username for MDM

=cut

has proxy => (is => 'rw', lazy =>1, builder=>1);

=head2 protocol

Username for MDM

=cut

has protocol => (is => 'rw', default => sub { "https" } );

=head2 ua

The User Agent

=cut

has ua => (is => 'rw', lazy => 1, builder => 1);

sub _build_ua {
    LWP::UserAgent->new;
}

sub _build_proxy {
    my ($self) = @_;
    return $self->protocol . '://' . $self->host . ":" . $self->port;
}

sub authorize {
    my ($self, $mac) = @_;
    $mac = clean_mac($mac);
    my $request  = $self->makeRequest($mac);
    my $response = $self->ua->request($request);
    if($response->is_success) {
        return $self->is_valid($response->decoded_content);
    }
    return 0;
}

sub makeRequest {
    my ($self,$mac) = @_;
    my $path = "/appstore/ciscoise/devices/0/macaddress/$mac/all";
    my $url  = $self->proxy . $path;
    print "$url\n";
    my $request = HTTP::Request->new(GET => $url);
    $request->authorization_basic($self->username,$self->password);
    return $request;
}

sub is_valid {

}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and::or
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
