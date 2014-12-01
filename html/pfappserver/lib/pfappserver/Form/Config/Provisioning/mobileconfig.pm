package pfappserver::Form::Config::Provisioning::mobileconfig;

=head1 NAME

pfappserver::Form::Config::Provisioning - Web form for a switch

=head1 DESCRIPTION

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Config::Provisioning';
with 'pfappserver::Base::Form::Role::Help';

has_field 'eap_type' =>
  (
   type => 'Select',
   multiple => 0,
   label => 'EAP Type',
   options_method => \&options_eap_type,
   element_class => ['chzn-deselect'],
   tags => { after_element => \&help,
             help => 'Select the EAP type of your SSID' },
  );

has_field 'ssid' =>
  (
   type => 'Text',
   label => 'SSID',
  );

has_field 'ca_cert_path' =>
  (
   type  => 'Text',
   label => 'Certificate',
  );

has_block definition =>
  (
   render_list => [ qw(id type description category ssid ca_cert_path eap_type) ],
  );

sub options_eap_type {
    my $self = shift;
    my @eap_types = ["13" => "TLS",
                     "17" => "LEAP",
                     "18" => "EAP-SIM", 
                     "21" => "TTLS",
                     "23" => "EAP-AKA",
                     "25" => "PEAP",
                     "43" => "EAP-FAST",
                    ];
    return @eap_types;
}
=head1 COPYRIGHT

Copyright (C) 2014 Inverse inc.

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
