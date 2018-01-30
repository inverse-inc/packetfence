package captiveportal::PacketFence::DynamicRouting::Module::Authentication::OAuth::Google;

=head1 NAME

captiveportal::DynamicRouting::Module::Authentication::OAuth::Google

=head1 DESCRIPTION

Google OAuth module

=cut

use Moose;
extends 'captiveportal::DynamicRouting::Module::Authentication::OAuth';

use pf::log;
use pf::auth_log;

has '+source' => (isa => 'pf::Authentication::Source::GoogleSource');

=head2 handle_callback

Google override to handle the callback from the OAuth2 provider and fetch the protected resource

=cut

sub handle_callback {
    my ($self) = @_;

    my $token = $self->get_token();
    return unless($token);

    # request a JSON response
    my $h = HTTP::Headers->new( 'x-li-format' => 'json' );
    my $response = $token->get($self->source->{'protected_resource_url'}, $h ); 

    if ($response->is_success) {
        my $info = $self->_decode_response($response); 
        my $pid = $self->_extract_username_from_response($info);
        my $hd = $info->{hd};
        my $hosted_domain = $self->source->hosted_domain;
        # get_logger->info(sub { use Data::Dumper; "OAuth2  response : ".Dumper($info) });   
        if ( defined $hosted_domain && $hosted_domain ne "" && (!defined $hd || $hosted_domain ne $hd)){
            get_logger->info("OAuth2: google domain for user: ".$pid." did not match the allowed domain: ".$hosted_domain);
            get_logger->debug(sub { use Data::Dumper; "OAuth2 failed response : ".Dumper($response) });
            pf::auth_log::change_record_status($self->source->id, $self->current_mac, $pf::auth_log::FAILED);
            $self->app->flash->{error} = "OAuth2: google domain did not match the allowed domain: ".$hosted_domain ;
            $self->landing();
            return;    
        }
        
        $self->username($pid);

        get_logger->info("OAuth2 successfull for username ".$self->username);
        $self->source->lookup_from_provider_info($self->username, $info);
        
        pf::auth_log::record_completed_oauth($self->source->id, $self->current_mac, $pid, $pf::auth_log::COMPLETED);

        $self->done();
    }
    else {
        get_logger->info("OAuth2: failed to validate the token, redireting to login page.");
        get_logger->debug(sub { use Data::Dumper; "OAuth2 failed response : ".Dumper($response) });
        pf::auth_log::change_record_status($self->source->id, $self->current_mac, $pf::auth_log::FAILED);
        $self->app->flash->{error} = "OAuth2 Error: Failed to validate the token, please retry";
        $self->landing();
        return;
    }
}


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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

1;

