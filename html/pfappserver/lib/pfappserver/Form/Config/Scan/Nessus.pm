package pfappserver::Form::Config::Scan::Nessus;

=head1 NAME

pfappserver::Form::Config::Scan::Nessus - Web form to add a Nessus Scan Engine

=head1 DESCRIPTION

Form definition to create or update a Nessus Scan Engine.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Config::Scan';
with 'pfappserver::Base::Form::Role::Help';

use pf::config;
use pf::util;
use File::Find qw(find);

## Definition
has 'roles' => (is => 'ro', default => sub {[]});
has oses => ( is => 'rw' );

has_field 'id' =>
  (
   type => 'Text',
   label => 'Name',
   required => 1,
   messages => { required => 'Please specify a name for the scan engine' },
  );
has_field 'ip' =>
  (
   type => 'Text',
   label => 'Hostname or IP Address',
   required => 1,
   messages => { required => 'Please specify the hostname or IP of the scan engine' },
  );
has_field 'username' =>
  (
   type => 'Text',
   label => 'Username',
   required => 1,
   messages => { required => 'Please specify the username for the Scan Engine' },
  );
has_field 'password' =>
  (
   type => 'Password',
   label => 'Password',
   required => 1,
   password => 0,
   messages => { required => 'You must specify the password' },
  );
has_field 'port' =>
  (
   type => 'PosInteger',
   label => 'Port of the service',
   tags => { after_element => \&help,
             help => 'If you use an alternative port, please specify' },
   default => 8834,
  );
has_field 'type' =>
  (
   type => 'Hidden',
  );
has_field 'categories' =>
  (
   type => 'Select',
   multiple => 1,
   label => 'Roles',
   options_method => \&options_categories,
   element_class => ['chzn-select'],
   element_attr => {'data-placeholder' => 'Click to add a role'},
   tags => { after_element => \&help,
             help => 'Nodes with the selected roles will not be affected' },
  );

has_field 'duration' =>
  (
   type => 'Duration',
   label => 'Duration',
   default => '20s',
   tags => { after_element => \&help,
             help => 'Approximate duration of a scan. User being scanned on registration are presented a progress bar for this duration, afterwards the browser refreshes until scan is complete.' },
  );

has_block definition =>
  (
   render_list => [ qw(id ip type username password port nessus_clientpolicy categories oses duration registration dot1x dot1x_type) ],
  );

has_field 'registration' =>
  (
   type => 'Checkbox',
   label => 'Scan on reg',
   tags => { after_element => \&help,
             help => 'If this option is enabled, the PF system will scan each host after registration is complete.' },
  );

has_field 'dot1x' =>
  (
   type => 'Checkbox',
   label => '802.1x',
   tags => { after_element => \&help,
             help => 'If this option is enabled, PacketFence will scan all the 802.1x auto-registration connections.' },
  );

has_field 'dot1x_type' =>
  (
   type => 'Text',
   label => '802.1x types',
   tags => { after_element => \&help,
             help => 'Comma-delimited list of EAP-Type attributes that will pass to the scan engine.' },
  );

has_field 'nessus_clientpolicy' =>
  (
   type => 'Text',
   label => 'Nessus client policy',
   tags => { after_element => \&help,
             help => 'Name of the policy to use on the nessus server' },
  );

has_field 'oses' =>
  (
   type => 'Select',
   multiple => 1,
   label => 'OS',
   options_method => \&options_oses,
   element_class => ['chzn-deselect'],
   element_attr => {'data-placeholder' => 'Click to add an OS'},
   tags => { after_element => \&help,
             help => 'Nodes with the selected OS will be affected' },
  );

=head2 Methods

=cut

=head2 options_categories

=cut

sub options_categories {
    my $self = shift;

    my ($status, $result) = $self->form->ctx->model('Roles')->list();
    my @roles = map { $_->{name} => $_->{name} } @{$result} if ($result);
    return ('' => '', @roles);
}

=head2 options_oses

=cut

sub options_oses {
    my $self = shift;
    return $self->form->oses;
}


=over

=back

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
