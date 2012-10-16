package pfappserver::Form::Field::Duration;
 
use HTML::FormHandler::Moose;
extends 'HTML::FormHandler::Field::Compound';
use namespace::autoclean;

use pf::config;

#has '+wrapper_class' => ['interval' ];
has '+do_wrapper' => ( default => 1 );
has '+do_label' => ( default => 1 );
has '+inflate_default_method'=> ( default => sub { \&duration_inflate } );
has '+deflate_value_method'=> ( default => sub { \&duration_deflate } );

has_field 'interval' =>
  (
   type => 'PosInteger',
   do_label => 0,
   #do_wrapper => 0,
   #tags => { no_errors => 1 },
   widget_wrapper => 'None',
   element_class => ['input'],
   apply => [ { check => qr/^[0-9]+$/ } ],
  );
has_field 'unit' =>
  (
   type => 'Select',
   widget => 'ButtonGroup',
   do_label => 0,
   localize_labels => 1,
   tags => { no_errors => 1 },
   wrapper_class => ['btn-group'],
   wrapper_attr => {'data-toggle' => 'buttons-radio'},
   options => [
               {value => 's', label => 'seconds'},
               {value => 'm', label => 'minutes'},
               {value => 'h', label => 'hours'},
               {value => 'D', label => 'days'},
               {value => 'W', label => 'weeks'},
               {value => 'M', label => 'months'},
               {value => "Y", label => 'years'},
              ],
   apply => [ { check => $TIME_MODIFIER_RE } ],
  );

sub duration_inflate {
    my ($self, $value) = @_;

    #use Data::Dumper;
    #$self->form->ctx->log->debug('initial window = ' . Dumper $self->form->init_object->{window});
    return {} unless ($value =~ m/(\d+)($TIME_MODIFIER_RE)/);
    my $hash = {interval => $1,
                unit => $2};

    return $hash;
}

sub duration_deflate {
    my ($self, $value) = @_;

#    if ($self->form->value->{'window_dynamic'} eq 'dynamic') {
#        return 'dynamic';
#    }
    
    my $interval = $value->{interval};
    my $unit = $value->{unit};

    return $interval.$unit;
}

#sub clear_errors {
#    
#}

#sub build_update_subfields {{
#    all => { wrapper_class => ['interval'] }
#}}

#sub html_attributes {
#    my ( $self, $field, $type, $attr ) = @_;
#    $attr->{class} = 'interval' if $type eq 'duration';
#    return $attr;
#}

1;
