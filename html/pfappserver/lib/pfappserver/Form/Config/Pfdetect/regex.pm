package pfappserver::Form::Config::Pfdetect::regex;

=head1 NAME

pfappserver::Form::Config::Pfdetect::regex - Web form for a pfdetect detector

=head1 DESCRIPTION

Form definition to create or update a pfdetect detector.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Config::Pfdetect';
with 'pfappserver::Base::Form::Role::Help';
use pf::log;


sub build_form_element_class { ['form-vertical'] }

=head2 rules

The list of rule

=cut

has_field 'rules' =>
  (
    'type' => 'Repeatable',
    has_label => 0,
   Widget => 'Repeatable',
  );

has_field 'rules.name' =>
  (
   type => 'Text',
   label => 'Name',
   required => 1,
   messages => { required => 'Please specify the name of the rule' },
  );

has_field 'rules.regex' =>
  (
   type => 'Text',
   label => 'Regex',
   required => 1,
   messages => { required => 'Please specify the regex pattern using named captures' },
  );

has_field 'rules.send_add_event' =>
  (
   type => 'Toggle',
   label => 'Send Add Event',
   messages => { required => 'Please specify the if the add_event is sent' },
   checkbox_value => 'enabled',
   unchecked_value => 'disabled',
  );

has_field 'rules.events' =>
  (
   type => 'Text',
   label => 'Event List',
   #This is required if the send_add_event if checked
   #Add validation to the event list
   messages => { required => 'Please specify the regex pattern using named captures' },
  );

=head2 rules.actions

The list of action

=cut

has_field 'rules.actions' =>
  (
    'type' => 'Repeatable',
  );

=head2 rules.actions.contains

The definition for the list of actions

=cut

has_field 'rules.actions.contains' =>
  (
    type => 'Text',
    label => 'Action',
  );


=head2 validate

=cut

sub validate {
    my ($self) = @_;
    my $value  = $self->value;
    my $i      = 0;
    foreach my $rule (@{$value->{rules} // []}) {
        my $regex = eval {qr/$rule->{regex}/};
        if ($@) {
            my $f_rules = $self->field('rules');
            my $f_rule = $f_rules->field($i);
            $f_rule->field("regex")->add_error("Invalid regex provided");
        }
        $i++;
    }
    return 1;
}

=over

=back

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
