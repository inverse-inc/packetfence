package fingerbank::Log;

=head1 NAME

fingerbank::Log

=head1 DESCRIPTION

Logging framework that will take care of returning a logging instance depending on caller and
will also handle the initiation and watching of log configuration files.

=cut

use strict;
use warnings;

use Log::Log4perl;

use fingerbank::FilePath qw($LOG_CONF_FILE);

=head1 METHODS

=head2 init_logger

Initiate the logging facility

=cut

sub init_logger {
    Log::Log4perl::init_and_watch($LOG_CONF_FILE, 60);
}

=head2 get_logger

Return a logger instance for the caller package

=cut

sub get_logger {
    my ( $package, $filename, $line ) = caller;
    return Log::Log4perl->get_logger($package);
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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
