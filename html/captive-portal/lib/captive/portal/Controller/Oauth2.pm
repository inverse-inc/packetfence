package captive::portal::Controller::Oauth2;
use Moose;
use namespace::autoclean;
use pf::config;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

captive::portal::Controller::Oauth2 - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.



=head1 METHODS

=cut

our %VALID_OAUTH_PROVIDERS = (
    google   => undef,
    facebook => undef,
    github   => undef,
);

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;
    $c->forward('Root' => 'validateMac');
    my $logger        = $c->log;
    my $portalSession = pf::Portal::Session->new();
    my $request       = $c->request;


    my $source_type = undef;
    my %info;
    my $pid;

    # Pull username
    $info{'pid'} = "admin";

    # Pull browser user-agent string
    $info{'user_agent'} = $request->user_agent;
    my $provider = $request->param('provider');

    if ( defined($provider) ) {
        $logger->info( "Sending "
              . $portalSession->getClientMac()
              . " to OAuth2 - Provider: $provider" );
        pf::web::generate_oauth2_page($portalSession);
        exit(0);
    } else {
        my $result = $request->param('result');
        if ( exists $VALID_OAUTH_PROVIDERS{$result} ) {

            # Handle OAuth2
            my ( $code, $username, $err ) =
              pf::web::generate_oauth2_result( $portalSession, $result );
            if ($code) {
                $pid = $username;
                if ( $result eq 'facebook' ) {
                    $pid .= "\@facebook.com";
                }
            } else {
                exit(0);
            }
        }

        my $source = $portalSession->getProfile->getSourceByType($result);

        if ($source) {

            # Setting access timeout and role (category) dynamically
            $info{'unregdate'} =
              &pf::authentication::match( $source->{id}, { username => $pid },
                $Actions::SET_ACCESS_DURATION );

            if ( defined $info{'unregdate'} ) {
                $info{'unregdate'} = POSIX::strftime(
                    "%Y-%m-%d %H:%M:%S",
                    localtime( time + normalize_time( $info{'unregdate'} ) )
                );
            } else {
                $info{'unregdate'} =
                  &pf::authentication::match( $source->{id},
                    { username => $pid },
                    $Actions::SET_UNREG_DATE );
            }

            $info{'category'} =
              &pf::authentication::match( $source->{id}, { username => $pid },
                $Actions::SET_ROLE );
            $c->forward('Root' => 'webNodeRegister', [$pid, %info]);
            $c->forward('Root' => 'endPortalSession');
        } else {
            $logger->warn( "No active $source_type source for profile "
                  . $portalSession->getProfile->getName
                  . ", redirecting to "
                  . $Config{'trapping'}{'redirecturl'} );
            $c->response->redirect( $Config{'trapping'}{'redirecturl'} );
        }
    }
}

=head1 AUTHOR

root

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
