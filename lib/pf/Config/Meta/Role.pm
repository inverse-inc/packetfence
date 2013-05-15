package pf::Config::Meta::Role;
=head1 NAME

pf::Config::Meta::Role;

=cut

=head1 DESCRIPTION

pf::Config::Meta::Role;

=cut

use Moose::Role;


has 'field_list' => (
    traits    => ['Array'],
    is        => 'rw',
    isa       => 'ArrayRef',
    default   => sub { [] },
    handles  => {
        add_to_field_list => 'push',
        clear_field_list => 'clear',
        has_field_list => 'count',
    }
);

has 'apply_list' => (
    traits    => ['Array'],
    is        => 'rw',
    isa       => 'ArrayRef',
    default   => sub { [] },
    handles  => {
        add_to_apply_list => 'push',
        has_apply_list => 'count',
        clear_apply_list => 'clear',
    }
);

has 'page_list' => (
    traits    => ['Array'],
    is        => 'rw',
    isa       => 'ArrayRef',
    default   => sub { [] },
    handles  => {
        add_to_page_list => 'push',
        has_page_list => 'count',
        clear_page_list => 'clear',
    }
);

has 'block_list' => (
    traits    => ['Array'],
    is        => 'rw',
    isa       => 'ArrayRef',
    default   => sub { [] },
    handles  => {
        add_to_block_list => 'push',
        has_block_list => 'count',
        clear_block_list => 'clear',
    }
);

has 'found_hfh' => ( is => 'rw', default => '0' );

use namespace::autoclean;
1;

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

