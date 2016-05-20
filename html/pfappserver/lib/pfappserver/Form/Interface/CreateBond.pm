package pfappserver::Form::Interface::CreateBond;

=head1 NAME

pfappserver::Form::Interface::CreateBond - Web form to add a Bond

=head1 DESCRIPTION

Form definition to add a Bond to the network configuration.

=cut

use HTML::FormHandler::Moose;
use pf::log;
extends 'pfappserver::Form::Interface';
with 'pfappserver::Base::Form::Role::Help';

has 'interfaces' => ( is => 'ro' );

# Form fields

has_field 'bond_name' =>
  (
   type => 'Text',
   label => 'Name',
  );

has_field 'interfaces' =>
  (
   type => 'Select',
   label => 'Interfaces',
   multiple => 1,
   options_method => \&options_interfaces,
   element_class => ['chzn-select'],
   element_attr => { 'data-placeholder' => 'None' },
   tags => { after_element => \&help,
             help => 'Select your interfaces' },
  );

has_field 'mode' =>
  (
   type => 'Hidden',
   label => 'Mode',
   value => 'active-backup',
  );

#has_block definition =>
#  (
#   render_list => [ qw(name interfaces ipaddress netmask type additional_listening_daemons dns vip dhcpd_enabled nat_enabled) ],
#  );


use Data::Dumper;

my $logger = get_logger();

sub ACCEPT_CONTEXT {
    my ($self, $c, @args) = @_;
    my $interfaces = $c->model('Interface')->get('all');
    return $self->SUPER::ACCEPT_CONTEXT($c, interfaces => $interfaces, @args);
}

sub options_interfaces {
    my $self = shift;
    my $interfaces_list = [
        keys %{$self->form->interfaces} ];
    return sort ( $interfaces_list );
}

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
