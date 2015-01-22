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

has_field 'cert_type' =>
  (
   type => 'Select',
   multiple => 0,
   label => 'Certificate type',
   options_method => \&option_cert_type,
   element_class => ['chzn-deselect'],
   tags => { after_element => \&help,
             help => 'Select the type of certifiate you use' },
  );

has_field 'security_type' =>
  (
   type => 'Select',
   multiple => 0,
   label => 'Security type',
   options_method => \&option_security,
   element_class => ['chzn-deselect'],
   tags => { after_element => \&help,
             help => 'Select the type of security applied for your SSID' },
  );

has_field 'passcode' =>
  (
   type => 'Text',
   label => 'Wifi Key',
  );

has_field 'reversedns' =>
  (
   type => 'Text',
   label => 'Reverse DNS Identifier',
   required => 1,
   tags => { after_element => \&help,
             help => 'Example: com.packetfence' },
  );

has_field 'company' =>
  (
   type => 'Text',
   label => 'Company Name',
   required => 1,
  );

has_field 'pki' =>
  (
   type => 'Text',
   label => 'PKI URI',
   required => 1,
   tags => { after_element => \&help,
             help => 'Example: https://packetfence.org:8081/pki/api/' },
  );

has_field 'pki_username' =>
  (
   type => 'Text',
   label => 'PKI Username',
   required => 1,
  );

has_field 'pki_passwd' =>
  (
   type => 'Text',
   label => 'PKI Password',
   required => 1,
   password => 0,
  );

has_block 'definition' =>
  (
   render_list => [ qw(id type description company reversedns category ssid security_type passcode eap_type ca_cert_path cert_type pki pki_username pki_passwd) ],
  );

sub options_eap_type {
    my $self = shift;
    my @eap_types = ["25" => "PEAP",
                     "13" => "EAP-TLS",
                     "21" => "EAP-TTLS",
                     "" => "No EAP",
                    ];
    return @eap_types;
}

sub option_cert_type {
    my $self = shift;
    my @cert_types = ["com.apple.security.pem" => "PEM",
                      "com.apple.security.root" => "DER",
                     ];
    return @cert_types;
}

sub option_security {
    my $self = shift;
    my @security_type = ["None" => "Open",
                         "WEP" => "WEP",
                         "WPA" => "WPA",
                         "WPA" => "WPA2",
                        ];
    return @security_type;
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
