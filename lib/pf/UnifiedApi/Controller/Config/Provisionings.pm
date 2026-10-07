package pf::UnifiedApi::Controller::Config::Provisionings;

=head1 NAME

pf::UnifiedApi::Controller::Config::Provisionings - 

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Controller::Config::Provisionings



=cut

use strict;
use warnings;

use Mojo::Base qw(pf::UnifiedApi::Controller::Config::Subtype);
has 'config_store_class' => 'pf::ConfigStore::Provisioning';
has 'form_class' => 'pfappserver::Form::Config::Provisioning';
has 'primary_key' => 'provisioning_id';

use pf::ConfigStore::Provisioning;
use pf::node qw(node_view);
use pf::provisioner::generic_http;
use pf::util qw(clean_mac);
use pfappserver::Form::Config::Provisioning;
use pfappserver::Form::Config::Provisioning::accept;
use pfappserver::Form::Config::Provisioning::airwatch;
use pfappserver::Form::Config::Provisioning::android;
use pfappserver::Form::Config::Provisioning::deny;
use pfappserver::Form::Config::Provisioning::dpsk;
use pfappserver::Form::Config::Provisioning::generic_http;
use pfappserver::Form::Config::Provisioning::google_workspace_chromebook;
use pfappserver::Form::Config::Provisioning::intune;
use pfappserver::Form::Config::Provisioning::jamf;
use pfappserver::Form::Config::Provisioning::jamfCloud;
use pfappserver::Form::Config::Provisioning::kandji;
use pfappserver::Form::Config::Provisioning::mobileconfig;
use pfappserver::Form::Config::Provisioning::mobileiron;
use pfappserver::Form::Config::Provisioning::sentinelone;
use pfappserver::Form::Config::Provisioning::windows;

our %TYPES_TO_FORMS = (
    map { $_ => "pfappserver::Form::Config::Provisioning::$_" } qw(
      accept
      airwatch
      android
      deny
      dpsk
      generic_http
      google_workspace_chromebook
      intune
      jamf
      jamfCloud
      kandji
      mobileconfig
      mobileiron
      sentinelone
      windows
    )
);

sub type_lookup {
    return \%TYPES_TO_FORMS;
}

=head2 fields_to_mask

fields_to_mask

headers and body are templates that commonly carry an API token
(Authorization: Bearer ...), so they are masked in the audit record.

=cut

sub fields_to_mask { qw(access_token refresh_token password passcode private_key applicationSecret access_token headers body) }

=head2 test_jq

Evaluate a jq query against a sample JSON payload.
Used by the admin GUI to test the jq query of a generic_http provisioner.

The query can be tested against a node, the way the provisioner runs one: see
L</test_jq_vars>. The node it was given back is returned with the result, so
the admin can see which attributes C<$node> held.

=cut

sub test_jq {
    my ($self) = @_;
    my ($error, $data) = $self->get_json;
    if (defined $error) {
        return $self->render_error(400, "Bad Request : $error");
    }

    if (ref($data) ne 'HASH') {
        return $self->render_error(400, "Bad Request : a JSON object is expected");
    }

    my $query = $data->{jq_query} // '';
    my $json  = $data->{json} // '';
    if ($query eq '' || $json eq '') {
        return $self->render_error(422, "Both jq_query and json must be provided");
    }

    my ($vars, $vars_err) = $self->test_jq_vars($data);
    if (defined $vars_err) {
        return $self->render_error(422, $vars_err);
    }

    # the query is arbitrary here, so bound how long it may run
    my ($pass, $results, $err) = pf::provisioner::generic_http->evaluate_jq_guarded($json, $query, undef, $vars);
    if (defined $err) {
        return $self->render_error(422, "jq evaluation failed: $err");
    }

    return $self->render(
        status => 200,
        json => {
            passes  => ($pass ? $self->json_true : $self->json_false),
            results => $results,
            mac     => $vars->{mac},
            node    => $vars->{node},
        }
    );
}

=head2 test_jq_vars

Build the jq variables of a test from the request body: a node given as a JSON
object in C<node>, or the node of the MAC address in C<mac> looked up in the
database. Neither is required -- without them C<$mac> and C<$node> are null,
which is what a query that does not use them has always seen.

A MAC that no node matches is not an error: the query runs with C<$node> null
and the caller sees a null node in the answer, which is also what the
provisioner would do for an unknown device.

Returns (\%vars, undef), or (undef, $error) when the request describes a node
it cannot build.

=cut

sub test_jq_vars {
    my ($self, $data) = @_;
    my $mac = $data->{mac};
    undef $mac if defined $mac && $mac eq '';
    if (defined $mac) {
        my $cleaned = clean_mac($mac);
        if (!$cleaned) {
            return (undef, "'$mac' is not a valid MAC address");
        }

        $mac = $cleaned;
    }

    my $node = $data->{node};
    if (defined $node) {
        if (ref($node) ne 'HASH') {
            return (undef, "node must be a JSON object");
        }

        # a node given outright stands in for the lookup, so a query can be
        # tested against attributes no node carries yet
        $mac //= $node->{mac};
    } elsif (defined $mac) {
        $node = node_view($mac);
    }

    return (pf::provisioner::generic_http->jq_vars($mac, $node), undef);
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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
