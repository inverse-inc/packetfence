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
use pf::security_event qw(security_event_close);
use LWP::UserAgent;
use HTTP::Request;
use pf::api::jsonrpcclient;
use JSON::MaybeXS;
use List::MoreUtils qw(last_value);

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
            '_engine_id' => undef,
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

=head2 buildApiUri

Given a path, build the URI that points to the Rapid7 API

=cut

sub buildApiUri {
    my ($self, $path) = @_;
    return "https://".$self->{_host}.":".$self->{_port}."/api/3/".$path;
}

=head2 buildUA

Build the LWP::UserAgent object to connect to the Rapid7 API

=cut

sub buildUA {
    my ($self) = @_;
    my $ua = LWP::UserAgent->new;
    if(isdisabled($self->{_verify_hostname})) {
        $ua->ssl_opts(verify_hostname => 0, SSL_verify_mode => 0x00);
    }
    $ua->timeout(10);
    return $ua;
}

=head2 wrapRequest

Add common parameters that should be in all API requests sent to Rapid7

=cut

sub wrapRequest {
    my ($self, $req) = @_;
    $req->authorization_basic($self->{_username}, $self->{_password});
    return $req;
}

=head2 doRequest

Execute a request bound for the Rapid7 API

=cut

sub doRequest {
    my ($self, $req) = @_;
    my $logger = get_logger();

    $self->wrapRequest($req);
    my $ua = $self->buildUA();
    my $response = $ua->request($req);
    
    if (!$response->is_success) {
        $logger->warn("Rapid7 API request on ".$req->uri." failed: ".$response->status_line);
        return $response;
    }
    else {
        return $response
    }
}

=item startScan

Start a scan using the Rapid7 API

=cut

sub startScan {
    my ( $self ) = @_;
    my $logger = get_logger();

    $logger->info("Starting Rapid7 scan");

    my $response = $self->runScanTemplate("Automatic scan started from PacketFence", $self->{_scanIp}, $self->{_template_id});
    my $result = $response->is_success;
 
    my $scan_security_event_id = $pf::constants::scan::POST_SCAN_SECURITY_EVENT_ID;
    $scan_security_event_id = $pf::constants::scan::SCAN_SECURITY_EVENT_ID if ($self->{'_registration'});
    $scan_security_event_id = $pf::constants::scan::PRE_SCAN_SECURITY_EVENT_ID if ($self->{'_pre_registration'});

    if (!$result) {
        $logger->warn("Rapid7 scan didnt start: ".$response->status_line);
        return $scan_security_event_id;
    }
    else {
        $logger->info("Started rapid7 scan for ".$self->{_scanMac});
    }

    my $apiclient = pf::api::jsonrpcclient->new;
    my %data = (
       'security_event_id' => $scan_security_event_id,
       'mac' => $self->{'_scanMac'},
    );
    $apiclient->notify('close_security_event', %data );

    $self->setStatus($pf::constants::scan::STATUS_CLOSED);
    $self->statusReportSyncToDb();
    return 0;
}

=head2 runScanTemplate

Run a specific scan template on an endpoint

=cut

sub runScanTemplate {
    my ($self, $name, $ip, $template_id) = @_;
    
    my $payload = {
        engineId => $self->{_engine_id} . "",
        hosts => [ $ip ],
        name => $name,
        templateId => $template_id,
    };

    my $req = HTTP::Request->new(
        POST => $self->buildApiUri("sites/".$self->{_site_id}."/scans"), 
        ["Content-Type" => "application/json"],
        encode_json($payload),
    );
    my $response = $self->doRequest($req);

    return $response;
}

=head2 listScanEngines

List the available scan engines in Rapid7

=cut

sub listScanEngines {
    my ($self) = @_;

    my $req = HTTP::Request->new(GET => $self->buildApiUri("scan_engines"));
    my $response = $self->doRequest($req);
    
    return $response->is_success ? decode_json($response->decoded_content)->{"resources"} : undef;
}

=head2 listSites

List the available sites in Rapid7, limited to 1000

=cut

sub listSites {
    my ($self) = @_;

    my $req = HTTP::Request->new(GET => $self->buildApiUri("sites?size=1000"));
    my $response = $self->doRequest($req);
    
    return $response->is_success ? decode_json($response->decoded_content)->{"resources"} : undef;
}

=head2 listScanTemplates

List the available scan templates that can be ran on endpoints

=cut

sub listScanTemplates {
    my ($self) = @_;

    my $req = HTTP::Request->new(GET => $self->buildApiUri("scan_templates"));
    my $response = $self->doRequest($req);
    
    return $response->is_success ? decode_json($response->decoded_content)->{"resources"} : undef;
}

=head2 assetDetails

Get the details of an asset given its IP address

