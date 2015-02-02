package zicache::zicache;

#use Cache::BDB;
use Cache::Memcached;
use Config::IniFiles;
use List::MoreUtils qw(any firstval uniq);
use Scalar::Util qw(refaddr reftype tainted blessed);
use UNIVERSAL::require;
use Data::Dumper;
use zicache::backend::memcached;

sub config_builder {
  my ($self, $namespace) = @_;

  my $type = "zicache::namespaces::$namespace";

  # load the module to instantiate
  if ( !(eval "$type->require()" ) ) {
      print STDERR "Can not load namespace $namespace "
          . "Read the following message for details: $@";
  }

  my $elem = $type->new($self);
  my $tmp = $elem->build();

  return $tmp;
};

sub new {
  my ($class) = @_;
  my $self = bless {}, $class;

  $self->init_cache();

  return $self;
}

sub init_cache {
  my ($self) = @_;

  $self->{cache} = zicache::backend::memcached->new;

  $self->{memory} = {};
  $self->{memorized_at} = {};
}

# update the timestamp on the control file
# send the signal that the raw memory is expired
sub touch_cache {
  my ($self, $what) = @_;
  $what =~ s/\//;/g;
  open HANDLE, ">>/usr/local/pf/var/$what-control" or die "touch $filename: $!\n"; 
  close HANDLE;
  my $now = time;
  utime $now, $now, "/usr/local/pf/var/$what-control";
}

# get a key in the cache
sub get_cache {
  my ($self, $what) = @_;
  print "Cache value : ".$cached."\n";
  # we look in raw memory and make sure that it's not expired
  if(defined($self->{memory}->{$what}) && $self->is_valid($what)){
    print "Getting from memory\n";
    return $self->{memory}->{$what};
  }
  else {
    my $cached = $self->{cache}->get($what);
    # raw memory is expired but cache is not
    if($cached){
      print "Getting from cache db\n";
      $self->{memory}->{$what} = $cached;
      $self->{memorized_at}->{$what} = time; 
      return $cached;
    }
    # everything is expired. need to rebuild completely
    else {
      print "loading from outside\n";
      my $result = $self->config_builder($what);
      print "in get cache".Dumper($result);
      my $cache_w = $self->{cache}->set($what, $result, 864000) ;
      print "Cache write gave : $cache_w \n";
      $self->touch_cache($what);
      $self->{memory}->{$what} = $result;
      $self->{memorized_at}->{$what} = time; 
      return $result;
    }
  }
 
}

# helper to know if the raw memory cache is still valid
sub is_valid {
  my ($self, $what) = @_;
  my $control_file;
  ($control_file = $what) =~ s/\//;/g;
  my $epoch_timestamp = (stat("var/".$control_file."-control"))[9];
  print "ts : ".$epoch_timestamp."\n";
  print "memorized ts : ".$self->{memorized_at}->{$what}."\n";
  # if the timestamp of the file is after the one we have in memory
  # then we are expired
  if ($self->{memorized_at}->{$what} > $epoch_timestamp){
    print "valid \n";
    return 1;
  }
  else{
    print "invalid \n";
    return 0;
  }
}

# expire a key in the cache and rebuild it
# will expire the memory cache after building
sub expire {
  my ($self, $what) = @_;
  $self->{cache}->remove($what);
  $self->get_cache($what);
}

1;
