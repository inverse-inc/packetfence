package pf::provisioner::ibm;
=head1 NAME

pf::provisioner::ibm add documentation

=cut

=head1 DESCRIPTION

pf::provisioner::ibm

=cut

use strict;
use warnings;
use pf::log;
use URI::Escape::XS;
use Moo;
use pf::constants qw($TRUE $FALSE);
use List::MoreUtils qw(any);
use pf::util qw(valid_mac clean_mac);
use Sub::Name;
    # SOAP global error handler (mostly transport or server errors)
    # here we only log, the or on soap method calls will take care of returning
my $logger = get_logger();
use SOAP::Lite
    on_fault => subname on_fault => sub {
        my($soap, $res) = @_;
        my $errmsg;
        if (ref $res && defined($res->faultstring)) {
            $errmsg = $res->faultstring;
        } else {
            $errmsg = $soap->transport->status;
        }
        $logger->error("Error in SOAP communication with server: $errmsg");
    };

=head1 Attributes

=head2 username

username of for soap call

=cut

has username => (is => 'rw');

=head2 password

password of for soap call

=cut

has password => (is => 'rw');

=head2 host

host of the soap server

=cut

has host => (is => 'rw');

=head2 port

port of soap server

=cut

has port => (is => 'rw');

=head2 protocal

Protocol for the webservice http | https

=cut

has protocol => (is => 'rw', default => sub { "http" } );

=head2 api_uri

location of the wsdl file

=cut

has api_uri => (is => 'rw');

=head2 soap

the soap client to be used

=cut

has soap => (is => 'rw', lazy =>1, builder=>1);

=head2 proxy

the uri for the soap client to connect to

=cut

has proxy => (is => 'rw', lazy =>1, builder=>1);

=head2 relevanceExpr

The relevanceExpr used to find the mac addresses

=cut

has relevanceExpr => (is => 'rw');

=head2 agent_download_uri

The URI to download the agent

=cut

has agent_download_uri => (is => 'rw');

sub _build_proxy {
    my ($self) = @_;
    return $self->protocol . '://' . $self->host . ":" . $self->port;
}

sub _build_soap {
    my ($self) = @_;
    return SOAP::Lite->new(uri => $self->api_uri, proxy => $self->proxy );
}

sub authorize {
    my ($self, $mac) = @_;
    my $logger = get_logger();
    $mac = clean_mac($mac);

    #Grab the List of registered devices, and check if our MAC is in there
#    my $expr = SOAP::Data->name('relevanceExpr' => 'values of results whose (not exists values whose (it contains "n/a") of it) of BES Property "Mobile Mac" ');
    my $username = SOAP::Data->name('username' => $self->username);
    my $password = SOAP::Data->name('password' => $self->password);
    my $expr = SOAP::Data->name('relevanceExpr' => $self->relevanceExpr);
    my $som = $self->soap->GetRelevanceResult($expr,$username,$password);
    if($som) {
        # did SOAP server returned a fault in the request?
        if ($som->fault) {
            return $FALSE;
        }

        # grabbing the result
        my @results = $som->valueof( "//GetRelevanceResultResponse/a" );
        return $TRUE if any { valid_mac($_) && clean_mac($_) eq $mac } @results ;
    }
    return $FALSE;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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
