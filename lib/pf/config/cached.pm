package pf::config::cached;

=head1 NAME

pf::config::cached

=head1 DESCRIPTION

pf::config::cached object is a proxy for a cached (in CHI) Config::IniFiles object

=head1 SYNOPSIS

By default, the pf::cached::object is internally cached and keyed by file path.

So multiple calls to pf::config::cached->new with the same file path will return the same object.

Simple usage

  use pf::config::cached;
  my $cached_config = pf::config::cached->new( -file => 'file.conf');

Using as an tied hash

  use pf::config::cached;
  tie my %Config, 'pf::config::cached' => (-file => 'file.conf');

Tying an hash using an existing pf::config::cached object

  use pf::config::cached;
  my $cached_config = pf::config::cached->new( -file => 'file.conf');
  tie my %Config, $cached_config;

Creating a pf::config::cached object with some callbacks

  use pf::config::cached;
  my $cached_config = pf::config::cached->new(
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

=over

=item C<onreload> - called whenever the config is (re)loaded from the filesystem or the cache

=item C<onfilereload> - called whenever the config is (re)loaded only from the filesystem

=back

=head3 Behavior

The callbacks are triggered by calling C<ReloadConfig> and there has been a change in the cache or filesystem.
  $config->ReloadConfig()

To reload all the configs that have been created call C<ReloadConfigs>.

Call C<unloadConfig> to avoid a config file from being re-read when C<ReloadConfigs> is called.
  $config->unloadConfig()

The order callbacks are called

=over

=item 1) C<onreload> callbacks in order of insertion

=item 2) C<onfilereload> callbacks in order of insertion

=back

=head3 Adding callbacks

All callbacks are named to ensure the same callback is added only once.

=head4 At creation of object

All callbacks will be called after creating an object or recieving it from the cache.
If recieved from the cache, it will replace any existing callbacks with the same name.

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

=head4 Add callbacks to an existing pf::config::cached object

If the name already exists, it replaces the previous callback keeping its calling order.

When adding a callback to an existing C<pf::config::cached> object it will not be called.
If it needs to be called it must be done manually.

Adding new callback example:
  $cached_config->addReloadCallbacks( 'onreload_do_something_else' => sub {...}  );
  $cached_config->addFileReloadCallbacks( 'onfilereload_do_something_else' => sub {...}  );

  my $callback = sub {...};
  $cached_config->addReloadCallbacks('callback_name' => $callback);
  $callback($cached_config,'callback_name');

Adding new callback then calling them after:
  my $callback = sub {...};
  $cached_config->addReloadCallbacks('callback_name' => $callback);
  $callback($cached_config,'callback_name');

=head3 Removing callbacks

Currently not supported

=head2 Libraries

A quick guide on how to use in a library

=head3 Singleton

By default pf::config::cached are singleton so you only initialize them once.

They should be stored in a package variable.

=head3 Readonly

If you are only reading the data and not creating other data then these methods are safe to use:

=over

=item C<val>

=item C<exists>

=item C<Sections>

=item C<SectionExists>

=item C<Parameters>

=item C<Groups>

=item C<GroupMembers>

=item C<GetFileName>

=back

=head3 Modifing data in the config

If the library doesn't have to modify data in the cache, then never call any methods that modify data.

If the library has to modify data, then always perform the C<RewriteConfig> at the latest time.

=head3 Setting up data

If the library is reading configuration data to setup global variables, then it must use callbacks to update its data when the config is reloaded.

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

In general, reloading configurations should only happen at the start or end of an event loop to ensure the latest data is loaded.
A good rule to follow for a function other than initialization is to not call C<$config->ReloadConfig()> or C<ReloadConfigs()>.

=head2 Daemons

=head3 When to Reload

It is best to reload the data before the event loop begins or after the event loop ends.

=head3 Using the configuration

=head4 Copying to non-global variables

The safest way (but not the most effecient way) is to copy the configuration to a temporary variable.

