package pf::config::cached;
=head1 NAME

pf::config::cached

=head1 DESCRIPTION

pf::config::cached object is a proxy for a cached (in CHI) Config::IniFiles object

=head1 SYNOPSIS

By default the pf::cached::object is interally cached keyed by file path.

So multiple calls to pf::config::cached->new with the same file path will results to the same object being return.

Simple usage

 use pf::config::cached;
 $cached_config = pf::config::cached->new( -file => 'file.conf');

Using as an tied hash

  use pf::config::cached;
  tie my %Config, 'pf::config::cached' => (-file => 'file.conf');

Tying an hash using an existing pf::config::cached object

  use pf::config::cached;
  $cached_config = pf::config::cached->new( -file => 'file.conf');
  tie my %Config, $cached_config;

Creating a pf::config::cached object with some callbacks

  use pf::config::cached;
  $cached_config = pf::config::cached->new(
    -file => 'file.conf'
    -onreload => [
        onreload_config => sub { ...  },
    ],
    -onfilereload => [
        onfilereload_config => sub { ...  },
    ],
  );

=head1 BEST PRACTICES

=head2 Callbacks

=head3 Types of callbacks

=head4 onreload

onreload callbacks are called whenever the config is loaded from the filesystem or the cache

=head4 onfilereload

onfilereload callbacks are called whenever the config is loaded only from the filesystem

=head3 Behavior

The callbacks are triggered by calling ReadConfig and there has been a change in the cache or filesystem.
  $config->ReadConfig()

To reload all the configs that have been created call ReloadConfigs

Call unloadConfig to avoid a config from being re-read when ReloadConfigs is call.
  $config->unloadConfig()

The order callbacks are called
  1) onreload callbacks in order of insertion
  2) onfilereload callbacks in order of insertion

=head3 Adding callbacks

All callbacks are named to ensure the same callback is added only once

=head4 At creation of object

All callbacks will be called after creating an object or recieving it from the cache.
If recieved from the cache it will replace any existing callbacks with the same name

Example:
  $cached_config = pf::config::cached->new(
    -file => 'file.conf'
    -onreload => [
        onreload_config => sub { ...  },
    ],
    -onfilereload => [
        onfilereload_config => sub { ...  },
    ],
  );

=head4 Add to an existing pf::config::cached object

If the name already exists it just replaces the previous callback keeping it's calling order

The new callbacks will not be called so would need to call them yourself.

Adding new callback example
    $cached_config->addReloadCallbacks( 'onreload_do_something_else' => sub {...}  );
    $cached_config->addFileReloadCallbacks( 'onfilereload_do_something_else' => sub {...}  );


Adding new callback then calling them after

    my $callback = sub {...};
    $cached_config->addReloadCallbacks('callback_name' => $callback);
    $callback($cached_config,callback_name);


=head3 Removing callbacks

Currently not supported

=head2 Libraries

A quick guide on how to use in a library

=head3 Singleton

By default pf::config::cached are singleton so you only initialize them once

They should stored in a package variable

=head3 Readonly

If you are only reading the data and not using to create other data then these methods are safe to use val, exists, Sections, SectionExists, Parameters, Groups, GroupMembers, GetFileName

=head3 Modifing data in the config

If the library is not responsible for modify data in the cache then never call any methods that modify data.

If the library is responsible for modify data always perform the RewriteConfig at the latest time.

=head3 Setting up data

If the library is reading configuration data to setup global variables.

Then it must use callbacks in ensure the after the config is reloaded it will update it's data.

Example:
  use pf::config::cached;
  my %hash;
  my = $cached_config = pf::config::cached->new(
    -file => 'file.conf'
    -onreload => [
      onreload_config => sub {
        my ($config,$name) = @_;
        $config->toHash(\%hash);
        $config->cleanupWhitespace(\%hash);
      },
    ],
  );

=head3 Reloading configurations

In general reloading configurations should only happen at the start or end of an event loop to ensure the latest data is loaded.
A good rule to follow if a function is consumed by others for other than initialization then do not call $config->ReadConfig() or ReloadConfigs().

=head2 Daemons

=head3 When to Reload

It is best reload the data before event loop begins or after the event loop ends

=head3 Using the configuration

=head4 Copying to non global variables

