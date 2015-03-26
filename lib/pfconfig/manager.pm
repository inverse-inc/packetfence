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

#use Cache::BDB;
use Cache::Memcached;
use Config::IniFiles;
use List::MoreUtils qw(any firstval uniq);
use Scalar::Util qw(refaddr reftype tainted blessed);
use UNIVERSAL::require;
use pfconfig::backend::mysql;
use pfconfig::log;
use pf::util;
use Time::HiRes qw(stat time);
use File::Find;
use pfconfig::util;
use POSIX;
use POSIX::2008;
use JSON;
use List::MoreUtils qw(first_index);

=head2 config_builder

Builds the object associated to a namespace
See it as a mini-factory

=cut

sub config_builder {
    my ( $self, $namespace ) = @_;
    my $logger = pfconfig::log::get_logger;

    my $elem = $self->get_namespace($namespace);
    my $tmp  = $elem->build();

    return $tmp;
}

=head2 get_namespace

Dynamicly requires the namespace module and instanciates the object associated to it

=cut

sub get_namespace {
    my ( $self, $name ) = @_;

    my $logger = pfconfig::log::get_logger;

    my $full_name = $name;

    my @args;
    ($name, @args) = pfconfig::util::parse_namespace($name);
    my $args_size = @args;
    if($args_size){
        $self->add_namespace_to_overlay($full_name);
    }

    my $type   = "pfconfig::namespaces::$name";

    $type = untaint_chain($type);

    # load the module to instantiate
    if ( !( eval "$type->require()" ) ) {
        $logger->error( "Can not load namespace $name " . "Read the following message for details: $@" );
    }

    my $elem = $type->new($self, @args);

    return $elem;
}

sub add_namespace_to_overlay {
    my ($self, $namespace) = @_;
    my $logger = pfconfig::log::get_logger;
    $logger->info("We're doing namespace overlaying for $namespace");
   
    my $namespaces = $self->{cache}->get('_namespace_overlay') || ();

    my $ns_index = first_index {$_ eq $namespace} @$namespaces;
    if($ns_index == -1){
        push @$namespaces, $namespace;
    }
    $self->{cache}->set('_namespace_overlay', $namespaces);
}

sub overlayed_namespaces {
    my ($self, $base_namespace) = @_;
    if($base_namespace =~ /.*\(.+\)/){
        return ();
    }
    my $namespaces_ref = $self->{cache}->get('_namespace_overlay');
    my @namespaces = defined($namespaces_ref) ? @$namespaces_ref : ();
    my @overlayed_namespaces;
    $base_namespace = quotemeta($base_namespace);
    foreach my $namespace (@namespaces){
        if($namespace =~ /^$base_namespace/){
            push @overlayed_namespaces, $namespace;
        }
    }
    return @overlayed_namespaces;
}

sub clear_overlayed_namespaces {
    my ($self) = @_;
    $self->{cache}->set('_namespace_overlay', undef);
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
    my $logger = pfconfig::log::get_logger;

    $self->{cache} = pfconfig::backend::mysql->new;

    $self->{memory}       = {};
    $self->{memorized_at} = {};
}

=head2 touch_cache

Updates the timestamp on the control file
That sends the signal that the raw memory is expired

=cut

sub touch_cache {
    my ( $self, $what ) = @_;
    my $logger = pfconfig::log::get_logger;
    $what =~ s/\//;/g;
    my $filename = pfconfig::util::control_file_path($what);
    $filename = untaint_chain($filename);

    if ( !-e $filename ) {
        my $fh;
        unless ( open( $fh, ">$filename" ) ) {
            $logger->error("Can't create $filename\nPlease run 'pfcmd fixpermissions'");
            return 0;
        }
        close($fh);
    }
    if ( -e $filename ) {
        sysopen( my $fh, $filename, O_RDWR | O_CREAT );
        POSIX::2008::futimens( fileno $fh );
        close($fh);
    }
    my ( undef, undef, $uid, $gid ) = getpwnam('pf');
    chown( $uid, $gid, $filename );
}

=head2 get_cache

Gets a namespace either in the L1, L2 or L3 (builds it)
Will use the memorized_at hash to know if it's still valid
It should not have to build the L3 since that's the slowest. The L3 should be built externally and this should only have to call the L2

=cut

sub get_cache {
    my ( $self, $what ) = @_;
    my $logger = pfconfig::log::get_logger;

    # we look in raw memory and make sure that it's not expired
    my $memory = $self->{memory}->{$what};
    if ( defined($memory) && $self->is_valid($what) ) {
        $logger->debug("Getting $what from memory");
        return $memory;
    }
    else {
        my $cached = $self->{cache}->get($what);

        # raw memory is expired but cache is not
        if ($cached) {
            $logger->debug("Getting $what from cache backend");
            $self->{memory}->{$what}       = $cached;
            $self->{memorized_at}->{$what} = time;
            return $cached;
        }

        # everything is expired. need to rebuild completely
        else {
            my $result = $self->cache_resource($what);
            return $result;
        }
    }

}

