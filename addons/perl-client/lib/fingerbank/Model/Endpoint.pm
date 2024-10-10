package fingerbank::Model::Endpoint;

=head1 NAME

fingerbank::Model::Endpoint

=head1 DESCRIPTION

Class that represents an endpoint

=cut

use Moose;
use namespace::autoclean;

use fingerbank::Constant qw($TRUE $FALSE $UPSTREAM_SCHEMA);
use fingerbank::Log;
use fingerbank::Util qw(is_error is_success);
use fingerbank::Model::Device;
use List::MoreUtils qw(any);

has 'name' => (is => 'rw', required => 1);
has 'version' => (is => 'rw', required => 1);
has 'score' => (is => 'rw', required => 1);
has 'parents' => (is => 'rw', isa => 'ArrayRef');

sub BUILD {
    my ($self) = @_;
    my $logger = fingerbank::Log::get_logger;

    unless(defined($self->parents)){
        my ($status, $result) = fingerbank::Model::Device->find([{ name => $self->name }, {columns => ['id']}], $UPSTREAM_SCHEMA);
        if(is_success($status)){
            my $device_id = $result->id;
            ($status, $result) = fingerbank::Model::Device->read($device_id, $TRUE);
            if(is_success($status)){
                $logger->debug("Looked up parents for $device_id successfully");
                my @parents = map {$_->name} @{$result->{parents}};
                $self->parents(\@parents);
            }
            else {
                $logger->debug("Cannot find device ".$device_id." in the database");
            }
        }
        else {
            $logger->debug("Cannot find device ".$self->name." in the database");
        }
    }
}

=head2 fromResult

Build an endpoint object from a result obtained from Fingerbank sources

=cut

sub fromResult {
    my ( $class, $result ) = @_;
    my @parents;
    foreach my $parent (@{$result->{device}->{parents}}){
        push @parents, $parent->{name};
    }
    return $class->new(name => $result->{device}->{name}, version => $result->{version}, score => $result->{score}, parents => \@parents);
}

=head2 isWindows

Test if endpoint is Windows based

=cut

sub isWindows {
    my ( $self ) = @_;
    return $self->is_a_by_id($fingerbank::Constant::PARENT_IDS{WINDOWS});
}

=head2 isMacOS

Test if endpoint is MAC OS based

=cut

sub isMacOS {
    my ( $self ) = @_;
    return $self->is_a_by_id($fingerbank::Constant::PARENT_IDS{MACOS});
}

=head2 isAndroid

Test if endpoint is Android based

=cut

sub isAndroid {
    my ( $self ) = @_;
    return $self->is_a_by_id($fingerbank::Constant::PARENT_IDS{ANDROID});
}

=head2 isIOS

Test if endpoint is IOS based

=cut

sub isIOS {
    my ( $self ) = @_;
    return $self->is_a_by_id($fingerbank::Constant::PARENT_IDS{IOS});
}


=head2 isWindowsPhone

Test if endpoint is Windows Phone based

=cut

sub isWindowsPhone {
    my ( $self ) = @_;
    return $self->is_a_by_id($fingerbank::Constant::PARENT_IDS{WINDOWS_PHONE});
}

=head2 isBlackberry

Test if endpoint is Blackberry based

=cut

sub isBlackberry {
    my ( $self ) = @_;
    return $self->is_a_by_id($fingerbank::Constant::PARENT_IDS{BLACKBERRY});
}

=head2 isLinux

Test if endpoint is Linux based

=cut

sub isLinux {
    my ( $self ) = @_;
    return $self->is_a_by_id($fingerbank::Constant::PARENT_IDS{LINUX});
}

=head2 is_a

=cut

sub is_a {
    my ( $self, $device_name ) = @_;
    my $logger = fingerbank::Log::get_logger;
    $logger->debug("Testing if device '".$self->name."' is or has $device_name for parent");

    return fingerbank::Model::Device->is_a($self->name, $device_name);
}

sub is_a_by_id {
    my ($self, $id) = @_;
    my $logger = fingerbank::Log::get_logger;
    $logger->debug("Testing if device '".$self->name."' is or has $id for parent");

    return fingerbank::Model::Device->is_a($self->name, $id);
}

=head2 hasParent

=cut

sub hasParent {
    my ( $self, $device_name ) = @_;
    return any { $_ eq $device_name } @{$self->parents // []};
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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
