package pfappserver::Form::Field::PortalModuleAction;

=head1 NAME

pfappserver::Form::Field::PortalModuleAction - an action for the portal modules

=head1 DESCRIPTION

This is to create an action for a portal module

=cut

use HTML::FormHandler::Moose;
extends 'HTML::FormHandler::Field::Compound';

use namespace::autoclean;

use pf::config;
use pfconfig::namespaces::config::PortalModules;

has '+do_wrapper' => ( default => 1 );
has '+do_label' => ( default => 1 );
has '+inflate_default_method'=> ( default => sub { \&action_inflate } );
has '+deflate_value_method'=> ( default => sub { \&action_deflate } );
has '+wrapper_class' => (builder => 'action_wrapper_class');

sub action_wrapper_class {[qw(compound-input-btn-group)] }

has_field 'type' =>
  (
   type => 'Select',
   do_label => 0,
   required => 1,
   widget_wrapper => 'None',
   options_method => \&options_type,
  );

has_field 'value' =>
  (
   type => 'Hidden',
   do_label => 0,
   widget_wrapper => 'None',
   element_class => ['input-medium'],
  );

=head2 action_inflate

Inflate an action of the format :
  action(arg1,arg2,arg3)

=cut

sub action_inflate {
    my ($self, $value) = @_;
    my $hash = {};
    if (defined $value) {
        @{$hash}{'type', 'value'} = pfconfig::namespaces::config::PortalModules::inflate_action($value);
        my $type = $hash->{type};
        $hash->{type} = 'set_unreg_date' if $type eq 'set_unregdate';
        $hash->{value} = join(',',@{$hash->{value}});
    }
    return $hash;
}

=head2 action_inflate

Deflate an action to the format :
  action(arg1;arg2;arg3)

=cut

sub action_deflate {
    my ($self, $value) = @_;
    my $type = $value->{type};
    $type = 'set_unregdate' if $type eq 'set_unreg_date';
    my $joined_arguments = $value->{value};
    return "${type}(${joined_arguments})";
}

sub options_type {
    my ($self) = @_;
    my $form = $self->form;
    return (
        { value => '', label => $form->_localize('Select an option') },
        (
            map {
                my $v = {
                    value => ( $_ ne 'set_unregdate' ? $_ : 'set_unreg_date' ),
                    label => $form->_localize($_),
                };
                if ($_ eq 'set_role') {
                    $v->{siblings} = {
                        type => {
                            allowed_values => options_roles($self),
                        }
                    }
                }
                $v
            } @{ $form->for_module->available_actions }
        )
    );
}

sub options_roles {
    my $self = shift;
    my @roles = map { { text => $_->{name}, value => $_->{name} } } @{$self->form->roles || []};
    return \@roles;
}

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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
