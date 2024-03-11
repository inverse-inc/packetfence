package pfappserver::Form::Config::Mfa;

=head1 NAME

pfappserver::Form::Config::Mfa - Web form for Mfa

=head1 DESCRIPTION

Form definition to create or update a MFA

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
use pf::constants::mfa;

has_field 'id' =>
  (
   type => 'Text',
   required => 1,
   messages => { required => 'Please specify the name of the MFA Service' },
  );

has_field 'type' =>
  (
   type => 'Select',
   options_method => \&options_type,
  );

has_field 'cache_duration' =>
  (
   type => 'Duration',
   default => {
    interval => 60,
    unit => 's',
   },
  );

has_field 'post_mfa_validation_cache_duration' =>
  (
   type => 'Duration',
   default => {
    interval => 5,
    unit => 's',
   },
  );

has_field 'split_char' =>
  (
   type => 'Text',
   required => 1,
   default => ',',
   messages => { required => 'Please specify the char to split password field to get the code' },
  );

has_block 'definition' =>
  (
   render_list => [ qw(id cache_duration post_mfa_validation_cache_duration split_char) ],
  );

=head2 options_type

Dynamically extract the descriptions from the various MFA modules.

=cut

sub options_type {
    my $self = shift;

    return map{$_ => $_} $pf::constants::mfa::MFA_TYPES;
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
