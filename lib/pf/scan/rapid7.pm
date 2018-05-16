package pf::scan::rapid7;

=head1 NAME

pf::scan::rapid7

=cut

=head1 DESCRIPTION

pf::scan::rapid7 is a module to add rapid7 scanning option.

=cut

use strict;
use warnings;

use pf::log;
use Readonly;

use base ('pf::scan');

use pf::config;
use pf::scan;
use pf::util;
use pf::node;
use pf::violation qw(violation_close);
use LWP::UserAgent;
use pf::api::jsonrpcclient;
use JSON::MaybeXS;

sub description { 'rapid7 Scanner' }

=head1 SUBROUTINES

=over   

=item new

Create a new rapid7 scanning object with the required attributes

=cut

sub new {
    my ( $class, %data ) = @_;
    my $logger = get_logger();

    $logger->debug("Instantiating a new pf::scan::rapid7 scanning object");

    my $self = bless {
            '_id'       => undef,
            '_username' => undef,
            '_password' => undef,
            '_type'     => undef,
            '_domain'   => undef,
            '_oses'     => undef,
            '_categories' => undef,
            '_template_id' => undef,
            '_engineId' => undef,
            '_site_id' => undef,
            '_host' => undef,
            '_port' => undef,
            '_verify_hostname' => undef,
    }, $class;

    foreach my $value ( keys %data ) {
        $self->{'_' . $value} = $data{$value};
    }

    return $self;
}

sub buildApiUri {
    my ($self, $path) = @_;
    return "https://".$self->{_host}.":".$self->{_port}."/api/3/".$path;
}

=item startScan

=cut

sub startScan {
    my ( $self ) = @_;
    my $logger = get_logger();

    my $payload = {
        engineId => $self->{_engineId} . "",
        hosts => [ $self->{_scanIp} ],
        name => "Automatic scan started from PacketFence",
        templateId => $self->{_template_id},
    };

    my $ua = LWP::UserAgent->new;
    if(isdisabled($self->{_verify_hostname})) {
        $ua->ssl_opts(verify_hostname => 0, SSL_verify_mode => 0x00);
    }

    my $req = HTTP::Request->new(
        POST => $self->buildApiUri("sites/".$self->{_site_id}."/scans"), 
        ["Content-Type" => "application/json"],
        encode_json($payload),
    );
    use Data::Dumper ; print Dumper($req);
    $req->authorization_basic($self->{_username}, $self->{_password});
    my $response = $ua->request($req);

    my $result = $response->is_success;
 
    my $scan_vid = $pf::constants::scan::POST_SCAN_VID;
    $scan_vid = $pf::constants::scan::SCAN_VID if ($self->{'_registration'});
    $scan_vid = $pf::constants::scan::PRE_SCAN_VID if ($self->{'_pre_registration'});

    if (!$result) {
        $logger->warn("Rapid7 scan didnt start: ".$response->status_line);
        return $scan_vid;
    }
    else {
        $logger->info("Started rapid7 scan for ".$self->{_scanMac});
    }

    my $apiclient = pf::api::jsonrpcclient->new;
    my %data = (
       'vid' => $scan_vid,
       'mac' => $self->{'_scanMac'},
    );
    $apiclient->notify('close_violation', %data );

    $self->setStatus($pf::constants::scan::STATUS_CLOSED);
    $self->statusReportSyncToDb();
    return 0;
}

=back

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

1;