Sample curl:
curl -u 'username:password' -H 'Content-Type: application/json' https://172.20.20.230:3780/api/3/assets/search -d '{"match":"all", "filters":[{"field":"ip-address", "operator":"is", "value":"10.0.0.90"}]}' --insecure | less

=cut

sub assetDetails {
    my ($self, $assetIp) = @_;

    my $req = HTTP::Request->new(
        POST => $self->buildApiUri("assets/search"), 
        ["Content-Type" => "application/json"],
        encode_json({
            "match" => "all", 
            "filters" => [{"field" => "ip-address", "operator" => "is", "value" => $assetIp}],
        }),
    );
    my $response = $self->doRequest($req);

    return $response->is_success ? decode_json($response->decoded_content)->{"resources"}->[0] : undef;
}

=head2 assetVulnerabilities

Get the vulnerabilities of an asset

=cut

sub assetVulnerabilities {
    my ($self, $assetIp) = @_;
    
    my $details = $self->assetDetails($assetIp);
    return undef unless(defined $details);

    my $asset_id = $details->{id};

    my @vulnerabilities;
    my ($page, $totalPages, $totalResources);
    while(!defined($totalPages) || $page < $totalPages) {

        my $uri = "assets/$asset_id/vulnerabilities";
        $uri .= "?page=$page" if(defined($page));
        my $req = HTTP::Request->new(
            GET => $self->buildApiUri($uri), 
        );
        my $response = $self->doRequest($req);
        my $decoded = decode_json($response->decoded_content);

        if($response->is_success) {
            push @vulnerabilities, @{$decoded->{resources}};
        }
        else {
            return undef;
        }

        $totalPages = $decoded->{page}->{totalPages};
        $page = $decoded->{page}->{number};
        $page ++;

        $totalResources = $decoded->{page}->{totalResources};
    }

    return \@vulnerabilities;
}

=head2 vulnerabilityDetails

Get the details of a specific vulnerability

Sample curl:
curl -u 'username:password' https://172.20.20.230:3780/api/3/vulnerabilities/apache-httpd-cve-2007-6388 --insecure | less

=cut

sub vulnerabilityDetails {
    my ($self, $vulnerability_id) = @_;

    my $req = HTTP::Request->new(
        GET => $self->buildApiUri("vulnerabilities/$vulnerability_id"), 
    );
    my $response = $self->doRequest($req);
    return $response->is_success ? decode_json($response->decoded_content) : undef;
}

=head2 assetTopVulnerabilities

Get an asset top 10 vulnerabilities sorted by the CVSS score

=cut

sub assetTopVulnerabilities {
    my ($self, $assetIp, $amount) = @_;
    $amount //= 10;
    my $logger = get_logger;

    my $vulnerabilities = $self->assetVulnerabilities($assetIp);

    my @vulnerabilities_with_details;
    
    foreach my $vulnerability (@$vulnerabilities) {
        my $security_event_id = $vulnerability->{id};
        if(my $details = $self->vulnerabilityDetails($security_event_id)) {
            push @vulnerabilities_with_details, $details;
        }
        else {
            $logger->error("Failed to the details of vulnerability $security_event_id");
        }
    }

    my @sorted = sort { $b->{cvss}->{v2}->{score} <=> $a->{cvss}->{v2}->{score} } @vulnerabilities_with_details;

    # Make the amount a maximum of the amount of vulnerabilities
    if($amount > (scalar(@sorted) -1)) {
        $amount = scalar(@sorted) -1 
    } else {
        $amount -= 1;
    }

    return [@sorted[0..$amount]];
}

=head2 lastScan

Get the last scan of an asset

Sample curl:
curl -u 'username:password' -H 'Content-Type: application/json' https://172.20.20.230:3780/api/3/scans/{{scan_id}} --insecure | less

=cut

sub lastScan {
    my ($self, $assetIp) = @_;
    my $logger = get_logger;

    my $details = $self->assetDetails($assetIp);
    return undef unless(defined $details);

    my $history = $details->{history};
    my $scan = last_value{ $_->{type} eq "SCAN" } @$history;
    my $scan_id = $scan->{scanId};

    if(!defined($scan_id)) {
        $logger->error("Failed to find scan entry in the asset's history for IP $assetIp");
        return undef;
    }


    my $req = HTTP::Request->new(
        GET => $self->buildApiUri("scans/$scan_id"), 
    );
    my $response = $self->doRequest($req);

    return $response->is_success ? decode_json($response->decoded_content) : undef;
}

=head2 deviceProfiling

Get the device profiling information of an asset

=cut

sub deviceProfiling {
    my ($self, $assetIp) = @_;
    my $details = $self->assetDetails($assetIp);

    return defined($details) ? $details->{osFingerprint} // {} : undef;
}

=back

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
