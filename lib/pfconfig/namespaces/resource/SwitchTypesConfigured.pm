package pfconfig::namespaces::resource::SwitchTypesConfigured;

=head1 NAME

pfconfig::namespaces::resource::SwitchTypesConfigured

=cut

=head1 DESCRIPTION

pfconfig::namespaces::resource::SwitchTypesConfigured

This module creates a hash of all the configured switches

=cut

use strict;
use warnings;

use base 'pfconfig::namespaces::resource';

use NetAddr::IP;

=head2 init

Initialize the pfconfig::namespaces::resource::SwitchTypesConfigured object

=cut

sub init {
    my ($self) = @_;
    # we depend on the switch configuration object (russian doll style)
    $self->{switches} = $self->{cache}->get_cache('config::Switch');
}

=head2 build

Builds a hash of all the configured switches

=cut

sub build {
    my ($self) = @_;
    my %types;
    my @ranges;
    foreach my $data ( values %{$self->{switches}} ) {
        my $type = $data->{type};
        next if !defined $type;
        $types{"pf::Switch::$type"} = 1;
    }
    return \%types;
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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