Example:
  $config->toHash(\%hash);

=head4 Setting up global variables

If the daemon is reading configuration data to setup global variables, then it must use callbacks to update its data when the config is reloaded.

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


=head2 HTML::FormHandler

=head3 Default values

If the default value is from a derived value then you should use a sub routine to set the default value

See L<HTML::FormHandler::Manual::Defaults/Defaults> for more information

  package pfappserver::Form::Person;

  use HTML::FormHandler::Moose;
  extends 'HTML::FormHandler';
  with 'pfappserver::Form::Widget::Theme::Pf';

  sub default_hair { $Config{person}{default} eq 'James' ? 'no' : 'yes' }

  has_field hair =>
  (
    type => 'Toggle',
    wrapper => 'Switch',
    checkbox_value => 'yes',
    unchecked_value => 'no',
  );

=head2 Moose

=head3 Default values

When using a value that was dervived from a configuration use a sub routine to create the default value

  package pf::person;

  use Moose;

  has 'hair' => (
    is => 'ro',
    default => sub { $Config{person}{default} ne 'James'  },
  );

=cut

use strict;
use warnings;
use pf::file_paths;
use Time::HiRes qw(stat time gettimeofday);
use pf::log;
use pf::CHI;
use pf::IniFiles;
use Scalar::Util qw(refaddr reftype tainted blessed weaken);
use Fcntl qw(:DEFAULT :flock);
use Storable;
use File::Flock;
use File::Spec::Functions qw(splitpath catpath);
use Readonly;
use Sub::Name;
use List::MoreUtils qw(any firstval uniq none);
use Fcntl qw(:flock :DEFAULT :seek);
use POSIX::2008;
use Data::Swap();
use Data::Structure::Util qw(unbless);
use pf::FileLocker;
use base qw(pf::IniFiles);


our $CACHE;
our @LOADED_CONFIGS_FILE;
our %LOADED_CONFIGS;
our %ON_RELOAD;
our %ON_FILE_RELOAD;
our %ON_FILE_RELOAD_ONCE;
our %ON_CACHE_RELOAD;
our %ON_POST_RELOAD;
our %FILE_LOCKERS;
our $NO_DESTROY;

our @ON_DESTROY_REFS = (
    \%ON_RELOAD,
    \%ON_FILE_RELOAD,
    \%ON_CACHE_RELOAD,
    \%ON_FILE_RELOAD_ONCE,
    \%ON_POST_RELOAD,
    \%FILE_LOCKERS,
);

our %CONFIG_DATA;

Readonly::Scalar our $WRITE_PERMISSIONS => 0664;

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
The sub reference is passed the C<pf::config::cached> object and the name of the callback

=item I<-onfilereload> [name => sub {...}]

This is an array ref that contains pairs of strings and sub references
The sub reference is passed the C<pf::config::cached> object and the name of the callback

=back

=cut

sub new {
    my ($proto,%params) = @_;
    my $class = ref($proto) || $proto;
    my $self;
    my $file = $params{'-file'};
    $file =~ /^(.*)$/;
    $file = $1;
    my $onReload = delete $params{'-onreload'} || [];
    my $onFileReload = delete $params{'-onfilereload'} || [];
    my $onCacheReload = delete $params{'-oncachereload'} || [];
    my $onPostReload = delete $params{'-onpostreload'} || [];
    my $reload_onfile;
    die "param -file missing or empty" unless $file;
    delete $params{'-file'} unless -e $file;
    $self = $class->computeFromPath(
        $file,
        sub {
            my $lock = lockFileForReading($file);
            my $config = $class->SUPER::new(%params);
            die "$file cannot be loaded" unless $config;
            $config->SetFileName($file);
            $config->SetWriteMode($WRITE_PERMISSIONS);
            $reload_onfile = 1;
            return $config;
        }
    );
    untaint($self) unless $reload_onfile;
    $ON_RELOAD{$file} ||= [];
    $ON_FILE_RELOAD{$file} ||= [];
    $ON_FILE_RELOAD_ONCE{$file} ||= [];
    $ON_CACHE_RELOAD{$file} ||= [];
    $ON_POST_RELOAD{$file} ||= [];
    #Adding to the loaded config
    $self->addToLoadedConfigs();
    $self->addReloadCallbacks(@$onReload) if @$onReload;
    $self->addFileReloadCallbacks(@$onFileReload) if @$onFileReload;
    $self->addCacheReloadCallbacks(@$onCacheReload) if @$onCacheReload;
    $self->addPostReloadCallbacks(@$onPostReload) if @$onPostReload;
    $self->doCallbacks($reload_onfile,!$reload_onfile);
    return $self;
}

