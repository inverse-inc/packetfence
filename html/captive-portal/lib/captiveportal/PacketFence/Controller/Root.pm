package captiveportal::PacketFence::Controller::Root;
use Moose;
use namespace::autoclean;
use pf::web::constants;
use URI::Escape::XS qw(uri_escape uri_unescape);
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
use List::Util qw(first);
use POSIX;

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
    $c->forward('setupLanguage');
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
    my $request  = $c->request;
    my $r = $request->{'env'}->{'psgi.input'};
    if ($r->pnotes('last_uri') ) {
        $c->forward(CaptivePortal => 'index');
    }
    $c->response->body('Page not found');
    $c->response->status(404);
}

=head2 setupCommonStash

Add all the common variables in the stash

=cut

sub setupCommonStash : Private {
    my ( $self, $c ) = @_;
    my $logger = get_logger;
    my $portalSession   = $c->portalSession;
    my $destination_url = $c->request->param('destination_url');
    if (isenabled($c->profile->forceRedirectURL)){
        $destination_url = $c->profile->getRedirectURL;
    }
    elsif (defined $destination_url && !($destination_url eq "")) { 
        $destination_url = decode_entities( uri_unescape($destination_url) );
    } 
    else {
        $destination_url = $c->profile->getRedirectURL;
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

=head2 setupLanguage

Define the locale

=cut

sub setupLanguage : Private {
    my ($self, $c) = @_;
    my $logger = get_logger;
    my ($locales) = $c->forward('getLanguages');

    my $locale = shift @$locales;
    $logger->debug("Setting locale to ".$locale);
    setlocale(POSIX::LC_MESSAGES, "$locale.utf8"); 
}

=head2 getLanguages

Retrieve the user preferred languages from the following ordered sources:

=over

=item 1. the 'lang' URL parameter

=item 2. the 'lang' parameter of the Web session

=item 3. the browser accepted languages

=back

If no language matches the authorized locales from the configuration, the first locale
of the configuration is returned.

=cut

sub getLanguages :Private {
    my ($self, $c) = @_;
    my $logger = get_logger;
    my $portalSession = $c->portalSession;

    my ($lang, @languages);

    my @authorized_locales = $c->profile->getLocales();
    unless (scalar @authorized_locales > 0) {
        @authorized_locales = @WEB::LOCALES;
    }

    $logger->debug("Authorized locale(s) are " . join(', ', @authorized_locales));

    # 1. Check if a language is specified in the URL
    if ( defined($c->request->param('lang')) ) {
        my $user_chosen_language = $c->request->param('lang');
        $user_chosen_language =~ s/^(\w{2})(_\w{2})?/lc($1) . uc($2)/e;
        if (grep(/^$user_chosen_language$/, @authorized_locales)) {
            $lang = $user_chosen_language;
            # Store the language in the session
            $c->session->{lang} = $lang;
            $logger->debug("locale from the URL is $lang");
        }
        else {
            $logger->warn("locale from the URL $user_chosen_language is not supported");
        }
    }

    # 2. Check if the language is set in the session
    if ( defined($c->session->{lang}) ) {
        $lang = $c->session->{lang};
        push(@languages, $lang) unless (grep/^$lang$/, @languages);
        $logger->debug("locale from the session is $lang");
    }

    # 3. Check the accepted languages of the browser
    my $browser_languages = $c->forward('getRequestLanguages');
    foreach my $browser_language (@$browser_languages) {
        $browser_language =~ s/^(\w{2})(_\w{2})?/lc($1) . uc($2)/e;
        if (grep(/^$browser_language$/, @authorized_locales)) {
            $lang = $browser_language;
            push(@languages, $lang) unless (grep/^$lang$/, @languages);
            $logger->debug("locale from the browser is $lang");
        }
        else {
            $logger->trace("locale from the browser $browser_language is not supported");
        }
    }

    if (scalar @languages > 0) {
        $logger->trace("prefered user languages are " . join(", ", @languages));
    }
    else {
        push(@languages, $authorized_locales[0]);
    }

    return \@languages;
}

=head2 getRequestLanguages

Extract the preferred languages from the HTTP request.
Ex: Accept-Language: en-US,en;q=0.8,fr;q=0.6,fr-CA;q=0.4,no;q=0.2,es;q=0.2
will return qw(en_US en fr fr_CA no es)

=cut

sub getRequestLanguages : Private{
    my ($self, $c) = @_;
    my $s = $c->request->header('Accept-language') || 'en_US';
    my @l = split(/,/, $s);
    map { s/;.+// } @l;
    map { s/-/_/g } @l;
    #@l = map { m/^en(_US)?/? ():$_ } @l;

    return \@l;
}



=head2 end

Attempt to render a view, if needed.

=cut

sub end : ActionClass('RenderView') {
    my ( $self, $c ) = @_;
    if (scalar $c->has_errors) {
        my $errors = $c->error;
        for my $error ( @$errors ) {
            $c->log->error($error);
        }
        my $txt_message = join(' ',grep { ref($_) eq '' } @$errors);
        $c->stash(
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
