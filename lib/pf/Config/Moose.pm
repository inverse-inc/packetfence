package pf::Config::Moose;
=head1 NAME

pf::Config::Moose

=cut

=head1 DESCRIPTION

pf::Config::Moose

=cut

# ABSTRACT: to add pf::Config sugar

use strict;
use warnings;
use Moose;
use Moose::Exporter;
use Moose::Util::MetaRole;
use HTML::FormHandler::Meta::Role;
Moose::Exporter->setup_import_methods(
    with_meta => [ 'has_section', 'has_file_name'],
    also        => 'Moose',
);

sub init_meta {
    my $class = shift;

    my %options = @_;
    Moose->init_meta(%options);
    my $meta = Moose::Util::MetaRole::apply_metaroles(
        for             => $options{for_class},
        class_metaroles => {
            class => [ 'pf::Config::Meta::Role' ]
        }
    );
    return $meta;
}


sub has_section {
    my ($meta,$self,@args) = @_;

}

sub has_file_name {
    my ($meta,$self,@args) = @_;

}

use namespace::autoclean;
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

