package pfappserver::Form::Config::Billing::mirapay;

=head1 NAME
pfappserver::Form::Config::Billing::mirapay - Web form to add a Mirapay configuration
=head1 DESCRIPTION
Form definition to create or update a Mirapay configuration
=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Config::Billing';
with 'pfappserver::Base::Form::Role::Help';

use pf::config;
use pf::util;
use File::Find qw(find);


has_field 'mirapay_url' =>
  (
   type => 'Text',
   label => 'Mirapay URL',
   required => 1,
   messages => { required => 'The payment gateway processing URL for mirapay' },
   default => 'https://ms1.eigendev.com/OFT/EigenOFT_d.php',
  );

has_field 'mirapay_terminal_id' =>
  (
   type => 'Text',
   label => 'Mirapay terminal id',
   required => 1,
   messages => { required => 'The terminal id for mirapay' },
  );

has_field 'mirapay_terminal_id_group' =>
  (
   type => 'Text',
   label => 'Mirapay terminal group id',
   required => 1,
   messages => { required => 'The terminal id group for mirapay' },
  );

has_field 'mirapay_hash_password' =>
  (
   type => 'Text',
   label => 'Mirapay password',
   required => 1,
   messages => { required => 'The hash password for mirapay' },
  );

has_field 'mirapay_currency' =>
  (
   type => 'Select',
   label => 'Mirapay currency',
   options_method => \&currency,
   element_class => ['chzn-deselect', 'input'],
   element_attr => {'data-placeholder' => 'Select a currency'},
   required => 1,
   messages => { required => 'The currency of the mirapay transactions' },
  );

has_block definition =>
  (
   render_list => [ qw(id mirapay_url mirapay_terminal_id mirapay_terminal_id_group mirapay_hash_password) ],
  );

=head2 options_categories

=cut

sub currency {
    my $self = shift;

    my @roles = ('USD => USD','CAD => CAD');
    return ('' => '', @roles);
}

=over

=back

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
