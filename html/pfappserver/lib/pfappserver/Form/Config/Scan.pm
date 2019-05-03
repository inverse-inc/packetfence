package pfappserver::Form::Config::Scan;

=head1 NAME

pfappserver::Form::Config::Scan - Web form for Scan engine

=head1 DESCRIPTION

Form definition to create or update a scan engine.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';
with qw(
    pfappserver::Base::Form::Role::Help
    pfappserver::Role::Form::RolesAttribute
);

use pf::config;
use pf::file_paths qw($lib_dir);
use pf::util;
use File::Find qw(find);

has_field 'id' =>
  (
   type => 'Text',
   label => 'Name',
   required => 1,
   messages => { required => 'Please specify a name for the scan engine' },
   apply => [ pfappserver::Base::Form::id_validator('name') ]
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
   type => 'ObfuscatedText',
   label => 'Password',
   required => 1,
   messages => { required => 'You must specify the password' },
  );


has_field 'type' =>
  (
   type => 'Select',
   label => 'Scan Type',
   options_method => \&options_type,
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
             help => 'Nodes with the selected roles will be affected' },
  );

has_field 'duration' =>
  (
   type => 'Duration',
   label => 'Duration',
   default => {
    interval => 20,
    unit => 's',
   },
   tags => { after_element => \&help,
             help => 'Approximate duration of a scan. User being scanned on registration are presented a progress bar for this duration, afterwards the browser refreshes until scan is complete.' },
  );

has_field 'registration' =>
  (
   type => 'Checkbox',
   label => 'Scan on registration',
   tags => { after_element => \&help,
             help => 'If this option is enabled, the PF system will scan each host after registration is complete.' },
  );

has_field 'pre_registration' =>
  (
   type => 'Checkbox',
   label => 'Scan before registration',
   tags => { after_element => \&help,
             help => 'If this option is enabled, the PF system will scan host before the registration.' },
  );

has_field 'post_registration' =>
  (
   type => 'Checkbox',
   label => 'Scan after registration',
   tags => { after_element => \&help,
             help => 'If this option is enabled, the PF system will scan host after on the production vlan. This will not work for devices that are in an inline VLAN.' },
  );

has_field 'oses' =>
  (
   type => 'FingerbankSelect',
   multiple => 1,
   label => 'OS',
   element_class => ['chzn-deselect'],
   element_attr => {'data-placeholder' => 'Click to add an OS'},
   tags => { after_element => \&help,
             help => 'Nodes with the selected OS will be affected' },
   fingerbank_model => "fingerbank::Model::Device",
  );

=head2 options_type

Dynamically extract the descriptions from the various Scan modules.

=cut

sub options_type {
    my $self = shift;

    my %paths = ();
    my $wanted = sub {
        if ((my ($module, $pack, $scan) = $_ =~ m/$lib_dir\/((pf\/scan\/([A-Z0-9][\w\/]+))\.pm)\z/)) {
            $pack =~ s/\//::/g; $scan =~ s/\//::/g;

            # Parent folder is the vendor name
            my @p = split /::/, $scan;
            my $vendor = shift @p;

            # Only switch types with a 'description' subroutine are displayed
            require $module;
            if ($pack->can('description')) {
                $paths{$vendor} = {} unless ($paths{$vendor});
                $paths{$vendor}->{$scan} = $pack->description;
            }
        }
    };
    find({ wanted => $wanted, no_chdir => 1 }, ("$lib_dir/pf/scan"));

    # Sort vendors and switches for display
    my @modules;
    foreach my $vendor (sort keys %paths) {
        my @scan = map {{ value => $_, label => $paths{$vendor}->{$_} }} sort keys %{$paths{$vendor}};
        push @modules, { group => $vendor,
                         options => \@scan, value => '' };
    }

    return @modules;
}

=head2 options_categories

=cut

sub options_categories {
    my $self = shift;

    my $result = $self->form->roles;
    my @roles = map { $_->{name} => $_->{name} } @{$result} if ($result);
    return ('' => '', @roles);
}

=over

=back

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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
