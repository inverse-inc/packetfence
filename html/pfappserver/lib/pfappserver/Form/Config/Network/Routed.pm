package pfappserver::Form::Config::Network::Routed;

=head1 NAME

pfappserver::Form::Interface - Web form for a routed network

=head1 DESCRIPTION

Form definition to create or update a routed network.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Config::Network';
with 'pfappserver::Form::Widget::Theme::Pf';

use HTTP::Status qw(:constants is_success);

has_field 'network' =>
  (
   type => 'IPAddress',
   label => 'Routed Network',
   required => 1,
   messages => { required => 'Please specify the network.' },
  );
has_field 'dns' =>
  (
   type => 'IPAddress',
   label => 'DNS Server',
   required => 1,
   messages => { required => "Please specify the DNS server's IP address." },
   tags => { after_element => \&help,
             help => 'Should match the IP of a registration interface' },
  );
has_field 'gateway' =>
  (
   type => 'IPAddress',
   label => 'Gateway',
   required => 1,
   messages => { required => 'Please specify the gateway.' },
  );
has_field 'netmask' =>
  (
   type => 'IPAddress',
   label => 'Netmask',
   required => 1,
   messages => { required => 'Please specify the netmask.' },
  );
has_field 'next_hop' =>
  (
   type => 'IPAddress',
   label => 'Router IP',
   required => 1,
   messages => { required => 'Please specify the router IP address.' },
   tags => { after_element => \&help,
             help => 'IP address of the router in this network' },
  );

=head2 update_fields

Set the default network value

=cut

sub update_fields {
    my $self = shift;

    $self->SUPER::update_fields();
    $self->field('network')->default($self->network) if ($self->network);
}

=head2 validate

Make sure the network address is not already defined.

Make sure the router IP has a gateway.

=cut

sub validate {
    my $self = shift;

    $self->SUPER::validate();

    if ($self->network && $self->network ne $self->value->{network} || !$self->network) {
        # Build a list of existing networks
        my ($status, $result) = $self->ctx->model('Config::Networks')->list_networks();
        if (is_success($status)) {
            my %networks = map { $_ => 1 } @$result;
            if (defined $networks{$self->value->{network}}) {
                $self->field('network')->add_error('This network is already defined.');
            }
        }
    }
    my $interface = $self->ctx->model('Interface')->interfaceForDestination($self->value->{next_hop});
    unless ($interface) {
        $self->field('next_hop')->add_error("The router IP has no gateway on a network interface.");
    }
}

=head1 COPYRIGHT

Copyright (C) 2013 Inverse inc.

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
