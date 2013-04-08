package pfappserver::Model::Config::Cached::FloatingDevice;

=head1 NAME

pfappserver::Model::Config::Cached::FloatingDevice add documentation

=cut

=head1 DESCRIPTION

pfappserver::Model::Config::Cached::FloatingDevice

=cut

use HTTP::Status qw(:constants is_error is_success);
use Moose;
use namespace::autoclean;
use pf::config::cached;
use pf::config;

extends 'pfappserver::Base::Model::Config::Cached';


has '+configFile' => (default => $pf::config::floating_devices_config_file);

=head2 Methods

=over

=item search

=cut

sub search {
    my ($self, $field, $value) = @_;

    my @results;
    $self->readConfig();
    my ($status, $result) = $self->readAll();
    if (is_success($status)) {
        foreach my $floatingdevice (@{$result}) {
            if ($floatingdevice->{$field} eq $value) {
                push(@results, $floatingdevice);
            }
        }
    }
    if (@results) {
        return ($STATUS::OK, \@results);
    } else {
        return ($STATUS::NOT_FOUND);
    }
}

__PACKAGE__->meta->make_immutable;

=back

=head1 COPYRIGHT

Copyright (C) 2013 Inverse inc.

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