The safest way (but not the most effecient way) is to copy the configuration to a temporary variable

Example:
  $config->toHash(\%hash);

=head4 Setting up global variables

If the daemon is reading configuration data to setup global variables.

Then it must use callbacks in ensure the after the config is reloaded it will update it's data.

Example:
  use pf::config::cached;
  my %hash;
  my = $cached_config = pf::config::cached->new(
    -file => 'file.conf'
    -onreload => [
      onreload_config => sub {
        my ($config,$name) = @_;
        $config->toHash(\%hash);
        $config->cleanupWhitespace(\%hash);
      },
    ],
  );


=head2 Catalyst

=head3 When to Reload

This ideally should be done in the begin action of a Catalyst controller

sub begin :Private { pf::config::cached::ReloadConfigs(); }

=cut

use strict;
use warnings;
use constant INSTALL_DIR => '/usr/local/pf';
use lib INSTALL_DIR . "/lib";
use CHI;
use CHI::Driver::Memcached;
use CHI::Driver::RawMemory;
use Config::IniFiles;
use Scalar::Util qw(refaddr);
use Fcntl qw(:DEFAULT :flock);
use Storable;
use File::Flock;
use Readonly;
use Sub::Name;
use Log::Log4perl qw(get_logger);
use List::Util qw(first);


our $CACHE;
our %LOADED_CONFIGS;
our %ON_RELOAD;
our %ON_FILE_RELOAD;
our @ON_DESTROY_REFS = (
    \%ON_RELOAD,
    \%ON_FILE_RELOAD,
);
use overload "%{}" => \&config, fallback => 1;

our $chi_config = Config::IniFiles->new( -file => INSTALL_DIR . "/conf/chi.conf");

Readonly::Scalar our $WRITE_PERMISSIONS => '0664';

=head1 METHODS

=head2 new

Creates a new pf::config::cached

Accepts all the arguements from L<Config::IniFiles-E<gt>new|Config::IniFiles/new>
With the the following additional arguements

=over

=item I<-file>  filename * required

The pathname of a file of the configuration file
The file does need to exist
This will the key used for store the cached config

=item I<-onreload> [name => sub {...}]

This is an array ref that contains pairs of strings and sub references
The sub reference is passed the pf::config::cached object and the name of the callback

=item I<-onfilereload> [name => sub {...}]

This is an array ref that contains pairs of strings and sub references
The sub reference is passed the pf::config::cached object and the name of the callback

=back

=cut

sub new {
    my ($proto,%params) = @_;
    my $class = ref($proto) || $proto;
    my $self;
    my $file = $params{'-file'};
    my $config;
    my $onReload = delete $params{'-onreload'} || [];
    my $onFileReload = delete $params{'-onfilereload'} || [];
    if($file) {
        if(exists $LOADED_CONFIGS{$file}) {
            $self = $LOADED_CONFIGS{$file};
            #Adding the reload and filereload callbacks
            $self->addReloadCallbacks(@$onReload) if @$onReload;
            $self->addFileReloadCallbacks(@$onFileReload) if @$onFileReload;
            #Rereading the config to ensure the latest version
            $self->ReadConfig();
        } else {
            delete $params{'-file'} unless -e $file;
            $config = $class->computeFromPath(
                $file,
                sub {
                    my $lock = lockFileForReading($file);
                    my $config = Config::IniFiles->new(%params);
                    unlockFilehandle($lock);
                    $config->SetFileName($file);
                    $config->SetWriteMode($WRITE_PERMISSIONS);
                    return $config;
                }
            );
        }
    } else {
        die "param -file missing or empty";
    }
    if ($config) {
        $self = \$config;
        $LOADED_CONFIGS{$file} = $self;
        $ON_RELOAD{$file} = [];
        $ON_FILE_RELOAD{$file} = [];
        bless $self,$class;
        $self->addReloadCallbacks(@$onReload) if @$onReload;
        $self->addFileReloadCallbacks(@$onFileReload) if @$onFileReload;
        $self->_callReloadCallbacks();
        $self->_callFileReloadCallbacks();
    }
    return $self;
}

=head2 config

access for the proxied Config::IniFiles object

=cut

sub config { ${$_[0]}}

=head2 RewriteConfig

