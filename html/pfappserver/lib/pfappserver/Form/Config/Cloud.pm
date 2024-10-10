package pfappserver::Form::Config::Cloud;

=head1 NAME

pfappserver::Form::Config::Cloud - Web form for cloud

=head1 DESCRIPTION

Form definition to create or update a cloud service.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';
with qw(
    pfappserver::Base::Form::Role::Help
);

use pf::config;
use pf::file_paths qw($lib_dir);
use pf::util;
use File::Find qw(find);
use pf::constants::cloud;

has_field 'id' =>
  (
   type => 'Text',
   label => 'Name',
   required => 1,
   messages => { required => 'Please specify the name of the Cloud Service' },
  );

has_field 'type' =>
  (
   type => 'Select',
   label => 'Cloud Type',
   options_method => \&options_type,
  );

has_block 'definition' =>
  (
   render_list => [ qw(id) ],
  );

=head2 options_type

Dynamically extract the descriptions from the various Cloud modules.

=cut

sub options_type {
    my $self = shift;

    return map{$_ => $_} $pf::constants::cloud::CLOUD_TYPES;
}

=over

=back

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
