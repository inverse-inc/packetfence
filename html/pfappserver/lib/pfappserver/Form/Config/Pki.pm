package pfappserver::Form::Config::Pki;

=head1 NAME

pfappserver::Form::Config::Pki - Web form for a PKI to contact

=head1 DESCRIPTION

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';
with 'pfappserver::Base::Form::Role::Help';

has pki_ip => ( is => 'rw' );
has pki_username => ( is => 'rw' );
has pki_password => ( is => 'rw');

## Definition
has_field 'id' =>
  (
   type => 'Text',
   label => 'PKI Name',
   required => 1,
   messages => { required => 'Please specify the name of the PKI entry.' },
  );

has_field 'description' =>
  (
   type => 'Text',
   messages => { required => 'Please specify the Description of the PKI entry.' },
  );

#has_field 'type' =>
#  (
#   type => 'Hidden',
#   label => 'Provisioning type',
#   required => 1,
#   messages => { required => 'Please select Provisioning type' },
#  );

has_field 'pki_ip' =>
  (
   type => 'Text',
   label => 'IP',
   required => 1,
   messages => { required => 'Please specify the IP:port of the PKI'}
  );

has_field 'pki_uri' =>
  (
   type => 'Text',
   label => 'URI',
   required => 1,
   messages => { required => 'Please specify the URI (without IP:port) of the PKI'}
  );


has_field 'pki_username' =>
  (
   type => 'Text',
   label => 'Username',
   required => 1,
   messages => { required => 'Please specify the username of the PKI'}
  );

has_field 'pki_password' =>
  (
   type => 'Text',
   label => 'Password',
   required => 1,
   messages => { required => 'Please specify the password of the PKI'}
  );

has_field 'pki_profile' =>
  (
   type => 'Select',
   multiple => 1,
   label => 'Profiles available',
   required => 1,
   options_method => \&options_profile,
   element_class => ['chzn-deselect'],
   element_attr => {'data-placeholder' => 'Click to add a Profile'},
   tags => { after_element => \&help,
             help => 'Profile are here to help you ditribute certificate by service in your company' },
  
  );
has_block definition =>
  (
   render_list => [ qw(id type description pki_ip pki_uri pki_profile pki_username pki_password) ],
  );

=head2 options_profile

=cut

sub options_profile {
    my $self = shift;
    my @profiles = ["Staff" => "Employes",
                   "HR" => "Human Resources",
                   "Dir" => "Direction", 
                   "Compta" => "Comptability",
                   "Students" => "Students",
                  ];
    return @profiles;
}

#=head2 ACCEPT_CONTEXT
#
#To automatically add the context to the Form
#
#=cut
#
#sub ACCEPT_CONTEXT {
#    my ($self, $c, @args) = @_;
#    my ($status, $roles) = $c->model('Roles')->list();
#    my @oses = ["Windows" => "Windows",
#                "Mac OS" => "Mac OS",
#                "Android" => "Android", 
#                "Apple" => "Apple IOS device"
#               ];
#    my (undef, $violations) = $c->model('Config::Violations')->readAll();
#    return $self->SUPER::ACCEPT_CONTEXT($c, roles => $roles, oses => @oses, violations => $violations, @args);
#}

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
