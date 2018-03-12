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
use pf::util;
use pf::config::util;
use List::MoreUtils qw(any);
use URI::Escape::XS qw(uri_unescape);
use HTML::Entities;
use pf::constants::web qw($USER_AGENT_CACHE_EXPIRATION);
use pf::web ();
use pf::api::queue;
use pf::file_paths qw($install_dir);
use pf::config qw(%Config);

has 'session' => (is => 'rw', required => 1);

has 'user_session' => (is => 'rw', required => 1);

has 'root_module' => (is => 'rw', isa => "captiveportal::DynamicRouting::Module::Root");

has 'root_module_id' => (is => 'rw');

has 'request' => (is => 'ro', required => 1);

has 'hashed_params' => (is => 'rw');

has 'profile' => (is => 'rw', required => 1, isa => "pf::Connection::Profile");

has 'template_output' => (is => 'rw');

has 'response_code' => (is => 'rw', isa => 'Int', default => sub{200});

has 'title' => (is => 'rw', isa => 'Str|ArrayRef');

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

=head2 process_fingerbank

Fingerbank processing

=cut

sub process_fingerbank {
    my ( $self ) = @_;

    my $attributes = pf::fingerbank::endpoint_attributes($self->current_mac);
    if($attributes->{most_accurate_user_agent} ne $self->current_user_agent) {
        pf::fingerbank::update_collector_endpoint_data($self->current_mac, {
            most_accurate_user_agent => $self->current_user_agent,
            user_agents => {$self->current_user_agent => $TRUE},
        });
    }

    my $client = pf::api::queue->new(queue => 'general');
    $client->notify('fingerbank_process', $self->current_mac);
}

=head2 current_module_id

Get or set the current module ID

=cut

sub current_module_id {
    my ($self, $module_id) = @_;
    if(defined($module_id)){
        get_logger->debug("Setting current module id : $module_id");
        $self->session->{current_module_id} = $module_id;
    }
    else {
        return $self->session->{current_module_id};
    }
}

=head2 current_module

Get the current module as an object

=cut

sub current_module {
    my ($self) = @_;
    return defined($self->current_module_id) ? $captiveportal::PacketFence::DynamicRouting::Factory::INSTANTIATED_MODULES{$self->current_module_id} : undef;
}

=head2 previous_module_id

Get or set the previous module id

=cut

sub previous_module_id {
    my ($self, $module_id) = @_;
    if(defined($module_id)){
        get_logger->debug("Setting previous module id : $module_id");
        $self->session->{previous_module_id} = $module_id;
    }
    else {
        return $self->session->{previous_module_id};
    }
}

sub detect_first_action {
    my ($self) = @_;
    if(defined($self->previous_module_id) && defined($self->current_module_id)
        && $self->previous_module_id ne $self->current_module_id){
        $self->session->{action_made} = $TRUE;
    }
    $self->session->{action_made} //= $FALSE;
    return $self->session->{action_made};
}

=head2 preprocessing

Processing that needs to occur before we execute the application

=cut

sub preprocessing {
    my ($self) = @_;
    my $timer = pf::StatsD::Timer->new({sample_rate => 0.05, level => 6});
    $self->process_destination_url();
    $self->process_fingerbank();
}

=head2 execute

Application execution
This will cycle through the proper modules and the appropriate module will set template_output and status

=cut

sub execute {
    my ($self) = @_;
    my $timer = pf::StatsD::Timer->new({sample_rate => 0.05, level => 6});
    # This will be defined after the first time the user hits the dynamic routing portal
    # Then will be true on the second time he hits the dynamic routing portal
    $self->root_module->execute();
    unless(defined($self->previous_module_id) && $self->previous_module_id eq $self->current_module_id){
        $self->previous_module_id($self->current_module_id);
    }
}

=head2 current_user_agent

The current user agent in the request.
Returns an empty string if it is undefined

=cut

