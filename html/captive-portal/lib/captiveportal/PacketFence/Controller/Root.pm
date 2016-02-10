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
use pf::web;
use pf::node;
use pf::useragent;
use pf::violation;
use pf::class;
use Cache::FileCache;
use List::Util qw(first);
use POSIX;
use Locale::gettext qw(bindtextdomain textdomain bind_textdomain_codeset);
use List::Util 'first';
use List::MoreUtils qw(uniq);
use Plack::Request;
use captiveportal::DynamicRouting::Factory;
use captiveportal::DynamicRouting::Application;

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
    
    my $request = $c->request;
    my $profile = $c->portalSession->profile;
    my $application = captiveportal::DynamicRouting::Application->new(
        session => $c->session, 
        profile => $profile, 
        request => $request, 
        root_module_id => "root_module"
    );
    $application->session->{client_mac} = $c->portalSession->clientMac;
    $application->session->{client_ip} = $c->portalSession->clientIp;
    my $factory = captiveportal::DynamicRouting::Factory->new();
    $factory->build_application($application);

    $application->process_user_agent();
    $application->process_destination_url();
    $application->process_fingerbank();

    $c->stash(application => $application);
    return 1;
}


=head2 index

index

=cut

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;
    $c->forward('dynamic_application');
}


=head2 default

We send everything we don't know about inside the dynamic application

=cut

sub default : Path {
    my ( $self, $c ) = @_;
    $c->forward('dynamic_application');
}

sub dynamic_application :Private {
    my ($self, $c) = @_;
    my $application = $c->stash->{application};
    $application->execute();

    if($application->response_code =~ /^(301|302)$/){
        $c->response->redirect($application->template_output, $application->response_code);
    }
    else {
        $c->response->body($application->template_output);
        $c->response->status($application->response_code);
    }
    $c->detach;
}

=head2 setupCommonStash

Add all the common variables in the stash

=cut

sub setupCommonStash : Private {
    my ( $self, $c ) = @_;
    my $logger = $c->log();
    my $portalSession   = $c->portalSession;

    if (defined( $portalSession->clientMac ) ) {
        my $node_info = node_view($portalSession->clientMac);
        if ( defined( $node_info ) ) {
            $c->stash(
                map { $_ => $node_info->{$_} }
                  qw(dhcp_fingerprint last_switch last_port
                  last_vlan last_connection_type last_ssid username)
            );
        }
    }
    $c->stash(
        pf::web::constants::to_hash(),
        logo            => $c->profile->getLogo,
    );
    $c->stash(
        client_mac => $portalSession->clientMac,
        client_ip => $portalSession->clientIp,
    );

}

=head2 setupLanguage

Define the locale

=cut

sub setupLanguage : Private {
    my ($self, $c) = @_;
    my $logger = $c->log();
    my ($locales) = $c->forward('getLanguages');

    my $locale = shift @$locales;
    $logger->debug("Setting locale to ".$locale);
    setlocale(POSIX::LC_MESSAGES, "$locale.utf8");
    my $newlocale = setlocale(POSIX::LC_MESSAGES);
    if ($newlocale !~ m/^$locale/) {
        $logger->error("Error while setting locale to $locale.utf8. Is the locale generated on your system?");
    }
    $c->stash->{locale} = $newlocale;
    bindtextdomain( "packetfence", "$conf_dir/locale" );
    bind_textdomain_codeset( "packetfence", "utf-8" );
    textdomain("packetfence");
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
    my $logger = $c->log();
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
        $browser_language =~ s/^(\w{2})(_\w{2})?/lc($1) . uc($2 || "")/e;
        if (grep(/^$browser_language$/, @authorized_locales)) {
            $lang = $browser_language;
            push(@languages, $lang) unless (grep/^$lang$/, @languages);
            $logger->debug("locale from the browser is $lang");
        }
        else {
            $logger->debug("locale from the browser $browser_language is not supported");
        }
    }

    # 4. Check the closest language that match the browser
    # Browser = fr_FR and portal is en_US and fr_CA then fr_CA will be used
    foreach my $browser_language (@$browser_languages) {
        $browser_language =~ s/^(\w{2})(_\w{2})?/lc($1) . uc($2 || "")/e;
        my $language = $1;
        if (grep(/^$language$/, @authorized_locales)) {
            $lang = $browser_language;
            my $match = first { /$language(.*)/ } @authorized_locales;
            push(@languages, $match) unless (grep/^$language$/, @languages);
            $logger->debug("Language locale from the browser is $lang");
        }
        else {
            $logger->debug("Language locale from the browser $browser_language is not supported");
        }
    }

    if (scalar @languages > 0) {
        $logger->debug("prefered user languages are " . join(", ", @languages));
    }
    else {
        push(@languages, $authorized_locales[0]);
    }
    my @returned_languages = uniq(@languages);
    return \@returned_languages;
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
