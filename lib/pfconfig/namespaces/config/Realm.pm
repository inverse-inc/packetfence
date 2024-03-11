package pfconfig::namespaces::config::Realm;

=head1 NAME

pfconfig::namespaces::config::Realm

=cut

=head1 DESCRIPTION

pfconfig::namespaces::config::Realm

This module creates the configuration hash associated to realm.conf

=cut

use strict;
use warnings;

use pfconfig::namespaces::config;
use pf::file_paths qw(
  $realm_default_config_file
  $realm_config_file
);

use base 'pfconfig::namespaces::config';

sub init {
    my ($self) = @_;
    $self->{child_resources} = [qw(
        resource::RealmReverseLookup
        config::OrderedRealm
    )];
    $self->{file}            = $realm_config_file;
    $self->{added_params}{'-import'} = pf::IniFiles->new(-file => $realm_default_config_file, -envsubst => 1);
    $self->{added_params}{'-envsubst'} = 1;
}

sub build_child {
    my ($self) = @_;
    my %cfg = %{ $self->{cfg} };
    $self->cleanup_whitespaces( \%cfg );
    my %reverselookup;
    $self->{reverselookup} = \%reverselookup;
    my %cfg_lc;
    while ( my ($k, $val) = each %cfg) {
        $self->expand_list($val, qw(categories));
        if (exists $val->{domain}) {
            push @{$reverselookup{domain}{$val->{domain}}}, $k;
        }
        $cfg_lc{lc($k)} = $val;
    }

    return \%cfg_lc;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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
