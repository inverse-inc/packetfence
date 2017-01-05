package pfconfig::objects::NetAddr::IP;

use base qw(NetAddr::IP);
use NetAddr::IP;

sub new {
    my $package = shift;
    my $o = NetAddr::IP->new(@_);
    return bless $o, $package;
}

sub TO_JSON {
    my ($self) = @_;
    my $o = {
       ip => $self->addr(), 
       mask => $self->mask(),
       cidr => $self->cidr(),
    };
    return $o;
}

1;

