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

The callbacks are triggered by calling C<ReadConfig> and there has been a change in the cache or filesystem.
  $config->ReadConfig()

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
A good rule to follow for a function other than initialization is to not call C<$config->ReadConfig()> or C<ReloadConfigs()>.

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


=head2 Catalyst

=head3 When to Reload

This ideally should be done in the begin action of a Catalyst controller

sub begin :Private { pf::config::cached::ReloadConfigs(); }


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
use Time::HiRes qw(stat time);
use pf::log;
use pf::CHI;
use pf::IniFiles;
use Scalar::Util qw(refaddr);
use Fcntl qw(:DEFAULT :flock);
use Storable;
use File::Flock;
use Readonly;
use Sub::Name;
use List::Util qw(first);
use List::MoreUtils qw(uniq);


our $CACHE;
our @LOADED_CONFIGS;
our %ON_RELOAD;
our %ON_FILE_RELOAD;
our %ON_CACHE_RELOAD;
our @ON_DESTROY_REFS = (
    \%ON_RELOAD,
    \%ON_FILE_RELOAD,
    \%ON_CACHE_RELOAD,
);

our %CONFIG_DATA;

use overload "%{}" => \&config, fallback => 1;

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
    my $config;
    my $onReload = delete $params{'-onreload'} || [];
    my $onFileReload = delete $params{'-onfilereload'} || [];
    my $onCacheReload = delete $params{'-oncachereload'} || [];
    my $reload_onfile;
    if($file) {
        $self = first { $_->GetFileName eq $file} @LOADED_CONFIGS;
        if( defined $self) {
            #Adding the reload and filereload callbacks
            $self->addReloadCallbacks(@$onReload) if @$onReload;
            $self->addFileReloadCallbacks(@$onFileReload) if @$onFileReload;
            $self->addCacheReloadCallbacks(@$onCacheReload) if @$onCacheReload;
        } else {
            delete $params{'-file'} unless -e $file;
            $config = $class->computeFromPath(
                $file,
                sub {
                    my $lock = lockFileForReading($file);
                    my $config = pf::IniFiles->new(%params);
                    die "$file cannot be loaded" unless $config;
                    unlockFilehandle($lock);
                    $config->SetFileName($file);
                    $config->SetWriteMode($WRITE_PERMISSIONS);
                    my $mode = oct($config->GetWriteMode);
                    chmod $mode, $file;
                    $reload_onfile = 1;
                    return $config;
                }
            );
        }
    } else {
        die "param -file missing or empty";
    }
    if ($config) {
        $self = \$config;
        push @LOADED_CONFIGS, $self;
        $ON_RELOAD{$file} = [];
        $ON_FILE_RELOAD{$file} = [];
        $ON_CACHE_RELOAD{$file} = [];
        bless $self,$class;
        $self->addReloadCallbacks(@$onReload) if @$onReload;
        $self->addFileReloadCallbacks(@$onFileReload) if @$onFileReload;
        $self->addCacheReloadCallbacks(@$onCacheReload) if @$onCacheReload;
        $self->_callReloadCallbacks();
        $self->_callFileReloadCallbacks() if $reload_onfile;
        $self->_callCacheReloadCallbacks() unless $reload_onfile;
    }
    #Rereading the config to ensure the latest version if from the global cache or has an imported config
    $self->ReadConfig();
    return $self;
}

=head2 config

Access for the proxied C<Config::IniFiles> object

=cut

sub config { ${$_[0]}}

=head2 RewriteConfig

Will rewrite the config using the filename passed to it, update the cache, and run the C<onreload> and C<onfilereload> callbacks if successful.

=cut

sub RewriteConfig {
    my ($self) = @_;
    my $logger = get_logger();
    my $config = $self->config;
    my $file = $config->GetFileName;
    if( -e $file && $config->{_timestamp} < getModTimestamp($file) ) {
        die "Config $file was modified from last loading\n";
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
        $config->SetWriteMode($WRITE_PERMISSIONS);
        my $mode = oct($config->GetWriteMode);
        chmod $mode, $file;
        $self->_callReloadCallbacks();
        $self->_callFileReloadCallbacks();
    }
    unlockFilehandle($lock);
    return $result;
}



=head2 Rollback

Rollback to current version of config in the cache
Reverting all current changes

=cut

