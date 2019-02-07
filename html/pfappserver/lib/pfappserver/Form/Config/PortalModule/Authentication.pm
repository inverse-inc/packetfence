package pfappserver::Form::Config::PortalModule::Authentication;

=head1 NAME

pfappserver::Form::Config::PortalModule::AuthModule

=head1 DESCRIPTION

Form definition to create or update an authentication portal module.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Config::PortalModule';
with 'pfappserver::Base::Form::Role::Help';
with 'pfappserver::Base::Form::Role::WithSource';
with 'pfappserver::Base::Form::Role::WithCustomFields';

use pf::log; 
use List::MoreUtils qw(uniq);
use captiveportal::DynamicRouting::Module::Authentication;
sub for_module {'captiveportal::PacketFence::DynamicRouting::Module::Authentication'}

has_field 'pid_field' =>
  (
   type => 'Select',
   label => 'PID field',
   options_method => \&options_pid_field,
   element_class => ['chzn-select'],
   tags => { after_element => \&help,
             help => 'Which field should be used as the PID.' },
  );

has_field 'with_aup' =>
  (
   type => 'Checkbox',
   label => 'Require AUP',
   checkbox_value => '1',
   tags => { after_element => \&help,
             help => 'Require the user to accept the AUP' },
  );

has_field 'aup_template' =>
  (
   type => 'Text',
   label => 'AUP template',
   required => 1,
   tags => { after_element => \&help,
             help => 'The template to use for the AUP' },
  );

has_field 'signup_template' =>
  (
   type => 'Text',
   label => 'Signup template',
   required => 1,
   tags => { after_element => \&help,
             help => 'The template to use for the signup' },
  );

=head2 child_definition

The fields to display

=cut

sub child_definition {
    my ($self) = @_;
    return ($self->source_fields, qw(pid_field custom_fields fields_to_save with_aup aup_template signup_template), $self->auth_module_definition());
}

=head2 BUILD

set the default value for for fields

=cut

sub BUILD {
    my ($self) = @_;
    my $pid_default_method = $self->for_module->meta->find_attribute_by_name('pid_field')->default;
    if($pid_default_method) {
        $self->field('pid_field')->default($pid_default_method->());
    }
    $self->field('with_aup')->default($self->for_module->meta->find_attribute_by_name('with_aup')->default->());
    $self->field('aup_template')->default($self->for_module->meta->find_attribute_by_name('aup_template')->default->());
    $self->field('signup_template')->default($self->for_module->meta->find_attribute_by_name('signup_template')->default->());
}

# To override in the child modules
sub auth_module_definition {
    return ();
}

sub options_pid_field {
    my ($self) = @_;
    my $default_method = $self->form->for_module->meta->find_attribute_by_name('pid_field')->default;
    my @fields = @pf::person::PROMPTABLE_FIELDS;
    if($default_method){
        unshift @fields, $default_method->();
    }
    return map {$_ => $_} uniq(@fields);
}


=over

=back

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};
1;
