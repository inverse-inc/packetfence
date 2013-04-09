package pfappserver::Base::Model::Config::Cached::Mapped;

=head1 NAME

pfappserver::Base::Model::Config::Cached::Mapped

=cut

=head1 DESCRIPTION

Maps values in different sections into one "object"

=cut

use Moose;
use namespace::autoclean;
use pf::config::cached;
use pf::config;

extends 'pfappserver::Base::Model::Config::Cached';


=head1 FIELDS

=head2 mapping

The hash that maps the key to the section and value
Example below

{
    key1 => [qw(section1 val1)],
    key2 => [qw(section2 val2)],
}


=cut

has mapping => ( is => 'ro');

=head1 Methods


=head2 remove

remove always throws an error

=cut

sub remove {
    return ($STATUS::INTERNAL_SERVER_ERROR, "Cannot remove using this interface");
}

=head2 create

create always throws an error

=cut

sub create {
    return ($STATUS::INTERNAL_SERVER_ERROR, "Cannot create using this interface");
}

=head2 read

Read mapped config

=cut

sub read {
    my ($self,$id) = @_;
    my %item = ($self->idKey => $id);
    my $config = $self->cachedConfig;
    while ( my ($key,$section_val) = each %{$self->mapping}  ) {
        $item{$key} = $config->val($section_val->[0],$section_val->[1]);
    }
    $self->cleanupAfterRead($id,\%item);
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

