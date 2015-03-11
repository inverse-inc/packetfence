package pfappserver::Model::Authentication;

=head1 NAME

pfappserver::Model::Authentication - Catalyst Model

=head1 DESCRIPTION

Catalyst Model.

=cut

use strict;
use warnings;

use Moose;
use namespace::autoclean;

use pf::authentication;
use pf::error qw(is_error is_success);
use pf::ConfigStore::Authentication;

=head2 update

=cut

sub update {
    my ($self, $sources) = @_;

    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    
    # Update sources order
    my %valid_sources = map { $_->{id} => $_ } @pf::ConfigStore::auth_sources;
    my @sorted_sources;
    foreach my $source (@{$sources}) {
        if ($valid_sources{$source->{id}}) {
            push(@sorted_sources, $valid_sources{$source->{id}});
        }
    }
    @pf::ConfigStore::auth_sources = @sorted_sources;

    # Write configuration file to disk
    my $cs = pf::ConfigStore::Authentication->new;
    $cs->writeAuthenticationConfigFile();

    return ($STATUS::OK, "The sources order was successfully saved.");
}


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
