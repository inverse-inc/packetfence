#  small cron obj 
#  _index wrapper functions for later move to Schedule::Cron
#  we only need %10 of what Schedule::Cron does
#  
package schedule;

sub new {
   my ($class) = @_;
   my $self;
   $self->{timetable}=[];
   bless $self, $class;
   return $self;
}

sub add_entry {
   my ($self,$time,$args) = @_;
   push @{$self->{timetable}},
    {
     time => $time,
     args => $args
    };
}

sub list_entries {
    my ($self) = shift;
    my @ret;
    foreach my $entry (@{$self->{timetable}}) {
        push @ret,$entry;
    }
    return @ret;
}

sub get_entry {
    my ($self,$idx) = @_;
    my $entry = $self->{timetable}->[$idx];
    if (!$entry){
        return undef;
    }
    return ($entry);
}

sub delete_entry
{
    my ($self,$idx) = @_;
    if ($idx <= $#{$self->{timetable}}){
        return splice @{$self->{timetable}},$idx,1;
    }
    else{
        return undef;
    }
}

sub update_entry
{
    my ($self,$idx,$entry) = @_;
    return undef unless $entry;
    return undef unless $entry->{time};
    if ($idx <= $#{$self->{timetable}}){
        $entry->{args} = [] unless $entry->{args};
        return splice @{$self->{timetable}},$idx,1,$entry;
    }
    else{
        return undef;
    }
}

# load cron from $filename
sub load_cron {
  my ($self,$filename) = @_;
  $filename="pf" if (!$filename);
  my $file_fh;
  open($file_fh,'<', "/var/spool/cron/".$filename) || return;
  my @array=<file_fh>;
  foreach (@array){
     my ($min,$hour,$dmon,$month,$dweek,$rest) = split (/\s+/,$_,6);
     $rest=~s/\\//g;  
     chop($rest);
     my $date=join ' ',($min,$hour,$dmon,$month,$dweek);
     if ($rest=~/.*pfcmd.*$/){
        $self->add_entry($date,$rest);
     }
  }
}

# load cron from $filename
sub write_cron {
  my ($self,$filename) = @_;
  $filename="pf" if (!$filename);
  my $file_fh;
  open($file_fh, '>', "/var/spool/cron/".$filename);
  flock($file_fh,2);
  foreach my $ref ($self->list_entries()){
    $ref->{args}=~s/;/\\;/g;   
    print {$file_fh} "$ref->{time}\t$ref->{args}\n";
  }
}

# return all entries in table
sub get_indexes {
  my ($self,$idx) = @_;
  my @array;
  my $i=0;
  my $delimiter = "|";
  foreach my $ref ($self->list_entries()){
      $ref->{args}=~/now\s+(\S+).+tid=(\S+)/;
      push @array,join($delimiter,($i++,$ref->{time},$1,$2))."\n";
  }
  return @array;
}

sub delete_index {
    my ($self,$idx) = @_;
    return $self->delete_entry($idx);
}

sub add_index {
   my ($self,$time,$args) = @_;
   return $self->add_entry($time,$args);
}

# return index int in table
sub get_index {
  my ($self,$idx) = @_;
  my @array;
  my $ref=$self->get_entry($idx);
  $ref->{args}=~/now\s+(\S+).+tid=(\S+)/;
  return ($idx,$ref->{time},$1,$2);
}

# update index int in table with time/args
sub update_index {
    my ($self,$idx,$time,$args) = @_;
    return undef unless $args;
    return undef unless $time;
    my $entry= {
     time => $time,
     args => $args
    };
    return $self->update_entry($idx,$entry);
} 

1 
