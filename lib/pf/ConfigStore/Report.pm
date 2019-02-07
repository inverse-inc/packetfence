package pf::ConfigStore::Report;
=head1 NAME

pf::ConfigStore::Report

=cut

=head1 DESCRIPTION

ConfigStore for the reports configuration

=cut

use strict;
use warnings;
use Moo;
use pf::file_paths qw($report_config_file $report_default_config_file);
use pf::util;
extends 'pf::ConfigStore';

sub importConfigFile { $report_default_config_file };

sub configFile { $report_config_file };

sub pfconfigNamespace {'config::Report'}

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