=head2 RewriteConfig

Will rewrite the config using the filename passed to it, update the cache, and run the C<onreload> and C<onfilereload> callbacks if successful.

=cut

sub RewriteConfig {
    my ($self) = @_;
    my $logger = get_logger();
    my $file = $self->GetFileName;
    if( $self->HasChanged(1) ) {
        die "Config $file was modified from last loading\n";
    }
    my $result;
    my $lock = lockFileForWriting($file);
    #lock will release when out of scope
    if ( exists $self->{imported} && defined $self->{imported}) {
        #localizing for saving only what is in
        local $self->{v} = Config::IniFiles::_deepcopy($self->{v});
        local $self->{sCMT} = Config::IniFiles::_deepcopy($self->{sCMT});
        local $self->{pCMT} = Config::IniFiles::_deepcopy($self->{pCMT});
        local $self->{EOT} = Config::IniFiles::_deepcopy($self->{EOT});
        local $self->{parms} = Config::IniFiles::_deepcopy($self->{parms});
        local $self->{myparms} = Config::IniFiles::_deepcopy($self->{myparms});
        local $self->{sects} = Config::IniFiles::_deepcopy($self->{sects});
        local $self->{group} = Config::IniFiles::_deepcopy($self->{group});
        local $self->{mysects} = Config::IniFiles::_deepcopy($self->{mysects});
        $self->removeDefaultValues();
        $result = $self->SUPER::RewriteConfig();
    } else {
        $result = $self->SUPER::RewriteConfig();
    }
    if($result) {
        $self = $self->computeFromPath(
            $file,
            sub {
                $self->ExpireLockFile();
                return $self;
            },
            1
        );
        $self->doCallbacks(1,0);
    }
    return $result;
}


=head2 Rollback

Rollback to current version of config in the cache
Reverting all current changes

=cut

sub Rollback {
    my ($self) = @_;
    my $cache = $self->cache;
    my $file = $self->GetFileName;
    $cache->l1_cache->remove($file);
    my $old_config = $cache->get($file);
    $self->_swap_data($old_config);
    $self->doCallbacks(0,1);
}

=head2 _callCallbacks

Helper function for calling the callbacks

=cut

sub _callCallbacks {
    my ($self,$data) = @_;
    my $callbacks =  $data->{$self->GetFileName};
    foreach my $callback_data ( @$callbacks) {
        $callback_data->[1]->($self,$callback_data->[0]);
    }
}

=head2 _callReloadCallbacks

Call all reload callbacks

=cut

sub _callReloadCallbacks {
    my ($self) = @_;
    $self->_callCallbacks(\%ON_RELOAD);
}

=head2 _callFileReloadCallbacks

Call all the file reload callbacks

=cut

sub _callFileReloadCallbacks {
    my ($self) = @_;
    $self->_callCallbacks(\%ON_FILE_RELOAD);
}

=head2 _callCacheReloadCallbacks

Call all the cache reload callbacks

=cut

sub _callCacheReloadCallbacks {
    my ($self) = @_;
    $self->_callCallbacks(\%ON_CACHE_RELOAD);
}

=head2 _callPostReloadCallbacks

Call all reload callbacks

