package pfappserver::Form::Config::Pf;

=head1 NAME

pfappserver::Form::Config::Pf - Web form for pf.conf

=head1 DESCRIPTION

Form definition to create or update a section of pf.conf.

=cut

use HTML::FormHandler::Moose;
extends 'HTML::FormHandler';
with 'pfappserver::Form::Widget::Theme::Pf';

has '+field_name_space' => ( default => 'pfappserver::Form::Field' );
has '+widget_name_space' => ( default => 'pfappserver::Form::Widget' );
has '+language_handle' => ( builder => 'get_language_handle_from_ctx' );

has 'section' => ( is => 'ro' );

=head2 field_list

Dynamically build the field list from the 'section' instance attribute.

=cut

sub field_list {
    my $self = shift;

    my $list = [];
    my $init_compound = 1;
    foreach my $param (@{$self->section}) {
        my $name = $param->{parameter};
        #$name =~ s/\./::dot::/g; $name =~ s/::dot::/\./;
        my $id = $name; $id =~ s/\./_/;
        if ($init_compound) {
            # Create a compound field for the section name in order to keep
            # the section prefix for each parameter
            my ($section) = $name =~ m/^([^\.]+)\./;
            push(@$list, $section => { type => 'Compound' });
            $init_compound = 0;
        }
        my $field =
          { element_attr => { 'placeholder' => $param->{default_value} },
            tags => { after_element => \&help, # parent method, defined in Theme::Pf
                      help => $param->{description} },
            id => $id,
            label => $name,
          };
        my $type = $param->{type};
        {
            $type eq 'text' && do {
                $field->{type} = 'Text';
                last;
            };
            $type eq 'text-large' && do {
                $field->{type} = 'TextArea';
                last;
            };
            $type eq 'numeric' && do {
                $field->{type} = 'PosInteger';
                last;
            };
            $type eq 'multi' && do {
                $field->{type} = 'Select';
                $field->{multiple} = 1;
                $field->{element_class} = ['chzn-select'];
                $field->{element_attr} = {'data-placeholder' => 'Click to add'};
                my @options = map { { value => $_, label => $_ } } @{$param->{options}};
                $field->{options} = \@options;
                last;
            };
            $type eq 'toggle' && do {
                if ($param->{options}->[0] eq 'enabled' ||
                    $param->{options}->[0] eq 'yes') {
                    $field->{type} = 'Toggle';
                    $field->{checkbox_value} = $param->{options}->[0];
                    $field->{unchecked_value} = $param->{options}->[1];
                }
                else {
                    $field->{type} = 'Select';
                    $field->{element_class} = ['chzn-deselect'];
                    $field->{element_attr} = {'data-placeholder' => 'No selection'};
                    my @options = map { { value => $_, label => $_ } } @{$param->{options}};
                    $field->{options} = \@options;
                }
                last;
            };
            $type eq 'date' && do {
                $field->{type} = 'DatePicker';
                last;
            };
            $type eq 'time' && do {
                $field->{type} = 'Duration';
                last;
            };
        }

        push(@$list, $name => $field);
    }

    return $list;
}

=head2 init_object

Dynamically initialize the field values from the 'section' instance attribute.

=cut

sub init_object {
    my $self = shift;

    my $object = {};
    foreach my $param (@{$self->section}) {
        my ($section, $name) = $param->{parameter} =~ m/^([^\.]+)\.(.+)$/;
        #$name =~ s/\./::dot::/;
        $object->{$section}->{$name} = $param->{value};
    }

    return $object;
}

#sub validate {
#    my $self = shift;
#
#    foreach my $section (keys %{$self->value}) {
#        foreach my $field (keys %{$self->value->{$section}}) {
#            my $new_field = $field;
#            $new_field =~ s/::dot::/\./g;
#            $self->value->{$section}->{$new_field}
#              = delete $self->value->{$section}->{$field};
#        }
#    }
#}

=head1 COPYRIGHT

Copyright (C) 2012 Inverse inc.

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
