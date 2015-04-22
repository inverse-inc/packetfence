package pfappserver::Form::Config::Billing;

=head1 NAME

pfappserver::Form::Config::Billing - Web form for Billing

=head1 DESCRIPTION

Form definition to create or update a billing configuration.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';
with 'pfappserver::Base::Form::Role::Help';

use pf::config;
use pf::util;
use File::Find qw(find);
iuse pf::ConfigStore::Tiers;

## Definition

has_field 'id' =>
  (
   type => 'Text',
   label => 'Name',
   required => 1,
   messages => { required => 'Please specify a name for the billing configuration' },
  );

has_field 'type' =>
  (
   type => 'Select',
   label => 'Billing Type',
   options_method => \&options_type,
  );

has_field 'tiers' =>
(
    'type' => 'DynamicTable',
    'sortable' => 1,
    'do_label' => 0,
);

has_field 'tiers.contains' =>
(
    type => 'Select',
    options_method => \&options_tiers,
    widget_wrapper => 'DynamicTableRow',
);

=head2 options_type

Dynamically extract the descriptions from the various Scan modules.

=cut

sub options_type {
    my $self = shift;

    my %paths = ();
    my $wanted = sub {
        if ((my ($module, $pack, $billing) = $_ =~ m/$lib_dir\/((pf\/billing\/gateway\/([A-Z0-9][\w\/]+))\.pm)\z/)) {
            $pack =~ s/\//::/g; $billing =~ s/\//::/g;

            # Parent folder is the vendor name
            my @p = split /::/, $billing;
            my $vendor = shift @p;

            # Only switch types with a 'description' subroutine are displayed
            require $module;
            if ($pack->can('description')) {
                $paths{$vendor} = {} unless ($paths{$vendor});
                $paths{$vendor}->{$billing} = $pack->description;
            }
        }
    };
    find({ wanted => $wanted, no_chdir => 1 }, ("$lib_dir/pf/billing/gateway"));

    my @modules;
    foreach my $vendor (sort keys %paths) {
        my @billing = map {{ value => $_, label => $paths{$vendor}->{$_} }} sort keys %{$paths{$vendor}};
        push @modules, { group => $vendor,
                         options => \@billing };
    }

    return @modules;
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
