package pf::UnifiedApi::Controller::Config::Filters;

=head1 NAME

pf::UnifiedApi::Controller::Config::Filters - 

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Controller::Config::Filters



=cut

use strict;
use warnings;
use pf::constants::filters qw(%CONFIGSTORE_MAP);
use File::Slurp;
use pf::util;
use pf::error qw(is_error);
use Mojo::Base qw(pf::UnifiedApi::Controller::RestRoute);
use pf::config::builder::scoped_filter_engines;
use pf::IniFiles;

=head2 resource

Validate the resource

=cut

sub resource {
    my ($self) = @_;
    my $id = $self->stash->{filter_id};
    unless (exists $CONFIGSTORE_MAP{"${id}-filters"}) {
        return $self->render_error("404", "Item ($id) not found");
    }

    return 1;
}

=head2 fileName

File Name of filter

=cut

sub fileName {
    my ($self) = @_;
    return $self->configStore->configFile;
}

=head2 configStore

configStore

=cut

sub configStore {
    my ($self) = @_;
    my $id = $self->stash->{filter_id};
    return $CONFIGSTORE_MAP{"${id}-filters"};
}

=head2 get

get a filter

=cut

sub get {
    my ($self) = @_;
    my $fileName = $self->fileName;
    return $self->render(text => scalar read_file($fileName), status => 200);
}

=head2 replace

replace a filter

=cut

sub replace {
    my ($self) = @_;
    my $id = $self->stash->{filter_id};
    my ($status, $errors)  = $self->isFilterValid();
    if (is_error($status)) {
        return $self->render_error($status, "Invalid $id file" ,$errors);
    }

    my $body = $self->req->body;
    $body .= "\n" if $body !~ m/\n\z/s;
    pf::util::safe_file_update($self->fileName, $body);
    return $self->render(status => $status, json => {});
}

=head2 isFilterValid

Is a filter valid

=cut

sub isFilterValid {
    my ($self) = @_;
    my $body = $self->req->body;
    $body .= "\n" if $body !~ m/\n\z/s;
    my %args = $self->configStore->configIniFilesArgs();
    $args{'-file'} = \$body;
    my $builder = pf::config::builder::scoped_filter_engines->new();
    my $ini = pf::IniFiles->new(%args);
    unless (defined $ini) {
        return (422, [{ message => join("\n", @pf::IniFiles::errors)}]);
    }

    my ($errors, $scopes) = $builder->build($ini);
    if ($errors) {
        return (422, $errors);
    }

    return (200, undef);
}

=head2 list

list

=cut

sub list {
    my ($self) = @_;
    return $self->render( json => {
        items => [
           map { my $id = $_; $id =~ s/-filters//; { id => $id } } keys %CONFIGSTORE_MAP
        ],
    } );
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

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
