package pfappserver::Model::Config::Pf;
=head1 NAME

pfappserver::Model::Config::PF add documentation

=cut

=head1 DESCRIPTION

pfappserver::Model::Config::PF

=cut

use Moose;
use namespace::autoclean;
use pf::config qw(
    %Doc_Config
    %Default_Config
);
use pf::ConfigStore::Pf;

extends 'pfappserver::Base::Model::Config';

=head2 Methods

=over

=item _buildCachedConfig

=cut

sub _buildConfigStore { pf::ConfigStore::Pf->new ; }

=item remove

Delete an existing item

=cut

sub remove {
    my ($self,$id) = @_;
    return ($STATUS::INTERNAL_SERVER_ERROR, "Cannot delete this item");
}

=item help

Obtain the help of a given configuration parameter

=cut

sub help {
    my ( $self, $config_entry ) = @_;

    return ($STATUS::NOT_FOUND, "No help available for $config_entry")
        if ( !defined($Doc_Config{$config_entry}{'description'}) );
    my $doc_entry = $Doc_Config{$config_entry};
    my $description_ref = $doc_entry->{'description'};
    $description_ref = join("\n",@$description_ref) if ref($description_ref) eq 'ARRAY';
    my $options_ref = $doc_entry->{options};
    my ($section, $param) = split( /\s*\.\s*/, $config_entry );
    return ($STATUS::OK, {
        'parameter' => $config_entry,
        'default_value' => $Default_Config{$section}{$param},
        'options' => $options_ref,
        'description' => $description_ref,
    });
}

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

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

1;

