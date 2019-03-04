package pf::log::FileAppender;

=head1 NAME

pf::log::FileAppender

=cut

=head1 DESCRIPTION

Used to extend the Log4perl file appender so it doesn't die on failure.

=cut

use base qw( Log::Log4perl::Appender::File );
use strict;
use warnings;

sub log {
     my($self, @args) = @_;

     local $Log::Log4perl::caller_depth =
           $Log::Log4perl::caller_depth + 1;

     eval { $self->SUPER::log(@args) };
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

