package pf::Authentication::Source::AzureADSource;

=head1 NAME

pf::Authentication::Source::AzureADSource

=head1 DESCRIPTION

=cut

use pf::log;
use Moose;
use pf::config qw(%Config);
use pf::constants qw($TRUE $FALSE);
use pf::Authentication::constants;
use pf::constants::authentication::messages;
use JSON::MaybeXS qw(decode_json encode_json);
use List::Util qw(first);
use URI::Escape qw(uri_escape);
extends 'pf::Authentication::Source';
with qw(pf::Authentication::InternalRole);

has '+type' => (default => 'AzureAD');
has '+class' => (default => 'internal');
has 'client_id' => (isa => 'Str', is => 'rw', required => 1);
has 'client_secret' => (isa => 'Str', is => 'rw', required => 1);
has 'tenant_id' => (isa => "Str", is => "rw", required => 1);
has 'graph_url' => (isa => 'Str', is => 'rw', default => 'https://graph.microsoft.com');
has 'oauth_url' => (isa => 'Str', is => 'rw', default => 'https://login.microsoftonline.com');
has 'user_groups_url_path' => (isa => 'Str', is => 'rw', default => "/v1.0/users/%USERNAME/memberOf");
has 'user_groups_cache' => (isa => 'Int', is => "rw", default => 0);
has 'timeout' => (isa => 'Int', is => 'rw', default => 10);

my $GET_ADMIN_TOKEN_KEY = "get_admin_token";

my %AZURE_AD_UA = ();
# Safety net for the memberOf pagination loop (999 objects per page)
our $MAX_MEMBEROF_PAGES = 50;

sub get_ua {
    my ($self) = @_;
    if(exists $AZURE_AD_UA{$self->id}) {
        return $AZURE_AD_UA{$self->id};
    }

    my $ua = LWP::UserAgent->new;
    $ua->timeout($self->timeout);
    $ua->env_proxy;
    $ua->agent("PacketFence AzureAD Authentication source");
    $AZURE_AD_UA{$self->id} = $ua;
}

sub CLONE {
    %AZURE_AD_UA = ();
}

=head2 available_attributes

Add additional available attributes

=cut

sub available_attributes {
  my $self = shift;

  my $super_attributes = $self->SUPER::available_attributes;
  my @attributes = {value => "memberOf", type => $Conditions::SUBSTRING};
  return [@$super_attributes, @attributes];
}
=head2 dynamic_routing_module

Which module to use for DynamicRouting

=cut

sub dynamic_routing_module { 'Authentication::Login' }

sub build_token_url {
    my ($self) = @_;
    my $url = $self->oauth_url;
    $url =~ s#/*$##;
    my $tenant_id = $self->tenant_id;
    return "$url/$tenant_id/oauth2/v2.0/token";
}

sub build_user_groups_url {
    my ($self, $username) = @_;
    my $encoded_username = uri_escape($username);
    my $url = $self->graph_url;
    $url =~ s#/*$##;
    my $path = $self->user_groups_url_path;
    $path = "/$path" unless $path =~ m#^/#;
    $path =~ s/%USERNAME/$encoded_username/g;
    return "$url$path";
}

sub build_scope_url {
    my ($self) = @_;
    my $url = $self->graph_url;
    $url =~ s#/*$##;
    return "$url/.default";
}

sub _get_admin_token {
    my ($self) = @_;
    my $logger = get_logger;
    my $ua = $self->get_ua;

    my $r = $ua->post($self->build_token_url, [
        client_id => $self->client_id,
        client_secret => $self->client_secret,
        scope => $self->build_scope_url(),
        grant_type => "client_credentials",
    ]);
    if($r->is_success) {
        return decode_json($r->decoded_content);
    } else {
        $logger->error("Unable to obtain admin token: " . $r->status_line);
        return undef;
    }
}

sub cache {
    return pf::CHI->new(namespace => "azure_ad");
}

sub get_admin_token {
    my ($self) = @_;
    my $k = $GET_ADMIN_TOKEN_KEY;
    if(my $token = $self->cache->get($k)) {
        return $token;
    } else {
        my $data = $self->_get_admin_token();
        my $expires_in = int($data->{ext_expires_in} / 2) . "s";
        $self->cache->set($k, $data->{access_token}, { expires_in => $expires_in });
    }
}

