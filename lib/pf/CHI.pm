package pf::CHI;

=head1 NAME

pf::CHI add documentation

=cut

=head1 DESCRIPTION

pf::CHI

=cut

use strict;
use warnings;
use base qw(CHI);
use Module::Pluggable
  search_path => [ 'CHI::Driver', 'pf::Role::CHI' ],
  sub_name    => '_preload_chi_drivers',
  require     => 1,
  inner       => 0,
  except      => qr/(^CHI::Driver::.*Test|FastMmap)/;
use Clone();
use pf::file_paths qw(
    $chi_defaults_config_file
    $chi_config_file
    $var_dir
    $pf_default_file
    $pf_config_file
);
use pf::IniFiles;
use Hash::Merge;
use List::MoreUtils qw(uniq any);
use List::Util qw(first);
use DBI;
use Scalar::Util qw(tainted reftype);
use pf::log;
use Log::Any::Adapter;
use pf::Redis;
use CHI::Driver;
Log::Any::Adapter->set('Log4perl');

my @PRELOADED_CHI_DRIVERS;


Hash::Merge::specify_behavior(
    {
    #Always take the value from the right side
    'SCALAR' => {
        'SCALAR' => sub {$_[1]},
        'ARRAY'  => sub {$_[1]},
        'HASH'   => sub {$_[1]},
      },
      'ARRAY' => {
        #Convert the scalar into an array
        'SCALAR' => sub {[$_[1]]},
        #Always take the value from the right side
        'ARRAY'  => sub {$_[1]},
        #Convert the hash into an array
        'HASH'   => sub {[%{$_[1]}]},
      },
      'HASH' => {
        #Always take the value from the right side
        'SCALAR' => sub {$_[1]},
        #Always take the value of the hash and merge them into the array
        'ARRAY'  => sub {[values %{$_[0]}, @{$_[1]}]},
        #Merge the hash
        'HASH' => sub {
            Hash::Merge::_merge_hashes($_[0], $_[1]);
        },
      },
    },
    'PF_CHI_MERGE'
);

our @CACHE_NAMESPACES = qw(configfilesdata configfiles httpd.admin httpd.portal pfdns switch.overlay ldap_auth fingerbank firewall_sso switch metadefender accounting clustering person_lookup route_int provisioning switch_distributed);

our $chi_default_config = pf::IniFiles->new( -file => $chi_defaults_config_file) or die "Cannot open $chi_defaults_config_file";

our $chi_config = pf::IniFiles->new( -file => $chi_config_file, -allowempty => 1, -import => $chi_default_config) or die "Cannot open $chi_config_file";

our $pf_default_config = pf::IniFiles->new( -file => $pf_default_file) or die "Cannot open $pf_default_file";


our %DEFAULT_CONFIG = (
    'namespace' => {
        map { $_ => { 'storage' => $_ } } @CACHE_NAMESPACES
    },
    'memoize_cache_objects' => 1,
    'defaults'              => {'serializer' => 'Sereal'},
    'storage'               => {
        'raw' => {
            'global' => '1',
            'driver' => 'RawMemory'
        },
        'redis' => {
            driver => 'Redis',
            compress_threshold => 10000,
            server => '127.0.0.1:6379',
            redis_class => 'pf::Redis',
            prefix => 'pf',
            expires_on_backend => 1,
            reconnect => 60,
        },
        'file' => {
            driver => 'File',
            root_dir => "$var_dir/cache",
        },
    }
);

our %DEFAULT_STORAGE = %{$DEFAULT_CONFIG{storage}{redis}};

