package fingerbank::Source::Collector;

=head1 NAME

fingerbank::Source::Collector

=head1 DESCRIPTION

Source for interrogating the upstream Fingerbank Collector

=cut

use Moose;
extends 'fingerbank::Base::Source';

use JSON;

use fingerbank::Config;
use fingerbank::Constant qw($TRUE);
use fingerbank::Log;
use fingerbank::Model::Combination;
use fingerbank::Model::Device;
use fingerbank::Util qw(is_enabled is_disabled is_error is_success);
use fingerbank::Collector;

=head2 match

Check whether or not the arguments match this source

=cut

sub match {
    my ( $self, $args, $other_results ) = @_;
    my $logger = fingerbank::Log::get_logger;

    foreach my $discoverer_id (keys %$other_results){
        if($discoverer_id eq "fingerbank::Source::LocalDB"){
            $logger->debug("Found a good hit in the Fingerbank local databases. Will not interrogate Upstream.");
            return $fingerbank::Status::NOT_FOUND;
        }
    }

    my $Config = fingerbank::Config::get_config;    

    $logger->debug("Attempting to interrogate Fingerbank Collector");

    my %upstream_args = map {lc($_) => $args->{lc($_)}} @fingerbank::Constant::QUERY_PARAMETERS;

    my $collector = fingerbank::Collector->new_from_config();
    my $ua = $collector->get_lwp_client();
    my $query_args = encode_json(\%upstream_args);

    my $req = $collector->build_request("GET", "/endpoint_data/".$args->{mac}."/details");

    my $res = $ua->request($req);

    if ( $res->is_success ) {
        my $result = decode_json($res->decoded_content);
        $result = delete $result->{cloud_api_result};
        $logger->info("Successfully interrogate upstream Fingerbank project for matching. Got device : ".$result->{device}->{id});
        # Tracking down from where the result is coming
        $result->{'SOURCE'} = "Upstream";
        return ( $fingerbank::Status::OK, $result );
    } else {
        $logger->warn("An error occured while interrogating upstream Fingerbank project: " . $res->status_line . " result:" . $res->decoded_content);
        return ( $fingerbank::Status::INTERNAL_SERVER_ERROR );
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
1;
