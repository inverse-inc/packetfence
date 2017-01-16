package pfappserver::Form::Field::SourceRuleAction;

=head1 NAME

pfappserver::Form::Field::SourceRuleAction - action of a user source rule

=head1 DESCRIPTION

Manages the action of  user source rule

=cut

use pfappserver::Form::Field::DynamicList;
use pf::Authentication::Action;
use HTML::FormHandler::Moose;
extends 'HTML::FormHandler::Field::Compound';
has '+widget_wrapper' => (default => 'Bootstrap');
has '+inflate_default_method'=> ( default => sub { \&inflate } );
has '+deflate_value_method'=> ( default => sub { \&deflate } );


# Form fields

has_field 'type' => (
    type           => 'Select',
    widget_wrapper => 'None',
    options_method => \&options_type,
    element_class  => ['span3'],
    do_label       => 0,
);

has_field 'value' => (
    type           => 'Text',
    do_label       => 0,
    widget_wrapper => 'None',
);

=head2 options_type

Populate the action type select field with the available actions of the
authentication source.

=cut

sub options_type {
    my $self = shift;

    my ($classname, $actions_ref, @actions);
    my $form = $self->form;

    $classname = $form->source_type;
    eval "require $classname";
    if ($@) {
        $self->form->ctx->log->error($@);
        return [];
    }
    my @allowed_actions = $form->_get_allowed_options('allowed_actions');
    unless (@allowed_actions) {
        @allowed_actions = @{$classname->available_actions()};
    }
    @actions = map { 
      { value => $_, 
        label => $self->_localize($_), 
        attributes => { 'data-rule-class' => pf::Authentication::Action->getRuleClassForAction($_) } 
      } 
    } @allowed_actions;

    return @actions;
}


=head2 inflate

inflate the value from the config store

=cut

sub inflate {
    my ($self, $value) = @_;
    my %condition;
    @condition{qw(type value)} = split /\s*=\s*/, $value;
    return \%condition;
}

=head2 deflate

deflate to be saved into the config store

=cut

sub deflate {
    my ($self, $value) = @_;
    return join("=", @{$value}{qw(type value)});
}

=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

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
