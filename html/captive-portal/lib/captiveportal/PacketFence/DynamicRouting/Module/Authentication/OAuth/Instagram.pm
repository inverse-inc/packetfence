package captiveportal::PacketFence::DynamicRouting::Module::Authentication::OAuth::Instagram;

=head1 NAME

captiveportal::DynamicRouting::Module::Authentication::OAuth::Instagram

=head1 DESCRIPTION

Instagram OAuth module

=cut

use WWW::Curl::Easy;
use Moose;
extends 'captiveportal::DynamicRouting::Module::Authentication::OAuth';

has '+source' => (isa => 'pf::Authentication::Source::InstagramSource');

=head2 get_token

Get the OAuth2 token

=cut

sub get_token {
    my ($self) = @_;
    use Data::Dumper;
    use pf::log;

    my $curl = WWW::Curl::Easy->new;
    my $code = $self->app->request->parameters->{code};
    my $info = $self->get_client;

    my $source = $self->source;


    my $response_body = '';
    my $formdata = WWW::Curl::Form->new;
    
    $formdata->formadd("client_id", "$info->{NOP_id}");
    $formdata->formadd("client_secret", "$info->{NOP_secret}");
    $formdata->formadd("redirect_uri", "$info->{NOPW_redirect}");
    $formdata->formadd("grant_type", "authorization_code");
    $formdata->formadd("code", "$code");

    $curl->setopt(CURLOPT_HTTPPOST, $formdata);
    $curl->setopt(CURLOPT_WRITEDATA, \$response_body);
    $curl->setopt(CURLOPT_DNS_USE_GLOBAL_CACHE, 0);
    $curl->setopt(CURLOPT_NOSIGNAL, 1);
    $curl->setopt(CURLOPT_HTTPHEADER(), ['Content-Type: multipart/form-data']);
    $curl->setopt(CURLOPT_URL, "https://api.instagram.com/oauth/access_token");#$info->{NOP_access_token_url});

    my $curl_return_code = $curl->perform;

    my $response_code = $curl->getinfo(CURLINFO_HTTP_CODE);

    get_logger->info('response' . Dumper($response_body->{'access_token'}));
    get_logger->info('access test' . Dumper($source->{access_token_path}));

    my $token = $response_body->{'access_token'};

    if ($@) {
        get_logger->warn("OAuth2: failed to receive the token from the provider: $@");
        pf::auth_log::change_record_status($self->source->id, $self->current_mac, $pf::auth_log::FAILED);
        $self->app->flash->{error} = "OAuth2 Error: Failed to get the token";
        $self->landing();
        return;
    }
    return ($curl_return_code, $response_code, $response_body, $curl, $token);

}

=head2 handle_callback

Handle the callback from the OAuth2 provider and fetch the protected resource

=cut

#sub handle_callback {
#    my ($self) = @_;
#
#    my $token = $self->get_token();
#    return unless($token);
#
#    # request a JSON response
#    my $h = HTTP::Headers->new( 'x-li-format' => 'json' );
#    my $response = $token->get($self->source->{'protected_resource_url'}, $h ); 
#
#    if ($response->is_success) {
#        my $info = $self->_decode_response($response); 
#        my $pid = $self->_extract_username_from_response($info); 
#        
#        $self->username($pid);
#
#        get_logger->info("OAuth2 successfull for username ".$self->username);
#        $self->source->lookup_from_provider_info($self->username, $info);
#        
#        pf::auth_log::record_completed_oauth($self->source->id, $self->current_mac, $pid, $pf::auth_log::COMPLETED);
#
#        $self->done();
#    }
#    else {
#        get_logger->info("OAuth2: failed to validate the token, redireting to login page.");
#        get_logger->debug(sub { use Data::Dumper; "OAuth2 failed response : ".Dumper($response) });
#        pf::auth_log::change_record_status($self->source->id, $self->current_mac, $pf::auth_log::FAILED);
#        $self->app->flash->{error} = "OAuth2 Error: Failed to validate the token, please retry";
#        $self->landing();
#        return;
#    }
#
#}

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

__PACKAGE__->meta->make_immutable;

1;

