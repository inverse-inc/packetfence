package pfappserver::Form::Config::Provisioning::mobileconfig;

=head1 NAME

pfappserver::Form::Config::Provisioning - Web form for a switch

=head1 DESCRIPTION

=cut

use pf::config;
use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Config::Provisioning';
with 'pfappserver::Base::Form::Role::Help';

has_field 'company' =>
  (
   type => 'Text',
  );

has_field 'ssid' =>
  (
   type => 'Text',
   required => 1,
  );

has_field 'broadcast' =>
  (
   type => 'Checkbox',
   checkbox_value => 1,
   input_without_param => 0,
   default => 1,
   tags => { after_element => \&help,
             help => 'Disable this box if you are using a hidden SSID' },
  );

has_field 'security_type' =>
  (
   type => 'Select',
   multiple => 0,
   options_method => \&option_security,
   element_class => ['chzn-deselect'],
   tags => { after_element => \&help,
             help => 'Select the type of security applied for your SSID' },
  );

has_field 'eap_type' =>
  (
   type => 'Select',
   multiple => 0,
   options_method => \&options_eap_type,
   element_class => ['chzn-deselect'],
   tags => { after_element => \&help,
             help => 'Select the EAP type of your SSID' },
  );

has_field 'passcode' =>
  (
   type => 'Text',
   tags => { after_element => \&help,
             help => 'The WiFi key to join the SSID' },
  );

has_field 'dpsk' =>
  (
   type => 'Checkbox',
   tags => { after_element => \&help,
             help => 'Define if the PSK needs to be generated' },
  );

has_field 'dpsk_use_local_password' => (
   type => 'Toggle',
   checkbox_value => 'enabled',
   unchecked_value => 'disabled',
);

has_field 'psk_size' =>
  (
   type => 'PSKLength',
   default => 8,
   tags => { after_element => \&help,
             help => 'This is the length of the PSK key you want to generate. The minimum length is eight characters.' },
  );

has_field 'server_certificate_path' => (
  type => 'Path',
  #  required_when => { 'eap_type' => 25 },
  tags => { after_element => \&help,
            help => 'The path to the RADIUS server certificate' },
 );

has_field 'server_certificate_path_upload' => (
   type => 'PathUpload',
   accessor => 'server_certificate_path',
   config_prefix => '.crt',
   required => 0,
   upload_namespace => 'provisioning',
);

has_field 'ca_cert_path' => (
  type => 'Path',
  #  required_when => { 'eap_type' => 25 },
  tags => { after_element => \&help,
            help => 'The path to the RADIUS server CA' },
 );

has_field 'ca_cert_path_upload' => (
   type => 'PathUpload',
   accessor => 'ca_cert_path',
   config_prefix => '.crt',
   required => 0,
   upload_namespace => 'provisioning',
);

has_field 'cert_chain' =>
  (
   type => 'TextArea',
   element_class => ['input-xxlarge'],
   inflate_default_method => \&filter_inflate ,
   deflate_value_method => \&filter_deflate ,
   tags => { after_element => \&help,
             help => 'The certificate chain of the signer certificate in pem format'},
  );

has_field 'certificate' =>
  (
   type => 'TextArea',
   inflate_default_method => \&filter_inflate ,
   deflate_value_method => \&filter_deflate ,
   element_class => ['input-xxlarge'],
   tags => { after_element => \&help,
             help => 'The Certificate for signing in pem format'},
  );

has_field 'private_key' =>
  (
   type => 'TextArea',
   element_class => ['input-xxlarge'],
   inflate_default_method => \&filter_inflate ,
   deflate_value_method => \&filter_deflate ,
   tags => { after_element => \&help,
             help => 'The Private Key for signing in pem format'},
  );

has_field 'can_sign_profile' =>
  (
   type => 'Checkbox',
   value => 0,
   checkbox_value => 1,
   tags => { after_element => \&help,
             help => 'Check this box if you want the profiles signed' },
  );

sub filter_inflate {
    my ($self, $value) = @_;
    if(ref($value) eq 'ARRAY' ) {
         return (join("\n",@{$value}));
    }
    return $value;
}

sub filter_deflate {
    my ($self, $value) = @_;
    return [split /\r?\n/,$value];
}


has_block definition =>
  (
   render_list => [ qw(id description type category ssid broadcast eap_type security_type dpsk dpsk_use_local_password passcode pki_provider server_certificate_path ca_cert_path apply_role role_to_apply autoregister) ],
  );

has_block signing =>
  (
   render_list => [ qw(can_sign_profile certificate private_key cert_chain) ],
  );

sub options_eap_type {
    my $self = shift;
    my @eap_types = ["25" => "PEAP",
                     "13" => "EAP-TLS",
                     ""   => "No EAP",
                    ];
    return @eap_types;
}

sub option_security {
    my $self = shift;
    my @security_type = ["None" => "Open",
                         "WEP" => "WEP",
                         "WPA" => "WPA",
                         "WPA2" => "WPA2",
                        ];
    return @security_type;
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