sub chiConfigFromIniFile {
    my @keys = uniq map { s/ .*$//; $_; } $chi_config->Sections;
    my %args;
    foreach my $key (@keys) {
        $args{$key} = sectionData($chi_config,$key);
    }
    copyStorage($args{storage});
    foreach my $storage (values %{$args{storage}}) {
        my $driver = $storage->{driver};
        if (defined $driver) {
            if($driver eq 'File') {
                setFileDriverParams($storage);
            } elsif($driver eq 'DBI') {
                setDBIDriverParams($storage);
            }
        }
        foreach my $param (qw(servers traits roles)) {
            next unless exists $storage->{$param};
            my $value =  listify($storage->{$param});
            $storage->{$param} = [ map { split /\s*,\s*/, $_ } @$value ];
        }
        push @{$storage->{traits}}, '+pf::Role::CHI::Driver::ComputeWithUndef';
    }
    setDefaultStorage($args{storage});
    setRawL1CacheAsLast($args{storage}{configfiles});
    my $merge = Hash::Merge->new('PF_CHI_MERGE');
    my $config = $merge->merge( \%DEFAULT_CONFIG, \%args );
    return $config;
}

sub setDefaultStorage {
    my ($storageUnits) = @_;
    my $defaults = delete $storageUnits->{DEFAULT} || \%DEFAULT_STORAGE;
    my $merge = Hash::Merge->new('PF_CHI_MERGE');
    foreach my $name (@CACHE_NAMESPACES) {
        $storageUnits->{$name} = {} unless exists $storageUnits->{$name};
        my $clonedDefaults = Clone::clone($defaults);
        my $storage = $storageUnits->{$name};
        %$storage = %{$merge->merge( $storage, $clonedDefaults )};
    }
}

sub copyStorage {
    my ($storageUnits) = @_;
    foreach my $storageUnit (values %$storageUnits) {
        next unless exists $storageUnit->{storage} &&
            defined $storageUnit->{storage};
        my $useStorage = delete $storageUnit->{storage};
        %$storageUnit = (%{$storageUnits->{$useStorage}},%$storageUnit);
    }
}

sub setFileDriverParams {
    my ($storage) = @_;
    $storage->{dir_create_mode} = oct('02775');
    $storage->{file_create_mode} = oct('00664');
    $storage->{umask_on_store} = oct('00007');
    $storage->{traits} = ['+pf::Role::CHI::Driver::FileUmask', '+pf::Role::CHI::Driver::Untaint'];
}

sub setDBIDriverParams {
    my ($storage, $dbi) = @_;
    $storage->{dbh} = \&getDbi;
}

=head2 getDbi

Get the DBI using the database config from pf.conf

=cut

sub getDbi {
    my $pf_config = pf::IniFiles->new( -file => $pf_config_file, -allowempty => 1, -import => $pf_default_config) or die "Cannot open $pf_config_file";
    my ($db,$host,$port,$user,$pass) = @{sectionData($pf_config, "database")}{qw(db host port user pass)};
    return DBI->connect( "dbi:mysql:dbname=$db;host=$host;port=$port",
    $user, $pass, { RaiseError => 0, PrintError => 0 } );

}

sub setRawL1CacheAsLast {
    my ($storage) = @_;
    if ( exists $storage->{l1_cache} ) {
        setRawL1CacheAsLast($storage->{l1_cache});
    } else {
        $storage->{l1_cache} = { 'storage' => 'raw' };
    }
}

sub sectionData {
    my ($config,$section) = @_;
    my %args;
    foreach my $param ($config->Parameters($section)) {
        my $val = $config->val($section,$param);
        $args{$param} = $1 if $val =~ /^(.*)$/;
    }
    my @sections = uniq map { s/^$section ([^ ]+).*$//;$1 } grep { /^$section / } $config->Sections;
    foreach my $name (@sections) {
        $args{$name} = sectionData($config,"$section $name");
    }
    return \%args;
}

sub CLONE {
    pf::CHI->clear_memoized_cache_objects;
}

sub preload_chi_drivers {
    unless (@PRELOADED_CHI_DRIVERS) {
        @PRELOADED_CHI_DRIVERS = __PACKAGE__->_preload_chi_drivers;
    }
}


__PACKAGE__->config(chiConfigFromIniFile());

=head2 listify

Will change a scalar to an array ref if it is not one already

=cut

sub listify($) {
    ref($_[0]) eq 'ARRAY' ? $_[0] : [$_[0]]
}

=head2 get_redis_config

Get the redis config from pf::CHI

=cut

sub get_redis_config {
    # This code was adapted from CHI::Driver::Redis::BUILD
    my $config = CHI::Driver->non_common_constructor_params(pf::CHI->config->{storage}{redis});
    $config->{encoding} //= undef;
    delete @$config{qw(redis redis_class redis_options prefix driver traits)};
    return $config;
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

1;
