package pfappserver::Model::Config::MappedPf;

=head1 NAME

pfappserver::Model::Config add documentation

=cut

=head1 DESCRIPTION

MappedPf

=cut

use strict;
use warnings;
use Moose;  # automatically turns on strict and warnings
use namespace::autoclean;
use Readonly;
use pfappserver::Model::Config::IniStyleBackend;
use HTTP::Status qw(:constants is_error is_success);


has 'mapping'       => ( is => 'rw', isa => 'HashRef');
has 'pf_config'     => ( is => 'rw');
has 'pf_entries'    => ( is => 'rw', isa => 'ArrayRef');
has 'virtual_names' => ( is => 'rw', isa => 'ArrayRef');


=head2 Methods

=over

=item BUILDARGS

=cut

sub BUILDARGS {
    my ($self,@args) = @_;
    my $args_ref = {};
    if(@args == 1 ) {
        $args_ref = $args[0];
    }
    else {
        $args_ref = {@args};
    }
    return $args_ref;
}


=item BUILD

=cut

sub BUILD {
    my ($self,$args) = @_;
    my %mapping = %$args;
    my @pf_entries = keys %mapping;
    my @virtual_names = @mapping{@pf_entries};
    @mapping{@virtual_names} = @pf_entries;
    $self->pf_entries(\@pf_entries);
    $self->mapping(\%mapping);
    $self->virtual_names(\@virtual_names);
    $self->pf_config(new pfappserver::Model::Config::Pf);
};


=item read

=cut

sub read {
    my ($self) = @_;
    my $pf_entries = $self->pf_entries;
    my ($status,$result) = $self->pf_config->read_value($pf_entries);
    if(is_success($status)) {
        $result = $self->map_names($result);
    }
    return ($status,$result);
}


=item map_names

=cut

sub map_names {
    my ($self,$hash) = @_;
    my $mapping = $self->mapping;
    my @names = grep {exists $mapping->{$_} } keys %$hash;
    my %new_hash;
    @new_hash{@{$self->mapping}{@names}} = @{$hash}{@names};
    return \%new_hash;
}



=item update

=cut

sub update {
    my ($self,$config_ref) = @_;
    return $self->pf_config->update($self->map_names($config_ref));
}

sub readConfig {}

no Moose;
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

