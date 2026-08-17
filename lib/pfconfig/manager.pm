package pfconfig::manager;

=head1 NAME

pfconfig::manager

=cut

=head1 DESCRIPTION

pfconfig::manager

This module controls the access, buikd and expiration of the config namespaces

This module will serve as an interface to build and cache the namespaces

It will first search in the raw in-memory cache, then the layer 2 backend (pfconfig::backend),
then it will build the associated object of the namespace

=cut

=head1 USAGE

In order to access the configuration namespaces :
- Instanciate the object
- Then call get_cache on a specific namespace in order to fetch it
- The classes that build the namespaces are located in pfconfig::namespaces

=cut

use strict;
use warnings;

use JSON::MaybeXS;
use List::MoreUtils qw(any firstval uniq);
use Scalar::Util qw(refaddr reftype tainted blessed);
use UNIVERSAL::require;
use pf::log;
use pf::util;
use Fcntl;
use Time::HiRes qw(stat time);
use File::Find;
use pfconfig::util qw(normalize_namespace_query);
use POSIX;
use POSIX::2008;
use List::MoreUtils qw(first_index);
use Tie::IxHash;
use pfconfig::config;
use pf::constants::user;
use pfconfig::git_storage;
use pf::config::crypt;
use pf::config::crypt::object;
use pf::config::crypt::object::freeze;
use Scalar::Util qw(reftype);

my $ordered_prefix = "ORDERED::";

=head2 config_builder

Builds the object associated to a namespace
See it as a mini-factory

An already constructed element can be passed as the third argument, so a caller
that had to construct one anyway does not pay for a second construction. That
matters because construction runs init(), which for most namespaces reaches the
L2 backend and deserializes a config blob.

=cut

sub config_builder {
    my ( $self, $namespace, $elem ) = @_;
    my $logger = get_logger;
    $elem //= $self->get_namespace($namespace);
    unless (defined $elem) {
        $logger->error("Cannot build unknown namespace $namespace");
        return undef;
    }
    my $tmp  = $elem->build();
    return filter_data($tmp);
}

sub filter_data {
    my ($value) = @_;
    return $value if !defined $value;
    my $ref_type = reftype($value);
    if (!defined ($ref_type)) {
        if (rindex($value, $pf::config::crypt::PREFIX, 0) == 0) {
            return pf::config::crypt::object->new($value);
        }
        return $value;
    }

    if ($ref_type eq 'ARRAY') {
        for (my $i =0;$i<@$value;$i++) {
            $value->[$i] = filter_data($value->[$i]);
        }

        return $value;
    }

    if ($ref_type eq 'HASH') {
        while (my ($k, $v) = each %$value) {
            $value->{$k} = filter_data($v);
        }

        return $value;
    }

    return $value;
}

=head2 get_namespace

Dynamicly requires the namespace module and instanciates the object associated to it

=cut

sub get_namespace {
    my ( $self, $name ) = @_;

    my $logger = get_logger;

    my $full_name = $name;

    my @args;
    ($name, @args) = pfconfig::util::parse_namespace($name);

    my $type   = "pfconfig::namespaces::$name";

    $type = untaint_chain($type);

    # load the module to instantiate
    if ( !( eval "$type->require()" ) ) {
        $logger->error( "Can not load namespace $name " . "Read the following message for details: $@" );
        return undef;
    }

    my $elem = $type->new($self, @args);

    # Record the child graph while we have an object, so child_resources_for can
    # answer without ever constructing one again. Only the list of names is kept
    # -- never the object, which pins built state and snapshots its dependencies.
    #
    # Overlays are deliberately excluded: expire treats an overlay as terminal and
    # never asks for its children, so memoising an entry per overlay argument would
    # be unbounded growth for something nothing ever reads.
    unless ($self->is_overlayed_namespace($full_name)) {
        $self->{child_resources_cache}{normalize_namespace_query($full_name)}
            = $elem->{child_resources} ? [@{$elem->{child_resources}}] : [];
    }

    return $elem;
}

=head2 child_resources_for

Returns the child resources of a namespace as an arrayref, without constructing
the namespace object when we have already seen it.

Constructing a namespace is not cheap and it is not side-effect free: most
namespaces read their dependencies with get_cache inside init, which reaches the
L2 backend and deserializes a config blob. expire only ever wanted the child
graph, so paying that per namespace and per child on every expire request made a
single `pfcmd pfconfig reload` do thousands of L2 reads -- and it deserialized
config through the shared Sereal decoder often enough to eventually corrupt
memory and segfault the daemon.

