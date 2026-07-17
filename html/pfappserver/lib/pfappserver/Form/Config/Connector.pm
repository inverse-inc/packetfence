package pfappserver::Form::Config::Connector;

=head1 NAME

pfappserver::Form::Config::Connector - Web form for Connector

=head1 DESCRIPTION

Form definition to create or update a connector

=cut

use HTML::FormHandler::Moose;
use pf::ConfigStore::Connector::DomainsConnectors;
use pfconfig::cached_hash;

tie my %ConnectorConfig, "pfconfig::cached_hash" , "config::Connector";

extends 'pfappserver::Base::Form';
with qw(
    pfappserver::Base::Form::Role::Help
);

has_field 'id' =>
  (
   type => 'Text',
   required => 1,
  );

has_field 'description' =>
  (
   type => 'Text',
   required => 1,
  );

has_field 'networks' =>
  (
   type => 'Repeatable',
  );

has_field 'networks.contains' =>
  (
   type => 'CIDR',
  );

has_field 'secret' =>
  (
   type => 'Text',
   required => 1,
  );

has_field 'fingerbank_environment' => (
   type => 'Repeatable',
);

has_field 'fingerbank_environment.contains' => (
   type => 'EnvVar',
);

sub validate_networks {
    my ($self, $field) = @_;
    my $networks = $field->value;
    my %counts;
    for my $n (@$networks) {
        $counts{$n}++;
        if ($counts{$n} == 2) {
            $field->add_error("Cannot have network '$n' defined multiple times");
        }
    }

    my $id = $self->field("id")->value;
    for my $k (grep { $_ ne $id && $_ ne 'local_connector' } keys %ConnectorConfig) {
        for my $n (@{$ConnectorConfig{$k}{networks} // []}) {
            if (exists $counts{$n}) {
                $field->add_error("network '$n' is defined in '$k'");
            }
        }
    }
}

=over

=back

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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
