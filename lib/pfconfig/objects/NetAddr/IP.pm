package pfconfig::objects::NetAddr::IP;

use base qw(NetAddr::IP);
use NetAddr::IP;
use pf::log;
use Data::Dumper;

sub new {
    my $package = shift;
    my $o = NetAddr::IP->new(@_);
    if(ref($o) ne "") {
        return bless $o, $package;
    }
    else {
        get_logger->error("Cannot instantiate NetAddr::IP with params ".Dumper(@_).", ignoring it");
        return undef;
    }
}

sub TO_JSON {
    my ($self) = @_;
    my $o = {
       ip => $self->addr(), 
       # The golang driver excepts this to be a string
       mask => $self->mask()."",
       cidr => $self->cidr(),
    };
    return $o;
}

1;

