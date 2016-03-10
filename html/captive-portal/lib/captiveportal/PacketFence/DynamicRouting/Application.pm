package captiveportal::PacketFence::DynamicRouting::Application;

=head1 NAME

captiveportal::DynamicRouting::Application

=head1 DESCRIPTION

Application definition for Dynamic Routing

=cut

use Moose;

use CHI;
use Cache::FileCache;
use Template::AutoFilter;
use pf::constants;
use pf::log;
use Locale::gettext qw(gettext ngettext);
use captiveportal::Base::I18N;
use pf::node;
use pf::useragent;
use pf::util;
use pf::config::util;
use List::MoreUtils qw(any);
use URI::Escape::XS qw(uri_unescape);
use HTML::Entities;
use pf::constants::web qw($USER_AGENT_CACHE_EXPIRATION);

has 'session' => (is => 'rw', required => 1);

has 'root_module' => (is => 'rw', isa => "captiveportal::DynamicRouting::Module::Root");

has 'root_module_id' => (is => 'rw');

has 'request' => (is => 'ro', required => 1);

has 'hashed_params' => (is => 'rw');

has 'profile' => (is => 'rw', required => 1, isa => "pf::Portal::Profile");

has 'template_output' => (is => 'rw');

has 'response_code' => (is => 'rw', isa => 'Int', default => sub{200});

# to cache the cache objects
has 'cache_cache' => (is => 'rw', default => sub {{}});

=head2 BUILD

Additionnal building on the application

=cut

sub BUILD {
    my ($self) = @_;
    my $hashed = {};
    my $request = $self->request;
    foreach my $param (keys %{$request->parameters}){
        if($param =~ /^(.+)\[(.+)\]$/){
            $hashed->{$1} //= {};
            $hashed->{$1}->{$2} = $request->parameters->{$param};
        }
        else {
            $hashed->{$param} = $request->parameters->{$param};
        }
    }
    $self->hashed_params($hashed);
};

=head2 user_agent_cache

The User agent cache
TODO : migrate this to CHI ?

=cut

sub user_agent_cache {
    my ($self) = @_;
    $self->cache_cache->{user_agent_cache} //= new Cache::FileCache( { 'namespace' => 'CaptivePortal_UserAgents' } );
    return $self->cache_cache->{user_agent_cache};
}

=head2 lost_devices_cache

The lost devices cache
TODO : migrate this to CHI ?

=cut

sub lost_devices_cache {
    my ($self) = @_;
    $self->cache_cache->{lost_devices_cache} //= new Cache::FileCache( { 'namespace' => 'CaptivePortal_LostDevices' } );
    return $self->cache_cache->{lost_devices_cache};
}

=head2 user_cache

User based cache

=cut

sub user_cache {
    my ($self) = @_;
    return CHI->new(
        driver     => 'SubNamespace',
        chi_object => pf::CHI->new(namespace => 'httpd.portal'),
        namespace  => $self->current_mac,
    );
}

=head2 reached_retry_limit

Test if the retry limit has been reached for a session key
If the max is undef or 0 then check is disabled

=cut

sub reached_retry_limit {
    my ( $self, $retry_key, $max ) = @_;
    return 0 unless $max;
    my $cache = $self->user_cache;
    my $retries = $cache->get($retry_key) || 1;
    $retries++;
    $cache->set($retry_key,$retries,$self->profile->{_block_interval});
    return $retries > $max;
}

=head2 process_user_agent

Process the user agent

=cut

sub process_user_agent {
    my ( $self ) = @_;
    my $user_agent    = $self->request->user_agent;
    my $logger        = get_logger();
    my $mac           = $self->current_mac;
    unless ($user_agent) {
        $logger->warn("has no user agent");
        return;
    }

    # caching useragents, if it's the same don't bother triggering violations
    my $cached_useragent = $self->user_agent_cache->get($mac);

    # Cache hit
    return
      if ( defined($cached_useragent) && $user_agent eq $cached_useragent );

    # Caching and updating node's info
    $logger->debug("adding user-agent to cache");
    $self->user_agent_cache->set( $mac, $user_agent, $USER_AGENT_CACHE_EXPIRATION);

    # Recording useragent
    $logger->info("Updating node user_agent with useragent: '$user_agent'");
    node_modify( $mac, ( 'user_agent' => $user_agent ) );

    # updates the node_useragent information and fires relevant violations triggers
    return pf::useragent::process_useragent( $mac, $user_agent );
}

=head2 process_fingerbank

Fingerbank processing

=cut

sub process_fingerbank {
    my ( $self ) = @_;
    my $timer = pf::StatsD::Timer->new({sample_rate => 1});

    my %fingerbank_query_args = (
        user_agent          => $self->request->user_agent,
        mac                 => $self->current_mac,
        ip                  => $self->root_module->current_ip,
    );

    pf::fingerbank::process(\%fingerbank_query_args);
}

=head2 current_module_id

Get the current module ID

=cut

sub current_module_id {
    my ($self) = @_;
    $self->session->{current_module_id} //= $self->root_module->id;
    return $self->session->{current_module_id};
}

=head2 preprocessing

Processing that needs to occur before we execute the application

=cut

