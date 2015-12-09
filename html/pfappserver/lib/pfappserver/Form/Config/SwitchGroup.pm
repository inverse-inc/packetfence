package pfappserver::Form::Config::SwitchGroup;

=head1 NAME

pfappserver::Form::Config::Switch - Web form for a switch

=head1 DESCRIPTION

Form definition to create or update a network switch.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Config::Switch';

## Definition
has_field 'id' =>
  (
   type => 'Text',
   label => 'Group name',
   accept => ['default'],
   required => 1,
   messages => { required => 'Please specify a group name' },
  );

has_field 'is_group' => 
  (
   type => 'Hidden',
   value => 'Y',
   default => 'Y',
  );

has_field 'group' =>
  (
   type => 'Hidden',
   value => '',
   default => '',
  );


1;
