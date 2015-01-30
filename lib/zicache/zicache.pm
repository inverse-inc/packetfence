package zicache::zicache;

use Cache::BDB;
use Config::IniFiles;
use List::MoreUtils qw(any firstval uniq);
use Scalar::Util qw(refaddr reftype tainted blessed);

# ZI cache object
my $cache;
# raw memory cache
my %memory;
# raw memory timestamps
my $memorized_at;

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

sub untaint_value {
    my $val = shift;
    if (defined $val && $val =~ /^(.*)$/) {
        return $1;
    }
}

sub to_hash {
    my ($self) = @_;
    my %hash;
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
    return %hash;
}

# going all javascript and sh*t
my $config_builder = sub {
  my ($file) = @_;
  tie %tmp_cfg, 'Config::IniFiles', ( -file => $file );

  $tmp_cfg{'127.0.0.1'} = {
      id                => '127.0.0.1',
      type              => 'PacketFence',
      mode              => 'production',
      SNMPVersionTrap   => '1',
      SNMPCommunityTrap => 'public'
  };

  foreach my $section_name (keys %tmp_cfg){
    unless($section_name eq "default"){
      foreach my $element_name (keys %{$tmp_cfg{default}}){
        unless (exists $tmp_cfg{$section_name}{$element_name}){
          $tmp_cfg{$section_name}{$element_name} = $tmp_cfg{default}{$element_name};
        }
      }
    }
  }


  foreach my $switch ( values %tmp_cfg ) {

      # transforming uplink and inlineTrigger to arrays
      foreach my $key (qw(uplink inlineTrigger)) {
          my $value = $switch->{$key} || "";
          $switch->{$key} = [ split /\s*,\s*/, $value ];
      }

      # transforming vlans and roles to hashes
      my %merged = ( Vlan => {}, Role => {}, AccessList => {} );
      foreach my $key ( grep {/(Vlan|Role|AccessList)$/} keys %{$switch} ) {
          next unless my $value = $switch->{$key};
          if ( my ( $type_key, $type ) = ( $key =~ /^(.+)(Vlan|Role|AccessList)$/ ) ) {
              $merged{$type}{$type_key} = $value;
          }
      }
      $switch->{roles}        = $merged{Role};
      $switch->{vlans}        = $merged{Vlan};
      $switch->{access_lists} = $merged{AccessList};
      $switch->{VoIPEnabled} = (
          $switch->{VoIPEnabled} =~ /^\s*(y|yes|true|enabled|1)\s*$/i
          ? 1
          : 0
      );
      $switch->{mode} = lc( $switch->{mode} );
      $switch->{'wsUser'} ||= $switch->{'htaccessUser'};
      $switch->{'wsPwd'} ||= $switch->{'htaccessPwd'} || '';
      foreach my $cli_default (qw(EnablePwd Pwd User)) {
          $switch->{"cli${cli_default}"}
            ||= $switch->{"telnet${cli_default}"};
      }
      foreach my $snmpDefault (
          qw(communityRead communityTrap communityWrite version)) {
          my $snmpkey = "SNMP" . ucfirst($snmpDefault);
          $switch->{$snmpkey} ||= $switch->{$snmpDefault};
      }
  }


  return \%tmp_cfg;
};

sub init_cache {
  my %options = (
    cache_root => "tmp/",
    namespace => "Zi::Namespace",
    default_expires_in => 300, # seconds
  );
  $cache = Cache::BDB->new(%options);

  %memory = ();
  $memorized_at = {};
}

# update the timestamp on the control file
# send the signal that the raw memory is expired
sub touch_cache {
  my ($what) = @_;
  $what =~ s/\//;/g;
  open HANDLE, ">>tmp/$what-control" or die "touch $filename: $!\n"; 
  close HANDLE;
  my $now = time;
  utime $now, $now, "tmp/$what-control";
}

# get a key in the cache
sub get_cache {
  my ($what) = @_;
  print "Cache value : ".$cached."\n";
  # we look in raw memory and make sure that it's not expired
  if(defined($memory->{$what}) && is_valid($what)){
    print "Getting from memory\n";
    return $memory->{$what};
  }
  else {
    my $cached = $cache->get($what);
    # raw memory is expired but cache is not
    if($cached){
      print "Getting from cache db\n";
      $memory->{$what} = $cached;
      $memorized_at->{$what} = time; 
      return $cached;
    }
    # everything is expired. need to rebuild completely
    else {
      print "loading from outside\n";
      my $result = $config_builder->($what);
      $cache->set($what, $result, 864000) ;
      touch_cache($what);
      $memory->{$what} = $cached;
      $memorized_at->{$what} = time; 
      return $result;
    }
  }
 
}

# helper to know if the raw memory cache is still valid
sub is_valid {
  my ($what) = @_;
  my $control_file;
  ($control_file = $what) =~ s/\//;/g;
  my $epoch_timestamp = (stat("tmp/".$control_file."-control"))[9];
  print "ts : ".$epoch_timestamp."\n";
  print "memorized ts : ".$memorized_at->{$what}."\n";
  # if the timestamp of the file is after the one we have in memory
  # then we are expired
  if ($memorized_at->{$what} > $epoch_timestamp){
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
  my ($what) = @_;
  $cache->remove($what);
  get_cache($what);
}

# yes this is crappy module that is not OO
init_cache();

1;