Will Rewrite the config using the filename passed to it and update the cache with the latest caches.
And run the onreload and onfilereload callbacks if successful

=cut

sub RewriteConfig {
    my ($self) = @_;
    my $logger = get_logger();
    my $config = $self->config;
    my $file = $config->GetFileName;
    my $cache = $self->cache;
    my $cached_object = $cache->get_object($file);
    if( -e $file && $cached_object && $self->_expireIf($cached_object,$file)) {
        die "Config $file was modified from last loading";
    }
    my $result;
    my $lock = lockFileForWriting($file);
    if ( exists $config->{imported} && defined $config->{imported}) {
        #localizing for saving only what is in
        local $config->{v} = Config::IniFiles::_deepcopy($config->{v});
        local $config->{sCMT} = Config::IniFiles::_deepcopy($config->{sCMT});
        local $config->{pCMT} = Config::IniFiles::_deepcopy($config->{pCMT});
        local $config->{EOT} = Config::IniFiles::_deepcopy($config->{EOT});
        local $config->{parms} = Config::IniFiles::_deepcopy($config->{parms});
        local $config->{myparms} = Config::IniFiles::_deepcopy($config->{myparms});
        local $config->{sects} = Config::IniFiles::_deepcopy($config->{sects});
        local $config->{group} = Config::IniFiles::_deepcopy($config->{group});
        local $config->{mysects} = Config::IniFiles::_deepcopy($config->{mysects});
        $self->removeDefaultValues();
        $result = $config->RewriteConfig();
    } else {
        $result = $config->RewriteConfig();
    }
    if($result) {
        $config = $self->computeFromPath(
            $file,
            sub { return $config; }, 1
        );
        $self->_callReloadCallbacks();
        $self->_callFileReloadCallbacks();
    }
    unlockFilehandle($lock);
    return $result;
}

=head2 _callReloadCallbackss

call all reload callbacks

=cut

sub _callReloadCallbacks {
    my ($self) = @_;
    my $file = $self->GetFileName;
    my $on_reload = $ON_RELOAD{$file};
    foreach my $callback_data ( @$on_reload) {
        $callback_data->[1]->($self,$callback_data->[0]);
    }
}

=head2 _callFileReloadCallbackss

call all the file reload callbacks

=cut

sub _callFileReloadCallbacks {
    my ($self) = @_;
    my $file = $self->GetFileName;
    my $on_file_reload = $ON_FILE_RELOAD{$file};
    foreach my $callback_data ( @$on_file_reload) {
        $callback_data->[1]->($self,$callback_data->[0]);
    }
}


=head2 removeDefaultValues

Will removed all the default values in current config

=cut

sub removeDefaultValues {
    my ($self) = @_;
    my $config = $self->config;
    if (exists $config->{imported} && defined $config->{imported}) {
        my $imported = $config->{imported};
        foreach my $section ( $config->Sections ) {
            next if ( !$imported->SectionExists($section) );
            foreach my $parameter ( $config->Parameters($section) ) {
                next if ( !$imported->exists($section, $parameter) );
                my $config_val = $config->val($section, $parameter);
                my $default_val = $imported->val($section, $parameter);
                if ( !defined ($config_val) || $config_val eq $default_val  ) {
                    $config->delval($section, $parameter);
                }
            }
            if ($config->Parameters($section) == 0) {
                $config->DeleteSection($section);
            }
        }
    }
}

=head2 lockFileForWriting

Locks the lock file for writing a file

=cut

sub lockFileForWriting {
    my ($file) = @_;
    my $logger = get_logger();
    $logger->trace("locking file for writing $file");
    my $old_mask = umask 2;
    my $flock = File::Flock->new(_makeFileLock($file));
    umask $old_mask;
    return $flock;

}

=head2 lockFileForReading

Locks the lock file for reading a file

=cut

sub lockFileForReading {
    my ($file) = @_;
    my $logger = get_logger();
    $logger->trace("locking file for reading $file");
    my $old_mask = umask 2;
    my $flock = File::Flock->new(_makeFileLock($file),'shared');
    umask $old_mask;
    return $flock;
}

=head2 unlockFilehandle

unlock the file handle returned from lockFileForWriting or lockFileForReading

=cut

sub unlockFilehandle {
    my ($lock) = @_;
    my $logger = get_logger();
    $logger->trace("unlocking file");
    $lock->unlock;
}

