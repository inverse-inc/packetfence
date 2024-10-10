package fingerbank::Base::Schema;

use Moose;
use namespace::autoclean;
use MooseX::NonMoose;
use fingerbank::Log;

extends 'DBIx::Class::Core';

=head2 view_with_named_params

Create a view with named params that is universal to all databases by locally creating a map of where the named params go which can then be used to create the bind params list

=cut

sub view_with_named_params {
    my ($class, $view) = @_;
    my @ordered = $view =~ /\$([0-9]+)/g;
    $class->meta->{params} = \@ordered;
    $view =~ s/\$[0-9]+/\?/g;
    $class->result_source_instance->view_definition($view);
}

=head2 view_bind_params

Get the full list of bind params for the view based on the named params (map)

=cut

sub view_bind_params {
    my ($class, $map) = @_;
    my $logger = fingerbank::Log::get_logger;
    my @bind_params;

    # Looking in this class and super classes meta for the bind params map
    my $params = $class->meta->{params};
    unless(defined($params)) {
        foreach my $parent_meta (@{$class->meta->{_superclass_metas}}) {
            $params = $parent_meta->{params};
            if(defined($params)) {
                last;
            }
        }
    }

    foreach my $param (@$params) {
        my $element = $map->[$param-1];
        $logger->trace("Setting bind param $param with value $element");
        if(defined($element)){
            push @bind_params, $element;
        }
        else {
            die("Invalid argument $param");
        }
    }
    return \@bind_params;
}

__PACKAGE__->meta->make_immutable;

1;
