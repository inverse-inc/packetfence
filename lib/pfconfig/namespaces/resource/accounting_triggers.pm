package pfconfig::namespaces::resource::accounting_triggers;

=head1 NAME

pfconfig::namespaces::resource::accounting_triggers

=cut

=head1 DESCRIPTION

pfconfig::namespaces::resource::accouting_triggers

=cut

use strict;
use warnings;
use pfconfig::namespaces::FilterEngine::SecurityEvent;

use base 'pfconfig::namespaces::resource';

sub build {
    my ($self) = @_;

    # Build the engine here rather than in init(). The manager constructs this
    # namespace on every expire just to read its child_resources; building the
    # SecurityEvent engine in init() therefore ran a full config build on every
    # reload, and config builds leak memory through the tied pf::IniFiles reads.
    # Deferring it to build() keeps mere construction cheap and leak-free.
    my $engine = pfconfig::namespaces::FilterEngine::SecurityEvent->new;
    $engine->build();

    return $engine->{accounting_triggers};
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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

