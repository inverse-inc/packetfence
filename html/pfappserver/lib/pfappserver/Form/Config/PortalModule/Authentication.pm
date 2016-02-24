package pfappserver::Form::Config::PortalModule::Authentication;

=head1 NAME

pfappserver::Form::Config::PortalModule::AuthModule

=head1 DESCRIPTION

Form definition to create or update an authentication portal module.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Config::PortalModule';
with 'pfappserver::Base::Form::Role::Help';

use pf::log; 
use captiveportal::DynamicRouting::Module::Authentication;
sub for_module {'captiveportal::DynamicRouting::Module::Authentication'}

## Definition
has_field 'source_id' =>
  (
   type => 'Select',
   label => 'Sources',
   options => [],
   element_class => ['chzn-select'],
   element_attr => {'data-placeholder' => 'Click to add a source'},
   tags => { after_element => \&help,
             help => 'The sources to use in the module' },
  );

has_field 'custom_fields' =>
  (
   type => 'Select',
   multiple => 1,
   label => 'Mandatory fields',
   options_method => \&options_custom_fields,
   element_class => ['chzn-select'],
   element_attr => {'data-placeholder' => 'Click to add a required field'},
   tags => { after_element => \&help,
             help => 'The additionnal fields that should be required for registration' },
  );

has_field 'with_aup' =>
  (
   type => 'Checkbox',
   label => 'Require AUP',
   checkbox_value => '1',
   default => for_module->meta->get_attribute('with_aup')->default->(),
   tags => { after_element => \&help,
             help => 'Require the user to accept the AUP' },
  );

has_field 'signup_template' =>
  (
   type => 'Text',
   label => 'Signup template',
   required => 1,
   default => for_module->meta->get_attribute('signup_template')->default->(),
   tags => { after_element => \&help,
             help => 'The template to use for the signup' },
  );

sub BUILD {
    my ($self) = @_;

    if($self->for_module->does('captiveportal::DynamicRouting::MultiSource')){
        $self->field('source_id')->multiple(1);
        $self->field('source_id')->options([$self->options_sources(multiple => 1)]);
    }
    else {
        $self->field('source_id')->options([$self->options_sources(multiple => 0)]);
    }

}

sub child_definition {
    my ($self) = @_;
    return (qw(source_id custom_fields with_aup signup_template), $self->auth_module_definition());
}

# To override in the child modules
sub auth_module_definition {
    return ();
}

sub options_sources {
    my ($self, %options) = @_;
    require pf::authentication;
    my @sources;
    foreach my $source (@{pf::authentication::getAllAuthenticationSources()}){
        # We are dealing with a multi source module, meaning we are looking for the isa in the sources attribute
        my ($isa);
        if($options{multiple} && $self->for_module->meta->get_attribute('sources')->{isa} =~ /^ArrayRef\[(.*)\]/){
            $isa = $1;
        }
        else {
            $isa = $self->for_module->meta->get_attribute('source')->{isa};
        }
        get_logger->debug("Building options with isa : $isa");
        foreach my $splitted_isa (split(/\s*\|\s*/, $isa)){
            if($source->isa($splitted_isa)){
                push @sources, $source->id;
                last;
            }
        }
    }
    get_logger->debug(sub { use Data::Dumper; "The following sources are available : ".Dumper(\@sources) });
    return map { {value => $_, label => $_} } @sources;
}

sub options_custom_fields {
    return map {$_ => $_} @pf::person::PROMPTABLE_FIELDS;
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
