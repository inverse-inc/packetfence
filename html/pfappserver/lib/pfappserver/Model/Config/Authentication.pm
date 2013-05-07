package pfappserver::Model::Config::Authentication;
=head1 NAME

pfappserver::Model::Config::Authentication

=cut

=head1 DESCRIPTION

pfappserver::Model::Config::Authentication

=cut

use Moose;
use namespace::autoclean;
use pf::authentication;
use HTTP::Status qw(:constants is_error is_success);

extends 'pfappserver::Base::Model::Config';

has '+itemKey' => (default => 'source');
has '+itemsKey' => (default => 'sources');

sub _buildCachedConfig { $pf::authentication::cached_authentication_config };


sub readAll {
    my ($self) = @_;
    return ($STATUS::OK,\@authentication_sources);
}

sub update {
    my ($self,$id,$source_obj) = @_;
    my %not_params;
    @not_params{qw(rules unique class)} = ();
    # Update attributes
    my %assignments;
    foreach my $attr (grep { !exists $not_params{$_}  } map { $_->name } $source_obj->meta->get_all_attributes()) {
        $assignments{$attr} = $source_obj->$attr;
    }
    $self->SUPER::update($id,\%assignments);
}

sub create {
    my ($self) = @_;
}

sub remove {
    my ($self) = @_;
}

sub renameItem {
    my ($self) = @_;
}

sub cleanupAfterRead {
    my ($self) = @_;
}

sub cleanupBeforeCommit {
    my ($self) = @_;
}

__PACKAGE__->meta->make_immutable;

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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

