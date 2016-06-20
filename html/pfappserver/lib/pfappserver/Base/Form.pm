package pfappserver::Base::Form;

=head1 NAME

pfappserver::Base::Form
The base form

=cut

=head1 DESCRIPTION

The Base class for Forms

=cut

use HTML::FormHandler::Moose;
extends 'HTML::FormHandler';
with 'HTML::FormHandler::Widget::Theme::Bootstrap';

has '+field_name_space' => ( default => 'pfappserver::Form::Field' );
has '+widget_name_space' => ( default => 'pfappserver::Form::Widget' );
has '+language_handle' => ( builder => 'get_language_handle_from_ctx' );

use fingerbank::Model::Device;
use fingerbank::Constant;
use List::MoreUtils qw(any uniq);

=head2 get_language_handle_from_ctx

=cut

sub get_language_handle_from_ctx {
    my $self = shift;

    return pfappserver::I18N->get_handle( @{ $self->ctx->languages } );
}

=head2 html_attributes

Translate placeholders in select inputs (data-placeholder), if defined

=cut

sub html_attributes {
    my ( $self, $obj, $type, $attr, $result ) = @_;
    # obj is either form or field
    if (exists $attr->{'data-placeholder'}) {
        $attr->{'data-placeholder'} = $self->_localize($attr->{'data-placeholder'});
    }
    return $attr;
}

=head2 build_update_subfields

Set common attributes to specific field types

=cut

sub build_update_subfields {{
    by_type =>
      {
       'IntRange' =>
       {
        element_class => ['input-mini'],
       },
       'PosInteger' =>
       {
        element_class => ['input-mini'],
        element_attr => {'min' => '0'},
       },
       'TextArea' =>
       {
        element_class => ['input-xlarge'],
       },
       'Uneditable' =>
       {
        element_class => ['uneditable'],
       },
       'DatePicker' =>
       {
        element_class =>  ['datepicker', 'input-small'],
        element_attr => { 'data-date-format' => 'yyyy-mm-dd',
                          placeholder => 'yyyy-mm-dd' },
       },
       'TimePicker' =>
       {
        element_class => ['timepicker-default', 'input-small'],
        element_attr => {placeholder => 'HH:MM'},
       },
      },
}}

=head2 update_fields

Set conditional attributes for specific fields depending on their attributes

=cut

sub update_fields {
    my $self = shift;

    foreach my $field (@{$self->fields}) {
        $self->update_field($field);
    }
}

sub update_field {
    my ($self, $field) = @_;

    if ($field->required) {
        $field->set_element_attr('data-required' => 'required');
        $field->tags->{label_after} = ' <i class="icon-exclamation-sign"></i>';
    }
    if ($field->type eq 'PosInteger') {
        $field->type_attr($field->html5_type_attr);
        $field->set_element_attr('data-type' => 'number');
    }
    elsif ($field->type eq 'DatePicker') {
        if ($field->start) {
            $field->set_element_attr('data-date-startdate' => $field->start);
        }
        if ($field->end) {
            $field->set_element_attr('data-date-enddate' => $field->end);
        }
    }
    elsif ($field->can('fields')) {
        foreach my $subfield (@{$field->fields}) {
            $self->update_field($subfield);
        }
    }
}

=head2 field_errors

Return a hashref of field errors. Can be called once the form has been processed.

=cut

sub field_errors {
    my $self = shift;

    my %errors = ();
    if ($self->has_errors) {
        foreach my $field ($self->error_fields) {
            $errors{$field->name} = join(' ', @{$field->errors});
        }
    }

    return \%errors;
}

=head2 ACCEPT_CONTEXT

To automatically add the context to the Form

=cut

sub ACCEPT_CONTEXT {
    my ($self, $c, @args) = @_;
    return $self->new(ctx => $c, @args);
}

=head2 id_validator

Validation for an identifier

=cut

sub id_validator {
    my ($field_name) = @_;
    return {
        check => qr/^[a-zA-Z0-9][a-zA-Z0-9\._-]*$/,
        message =>
            "The $field_name is invalid. The $field_name can only contain alphanumeric characters, dashes, period and underscores."
   };   
}

before 'process' => sub {
    my ($self) = @_;
    foreach my $field (@{$self->fields}){
        if($field->type eq "FingerbankSelect"){
            # no need for pretty formatting, this is just for validation purposes
            my @options = map { 
                {
                    value => $_->id,
                    label => $_->id,
                }
            } $field->fingerbank_model->all();
            $field->options(\@options);
        }
    }
};

after 'process' => sub {
    my ($self) = @_;
    foreach my $field (@{$self->fields}) {
        if($field->type eq "FingerbankSelect"){

            my @base_ids = $field->fingerbank_model->base_ids();
            my @options = map {
                { 
                    value => $_,
                    label => [ $field->fingerbank_model->read($_) ]->[1]->{$field->fingerbank_model->description_field},
                }
            } uniq(@base_ids, @{$field->value});

            $field->options(\@options);
        }
    }
};


=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301,
USA.

=cut

__PACKAGE__->meta->make_immutable;

1;

