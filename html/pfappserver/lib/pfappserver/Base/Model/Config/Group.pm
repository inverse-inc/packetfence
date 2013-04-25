package pfappserver::Base::Model::Config::Group;
=head1 NAME

pfappserver::Base::Model::Config

=cut

=head1 DESCRIPTION

pfappserver::Base::Model::Config
Is the Generic class for the cached config

=cut

use Moose;
use namespace::autoclean;
use pf::config::cached;
use HTTP::Status qw(:constants is_error is_success);

BEGIN {extends 'pfappserver::Base::Model::Config';}

=head2 Fields

=over

=item group

=cut

has group => ( is=> 'ro', isa => 'Str');

=back

=head2 Methods

=over

=item readAllIds

Get all the sections names

=cut

sub readAllIds {
    my ( $self, $id ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    return ($STATUS::OK, [$self->_Sections]);
}


=item _Sections

=cut

sub _Sections {
    my ($self) = @_;
    my $group = $self->group;
    return grep { s/^\Q$group\E // }  $self->cachedConfig->Sections($group);
}


=item readAll

Get all the sections as an array of hash refs

=cut

sub readAll {
    my ( $self) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    my ($status,$status_msg);
    my $config = $self->cachedConfig;
    my @sections;
    foreach my $id ($self->_Sections()) {
        my %section = ( $self->idKey() => $id );
        foreach my $param ($self->_Parameters($id)) {
            $section{$param} = $self->_val( $id, $param);
        }
        $self->cleanupAfterRead($id,\%section);
        push @sections,\%section;
    }
    return ($STATUS::OK, \@sections);
}

=item _val

=cut

sub _val {
   my ($self,$id,$param) = @_;
   return $self->cachedConfig->val($self->_makeGroupName($id),$param);
}

=item _Parameters

=cut

sub _Parameters {
   my ($self,$id) = @_;
   return $self->cachedConfig->Parameters($self->_makeGroupName($id));
}


=item _makeGroupName

=cut

sub _makeGroupName {
   my ($self,$id) = @_;
   return $self->group . " " . $id;
}


=item hasId

If config has a section

=cut

sub hasId {
    my ($self, $id ) = @_;
    return $self->SUPER::hasId($self->_makeGroupName($id));
}

=item read

reads a section

=cut

sub read {
    my ($self, $id ) = @_;
    my ($status,$results) = $self->SUPER::read($self->_makeGroupName($id));
    if(is_success($status)) {
        $results->{$self->idKey} = $id;
    }
    return ($status,$results);
}

=item update

Update/edit/modify an existing section

=cut

sub update {
    my ( $self, $id, $assignments ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    my ($status,$status_msg) = ($STATUS::OK,"");
    if($id eq 'all') {
        $status = $STATUS::FORBIDDEN;
        $status_msg = "This method does not handle \"$id\"";
    } else {
        ($status,$status_msg) = $self->SUPER::update($self->_makeGroupName($id),$assignments);
    }
    return ($status, $status_msg);
}

=item create

To create

=cut

sub create {
    my ( $self, $id, $assignments ) = @_;
    return $self->SUPER::create($self->_makeGroupName($id),$assignments);
}


=item remove

Removes an existing item

=cut

sub remove {
    my ( $self, $id, $assignment ) = @_;
    return $self->SUPER::remove($self->_makeGroupName($id),$assignment);
}

=item cleanupAfterRead

=cut

sub cleanupAfterRead { }

=item cleanupBeforeCommit

=cut

sub cleanupBeforeCommit { }


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

