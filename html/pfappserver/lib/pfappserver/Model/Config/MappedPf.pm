package pfappserver::Model::Config::MappedPf;
=head1 NAME

pfappserver::Model::Config::Cached::Profile add documentation

=cut

=head1 DESCRIPTION

pfappserver::Model::Config::Cached::Profile

=cut

use Moose;
use namespace::autoclean;
use pf::config::cached;
use pf::config;

extends 'pfappserver::Base::Model::Config::Cached';

has mapping => ( is => 'rw');


=head1 Methods


=head2 _buildCachedConfig

=cut

sub _buildCachedConfig { $cached_pf_config }

=head2 remove

Delete an existing item

=cut

sub remove {
    return ($STATUS::INTERNAL_SERVER_ERROR, "Cannot delete this item");
}

=head2 read

Read mapped config

=cut

sub read {
    my ($self,$dummy) = @_;
    my %item = ($self->idKey => $dummy);
    my $config = $self->cachedConfig;
    while ( my ($key,$section_val) = each %{$self->mapping}  ) {
        $item{$key} = $config->val($section_val->[0],$section_val->[1]);
    }
    return ($STATUS::OK,\%item);
}

=head2 update

Update mapped config

=cut

sub update {
    my ( $self, $id, $assignments ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my ($status,$status_msg) = ($STATUS::OK,"");
    if($id eq 'all') {
        $status = $STATUS::FORBIDDEN;
        $status_msg = "This method does not handle \"$id\"";
    }
    else {
        $self->cleanupBeforeCommit($id,$assignments);
        my $config = $self->cachedConfig;
        delete $assignments->{$self->idKey};
        my $mapping = $self->mapping;
        while ( my ($key, $value) = each %$assignments ) {
            next unless exists $mapping->{$key};
            my ($section,$param) = @{$mapping->{$key}};
            if ( $config->exists($section, $param) ) {
                $config->setval( $section, $param, $value );
            } else {
                $config->newval( $section, $param, $value );
            }
        }
        $status_msg = "\"$id\" successfully modified";
        $logger->info("$status_msg");
    }
    return ($status, $status_msg);
}

__PACKAGE__->meta->make_immutable;

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

