package pfconfig::namespaces::config::FingerbankDoc;

=head1 NAME

pfconfig::namespaces::config::FingerbankDoc

=cut

=head1 DESCRIPTION

pfconfig::namespaces::config::FingerbankDoc

This module creates the configuration hash associated to documentation.conf

=cut

use strict;
use warnings;

use pfconfig::namespaces::config;
use pf::file_paths qw($fingerbank_doc_file);

use base 'pfconfig::namespaces::config';

sub init {
    my ($self) = @_;
    $self->{file} = $fingerbank_doc_file;
}

sub build_child {
    my ($self) = @_;

    my %hash = %{ $self->{cfg} };
    my %child;
    $self->cleanup_whitespaces( \%hash );
    while (my ($key, $val) = each %hash) {
        my ($section, $name) = split(/\./, $key);
        $child{$section}{$name} = $val;
    }

    return \%child;
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

