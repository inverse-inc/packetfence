package captiveportal::DynamicRouting::Application;

=head1 NAME

DynamicRouting::Application

=head1 DESCRIPTION

Application definition for Dynamic Routing

=cut

use Moose;

use CHI;
use Cache::FileCache;
use Template::AutoFilter;
use pf::log;
use Locale::gettext qw(gettext ngettext);
use captiveportal::DynamicRouting::I18N;
use pf::node;
use pf::useragent;
use pf::util;
use pf::config::util;
use List::MoreUtils qw(any);
use URI::Escape::XS qw(uri_unescape);
use HTML::Entities;

has 'session' => (is => 'rw', required => 1);

has 'root_module' => (is => 'rw', isa => "captiveportal::DynamicRouting::RootModule");

has 'root_module_id' => (is => 'rw');

has 'request' => (is => 'ro', required => 1);

has 'hashed_params' => (is => 'rw');

has 'profile' => (is => 'rw', required => 1, isa => "pf::Portal::Profile");

has 'template_output' => (is => 'rw');

has 'response_code' => (is => 'rw', isa => 'Int', default => sub{200});

# to cache the cache objects
has 'cache_cache' => (is => 'rw', default => sub {{}});

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

#TODO : migrate this to CHI ?
sub user_agent_cache {
    my ($self) = @_;
    $self->cache_cache->{user_agent_cache} //= new Cache::FileCache( { 'namespace' => 'CaptivePortal_UserAgents' } );
    return $self->cache_cache->{user_agent_cache};
}

#TODO : migrate this to CHI ?
sub lost_devices_cache {
    my ($self) = @_;
    $self->cache_cache->{lost_devices_cache} //= new Cache::FileCache( { 'namespace' => 'CaptivePortal_LostDevices' } );
    return $self->cache_cache->{lost_devices_cache};
}

sub user_cache {
    my ($self) = @_;
    return CHI->new(
        driver     => 'SubNamespace',
        chi_object => pf::CHI->new(namespace => 'httpd.portal'),
        namespace  => $self->root_module->current_mac,
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

sub process_user_agent {
    my ( $self ) = @_;
    my $user_agent    = $self->request->user_agent;
    my $logger        = get_logger();
    my $mac           = $self->root_module->current_mac;
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
    $self->user_agent_cache->set( $mac, $user_agent, "5 minutes" );

    # Recording useragent
    $logger->info("Updating node user_agent with useragent: '$user_agent'");
    node_modify( $mac, ( 'user_agent' => $user_agent ) );

    # updates the node_useragent information and fires relevant violations triggers
    return pf::useragent::process_useragent( $mac, $user_agent );
}

sub process_fingerbank {
    my ( $self ) = @_;

    my %fingerbank_query_args = (
        user_agent          => $self->request->user_agent,
        mac                 => $self->root_module->current_mac,
        ip                  => $self->root_module->current_ip,
    );

    pf::fingerbank::process(\%fingerbank_query_args);
}

# IS this still necessary ? I don't think so
sub set_current_module {
    my ($self, $module) = @_;
    $self->session->{current_module_id} = $module;
}

sub current_module_id {
    my ($self) = @_;
    $self->session->{current_module_id} //= $self->root_module->id;
    return $self->session->{current_module_id};
}

sub execute {
    my ($self) = @_;
    $self->root_module->execute();
}

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


sub render {
    my ($self, $template, $args) = @_;


    my $inner_content = $self->_render($template,$args);

    my $layout_args = {
        flash => $self->flash,
        content => $inner_content,
    };
    my $content = $self->_render('layout.html', $layout_args);

    $self->template_output($content);
   
    $self->empty_flash();
}

sub _render {
    my ($self, $template, $args) = @_;
    
#    get_logger->trace(sub { use Data::Dumper ; "Rendering template $template with args : ".Dumper($args)});
    
    our $TT_OPTIONS = {
        AUTO_FILTER => 'html',
        RELATIVE => 1,
        INCLUDE_PATH => "/usr/local/pf/html/captive-portal/new-templates",
    };

    use Template::Stash;

    # define list method to return new list of odd numbers only
    $args->{ i18n } = sub {
        my $string = shift;
        return $self->i18n($string);
    };

    our $processor = Template::AutoFilter->new($TT_OPTIONS);;
    my $output = '';
    $processor->process($template, $args, \$output) || die("Can't generate template $template: ".$processor->error);

    return $output;
}

sub redirect {
    my ($self, $url, $code) = @_;
    $self->template_output($url);
    $self->response_code($code || 301);
}

sub i18n {
    my ( $self, $msgid ) = @_;

    my $msg = gettext($msgid);
    utf8::decode($msg);

    return $msg;
}

sub ni18n {
    my ( $self, $singular, $plural, $category ) = @_;

    my $msg = ngettext( $singular, $plural, $category );
    utf8::decode($msg);

    return $msg;
}

=head2 i18n_format

Pass message id through gettext then sprintf it.

Meant to be called from the TT templates.

=cut

sub i18n_format {
    my ( $self, $msgid, @args ) = @_;
    my $msg = sprintf( gettext($msgid), @args );
    utf8::decode($msg);
    return $msg;
}

sub error {
    my ($self, $message) = @_;
    $self->render("error.html", {message => $message});
}

sub empty_flash {
    my ($self) = @_;
    $self->session->{flash} = {};
}

sub flash {
    my ($self) = @_;
    $self->session->{flash} //= {};
    return $self->session->{flash};
}

sub reset_session {
    my ($self) = @_;
    my @ignore = qw(flash destination_url);
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

