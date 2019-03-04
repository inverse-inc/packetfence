package pf::cmd::pf::version;
=head1 NAME

pf::cmd::pf::version add documentation

=cut

=head1 DESCRIPTION

pf::cmd::pf::version

=head1 SYNOPSIS

pfcmd version

output version information

=cut

use strict;
use warnings;

use pf::file_paths qw(
    $conf_dir
);
use pf::log;
use pf::constants::exit_code qw($EXIT_SUCCESS);

use base qw(pf::cmd);

sub _run {
    # TODO: move this code into library code and have pf::config hold the value somewhere.
    # Then report the version in Web Services API calls like for the Extreme Switches' appName
    my ( $pfrelease_fh, $release );
    open( $pfrelease_fh, '<', "$conf_dir/pf-release" )
        || get_logger->logdie("Unable to open $conf_dir/pf-release: $!");
    $release = <$pfrelease_fh>;
    close($pfrelease_fh);
    print $release;
    return $EXIT_SUCCESS;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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

