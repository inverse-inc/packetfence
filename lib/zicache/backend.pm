package zicache::backend;

# abstract class for a backend

sub new {
  my ($class) = @_;
  my $self = bless {}, $class;

  # this needs to be defined in init
  $self->{cache};

  $self->init();

  return $self;
}

sub init {
  # abstact
}

sub get {
  my ($self, $key) = @_;
  return $self->{cache}->get($key);
} 

sub set {
  my ($self, $key, $value) = @_;
  return $self->{cache}->set($key, $value);
}

sub remove {
  my ($self, $key) = @_;
  return $self->{cache}->remove($key);
}

1;
