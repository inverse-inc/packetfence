package pfconfig::backend::memcached;

use base 'pfconfig::backend';

sub init {
  my ($self) = @_;
  $self->{cache} = new Cache::Memcached {
    'servers' => ['127.0.0.1:11211']
  };
}

1;