=head2 _makeFileLock

will create the name of the lock file

=cut

sub _makeFileLock {
    my ($file) = @_;
    return "$file.lock";
}


=head2 ReadConfig

Will reload the config when changed on the filesystem and call any register callbacks

=cut

sub ReadConfig {
    my ($self) = @_;
    my $config = $self->config;
    my $cache  = $self->cache;
    my $file   = $config->GetFileName;
    my $reloaded;
    my $reloaded_from_cache = 0;
    my $reloaded_from_file = 0;
    #If considered latest version of file it is always succesful
    my $result = 1;
    my $logger = get_logger();
    $logger->trace("ReadConfig for $file");
    my $imported = $config->{imported} if exists $config->{imported};
    $$self = $self->computeFromPath(
        $file,
        sub {
            #reread files
            my $lock = lockFileForReading($file);
            $result = $config->ReadConfig();
            unlockFilehandle($lock);
            $reloaded_from_file = 1;
            return $config;
        }
    );
    if (refaddr($config) != refaddr($self->config)) {
        $reloaded_from_cache = 1;
    }
    $reloaded = $reloaded_from_file || $reloaded_from_cache;
    if($reloaded) {
        $self->_callReloadCallbacks();
    }
    if($reloaded_from_file) {
        $self->_callFileReloadCallbacks();
    }
    return $result;
}

=head2 TIEHASH

Creating a tied pf::config::cached object

=cut

sub TIEHASH {
    my ($proto,@args) = @_;
    my $object;
    if (ref($proto) && @args == 0 ) {
        $object = $proto;
    } else {
        $object = $proto->new(@args);
    }
    die "cannot create a tied pf::config::cached"
        unless $object;
    return $object;
}

=head2 AUTOLOAD

Will proxy all unknown functions to Config::IniFiles

=cut

sub AUTOLOAD {
    my ($self) = @_;
    my $command = our $AUTOLOAD;
    $command =~ s/.*://;
    if(Config::IniFiles->can($command) ) {
        no strict qw{refs};
        *$AUTOLOAD = sub  {
            my ($self,@args) = @_;
            return  wantarray ? ($self->config->$command(@args)) : scalar $self->config->$command(@args);
        };
        goto &$AUTOLOAD;
    }
    die "$command not found";
}

=head2 computeFromPath

Will load the Config::IniFiles object from cache or filesystem and update the cache

=cut

sub computeFromPath {
    my ($self,$file,$computeSub,$expire) = @_;
    my $mod_time = getModTimestamp($file);
    my $result = $self->cache->compute(
        $file,
        {
            expire_if => sub { return $expire || $self->_expireIf($_[0],$file); },
        },
        $computeSub
    );
    return $result;
}

=head2 cache

get the global CHI object

=cut

sub cache {
    my ($self) = @_;
    unless (defined($CACHE)) {
        $CACHE = $self->_cache();
    }
    return $CACHE;
}

=head2 _cache

builds the CHI object

=cut

sub _cache {
    return CHI->new(_buildCHIArgs());
}

=head2 _expireIf

check to see if the config file needs to be reread

=cut

sub _expireIf {
    my ($self,$cache_object,$file) = @_;
    my $imported_expired = 0;
    #checking to see if the imported file needs to be reimported also
    if ( ref($self) && exists $self->{imported} ) {
        my $imported = $self->{imported};
        $imported_expired = (defined $imported && $cache_object->created_at < getModTimestamp($imported->GetFileName));
    }
    return ($imported_expired ||  !-e $file ||  ($cache_object->created_at < getModTimestamp($file)));
}

=head2 getModTimestamp

simple util function for getting the modification timestamp

=cut

sub getModTimestamp {
    return (stat($_[0]))[9];
}


=head2 ReloadConfigs

ReloadConfigs reload all configs and call any register callbacks

=cut

sub ReloadConfigs {
    my $logger = get_logger();
    $logger->trace("Reloading all configs");
    foreach my $config (values %LOADED_CONFIGS) {
        $config->ReadConfig();
    }
}


=head2 addReloadCallbacks

$self->addReloadCallbacks('name' => sub {...});
Add named callbacks to the onreload array
Called in insert order
If callback already exists will replace the current in the position