sub Rollback {
    my ($self) = @_;
    my $cache = $self->cache;
    my $config = $self->config;
    my $file = $config->GetFileName;
    $cache->l1_cache->remove($file);
    my $old_config = $cache->get($file);
    $$self = $old_config;
    $self->_callReloadCallbacks();
    $self->_callCacheReloadCallbacks();
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

Unlock the file handle returned from lockFileForWriting or lockFileForReading

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
    if ($file =~ m/^(\Q$install_dir\E.*)$/) {
        $file = $1;
    }
    my $new_file = "$file.lock";
    return $new_file;
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
    $reloaded_from_cache = refaddr($config) != refaddr($$self);
    $self->_callReloadCallbacks if ($reloaded_from_cache || $reloaded_from_file);
    $self->_callFileReloadCallbacks if $reloaded_from_file;
    $self->_callCacheReloadCallbacks if $reloaded_from_cache;
    return $result;
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

=head2 AUTOLOAD

Will proxy all unknown functions to C<Config::IniFiles>

=cut

sub AUTOLOAD {
    my ($self) = @_;
    my $command = our $AUTOLOAD;
    $command =~ s/.*://;
    if(pf::IniFiles->can($command) ) {
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

Will load the C<Config::IniFiles> object from cache or filesystem and update the cache

=cut

sub computeFromPath {
    my ($self,$file,$computeSub,$expire) = @_;
    my $mod_time = getModTimestamp($file);
    my $computeWrapper = sub {
        my $config = $computeSub->();
        $config->{_timestamp} = time;
        return $config;
    };
    my $result = $self->cache->compute(
        $file,
        {
            expire_if => sub { return $expire || $self->_expireIf($_[0],$file); },
        },
        $computeWrapper
    );
    $computeWrapper = undef;
    $computeSub = undef;
    return $result;
}

=head2 cache

Get the global CHI object

=cut

sub cache {
    my ($self) = @_;
    unless (defined($CACHE)) {
        $CACHE = $self->_cache();
    }
    return $CACHE;
}

=head2 _cache

Builds the CHI object

=cut

sub _cache {
    return pf::CHI->new(namespace => 'configfiles' );
}

=head2 _expireIf

Check to see if the config file needs to be reread

=cut

sub _expireIf {
    my ($self,$cache_object,$file) = @_;
    my $imported_expired = 0;
    my $timestamp = $cache_object->value->{_timestamp} || 0;
    #checking to see if the imported file needs to be reimported also
    my $imported;
    if ( ref($self) && exists $self->{imported} && ($imported = $self->{imported} )) {
        $imported_expired = ($timestamp < getModTimestamp($imported->GetFileName));
    }
    return ($imported_expired ||  !-e $file ||  ( $timestamp < getModTimestamp($file)));
}

=head2 getModTimestamp

Simple utility function for getting the modification timestamp

=cut

sub getModTimestamp {
    my $timestamp = (stat($_[0]))[9];
    return $timestamp;
}


=head2 ReloadConfigs

ReloadConfigs reload all configs and call any register callbacks

=cut

sub ReloadConfigs {
    my $logger = get_logger();
    $logger->trace("Reloading all configs");
    foreach my $config (@LOADED_CONFIGS) {
        $config->ReadConfig();
    }
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
If callback already exists, previous callback is replaced and previous position is preserved

=cut

sub addFileReloadCallbacks {
    my ($self,@args) = @_;
    $self->_addCallbacks($ON_FILE_RELOAD{$self->GetFileName},@args);
}

=head2 addCacheReloadCallbacks

$self->addFileReloadCallbacks('name' => sub {...});
Add named callbacks to the onfilereload array
Called in insert order
If callback already exists, previous callback is replaced and previous position is preserved

=cut

sub addCacheReloadCallbacks {
    my ($self,@args) = @_;
    $self->_addCallbacks($ON_CACHE_RELOAD{$self->GetFileName},@args);
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

Unloads the cached config from the internal global cache

=cut

sub unloadConfig {
    my ($self) = @_;
    my $config = $self->config;
    if($config) {
        my $file = $config->GetFileName;
        @LOADED_CONFIGS = grep { $config->GetFileName ne $file  } @LOADED_CONFIGS;
    }
}

=head2 isa

Fake being a pf::IniFiles

=cut

sub isa {
    my ($self,@args) = @_;
    return $self->SUPER::isa(@args) || pf::IniFiles->isa(@args);
}

=head2 toHash

Copy configuration to a hash

=cut

sub toHash {
    my ($self,$hash) = @_;
    %$hash = ();
    my @default_parms;
    if (exists $self->{default} ) {
        @default_parms = $self->Parameters($self->{default});
    }
    foreach my $section ($self->Sections()) {
        my %data;
        foreach my $param (uniq $self->Parameters($section),@default_parms) {
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
