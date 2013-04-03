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
use Fcntl qw(:flock);


our $CACHE;
our %LOADED_CONFIGS;
our @GLOBAL_ON_RELOAD;
our %ON_RELOAD;
our %RELOADED;
our %RELOADED_FROM_CACHE;
use overload "%{}" => \&config, fallback => 1;

our $chi_config = Config::IniFiles->new( -file => INSTALL_DIR . "/conf/chi.conf");

=head2 Methods

=over

=item new

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
        delete $params{'-file'} unless (-e $file);
        $config = $class->computeFromPath(
            $file,
            sub {
                my $fh = lock_file_for_reading($file);
                my $config = Config::IniFiles->new(%params);
                unlock_filehandle($fh);
                if(!exists $params{'-file'}) {
                    $config->SetFileName($file);
                }
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

=item config

access for the proxied Config::IniFiles object

=cut

sub config { ${$_[0]}}

=item RewriteConfig

=cut

sub RewriteConfig {
    my ($self) = @_;
    my $config = $self->config;
    my $file = $config->GetFileName;
    my $cache = $self->cache;
    my $cached_object = $cache->get_object($file);
    if($cached_object && _expireIf($cached_object)) {
        die "Config $file was modified from last loading";
    }
    my $fh = lock_file_for_writing($file);
    my $result = $config->WriteConfig($file, -delta => exists $config->{imported});
    unlock_filehandle($fh);
    if($result) {
        $cache->set($file,$config);
    }
    return $result;
}

=item lock_file_for_writing

=cut

sub lock_file_for_writing {
    my ($file) = @_;
    my $fh;
    open($fh,">",$file) or die "cannot open $file";
    flock($fh, LOCK_EX);
    return $fh;
}

=item lock_file_for_reading

=cut

sub lock_file_for_reading {
    my ($file) = @_;
    my $fh;
    open($fh,"<",$file) or die "cannot open $file";
    flock($fh, LOCK_SH);
    return $fh;
}

=item unlock_filehandle

=cut

sub unlock_filehandle {
    my ($fh) = @_;
    flock($fh, LOCK_UN);
    close($fh);
}


=item ReadConfig

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
            my $fh = lock_file_for_reading($file);
            $result = $config->ReadConfig();
            unlock_filehandle($fh);
            $reloaded = 1;
            return $config;
        }
    );
    if (refaddr($config) != refaddr($self->config)) {
        $reloaded = 1;
        $reloaded_from_cache = 1;
    }
    if($reloaded) {
        local $_;
        $_->($self) foreach (@{$ON_RELOAD{$file}});
    }
    $RELOADED{$file} = $reloaded;
    $RELOADED_FROM_CACHE{$file} = $reloaded_from_cache;
    return $result;
}

=item TIEHASH

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

=item AUTOLOAD

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

=item computeFromPath

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

=item cache - get the global CHI object

=cut

sub cache {
    my ($self) = @_;
    unless (defined($CACHE)) {
        $CACHE = $self->_cache();
    }
    return $CACHE;
}

=item _cache

builds the CHI object

=cut

sub _cache {
    return CHI->new(_buildCHIArgs());
}

=item _expireIf

check to see if the config file needs to be reread

=cut

sub _expireIf {
    my ($cache_object) = @_;
    my $file = $cache_object->key;
    return -e $file &&  ($cache_object->created_at < getModTimestamp($file));
}

=item getModTimestamp

simple util function for getting the modification timestamp

=cut

sub getModTimestamp {
    return (stat($_[0]))[9];
}


=item ReloadConfigs

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


=item addReloadCallback

Add callbacks config have been reloaded

=cut

sub addReloadCallback {
    my ($self,@callbacks) = @_;
    my $file = $self->GetFileName;
    local $_;
    push @{$ON_RELOAD{$file}}, grep { ref($_) eq 'CODE' } @callbacks;
}

=item AddGlobalReloadCallback

Add global callbacks when configs have been reloaded

=cut

sub AddGlobalReloadCallback {
    local $_;
    push @GLOBAL_ON_RELOAD, grep { ref($_) eq 'CODE' } @_;
}


=item DESTROY

to avoid AUTOLOAD being called on object destruction

=cut

sub DESTROY {}


=item isa

Fake being a Config::IniFiles

=cut

sub isa {
    my ($proto,$arg) = @_;
    if ($arg eq 'Config::IniFiles') {
        return 1;
    }
    return $proto->SUPER::isa($arg);
}

=item toHash

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

=item cleanupWhitespace

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

=item _buildCHIArgs

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

=back

=head1 COPYRIGHT

Copyright (C) 2013 Inverse inc.

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
