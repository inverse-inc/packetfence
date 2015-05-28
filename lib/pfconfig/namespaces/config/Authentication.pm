package pfconfig::namespaces::config::Authentication;

=head1 NAME

pfconfig::namespaces::config::Authentication

=cut

=head1 DESCRIPTION

pfconfig::namespaces::config::Authentication

This module creates the configuration hash associated to authentication.conf

It also stores the information for @authentication_sources and %authentication_lookup

=cut

use strict;
use warnings;

use pfconfig::namespaces::config;
use pf::file_paths;
use pf::constants::authentication;
use pf::Authentication::constants;
use pf::Authentication::Action;
use pf::Authentication::Condition;
use pf::Authentication::Rule;
use pf::constants::authentication;

use base 'pfconfig::namespaces::config';

sub init {
    my ($self) = @_;
    $self->{file}            = $authentication_config_file;
    $self->{child_resources} = [
        'resource::authentication_lookup', 'resource::authentication_sources',
        'resource::guest_self_registration',
    ];
}

sub build_child {
    my ($self) = @_;

    my %cfg = %{ $self->{cfg} };

    my @authentication_sources = ();
    my %authentication_lookup  = ();
    foreach my $source_id (@{$self->{ordered_sections}}) {
        # We skip groups from our ini files
        if ($source_id =~ m/\s/) {
            next;
        }
        my %args = %{$cfg{$source_id}};

        # Keep aside the source type
        my $type = delete $args{type};
        delete $cfg{$source_id}{type};

        my %group_args;

        # Parse rules
        foreach my $group_id ($self->GroupMembers($source_id)) {
            my ($group, $id) = $group_id =~ m/\Q$source_id\E +(\S+) +(\S+)$/;
            push @{$group_args{$group}}, {id => $id, %{$cfg{$group_id}}};

        }
        $args{group_args} = \%group_args if keys %group_args;
        my $current_source =
          $self->newAuthenticationSource($type, $source_id, \%args);

        push(@authentication_sources, $current_source);
        $authentication_lookup{$source_id} = $current_source;
    }

    my %resources;
    $resources{authentication_sources} = \@authentication_sources;
    $resources{authentication_lookup}  = \%authentication_lookup;

    return \%resources;

}

=item newAuthenticationSource

Returns an instance of pf::Authentication::Source::* for the given type

=cut

sub newAuthenticationSource {
    my ( $self, $type, $source_id, $attrs ) = @_;

    my $source;
    $type = lc($type);
    if ( exists $pf::constants::authentication::TYPE_TO_SOURCE{$type} ) {
        my $source_module = $pf::constants::authentication::TYPE_TO_SOURCE{$type};
        $source = $source_module->new( { id => $source_id, %{$attrs} } );
    }

    return $source;
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

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

1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

