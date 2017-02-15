package pfconfig::objects::Net::Netmask;

use base qw(Net::Netmask);

sub new {
    my $package = shift;
    my $o = Net::Netmask->new(@_);
    return bless $o, $package;
}

sub TO_JSON {
    my ($self) = @_;
    my $o = {
       ip => $self->{Tip}, 
       ip_int => $self->{IBASE},
       mask => $self->{BITS},
       int => $self->{Tint},
    };
    $o->{vip} = $self->{Tvip} if(defined($self->{Tvip}));
    return $o;
}

1;