=cut

sub _callPostReloadCallbacks {
    my ($self) = @_;
    $self->_callCallbacks(\%ON_POST_RELOAD);
}

sub doCallbacks {
    my ($self,$file_reloaded,$cache_reloaded) = @_;
    if($file_reloaded || $cache_reloaded) {
        my $logger = get_logger;
        $logger->trace("doing callbacks for " . $self->GetFileName . " file_reloaded = " . ($file_reloaded ? 1 : 0) .  "  cache_reloaded = " .  ($cache_reloaded ? 1 : 0));
        $self->_callReloadCallbacks;
        if($file_reloaded) {
            my $locker = _getLocker($self->GetFileName); 
            $locker->blocking(0); 
            if($locker->writeLock) {
                $logger->trace("Got writelock for " . $self->GetFileName);
                $self->_callFileReloadCallbacks;
            } else {
                $cache_reloaded = 1;
            }
        }
        $self->_callCacheReloadCallbacks if $cache_reloaded;
        $self->_callPostReloadCallbacks;
    }
}


sub GetDotFileName {
    return _makeIntoDotFile (shift->GetFileName);
}

sub GetLockFileName {
    return _makeIntoDotFile (shift->GetFileName . ".lock");
}

sub _makeIntoDotFile {
    my ($oldFileName) = @_;
    my ($volume,$directories,$file) = splitpath( $oldFileName );
    return catpath($volume,$directories,".$file");
}


=head2 removeDefaultValues

Will removed all the default values in current config

=cut

