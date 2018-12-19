package pfappserver::Form::Config::PortalModule::SSL_Inspection;

=head1 NAME

pfappserver::Form::Config::PortalModule::SSL_Inspection

=head1 DESCRIPTION

Form definition to create or update an SSL Inspection portal module.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Config::PortalModule';
with 'pfappserver::Base::Form::Role::Help';

use captiveportal::DynamicRouting::Module::SSL_Inspection;
sub for_module {'captiveportal::PacketFence::DynamicRouting::Module::SSL_Inspection'}
## Definition

has_field 'skipable' =>
  (
   type => 'Toggle',
   label => 'Skippable',
   unchecked_value => '0',
   checkbox_value => '1',
   tags => { after_element => \&help,
             help => 'Whether or not, this message can be skipped' },
  );

has_field 'ssl_mobileconfig_path' =>
  (
   type => 'Text',
   label => 'SSL iOS profile URL',
   required => 1,
   tags => { after_element => \&help,
             help => 'URL of an iOS mobileconfig profile to install the certificate.' },
  );

has_field 'ssl_path' =>
  (
   type => 'Text',
   label => 'SSL Certificate URL',
   required => 1,
   tags => { after_element => \&help,
             help => 'URL of the SSL certificate in X509 Base64 format.' },
  );


sub child_definition {
    return qw(ssl_path ssl_mobileconfig_path skipable);
}

sub BUILD {
    my ($self) = @_;
    $self->field('skipable')->default($self->for_module->meta->find_attribute_by_name('skipable')->default->());
}

=over

=back

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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