=head2 cache_resource

Builds the resource associated to a namespace and then caches it in the L1 and L2

=cut

sub cache_resource {
    my ( $self, $what ) = @_;
    my $logger = pfconfig::log::get_logger;

    $logger->debug("loading $what from outside");
    my $result = $self->config_builder($what);
    my $cache_w = $self->{cache}->set( $what, $result, 864000 );
    $logger->trace("Cache write gave : $cache_w");
    unless ($cache_w) {
        my $message = "Could not write namespace $what to L2 cache ! This is bad.";
        print STDERR $message . "\n";
        $logger->error($message);
    }
    $self->touch_cache($what);
    $self->{memory}->{$what}       = $result;
    $self->{memorized_at}->{$what} = time;

    return $result;

}

=head2 is_valid

Method that is used to determine if the object has been refreshed in pfconfig
Uses the control files in var/control and the memorized_at hash to know if a namespace has expired

=cut

sub is_valid {
    my ( $self, $what ) = @_;
    my $logger         = pfconfig::log::get_logger;
    my $control_file   = pfconfig::util::control_file_path($what);
    my $file_timestamp = ( stat($control_file) )[9];

    unless ( defined($file_timestamp) ) {
        $logger->warn(
            "Filesystem timestamp is not set for $what. Setting it as now and considering memory as invalid."
        );
        $self->touch_cache($what);
        return 0;
    }

    my $memory_timestamp = $self->{memorized_at}->{$what};
    $logger->trace(
        "Control file has timestamp $file_timestamp and memory has timestamp $memory_timestamp for key $what"
    );

    # if the timestamp of the file is after the one we have in memory
    # then we are expired
    if ( $memory_timestamp > $file_timestamp ) {
        $logger->trace("Memory configuration is still valid for key $what");
        return 1;
    }
    else {
        $logger->info("Memory configuration is not valid anymore for key $what");
        return 0;
    }
}

=head2 expire

Expire a namespace in the cache and rebuild it
If the namespace has child resources, it expires them too.
Will expire the memory cache after building

=cut

sub expire {
    my ( $self, $what, $light ) = @_;
    my $logger = pfconfig::log::get_logger;
    if(defined($light) && $light){
        $logger->info("Light expiring resource : $what");
        delete $self->{memorized_at}->{$what};
        $self->touch_cache($what);
    }
    else {
        $logger->info("Hard expiring resource : $what");
        $self->cache_resource($what);
    }

    my $namespace = $self->get_namespace($what);
    if ( $namespace->{child_resources} ) {
        foreach my $child_resource ( @{ $namespace->{child_resources} } ) {
            $logger->info("Expiring child resource $child_resource. Master resource is $what");
            $self->expire($child_resource, $light);
        }
    }

    # expire overlayed namespaces
    my @overlayed_namespaces = $self->overlayed_namespaces($what);
    foreach my $namespace (@overlayed_namespaces){
        $logger->info("Expiring overlayed resource from base resource $what.");
        $self->expire($namespace, $light);
    }
}

=head2 list_namespaces

Method that lists the namespaces available to pfconfig
Has an ignore list declared below

=cut

sub list_namespaces {
    my ( $self, $what ) = @_;
    my @skip = ( 'config', 'resource', 'config::template', );
    my $namespace_dir = "/usr/local/pf/lib/pfconfig/namespaces";
    my @modules;
    find(
        {   wanted => sub {
                my $module = $_;
                return if $module eq $namespace_dir;
                $module =~ s/$namespace_dir\///g;
                $module =~ s/\.pm$//g;
                $module =~ s/\//::/g;
                return if $module =~ /::\..*$/;
                return if $module =~ /^\..*$/;
                return if grep( /^$module$/, @skip );
                push @modules, $module;
            },
            no_chdir => 1
        },
        $namespace_dir
    );
    my $overlayed_namespaces = $self->{cache}->get('_namespace_overlay') || [];
    return (@modules, @$overlayed_namespaces);
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
        print "Preloading $namespace\n";
        $self->get_cache($namespace);
    }
    print "------------------\n";
}

=head2 expire_all

Method that expires all the namespaces defined by list_namespaces

=cut

sub expire_all {
    my ($self, $light) = @_;
    my $logger = pfconfig::log::get_logger;
    my @namespaces = $self->list_namespaces;
    foreach my $namespace (@namespaces) {
        if(defined($light) && $light){
            $logger->info("Light expiring $namespace");
            delete $self->{memorized_at}->{$namespace};
        }
        else{
            $logger->info("Hard expiring $namespace");
            $self->expire($namespace);
        }
    }
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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

