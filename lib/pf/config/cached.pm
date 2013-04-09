package pf::config::cached;
=head1 NAME

pf::config::cached

=cut

=head1 DESCRIPTION

This is a proxy for Config::IniFiles that stored in CHI
The class is a bless scalar ref
When deferencing as a hash it will returned the proxied config

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


our $CACHE;
our %LOADED_CONFIGS;
our @GLOBAL_ON_RELOAD;
our %ON_RELOAD;
our %RELOADED;
our %RELOADED_FROM_CACHE;
use overload "%{}" => \&config, fallback => 1;

our $chi_config = Config::IniFiles->new( -file => INSTALL_DIR . "/conf/chi.conf");

=head1 METHODS

=head2 new

Creates a new pf::config::cached

=cut

sub new {
    my ($proto,%params) = @_;
    my $class = ref($proto) || $proto;
    my $self;
    my $file = $params{'-file'};
    my $config;
    if($file) {
        if(exists $LOADED_CONFIGS{$file}) {
            return $LOADED_CONFIGS{$file};
        }
        delete $params{'-file'} unless -e $file;
        $config = $class->computeFromPath(
            $file,
            sub {
                my $lock = lockFileForReading($file);
                my $config = Config::IniFiles->new(%params);
                $config->SetFileName($file);
                unlockFilehandle($lock);
                return $config;
            }
        );
    } else {
        die "param -file missing or empty";
    }
    if ($config) {
        $self = \$config;
        $LOADED_CONFIGS{$file} = $self;
        $ON_RELOAD{$file} = [];
        bless $self,$class;
    }
    return $self;
}

=head2 config

access for the proxied Config::IniFiles object

=cut

sub config { ${$_[0]}}

=head2 RewriteConfig

=cut

sub RewriteConfig {
    my ($self) = @_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__);
    my $config = $self->config;
    my $file = $config->GetFileName;
    my $cache = $self->cache;
    my $cached_object = $cache->get_object($file);
    if($cached_object && _expireIf($cached_object)) {
        die "Config $file was modified from last loading";
    }
    my $result;
    if ( $config->{imported} && defined $config->{imported}) {
        my $lock = lockFileForWriting($file);
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
        $result = $config->WriteConfig($file);
        unlockFilehandle($lock);
    } else {
        my $lock = lockFileForWriting($file);
        $result = $config->WriteConfig($file);
        unlockFilehandle($lock);
    }
    if($result) {
        $cache->set($file,$config);
        $self->_callReloadedCallback();
    }
    return $result;
}

=head2 _callReloadedCallbacks

call all the reloaded callbacks

=cut

sub _callReloadedCallback {
    my ($self) = @_;
    local $_;
    $_->($self) foreach (@{$ON_RELOAD{$self->GetFileName}});
}


=head2 removeDefaultValues

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
                if ( $config_val eq $default_val  ) {
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
    return File::Flock->new(_makeFileLock($file));
}

=head2 lockFileForReading

Locks the lock file for reading a file

=cut

sub lockFileForReading {
    my ($file) = @_;
    return File::Flock->new(_makeFileLock($file),'shared');
}

=head2 unlockFilehandle

unlock the file handle returned from lockFileForWriting or lockFileForReading

=cut

sub unlockFilehandle {
    my ($lock) = @_;
    $lock->unlock;
}

=head2 _makeFileLock

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
    my $reloaded = 0;
    my $reloaded_from_cache = 0;
    my $result;
    my $imported = $config->{imported} if exists $config->{imported};
    $$self = $self->computeFromPath(
        $file,
        sub {
            #reread files
            my $lock = lockFileForReading($file);
            $result = $config->ReadConfig();
            unlockFilehandle($lock);
            $reloaded = 1;
            return $config;
        }
    );
    if (refaddr($config) != refaddr($self->config)) {
        $reloaded = 1;
        $reloaded_from_cache = 1;
    }
    if($reloaded) {
        $self->_callReloadedCallback();
    }
    $RELOADED{$file} = $reloaded;
    $RELOADED_FROM_CACHE{$file} = $reloaded_from_cache;
    return $result;
}

=head2 TIEHASH

Creating a tied pf::config::cached object

=cut

sub TIEHASH {
    my ($proto,@args) = @_;
    my $object;
    my $first_arg = $args[0];
    if(ref($first_arg) && $args[0]->isa('pf::config::cached')) {
        $object = $first_arg;
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
    my ($self,$file,$computeSub) = @_;
    return $self->cache->compute(
        $file,
        {
            expire_if => \&_expireIf
        },
        $computeSub
    );
}

=head2 cache - get the global CHI object

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
    my ($cache_object) = @_;
    my $file = $cache_object->key;
    return -e $file &&  ($cache_object->created_at < getModTimestamp($file));
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
    my $any_reloaded = 0;
    my @files;
    while (my($file,$config) = each %LOADED_CONFIGS) {
        $config->ReadConfig();
        push @files, $file if $RELOADED{$file};
    }
    if(@files) {
        local $_;
        $_->(@files) for (@GLOBAL_ON_RELOAD);
    }
}


=head2 addReloadCallback

Add callbacks config have been reloaded

=cut

sub addReloadCallback {
    my ($self,@callbacks) = @_;
    my $file = $self->GetFileName;
    local $_;
    push @{$ON_RELOAD{$file}}, grep { ref($_) eq 'CODE' } @callbacks;
}

=head2 AddGlobalReloadCallback

Add global callbacks when configs have been reloaded

=cut

sub AddGlobalReloadCallback {
    local $_;
    push @GLOBAL_ON_RELOAD, grep { ref($_) eq 'CODE' } @_;
}


=head2 DESTROY

to avoid AUTOLOAD being called on object destruction

=cut

sub DESTROY {}


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
            $data->{$key} =~ s/\s+$//;
        }
    }
}

=head2 _buildCHIArgs

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
        $self->SectionExists($new_sect)) {
        return undef;
    }

    $self->_caseify(\$new_sect);
    $self->_AddSection_Helper($new_sect);
    $self->_caseify(\$old_sect);

    # This is done the fast way, change if data structure changes!!
    foreach my $key (qw(v sCMT pCMT EOT parms myparms)) {
        $self->{$key}{$new_sect} = delete $self->{$key}{$old_sect};
    }

    $self->{sects} = [grep {$_ ne $old_sect} @{$self->{sects}}];
    $self->_touch_section($old_sect);

    $self->RemoveGroupMember($old_sect);

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