sub authenticate {
    my ( $self, $username, $password ) = @_;
    my $logger = get_logger;
    my $ua = $self->get_ua;

    my $r = $ua->post($self->build_token_url, [
        client_id => $self->client_id,
        client_secret => $self->client_secret,
        scope => 'openid email',
        grant_type => 'password',
        username => $username,
        password => $password,
    ]);
    if ($r->is_success) {
        return ($TRUE, $AUTH_SUCCESS_MSG);
    } 
    else {
        my $response;
        eval {
           $response  = decode_json($r->decoded_content);
        };
        if($response && $response->{error}) {
            if($response->{error} eq "invalid_grant") {
                $logger->info("Invalid username/password for $username");
            }
            else {
                $logger->error("Error while authenticating $username against AzureAD: ".$response->{'error'});
            }
        } else {
            $logger->error("Failed to authenticate $username against AzureAD: ".$r->status_line);
        }
        return ($FALSE, $AUTH_FAIL_MSG);
    }

}

sub get_memberOf {
    my ($self, $username, $retrying) = @_;
    my $logger = get_logger;
    my $ua = $self->get_ua;
    my $id = $self->id;

    my $token = $self->get_admin_token();
    # Graph pages memberOf results (100 objects per page by default). Ask for
    # the largest page size allowed and follow @odata.nextLink so users with
    # many memberships still get their full group list.
    # Any failure throws: a partial list would look valid, fail to match rules
    # and, with user_groups_cache, be cached. get_cached_memberOf catches it.
    my $url = $self->build_user_groups_url($username) . '?$select=id,displayName&$top=999';
    my @groups;
    my $page = 0;
    while (defined $url) {
        $page++;
        if ($page > $MAX_MEMBEROF_PAGES) {
            die "Group lookup for $username (source[$id]) exceeded $MAX_MEMBEROF_PAGES pages\n";
        }
        my $r = $ua->get(
            $url,
            Authorization => "Bearer $token",
            "Content-Type" => "application/json",
        );
        unless ($r->is_success) {
            # A rejected admin token is refreshed and the whole lookup restarted, once
            if (($r->code == 401 || $r->code == 403) && !$retrying) {
                $logger->info("Admin token rejected while fetching groups for $username (source[$id], page $page): " . $r->status_line . "; refreshing the token and retrying");
                $self->cache->remove($GET_ADMIN_TOKEN_KEY);
                return $self->get_memberOf($username, 1);
            }
            die "Failed to obtain groups for $username (source[$id], page $page): " . $r->status_line . "\n";
        }
        my $response = eval { decode_json($r->decoded_content) };
        if ($@ || ref($response) ne 'HASH') {
            die "Failed to decode groups for $username (source[$id], page $page): " . ($@ || "unexpected response") . "\n";
        }
        push @groups, map { $_->{displayName} } grep { defined $_->{displayName} } @{$response->{value} // []};
        $url = $response->{'@odata.nextLink'};
    }
    $logger->debug("Found " . scalar(@groups) . " groups for $username (source[$id]) over $page page(s)");
    return @groups;
}

sub get_cached_memberOf {
    my ($self, $username, $params) = @_;
    my @radius_groups = map { $_ =~ /^radius_request\.OAuth2-Group:[0-9]+/ ? $params->{$_} : () } keys %$params;

    if(scalar(@radius_groups) > 0) {
        get_logger->debug("Found groups for $username in RADIUS parameters: ".join(",", @radius_groups));
        return @radius_groups;
    }

    # get_memberOf throws on failure. CHI::compute does not store anything when
    # the callback throws, so a failed lookup is never cached as "no groups".
    my @groups = eval {
        $self->user_groups_cache
            ? $self->cache->compute($self->id."-memberOf-$username", {expires_in => $self->user_groups_cache}, sub {$self->get_memberOf($username)})
            : $self->get_memberOf($username);
    };
    if ($@) {
        get_logger->error("Group lookup failed for $username (source[".$self->id."]): $@");
        return;
    }
    return @groups;
}

sub match_in_subclass {
    my ($self, $params, $rule, $own_conditions, $matching_conditions) = @_;
    # Some flows (e.g. sponsor validation) only provide the identity under
    # 'email' rather than 'username'. Mirror the LDAP source behavior and fall
    # back to the email so the Graph memberOf lookup can resolve the user
    # (Graph accepts the userPrincipalName / email as the {id} key).
    my $username = $params->{username};
    $username = $params->{email} unless (defined($username) && length($username));
    if (defined($username) && length($username)) {
        $params->{memberOf} = [ $self->get_cached_memberOf($username, $params) ];
    }
    else {
        get_logger->warn("No username or email provided while matching in AzureAD source ".$self->id."; skipping group (memberOf) lookup.");
        $params->{memberOf} = [];
    }
    my $match = $rule->match;
    # If match any we just want the first
    my @conditions;
    if ($rule->match eq $Rules::ANY) {
        my $c = first { $self->match_condition($_, $params) } @$own_conditions;
        push @conditions, $c if $c;
    }
    else {
        @conditions = grep { $self->match_condition($_, $params) } @$own_conditions;
    }
    push @$matching_conditions, @conditions;
    return ($username, undef);
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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};
1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