=cut

sub addReloadCallbacks {
    my ($self,@args) = @_;
    my $file = $self->GetFileName;
    my $on_reload = $ON_RELOAD{$file};
    $self->_addCallbacks($on_reload,@args);
}

=head2 _addCallbacks

internal helper method for adding callbacks

=cut

sub _addCallbacks {
    my ($self,$callback_array,$name,$callback,@args) = @_;
    my $callback_data = first { $_->[0] eq $name  } @$callback_array;
    #Adding a name to the anonymous function for debug and tracing purposes
    $callback = subname $name,$callback;
    if ($callback_data) {
        $callback_data->[1] = $callback;
    } else {
        push @$callback_array ,[$name, $callback];
    }
    if (@args) {
        $self->_addCallbacks($callback_array,@args);
    }
}

=head2 addFileReloadCallbacks

$self->addFileReloadCallbacks('name' => sub {...});
Add named callbacks to the onfilereload array
Called in insert order
If callback already exists will replace the current in the position

=cut

sub addFileReloadCallbacks {
    my ($self,@args) = @_;
    my $file = $self->GetFileName;
    my $on_file_reload = $ON_FILE_RELOAD{$file};
    $self->_addCallbacks($on_file_reload,@args);
}

=head2 DESTROY

Cleaning up externally stored

=cut

sub DESTROY {
    my ($self) = @_;
    my $config = $self->config;
    if($config) {
        my $file = $config->GetFileName;
        foreach my $hash_ref (@ON_DESTROY_REFS) {
            delete $hash_ref->{$file};
        }
    }
}

=head2 unloadConfig

Unloads the cached config from the global cache

=cut

sub unloadConfig {
    my ($self) = @_;
    my $config = $self->config;
    if($config) {
        my $file = $config->GetFileName;
        delete $LOADED_CONFIGS{$file};
    }
}

=head2 isa

Fake being a Config::IniFiles

=cut

sub isa {
    my ($proto,$arg) = @_;
    if ($arg eq 'Config::IniFiles') {
        return 1;
    }
    return $proto->SUPER::isa($arg);
}

=head2 toHash

Copy configuration to hash

=cut

sub toHash {
    my ($self,$hash) = @_;
    %$hash = ();
    foreach my $section ($self->Sections()) {
        my %data;
        foreach my $param ($self->Parameters($section)) {
            $data{$param} = $self->val($section,$param);
        }
        $hash->{$section} = \%data;
    }
}

=head2 cleanupWhitespace

Clean up whitespace is a utility function for cleaning up whitespaces for hashes

=cut

sub cleanupWhitespace {
    my ($self,$hash) = @_;
    foreach my $data (values %$hash ) {
        foreach my $key (keys %$data) {
            next unless defined $data->{$key};
            $data->{$key} =~ s/\s+$//;
        }
    }
}

=head2 _buildCHIArgs

Builds the arguments to pass to chi

=cut

sub _buildCHIArgs {
    my $args = _extractCHIArgs("default");
    return %$args;
}

sub _extractCHIArgs {
    my ($section) = @_;
    my %args;
    foreach my $param ($chi_config->Parameters($section)) {
        my $value = $chi_config->val($section,$param);
        if($param eq 'servers') {
            $args{$param} = [split(/\s*,\s*/,$value)];
        } elsif($param eq 'l1_cache') {
            $args{$param} = _extractCHIArgs($value);
        } else {
            $args{$param} = $value;
        }
    }
    return \%args;
}

=head2 RenameSection ( $old_section_name, $new_section_name)

Renames a section if it does not exists already

=cut

sub RenameSection {
    my $self = shift;
    my $old_sect = shift;
    my $new_sect = shift;

    if (not defined $old_sect or
        not defined $new_sect or
        !$self->SectionExists($old_sect) or
        $self->SectionExists($new_sect)) {
        return undef;
    }

    $self->_caseify(\$new_sect);
    $self->_AddSection_Helper($new_sect);

    # This is done the fast way, change if data structure changes!!
    foreach my $key (qw(v sCMT pCMT EOT parms myparms)) {
        $self->{$key}{$new_sect} = $self->{$key}{$old_sect};
    }

    $self->DeleteSection($old_sect);

    return 1;
} # end RenameSection

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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
