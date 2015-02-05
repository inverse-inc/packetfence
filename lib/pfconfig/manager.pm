package pfconfig::manager;

use strict;
use warnings;

#use Cache::BDB;
use Cache::Memcached;
use Config::IniFiles;
use List::MoreUtils qw(any firstval uniq);
use Scalar::Util qw(refaddr reftype tainted blessed);
use UNIVERSAL::require;
use Data::Dumper;
use pfconfig::backend::memcached;
use pf::log;

sub config_builder {
  my ($self, $namespace) = @_;
  my $logger = get_logger;

  my $elem = $self->get_namespace($namespace);
  my $tmp = $elem->build();

  return $tmp;
};

sub get_namespace {
  my ($self, $name) = @_;
  my $logger = get_logger;
   my $type = "pfconfig::namespaces::$name";

  # load the module to instantiate
  if ( !(eval "$type->require()" ) ) {
      $logger->error( "Can not load namespace $name "
          . "Read the following message for details: $@" );
  }

  my $elem = $type->new($self); 

  return $elem;
}

sub new {
  my ($class) = @_;
  my $self = bless {}, $class;

  $self->init_cache();

  return $self;
}

sub init_cache {
  my ($self) = @_;
  my $logger = get_logger;

  $self->{cache} = pfconfig::backend::memcached->new;

  $self->{memory} = {};
  $self->{memorized_at} = {};
}

# update the timestamp on the control file
# send the signal that the raw memory is expired
sub touch_cache {
  my ($self, $what) = @_;
  my $logger = get_logger;
  $what =~ s/\//;/g;
  my $filename = "/usr/local/pf/var/$what-control";
  open HANDLE, ">>$filename" or die "touch $filename: $!\n"; 
  close HANDLE;
  my $now = time;
  utime $now, $now, "$filename";
}

# get a key in the cache
sub get_cache {
  my ($self, $what) = @_;
  my $logger = get_logger;
  # we look in raw memory and make sure that it's not expired
  if(defined($self->{memory}->{$what}) && $self->is_valid($what)){
    $logger->debug("Getting $what from memory");
    return $self->{memory}->{$what};
  }
  else {
    my $cached = $self->{cache}->get($what);
    # raw memory is expired but cache is not
    if($cached){
      $logger->debug("Getting $what from cache backend");
      $self->{memory}->{$what} = $cached;
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

sub cache_resource {
    my ($self, $what) = @_;
    my $logger = get_logger;

    $logger->debug("loading $what from outside");
    my $result = $self->config_builder($what);
    my $cache_w = $self->{cache}->set($what, $result, 864000) ;
    $logger->trace("Cache write gave : $cache_w");
    $self->touch_cache($what);
    $self->{memory}->{$what} = $result;
    $self->{memorized_at}->{$what} = time; 

    return $result;

}

# helper to know if the raw memory cache is still valid
sub is_valid {
  my ($self, $what) = @_;
  my $logger = get_logger;
  my $control_file;
  ($control_file = $what) =~ s/\//;/g;
  my $file_timestamp = (stat("/usr/local/pf/var/".$control_file."-control"))[9];

  unless(defined($file_timestamp)){
    $logger->warn("Filesystem timestamp is not set for $what. Setting it as now and considering memory as invalid.");
    $self->touch_cache($what);
    return 0;
  }

  my $memory_timestamp = $self->{memorized_at}->{$what};
  $logger->trace("Control file has timestamp $file_timestamp and memory has timestamp $memory_timestamp for key $what");
  # if the timestamp of the file is after the one we have in memory
  # then we are expired
  if ($memory_timestamp > $file_timestamp){
    $logger->trace("Memory configuration is still valid for key $what");
    return 1;
  }
  else{
    $logger->info("Memory configuration is not valid anymore for key $what");
    return 0;
  }
}

# expire a key in the cache and rebuild it
# will expire the memory cache after building
sub expire {
  my ($self, $what) = @_;
  my $logger = get_logger;
  $logger->info("Expiring resource : $what");
  $self->cache_resource($what);

  my $namespace = $self->get_namespace($what);
  if ($namespace->{child_resources}){
    foreach my $child_resource (@{$namespace->{child_resources}}){
      $logger->info("Expiring child resource $child_resource. Master resource is $what");
      $self->expire($child_resource);
    }
  }

}

1;
