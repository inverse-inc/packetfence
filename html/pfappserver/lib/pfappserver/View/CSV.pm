package pfappserver::View::CSV;

use base qw ( Catalyst::View::CSV );

__PACKAGE__->config ( sep_char => ",", suffix => "csv" );

sub process {
    my ($self, $c) = @_;
    unless(defined($c->stash->{columns})){
        if(defined($c->stash->{items}->[0])) {
            $c->stash->{columns} = [keys(%{$c->stash->{items}->[0]})];
        }
    }
    $c->stash->{data} = $c->stash->{items};
    $self->SUPER::process($c);
}

1;

