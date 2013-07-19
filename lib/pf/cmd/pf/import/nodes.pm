package pf::cmd::pf::import::nodes;
=head1 NAME

pf::cmd::pf::import::nodes add documentation

=cut

=head1 DESCRIPTION

pf::cmd::pf::import::nodes

=cut

use strict;
use warnings;
use base qw(pf::cmd);
use Role::Tiny::With;
with 'pf::cmd::roles::show_parent_help';

sub parseArgs {
    my ($self) = @_;
    my ($file) = $self->args;
    if($file) {
        $self->{file} = $file;
        return 1;
    }
    return 0;
}

sub _run {
    my ($self) = @_;
    require pf::import;
    pf::import::nodes($self->{file});
    print "Import process complete\n";
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and::or
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