The child graph is a static property of the namespace module: every declaration
under lib/pfconfig/namespaces is a literal list, and the only two that vary
(interfaces.pm and config/Pf.pm) vary by the host_id *argument*, which is part
of the namespace key we memoise under. Module code only changes on upgrade, and
that restarts the daemon, so the memo is valid for the life of the process.

Only ever called for a static namespace: expire treats an overlay as terminal
(see the is_overlayed_namespace guard there) and list_top_namespaces walks
list_static_namespaces, so get_namespace does not memoise overlays.

Returns [] for a namespace that cannot be loaded -- get_namespace documents an
undef return, and the previous code dereferenced it blindly.

=cut

sub child_resources_for {
    my ( $self, $what ) = @_;
    $what = normalize_namespace_query($what);

    my $cached = $self->{child_resources_cache}{$what};
    return $cached if $cached;

    # get_namespace populates the memo as a side effect
    my $namespace = $self->get_namespace($what);
    unless (defined $namespace) {
        return $self->{child_resources_cache}{$what} = [];
    }

    return $self->{child_resources_cache}{$what} ||= [];
}

=head2 is_overlayed_namespace

Returns 0 if the namespace is static, 1 if it is an overlayed namespace

=cut

sub is_overlayed_namespace {
    my ($self, $base_namespace) = @_;
    if($base_namespace =~ /.*\(.+\)$/){
        return 1;
    }
    return 0;
}

=head2 overlayed_namespaces

Returns the overlayed namespaces for a static namespace
  ex :
    static namespace : "config::Pf"
    overlayed namespaces : ("config::Pf(some-argument)", "config::Pf(another-argument)")

=cut