sub current_user_agent {
    my ($self) = @_;
    return $self->request->user_agent ? $self->request->user_agent : "";
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
    my $url = $self->session->{user_destination_url};

    # Return connection profile's redirection URL if destination_url is not set or if redirection URL is forced
    if (!defined($url) || !$url || isenabled($self->profile->forceRedirectURL)) {
        $url = $self->profile->getRedirectURL;
    }

    my $host;
    eval {
        $host = URI::URL->new($url)->host();
    };
    if($@) {
        get_logger->info("Invalid destination_url $url. Replacing with profile defined one.");
        $url = $self->profile->getRedirectURL;
    }


    my @portal_hosts = portal_hosts();
    # if the destination URL points to the portal, we put the default URL of the connection profile
    if ( any { $_ eq $host } @portal_hosts) {
        get_logger->info("Replacing destination URL $url since it points to the captive portal");
        $url = $self->profile->getRedirectURL;
    }

    # if the destination URL points to a network detection URL, we put the default URL of the connection profile
    if ( any { $_ eq $url } @{$Config{captive_portal}{detection_mecanism_urls}}) {
        get_logger->info("Replacing destination URL $url since it is a network detection URL");
        $url = $self->profile->getRedirectURL;
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
    my $profile = $self->profile;

    my $layout_args = {
        flash => $self->flash,
        content => $inner_content,
        client_mac => $self->current_mac,
        client_ip => $self->current_ip,
        title => $self->title,
        logo => $profile->getLogo,
        profile => $profile,
    };

    $args->{layout} //= $TRUE;
    $args->{raw} //= $FALSE;
    if($args->{raw}){
        $args->{layout} = $FALSE;
    }

    my $content = $args->{layout} ? $self->_render('layout.html', $layout_args) : $inner_content;

    $self->template_output($content);

    $self->empty_flash();
}

=head2 _render

Render a template using Template Toolkit.

=cut

sub _render {
    my ($self, $template, $args) = @_;
    $template = $self->profile->getLocalizedTemplate($template);

    if(defined($args->{title})){
        $self->title($args->{title});
    }

    # define list method to return new list of odd numbers only
    $args->{ i18n } = sub {
        return $self->i18n(@_);
    };
    $args->{ i18n_format } = sub {
        return $self->i18n_format(@_);
    };

    get_logger->debug(sub { "Previous : ". ($self->previous_module_id // "undef") . ", Current module : " . ($self->current_module_id // "undef") });
    $self->detect_first_action();
    $args->{ show_restart } //= $self->session->{action_made};

    # Expose current module in all templates
    $args->{current_module} = $self->current_module;

    # Expose the preregistration flag in all templates
    $args->{preregistration} = $self->preregistration;

    my $processor = Template::AutoFilter->new($self->_template_toolkit_options($args));

    my $output = '';
    $processor->process($template, $args, \$output) || die("Can't generate template $template: ".$processor->error."Error : ".$@);

    return $output;
}

sub _template_toolkit_options {
    my ($self, $args) = @_;
    my $options = {
        AUTO_FILTER => 'html',
        RELATIVE => 1,
        PRE_PROCESS => 'macros.inc',
        INCLUDE_PATH => $self->profile->{_template_paths},
        ENCODING => 'utf8',
        COMPILE_DIR => $install_dir . "/var/tt_compile_cache",
        COMPILE_EXT => '.compiled.template',
    };
    if($args->{raw}){
        $options->{AUTO_FILTER} = 'none';
        delete $options->{PRE_PROCESS};
    }
    return $options;
}

=head2 redirect

Create a response that will redirect the user

=cut

sub redirect {
    my ($self, $url, $code) = @_;
    $self->detect_first_action();
    $self->template_output($url);
    $self->response_code($code || 302);
}

=head2 i18n

Internationalize a string

=cut

sub i18n {
    my ( $self, $msgid ) = @_;

    return pf::web::i18n($msgid);
}

=head2 ni18n

Internationalize a string that can be singular/plural

=cut

sub ni18n {
    my ( $self, $singular, $plural, $category ) = @_;

    return pf::web::n18n($singular, $plural, $category);
}

=head2 i18n_format

Pass message id through gettext then sprintf it.

=cut

sub i18n_format {
    my ( $self, $msgid, @args ) = @_;
    return pf::web::i18n_format($msgid, @args);
}

=head2 error

Create the template for an error

=cut

sub error {
    my ($self, $message) = @_;
    $self->render("error.html", {message => $message, title => "An error occured"});
}

=head2 empty_flash

Empty the flash

=cut

sub empty_flash {
    my ($self) = @_;
    if($self->user_session){
        $self->user_session->{flash} = {};
    }
    else {
        get_logger->warn("There is no user session in this request. Cannot delete its flash");
    }
}

=head2 flash

Access the flash

=cut

sub flash {
    my ($self) = @_;
    if($self->user_session){
        $self->user_session->{flash} //= {};
        return $self->user_session->{flash};
    }
    else {
        get_logger->warn("There is no user session in this request. Cannot create its flash. The flash will only exist for this request.");
        return {};
    }
}

=head2 reset_session

Reset the session except for attributes that are not related to the device state

=cut

sub reset_session {
    my ($self) = @_;
    my @ignore = qw(destination_url client_mac client_ip);
    foreach my $key (keys %{$self->session}){
        next if(any { $key eq $_ } @ignore);
        delete $self->session->{$key};
    }
}

=head2 preregistration

Whether or not we are currently doing pre-registration

=cut

sub preregistration {
    my ($self) = @_;
    return isenabled($self->profile->{_preregistration});
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