sub removeDefaultValues {
    my ($self) = @_;
    if (exists $self->{imported} && defined $self->{imported}) {
        my $imported = $self->{imported};
        foreach my $section ( $self->Sections ) {
            next if ( !$imported->SectionExists($section) );
            foreach my $parameter ( $self->Parameters($section) ) {
                next if ( !$imported->exists($section, $parameter) );
                my $self_val = $self->val($section, $parameter);
                my $default_val = $imported->val($section, $parameter);
                if ( !defined ($self_val) || $self_val eq $default_val  ) {
                    $self->delval($section, $parameter);
                }
            }
            if ($self->Parameters($section) == 0) {
                $self->DeleteSection($section);
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
    $logger->trace("locking file for write $file");
    my $locker = _getLocker($file);
    $locker->writeLock();
    return $locker;
}

=head2 _getLocker

Get the current file locker

=cut

sub _getLocker {
    my ($file) = @_;
    my $locker;
    if (exists $FILE_LOCKERS{$file} && defined $FILE_LOCKERS{$file}) {
        $locker = $FILE_LOCKERS{$file};
    } else {
        $locker = _makeLocker($file);
        $FILE_LOCKERS{$file} = $locker;
        weaken($FILE_LOCKERS{$file});
    }
    $locker->blocking(1);
    $locker->unlockOnDestroy(1);
    return $locker;
}

=head2 _makeLocker

creates the locker for file

=cut

sub _makeLocker {
    my ($file) = @_;
    my $lockfile = _makeFileLock($file);
    umask 2;
    open(my $fh,"+>>",$lockfile);
    my (undef,undef,$uid,$gid) = getpwnam('pf');
    chown($uid,$gid,$lockfile);
    return pf::FileLocker->new( fh => $fh);
}

=head2 lockFileForReading

Locks the lock file for reading a file

=cut

sub lockFileForReading {
    my ($file) = @_;
    my $logger = get_logger();
    my $locker = _getLocker($file);
    $locker->readLock();
    return $locker;
}

=head2 _makeFileLock

will create the name of the lock file

=cut

sub _makeFileLock {
    my ($file) = @_;
    $file =~ /^(.*)$/;
    $file = _makeIntoDotFile($1);
    return "${file}.lock";
}


=head2 ReloadConfig

Will reload the config when changed on the filesystem and call any register callbacks

=cut

sub ReloadConfig {
    my ($self,$force) = @_;
    my $file   = $self->GetFileName;
    my $cache  = $self->cache;
    my $reloaded;
    my $reloaded_from_cache = 0;
    my $reloaded_from_file = 0;
    #If considered latest version of file it is always succesful
    my $result = 1;
    my $logger = get_logger();
    my $new_self = $self->computeFromPath(
        $file,
        sub {
            #reread files
            #lock will release when out of scope
            my $lock = lockFileForReading($file);
            $result = $self->ReadConfig();
            $reloaded_from_file = 1;
            return $self;
        },
        $force
    );
    $reloaded_from_cache = refaddr($self) != refaddr($new_self);
    if($reloaded_from_cache) {
        $self->_swap_data($new_self);
    }
    $self->doCallbacks($reloaded_from_file,$reloaded_from_cache,$force);
    return $result;
}

=head2 _swap_data

Swap the data with cached data

=cut

sub _swap_data {
    my ($self,$new_self) = @_;
    Data::Swap::swap($self,$new_self); 
    $self->addToLoadedConfigs();
    #Unbless the old data to avoid DESTROY from being called
    unbless($new_self);
    my $cache = $self->cache;
    #Repopulate the in new memory cache after the swap
    if($cache->has_subcaches) {
        my $l1_cache = $cache->l1_cache;
        $l1_cache = $l1_cache->l1_cache while $l1_cache->has_subcaches;
        $l1_cache->set($self->GetFileName,$self) if $l1_cache->driver_class eq 'CHI::Driver::RawMemory';
    }
    #Setting no_destroy to avoid removal of call back data
    $new_self->{no_destroy} = 1;
}

=head2 TIEHASH

Creating a tied C<pf::config::cached> object

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

=head2 computeFromPath

Will load the C<Config::IniFiles> object from cache or filesystem and update the cache

=cut

sub computeFromPath {
    my ($self,$file,$computeSub,$expire) = @_;
    local $NO_DESTROY = 1;
    my $computeWrapper = sub {
        my $config = $computeSub->();
        $config->SetLastModTimestamp();
        $config->SetLockFileTimeStamp();
        return $config;
    };
    my $result = $self->cache->compute(
        $file,
        {
            expire_if => sub {
                return 1 if $expire;
                my $value = $_[0]->value;
                return 1 unless $value;
                return 1 if ref($value) eq 'HASH' ;
                return $value->HasExpired();
            },
        },
        $computeWrapper
    );
    $computeWrapper = undef;
    $computeSub = undef;
    return $result;
}

=head2 SetLockFileTimeStamp

Sets the current typestamp of the lock file

=cut

sub SetLockFileTimeStamp {
    my ($self) = @_;
    $self->{_last_lock_file_timestamp} = $self->GetCurrentLockFileTimestamp();
}

=head2 GetLockFileTimeStamp

Gets the last typestamp of the lock file

=cut

sub GetLockFileTimeStamp {
    my ($self) = @_;
    $self->{_last_lock_file_timestamp} || -1;
}

=head2 GetCurrentLockFileTimestamp

Gets the current typestamp of the file

=cut

sub GetCurrentLockFileTimestamp {
    my ($self) = @_;
    return pf::IniFiles::_getFileTimestamp($self->GetLockFileName) || -1;
}

=head2 HasExpired

check to see if the file has expired

=cut

sub HasExpired {
    my ($self) = @_;
    get_logger->trace( sub { "LockFile time stamp ". $self->GetLockFileTimeStamp . " for " . $self->GetFileName });
    get_logger->trace( sub { "time stamp ". $self->GetLastModTimestamp . " for " . $self->GetFileName });
    return $self->LockFileHasChanged() && $self->HasChanged() &&  $self->NoWriteLock;
}

=head2 NoWriteLock

The is no currently writelock

=cut

sub NoWriteLock {
    my ($self) = @_;
    get_logger->trace("NoWriteLock");
    my $locker = _getLocker($self->GetFileName); 
    $locker->blocking(0); 
    my $result = $locker->readLock;
    get_logger->trace("Has no write lock") if $result;
    return $locker->readLock;
}

=head2 LockFileHasChanged

TODO: documention

=cut

sub LockFileHasChanged {
    my ($self) = @_;
    my $timestamp = $self->GetCurrentLockFileTimestamp;
    get_logger->trace( sub { "LockFile time stamp $timestamp for " . $self->GetFileName });
    return $timestamp == -1 || $self->GetLockFileTimeStamp != $timestamp;
}

=head2 cache

Get the global CHI object for configfiles

=cut

sub cache {
    return pf::CHI->new(namespace => 'configfiles' );
}

=head2 cacheForData

Get the global CHI object for configfilesdata

=cut

sub cacheForData {
    return pf::CHI->new(namespace => 'configfilesdata' );
}

=head2 ReloadConfigs

ReloadConfigs reload all configs and call any register callbacks

=cut

sub ReloadConfigs {
    my ($force) = @_;
    my $logger = get_logger();
    $logger->trace("Started Reloading all configs");
    foreach my $config (@LOADED_CONFIGS{@LOADED_CONFIGS_FILE}) {
        next unless $config;
        $logger->trace("Reloading config $config->{cf}");
        next unless $config->LockFileHasChanged;
        $config->ReloadConfig($force);
    }
    $logger->trace("Finished Reloading all configs");
}

=head2 UpdateControlConfigs

ReloadConfigs reload all configs and call any register callbacks

=cut

sub UpdateControlConfigs {
    my ($force) = @_;
    my $logger = get_logger();
    $logger->trace("Started Reloading all configs");
    foreach my $config (@LOADED_CONFIGS{@LOADED_CONFIGS_FILE}) {
        $config->ExpireFile() if $force;
        $config->ExpireLockFile() if $config->HasChanged;
    }
    $logger->trace("Finished Reloading all configs");
}


=head2 addReloadCallbacks

$self->addReloadCallbacks('name' => sub {...});
Add named callbacks to the onreload array
Called in insert order
If callback already exists, previous callback is replaced and previous position is preserved

=cut

sub addReloadCallbacks {
    my ($self,@args) = @_;
    $self->_addCallbacks($ON_RELOAD{$self->GetFileName},@args);
}

=head2 _addCallbacks

Internal helper method for adding callbacks

=cut

sub _addCallbacks {
    my ($self,$callback_array,@args) = @_;
    if (@args > 1) {
        my ($name,$callback) = splice(@args,0,2);
        my $callback_data = firstval { $_->[0] eq $name  } @$callback_array;
        #Adding a name to the anonymous function for debug and tracing purposes
        $callback = subname $name,$callback;
        if ($callback_data) {
            $callback_data->[1] = $callback;
        } else {
            push @$callback_array ,[$name, $callback];
        }
        $self->_addCallbacks($callback_array,@args);
    }
}

=head2 addFileReloadCallbacks

$self->addFileReloadCallbacks('name' => sub {...});
Add named callbacks to the onfilereload array
Called in insert order
If callback already exists, previous callback is replaced and previous position is preserved

=cut

sub addFileReloadCallbacks {
    my ($self,@args) = @_;
    $self->_addCallbacks($ON_FILE_RELOAD{$self->GetFileName},@args);
}

=head2 addCacheReloadCallbacks

$self->addCacheReloadCallbacks('name' => sub {...});
Add named callbacks to the onfilereload array
Called in insert order
If callback already exists, previous callback is replaced and previous position is preserved

=cut

sub addCacheReloadCallbacks {
    my ($self,@args) = @_;
    $self->_addCallbacks($ON_CACHE_RELOAD{$self->GetFileName},@args);
}

=head2 addPostReloadCallbacks

$self->addPostReloadCallbacks('name' => sub {...});
Add named callbacks to the onpostreload array
Called in insert order
If callback already exists, previous callback is replaced and previous position is preserved

=cut

sub addPostReloadCallbacks {
    my ($self,@args) = @_;
    $self->_addCallbacks($ON_POST_RELOAD{$self->GetFileName},@args);
}

=head2 DESTROY

Cleaning up externally stored

=cut

sub DESTROY {
    my ($self) = @_;
    return if $NO_DESTROY;
    unless ($self->{no_destroy}) {
        my $file = $self->GetFileName;
        return unless $file;
        foreach my $hash_ref (@ON_DESTROY_REFS) {
            delete $hash_ref->{$file};
        }
    }
}

=head2 addToLoadedConfigs

adds the cached config from the internal global cache

=cut

sub addToLoadedConfigs {
    my ($self) = @_;
    return if $self->{nocache};
    my $file = $self->GetFileName;
    if ( none { $_ eq $file} @LOADED_CONFIGS_FILE ) {
        push @LOADED_CONFIGS_FILE,$file;
    }
    $LOADED_CONFIGS{$file} = $self;
}


=head2 unloadConfig

Unloads the cached config from the internal global cache

=cut

sub unloadConfig {
    my ($self) = @_;
    my $file = $self->GetFileName;
    @LOADED_CONFIGS_FILE = grep { $_ ne $file } @LOADED_CONFIGS_FILE;
    delete $LOADED_CONFIGS{$file};
}

sub untaint_value {
    my $val = shift;
    if (defined $val && $val =~ /^(.*)$/) {
        return $1;
    }
}

=head2 toHash

Copy configuration to a hash

=cut

sub toHash {
    my ($self, $hash) = @_;
    %$hash = ();
    my @default_parms;
    if (exists $self->{default} ) {
        @default_parms = $self->Parameters($self->{default});
    }
    foreach my $section ($self->Sections()) {
        my %data;
        foreach my $param ( map { untaint_value($_) } uniq $self->Parameters($section), @default_parms) {
            my $val = $self->val($section, $param);
            $data{$param} = untaint($val);
        }
        $hash->{$section} = \%data;
    }
}

sub fromCacheUntainted {
    my ($self, $key) = @_;
#    $self->removeFromSubcaches($key);
    return untaint($self->cache->get($key));
}

sub fromCacheForDataUntainted {
    my ($self, $key) = @_;
    return untaint($self->cacheForData->get($key));
}

sub removeFromSubcaches {
    my ($self, $key) = @_;
    my $cache = $self->cache;
    if($cache->has_subcaches) {
        get_logger->trace("Removing from subcache");
        $cache->l1_cache->remove($key);
    }
}

sub untaint {
    my $val = $_[0];
    if (tainted($val)) {
        $val = untaint_value($val);
    } elsif (my $type = reftype($val)) {
        if ($type eq 'ARRAY') {
            foreach my $element (@$val) {
                $element = untaint($element);
            }
        } elsif ($type eq 'HASH') {
            foreach my $element (values %$val) {
                $element = untaint($element);
            }
        }
    }
    return $val;
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

sub clearAllConfigs {
    my ($class) = @_;
    $class->cache->remove_multi(\@stored_config_files);
}

sub _ExpireFile {
    my ($self,$file) = @_;
    my $old_mask = umask(0);
    sysopen(my $fh,$file,O_RDWR | O_CREAT, 0660);
    POSIX::2008::futimens(fileno $fh);
    close($fh);
    my (undef,undef,$uid,$gid) = getpwnam('pf');
    chown($uid,$gid,$file);
    umask($old_mask);
}


sub ExpireLockFile {
    my ($self) = @_;
    my $locker = lockFileForWriting($self->GetFileName);
    $self->_ExpireFile($self->GetLockFileName());
}

sub ExpireFile {
    my ($self) = @_;
    my $locker = lockFileForWriting($self->GetFileName);
    $self->_ExpireFile($self->GetFileName());
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2014 Inverse inc.

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
