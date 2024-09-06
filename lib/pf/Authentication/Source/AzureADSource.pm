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
extends 'pf::Authentication::Source';
with qw(pf::Authentication::InternalRole);

has '+type' => (default => 'AzureAD');
has '+class' => (default => 'internal');
has 'client_id' => (isa => 'Str', is => 'rw', required => 1);
has 'client_secret' => (isa => 'Str', is => 'rw', required => 1);
has 'tenant_id' => (isa => "Str", is => "rw", required => 1);
has 'token_url' => (isa => 'Str', is => 'rw', default => "https://login.microsoftonline.com/%TENANT_ID/oauth2/v2.0/token");
has 'user_groups_url' => (isa => 'Str', is => 'rw', default => "https://graph.microsoft.com/v1.0/users/%USERNAME/memberOf");
has 'user_groups_cache' => (isa => 'Int', is => "rw", default => 0);
has 'timeout' => (isa => 'Int', is => 'rw', default => 10);

my $GET_ADMIN_TOKEN_KEY = "get_admin_token";

my %AZURE_AD_UA = ();

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
    my $url = $self->token_url;
    my $tenant_id = $self->tenant_id;
    $url =~ s/%TENANT_ID/$tenant_id/g;
    return $url;
}

sub build_user_groups_url {
    my ($self, $username) = @_;
    my $url = $self->user_groups_url;
    $url =~ s/%USERNAME/$username/g;
    return $url;
}

sub _get_admin_token {
    my ($self) = @_;
    my $logger = get_logger;
    my $ua = $self->get_ua;

    my $r = $ua->post($self->build_token_url, [
        client_id => $self->client_id,
        client_secret => $self->client_secret,
        scope => "https://graph.microsoft.com/.default",
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

sub handle_failed_admin_call {
    my ($self, $response, $retry_call) = @_;

    # We make sure this doesn't get called over and over
    my $caller2 = (caller(2))[3];
    my $caller3 = (caller(3))[3];
    if($caller2 eq "pf::Authentication::Source::AzureADSource::handle_failed_admin_call" || $caller3 eq "pf::Authentication::Source::AzureADSource::handle_failed_admin_call") {
        return undef;
    }

    if($response->code eq 401 || $response->code eq 403) {
        $self->cache->remove($GET_ADMIN_TOKEN_KEY) ;
        $retry_call->();
    }
    else {
        return undef;
    }
}

sub get_memberOf {
    my ($self, $username) = @_;
    my $logger = get_logger;
    my $ua = $self->get_ua;

    my $token = $self->get_admin_token();
    my $r = $ua->get(
        $self->build_user_groups_url($username) . '?$select=id,displayName', 
        Authorization => "Bearer $token", 
        "Content-Type" => "application/json", 
    );
    if($r->is_success) {
        my $response = decode_json($r->decoded_content);
        return map{ $_->{displayName} } @{$response->{value}};
    }
    else {
        $logger->error("Failed to obtain groups for $username: " . $r->status_line);
        return $self->handle_failed_admin_call($r, sub{$self->get_memberOf($username)});
    }
}

sub get_cached_memberOf {
    my ($self, $username, $params) = @_;
    my @radius_groups = map { $_ =~ /^radius_request\.OAuth2-Group:[0-9]+/ ? $params->{$_} : () } keys %$params;

    if(scalar(@radius_groups) > 0) {
        get_logger->debug("Found groups for $username in RADIUS parameters: ".join(",", @radius_groups));
        return @radius_groups;
    }
    elsif($self->user_groups_cache) {
        return $self->cache->compute($self->id."-memberOf-$username", {expires_in => $self->user_groups_cache}, sub {$self->get_memberOf($username)});
    } 
    else {
        return $self->get_memberOf($username);
    }
}

sub match_in_subclass {
    my ($self, $params, $rule, $own_conditions, $matching_conditions) = @_;
    $params->{memberOf} = [ $self->get_cached_memberOf($params->{username}, $params) ];
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
    return ($params->{'username'}, undef);
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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

