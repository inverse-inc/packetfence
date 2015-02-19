package pfappserver::Form::Config::Authentication::Source::SponsorEmail;

=head1 NAME

pfappserver::Form::Config::Authentication::Source::SponsorEmail - Web form for email-based self-registration by soonsor

=head1 DESCRIPTION

Form definition to create or update an guest-sponsored user source.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Config::Authentication::Source';
with 'pfappserver::Base::Form::Role::Help';

use pf::Authentication::Source::SponsorEmailSource;

# Form fields
has_field 'allow_localdomain' =>
  (
   type => 'Toggle',
   checkbox_value => 'yes',
   unchecked_value => 'no',
   label => 'Allow Local Domain',
   default => pf::Authentication::Source::EmailSource->meta->get_attribute('allow_localdomain')->default,
   tags => { after_element => \&help,
             help => 'Accept self-registration with email address from the local domain' },
  );

has_field 'create_local_account' => (
    type => 'Toggle',
    checkbox_value => 'yes',
    unchecked_value => 'no',
    label => 'Create Local Account',
    default => pf::Authentication::Source::EmailSource->meta->get_attribute('create_local_account')->default,
    tags => { 
        after_element => \&help,
        help => 'Create a local account on the PacketFence system based on the email address provided.',
    },
);

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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
