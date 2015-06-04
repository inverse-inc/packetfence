package pfappserver::Model::Config::Authentication::Source::BillingTier;

=head1 NAME

pfappserver::Model::Config::Profile add documentation

=cut

=head1 DESCRIPTION

pfappserver::Model::Config::Switch;

=cut

use Moose;
use namespace::autoclean;
use pf::ConfigStore::BillingTier;

extends 'pfappserver::Base::Model::Config';

has '+itemKey' => ( default => 'billing_tier' );
has '+itemsKey' => ( default => 'billing_tiers' );

=head2 Methods

=head2 ACCEPT_CONTEXT

Configure the billing tier from the previously defined source

=cut

sub ACCEPT_CONTEXT {
    my ($class,$c,@args) = @_;
    my $source_id = $c->stash->{source}->{id};
    my $group ="$source_id billing_tier";
    return $class->new(@args, configStore => pf::ConfigStore::BillingTier->new(group => $group));
}

__PACKAGE__->meta->make_immutable;

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

1;
