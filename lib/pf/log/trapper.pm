package pf::log::trapper;

=head1 NAME

pf::log::trapper

=head1 DESCRIPTION

pf::log::trapper traps print to filehandles to a log

=head1 SYNOPSIS

    use pf::log::trapper;
    use Log::Log4perl::Level;
    tie *STDERR,'pf::log::trapper',$ERROR;
    tie *STDOUT,'pf::log::trapper',$DEBUG;

=cut

use strict;
use warnings;
use base qw(Tie::Handle);
use Log::Log4perl;
Log::Log4perl->wrapper_register(__PACKAGE__);

sub TIEHANDLE {
    my $class = shift;
    my $level = shift;
    bless [Log::Log4perl->get_logger(),$level], $class;
}


=head2 PRINT

Print the to logger

=cut

sub PRINT {
    my $self = shift;
    local $Log::Log4perl::caller_depth = $Log::Log4perl::caller_depth + 1;
    $self->[0]->log($self->[1],@_);
}

=head2 PRINTF

Implements printf for the TIE::Handle

=cut

sub PRINTF {
    my $self = shift;
    my $buf = sprintf(@_);
    $self->PRINT($buf);
}

=head2 FILENO

Return undef to avoid Cache::BDB from failing sometimes

=cut

sub FILENO { undef }

=head2 CLOSE

CLOSE is a noop just returns 1

=cut

sub CLOSE { 1; }

=head2 OPEN

OPEN is a noop just returns 1

=cut

sub OPEN { 1; }


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