sub overlayed_namespaces {
    my ($self, $base_namespace, $all_overlayed) = @_;

    # Namespace is an empty overlay
    if($base_namespace =~ /(.+)\(\)$/) {
        $base_namespace = $1;
    }

    # An overlayed namespace can't have overlayed namespaces
    return () if $self->is_overlayed_namespace($base_namespace);

    # Callers walking a whole tree pass the list in so it is enumerated once per
    # run rather than once per namespace (see expire)
    my @namespaces = @{ $all_overlayed // $self->all_overlayed_namespaces() };
    my @overlayed_namespaces;
    $base_namespace = quotemeta($base_namespace);
    foreach my $namespace (@namespaces){
        if($namespace =~ /^$base_namespace/){
            push @overlayed_namespaces, $namespace if $self->is_overlayed_namespace($namespace);
        }
    }
    return @overlayed_namespaces;
}

=head2 all_overlayed_namespaces

Returns an Array ref of all the overlayed namespaces persisted in the backend

=cut

sub all_overlayed_namespaces {
    my ($self) = @_;
    return [ uniq($self->{cache}->list_matching('\(.+\)$'), $self->list_control_overlayed_namespaces()) ];
}

=head2 list_control_overlayed_namespaces

List all the overlayed namespaces contained in the control directory

=cut

sub list_control_overlayed_namespaces {
    my ($self) = @_;
    my $control_dir = pfconfig::util::control_file_dir();
    my @modules;
    if(! -d $control_dir) {
        return @modules;
    }
    find(
        {   wanted => sub {
                my $module = $_;
                #Ignore directories
                return if -d $module;
                $module =~ s/$control_dir\///g;
                return if $module !~ /-control$/;
                $module =~ s/\-control$//g;
                if($module =~ /\(.*\)$/) {
                    push @modules, $module;
                }
            },
            no_chdir => 1
        },
        $control_dir
    );
    @modules = sort @modules;
    return @modules;
}

=head2 new

Constructor for the manager

=cut

sub new {
    my ($class) = @_;
    my $self = bless {}, $class;

    $self->init_cache();

    return $self;
}

=head2 init_cache

Creates the backend and internal data structures for the L1 and L2 cache

=cut

sub init_cache {
    my ($self) = @_;
    my $logger = get_logger;

    $self->{cache} = pfconfig::config->new->get_backend;
    $self->{memory}       = {};
    $self->{memorized_at} = {};
    # namespace -> child_resources arrayref; see child_resources_for
    $self->{child_resources_cache} = {};
    $self->{last_touch_cache} = time;
}

=head2 touch_cache

Updates the timestamp on the control file
That sends the signal that the raw memory is expired

=cut

sub touch_cache {
    my ( $self, $what ) = @_;
    $what =~ s/\//;/g;
    $what = normalize_namespace_query($what);
    my $filename = pfconfig::util::control_file_path($what);
    $filename = untaint_chain($filename);
    touch_file($filename);
    $self->{last_touch_cache} = $pfconfig::cached::LAST_TOUCH_CACHE = $pfconfig::cached::RELOADED_TOUCH_CACHE = time;
}

=head2 delete_cache_control

Deletes the control file of a namespace instead of touching it.

Used when evicting an overlayed namespace. Touching the control file (as
touch_cache does) would leave it behind for list_control_overlayed_namespaces
to rediscover on every subsequent expire, so the overlay working set could only
ever grow for the life of the daemon. Deleting it lets a no-longer-referenced
overlay drop out of the discovery set entirely; a consumer that still needs it
rebuilds it on demand (which re-creates the control file). We still bump
last_touch_cache so consumer processes invalidate their subcaches, exactly as
touch_cache does.

=cut

sub delete_cache_control {
    my ( $self, $what ) = @_;
    $what =~ s/\//;/g;
    $what = normalize_namespace_query($what);
    my $filename = pfconfig::util::control_file_path($what);
    $filename = untaint_chain($filename);
    unlink($filename);
    $self->{last_touch_cache} = $pfconfig::cached::LAST_TOUCH_CACHE = $pfconfig::cached::RELOADED_TOUCH_CACHE = time;
}

=head2 get_cache

Gets a namespace either in the L1, L2 or L3 (builds it)
Will use the memorized_at hash to know if it's still valid
It should not have to build the L3 since that's the slowest. The L3 should be built externally and this should only have to call the L2

=cut

sub get_cache {
    my ( $self, $what ) = @_;

    $what = normalize_namespace_query($what);

    my $logger = get_logger;
    # we look in raw memory and make sure that it's not expired
    my $memory = $self->{memory}{$what};
    unless (defined($memory) && $self->is_valid($what)) {
        my $cached = $self->{cache}->get($what);
        # raw memory is expired but cache is not
        if ($cached) {
            $logger->debug("Getting $what from cache backend");
            $memory = $cached;
            $self->{memory}{$what} = $cached;
            $self->{memorized_at}{$what} = time;
        } else {
            # everything is expired. need to rebuild completely
            $memory = $self->cache_resource($what);
        }
    }

    return $memory;
}

=head2 get_cache_ordered

Same as get_cache but it will order all the keys when the resource is a hash

=cut

sub get_cache_ordered {
    my ($self, $what) = @_;
    
    $what = normalize_namespace_query($what);
    
    my $memory = $self->{memory}{"$ordered_prefix$what"};

    unless (defined($memory) && $self->is_valid($what)) {
        $memory = $self->get_cache($what);
        return undef unless defined $memory;

        if(ref($memory) eq "HASH") {
            $memory = $self->tie_ixhash_copied($memory);
        }
        
        $self->{memory}{"$ordered_prefix$what"} = $memory;
    }

    return $memory;
}

=head2 post_process_element

Post processes an element fetched from the cache backend
For now, it is used only to transform non-ordered hashes into ordered ones so forked processes have the same ordering of the keys

=cut

sub post_process_element {
    my ($self, $what, $element) = @_;
    return $element;
}

=head2 tie_ixhash_copied

tie_ixhash_copied

=cut

sub tie_ixhash_copied {
    my ($self, $hash) = @_;
    tie my %copy, 'Tie::IxHash';
    my @keys = keys(%$hash);
    @keys = sort(@keys);
    @copy{@keys} = @{$hash}{@keys};
    return tied(%copy);
}

=head2 cache_resource

Builds the resource associated to a namespace and then caches it in the L1 and L2

=cut

sub cache_resource {
    my ( $self, $what ) = @_;
    my $logger = get_logger;

    $what = normalize_namespace_query($what);

    # An unknown namespace must not create any persistent state (L1, L2 or
    # control file), otherwise every bogus client key is cached forever
    my $elem = $self->get_namespace($what);
    unless (defined $elem) {
        $logger->error("Not caching unknown namespace $what");
        return undef;
    }

    $logger->debug("loading $what from outside");
    # Hand the element over rather than letting config_builder construct a second
    # one: init() is expensive and leaks through the tied pf::IniFiles reads
    my $result = $self->config_builder($what, $elem);
    # inflates the element if necessary
    $result = $self->post_process_element($what, $result);
    my $cache_w = $self->{cache}->set( $what, $result, 864000 );
    unless ($cache_w) {
        my $message = "Could not write namespace $what to L2 cache !";
        print STDERR $message . "\n";
        $logger->error($message);
    } else {
        $logger->trace("Cache write gave : $cache_w");
    }
    if($self->{pfconfig_server}) {
        $self->touch_cache($what);
    }
    else {
        if(!pfconfig::git_storage->is_enabled) {
            pfconfig::util::socket_expire(namespace => $what, light => 1);
        }
    }
    $self->{memory}->{$what}       = $result;
    delete $self->{memory}->{"$ordered_prefix$what"};
    $self->{memorized_at}->{$what} = time;

    return $result;

}

=head2 is_valid

Method that is used to determine if the object has been refreshed in pfconfig
Uses the control files in var/control and the memorized_at hash to know if a namespace has expired

=cut

sub is_valid {
    my ( $self, $what ) = @_;
    my $logger         = get_logger;
    my $control_file   = pfconfig::util::control_file_path($what);
    my $file_timestamp = ( stat($control_file) )[9];

    unless ( defined($file_timestamp) ) {
        $logger->warn(
            "Filesystem timestamp is not set for $what. Setting it as now and considering memory as invalid."
        );
        $self->touch_cache($what);
        return 0;
    }

    my $memory_timestamp = $self->{memorized_at}->{$what} // 0;
    $logger->trace(
        "Control file has timestamp $file_timestamp and memory has timestamp $memory_timestamp for key $what"
    );

    # if the timestamp of the file is after the one we have in memory
    # then we are expired
    if ( $memory_timestamp >= $file_timestamp ) {
        $logger->trace("Memory configuration is still valid for key $what");
        return 1;
    }
    else {
        $logger->debug("Memory configuration is not valid anymore for key $what");
        return 0;
    }
}

=head2 expire

Expire a namespace in the cache and rebuild it
If the namespace has child resources, it expires them too.
Will expire the memory cache after building

If expiring an overlayed namespace, it doesn't expire it's child resources as it's considered as a final resource to not duplicate expiration during it's associated namespace.

To fully expire a namespace with it's child resources and overlayed namespaces, the non-overlayed namespace must be passed to expire

=cut

sub expire {
    my ( $self, $what, $light, $ctx ) = @_;
    $what = normalize_namespace_query($what);

    # Per-run context, threaded through the recursion.
    #
    # seen: deduplicate within a single expiry run. A resource is a child of many
    # namespaces (e.g. resource::RolesReverseLookup is declared under 13 of
    # them), so without this guard expire_all rebuilds the same expensive
    # resources dozens of times. Rebuilding once per run is sufficient since
    # the configuration is static for the duration of the run.
    #
    # overlays: enumerating the overlays costs an L2 query plus a scan of the
    # control directory, and it does not change during a run, so do it once here
    # instead of once per namespace and per child.
    #
    # Callers outside this module pass no context: they expire a single namespace
    # and let both defaults below fill themselves in.
    $ctx //= {};
    $ctx->{seen}     //= {};
    $ctx->{overlays} //= $self->all_overlayed_namespaces();

    return if $ctx->{seen}{$what};
    $ctx->{seen}{$what} = 1;

    my $logger = get_logger;
    if($self->is_overlayed_namespace($what)){
        # Overlayed namespaces (name(arg)) are consumer-driven: rebuilding
        # them here would resurrect every argument ever requested, growing
        # the L1/L2 caches forever. Evict them instead; the next request
        # rebuilds them on demand like any cold key.
        $logger->info("Evicting overlayed resource : $what");
        delete $self->{memory}->{$what};
        delete $self->{memorized_at}->{$what};
        $self->{cache}->remove($what);
        # Delete (not touch) the control file so this overlay stops being
        # rediscovered by list_control_overlayed_namespaces on every expire.
        # Leaving it behind would keep the overlay working set growing forever
        # (see delete_cache_control). Consumers still see the change via the
        # last_touch_cache bump, and the overlay rebuilds on demand if needed.
        $self->delete_cache_control($what);
    }
    elsif(defined($light) && $light){
        $logger->info("Light expiring resource : $what");
        delete $self->{memorized_at}->{$what};
        $self->touch_cache($what);
    }
    else {
        $logger->info("Hard expiring resource : $what");
        $self->cache_resource($what);
    }

    delete $self->{memory}->{"$ordered_prefix$what"};

    unless($self->is_overlayed_namespace($what)){
        # expire overlayed namespaces
        my @overlayed_namespaces = $self->overlayed_namespaces($what, $ctx->{overlays});
        foreach my $overlayed (@overlayed_namespaces){
            # prevent deep recursion on namespace itself
            next if $overlayed eq $what;

            $logger->info("Expiring overlayed resource from base resource $what.");
            $self->expire($overlayed, $light, $ctx);
        }

        foreach my $child_resource ( @{ $self->child_resources_for($what) } ) {
            $logger->info("Expiring child resource $child_resource. Master resource is $what");
            $self->expire($child_resource, $light, $ctx);
        }
    }
}

=head2 list_namespaces

Method that lists the namespaces available to pfconfig
Has an ignore list declared below

=cut

sub list_namespaces {
    my ( $self, $what ) = @_;

    my $static_namespaces = $self->list_static_namespaces();
    my $overlayed_namespaces = $self->all_overlayed_namespaces;
    return (@$static_namespaces, @$overlayed_namespaces);
}

our %skip = ( 'config'=> 1, 'resource'=> 1, 'config::template'=> 1, 'FilterEngine::AccessScopes' => 1 );

sub list_static_namespaces {
    my $namespace_dir = "/usr/local/pf/lib/pfconfig/namespaces";
    my @modules;
    find(
        {   wanted => sub {
                my $module = $_;
                #Ignore directories
                return if -d $module;
                return unless $module =~ /\.pm$/;
                $module =~ s/$namespace_dir\///g;
                $module =~ s/\.pm$//g;
                $module =~ s/\//::/g;
                return if $module =~ /::\..*$/;
                return if $module =~ /^\..*$/;
                return if exists $skip{$module};
                push @modules, $module;
            },
            no_chdir => 1
        },
        $namespace_dir
    );
    @modules = sort @modules;
    return \@modules;
}

sub list_top_namespaces {
    my ( $self ) = @_;
    my $static_namespaces = $self->list_static_namespaces();
    my @children;
    my @top_level_namespaces;

    foreach my $namespace (@$static_namespaces){
        push @children, @{ $self->child_resources_for($namespace) };
    }

    foreach my $namespace (@$static_namespaces){
        push @top_level_namespaces, $namespace unless any { $_ eq $namespace } @children;
    }

    return @top_level_namespaces;
}

=head2 preload_all

Method that preloads all the objects through the get_cache method
Will build the object if needed and make sure it's in L1

=cut

sub preload_all {
    my ($self) = @_;
    my @namespaces = $self->list_namespaces;
    print "\n------------------\n";
    foreach my $namespace (@namespaces) {
        if ( !defined $namespace || $namespace eq '' ) {
            print "Skipping empty namespace\n";
            next;
        }
        $namespace = normalize_namespace_query($namespace);

        print "Preloading $namespace\n";
        $self->get_cache($namespace);
        $self->config_builder($namespace);
    }
    print "------------------\n";
}

=head2 expire_all

Method that expires all the namespaces defined by list_namespaces

=cut

sub expire_all {
    my ($self, $light) = @_;
    my $logger = get_logger;
    my @namespaces = $self->list_top_namespaces;
    # Enumerate the overlays once for the whole run rather than once per
    # namespace and per child; see expire
    my $ctx = { seen => {}, overlays => $self->all_overlayed_namespaces() };
    foreach my $namespace (@namespaces) {
        $self->expire($namespace, $light, $ctx);
    }

    # Anything left in L1 that the expiry run did not reach is a namespace
    # that no longer exists; drop it so a full expire returns the memory
    # cache to exactly the live namespace set
    foreach my $key (keys %{$self->{memory}}) {
        my $base = $key;
        $base =~ s/^\Q$ordered_prefix\E//;
        next if $ctx->{seen}{$base};
        $logger->info("Pruning stale resource from memory : $key");
        delete $self->{memory}->{$key};
        delete $self->{memorized_at}->{$key};
    }
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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

1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