sub preprocessing {
    my ($self) = @_; 
    my $timer = pf::StatsD::Timer->new({sample_rate => 1});
    $self->process_user_agent();
    $self->process_destination_url();
    $self->process_fingerbank();
}

=head2 execute

Application execution
This will cycle through the proper modules and the appropriate module will set template_output and status

=cut

sub execute {
    my ($self) = @_;
    my $timer = pf::StatsD::Timer->new({sample_rate => 1});
    $self->root_module->execute();
}

=head2 current_mac

The MAC address that is tied to the current request

=cut

sub current_mac {
    my ($self) = @_;
    return $self->session()->{"client_mac"};
}

=head2 current_ip

Get the IP address that is tied to the current request

=cut

sub current_ip {
    my ($self) = @_;
    return $self->session()->{"client_ip"};
}

=head2 process_destination_url

Destination URL handling

Will compute it using the following logic : 
- Use the Destination URL specified as a param or the one stored in the session
- Check if the profile requires a forced destination URL, in this case use the one of the profile
- If there is no destination URL at this point, use the one from the portal
- Now, if the destination URL points to one of the portal IP or hostname, replace it with the one from the profile

=cut

sub process_destination_url {
    my ($self) = @_;
    my $url = $self->request->parameters->{destination_url} || $self->session->{destination_url};

    # Return portal profile's redirection URL if destination_url is not set or if redirection URL is forced
    if (!defined($url) || !$url || isenabled($self->profile->forceRedirectURL)) {
        $url = $self->profile->getRedirectURL;
    }

    my $host = URI::URL->new($url)->host();

    my @portal_hosts = portal_hosts();
    # if the destination URL points to the portal, we put the default URL of the portal profile
    if ( any { $_ eq $host } @portal_hosts) {
        get_logger->info("Replacing destination URL since it points to the captive portal");
        return $self->profile->getRedirectURL;
    }

    $url = decode_entities(uri_unescape($url));
    $self->session->{destination_url} = $url;

    get_logger->debug("Destination is : ".$self->session->{destination_url});
}


=head2 render

Render a template inside the application layout

=cut

sub render {
    my ($self, $template, $args) = @_;

    get_logger->debug("Rendering $template");

    my $inner_content = $self->_render($template,$args);

    my $layout_args = {
        flash => $self->flash,
        content => $inner_content,
        client_mac => $self->current_mac,
        client_ip => $self->root_module->current_ip,
    };
    $args->{layout} //= $TRUE;
    my $content = $args->{layout} ? $self->_render('layout.html', $layout_args) : $inner_content;

    $self->template_output($content);
   
    $self->empty_flash();
}

=head2 _render

Render a template using Template Toolkit.

=cut

sub _render {
    my ($self, $template, $args) = @_;
    
    # this won't be needed once #1208 is merged
    $self->profile->{_template_paths} = ["/usr/local/pf/html/captive-portal/templates"];
    our $TT_OPTIONS = {
        AUTO_FILTER => 'html',
        RELATIVE => 1,
        INCLUDE_PATH => $self->profile->{_template_paths},
    };

    use Template::Stash;

    # define list method to return new list of odd numbers only
    $args->{ i18n } = sub {
        return $self->i18n(@_);
    };
    $args->{ i18n_format } = sub {
        return $self->i18n_format(@_);  
    };

    our $processor = Template::AutoFilter->new($TT_OPTIONS);;
    my $output = '';
    $processor->process($template, $args, \$output) || die("Can't generate template $template: ".$processor->error."Error : ".$@);

    return $output;
}

=head2 redirect

Create a response that will redirect the user

=cut

sub redirect {
    my ($self, $url, $code) = @_;
    $self->template_output($url);
    $self->response_code($code || 302);
}

=head2 i18n

Internationalize a string

=cut

sub i18n {
    my ( $self, $msgid ) = @_;

    my $msg = gettext($msgid);
    utf8::decode($msg);

    return $msg;
}

=head2 ni18n

Internationalize a string that can be singular/plural

=cut

sub ni18n {
    my ( $self, $singular, $plural, $category ) = @_;

    my $msg = ngettext( $singular, $plural, $category );
    utf8::decode($msg);

    return $msg;
}

=head2 i18n_format

Pass message id through gettext then sprintf it.

=cut

sub i18n_format {
    my ( $self, $msgid, @args ) = @_;
    my $msg = sprintf( gettext($msgid), @args );
    utf8::decode($msg);
    return $msg;
}

=head2 error

Create the template for an error

=cut

sub error {
    my ($self, $message) = @_;
    $self->render("error.html", {message => $message});
}

=head2 empty_flash

Empty the flash

=cut

sub empty_flash {
    my ($self) = @_;
    $self->session->{flash} = {};
}

=head2 flash

Access the flash

=cut

sub flash {
    my ($self) = @_;
    $self->session->{flash} //= {};
    return $self->session->{flash};
}

=head2 reset_session

Reset the session except for attributes that are not related to the device state

=cut

sub reset_session {
    my ($self) = @_;
    my @ignore = qw(flash destination_url client_mac client_ip);
    foreach my $key (keys %{$self->session}){
        next if(any { $key eq $_ } @ignore);
        delete $self->session->{$key};
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

