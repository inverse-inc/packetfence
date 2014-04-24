package captiveportal::PacketFence::Controller::Root;
use Moose;
use namespace::autoclean;
use pf::web::constants;
use URI::Escape qw(uri_escape uri_unescape);
use HTML::Entities;
use pf::enforcement qw(reevaluate_access);
use pf::config;
use pf::log;
use pf::util;
use pf::Portal::Session;
use Apache2::Const -compile => qw(OK DECLINED HTTP_MOVED_TEMPORARILY);
use pf::web;
use pf::node;
use pf::useragent;
use pf::violation;
use pf::class;
use Cache::FileCache;
use pf::sms_activation;
use List::Util qw(first);

BEGIN { extends 'captiveportal::Base::Controller'; }

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config( namespace => '' );

=head1 NAME

captiveportal::PacketFence::Controller::Root - Root Controller for captiveportal

=head1 DESCRIPTION

[enter your description here]

=head1 METHODS

=head2 auto

=cut

sub auto : Private {
    my ( $self, $c ) = @_;
    $c->forward('setupCommonStash');
    return 1;
}

=head2 index

index

=cut

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;
    $c->response->redirect('captive-portal');
}


sub default : Path {
    my ( $self, $c ) = @_;
    $c->response->body('Page not found');
    $c->response->status(404);
}

=head2 setupCommonStash

Add all the common variables in the stash

=cut

sub setupCommonStash : Private {
    my ( $self, $c ) = @_;
    my $portalSession   = $c->portalSession;
    my $destination_url = $c->request->param('destination_url');
    if ( defined $destination_url ) {
        $destination_url = decode_entities( uri_unescape($destination_url) );
    } else {
        $destination_url = $Config{'trapping'}{'redirecturl'};
    }
    my @list_help_info;
    push @list_help_info,
      { name => i18n('IP'), value => $portalSession->clientIp }
      if ( defined( $portalSession->clientIp ) );
    push @list_help_info,
      { name => i18n('MAC'), value => $portalSession->clientMac }
      if ( defined( $portalSession->clientMac ) );
    $c->stash(
        pf::web::constants::to_hash(),
        destination_url => $destination_url,
        logo            => $c->profile->getLogo,
        list_help_info  => \@list_help_info,
    );
}


=head2 end

Attempt to render a view, if needed.

=cut

sub end : ActionClass('RenderView') {
    my ( $self, $c ) = @_;
    my $errors = $c->error;
    if (scalar @$errors) {
        for my $error ( @$errors ) {
            $c->log->error($error);
        }
        my $txt_message = join(' ',grep { ref($_) eq '' } @$errors);
        $c->stash->(
            template => 'error.html',
            txt_message => $txt_message,
        );
        $c->response->status(500);
        $c->clear_errors;
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
