package pfconfig::namespaces::config::TemplateSwitches;

=head1 NAME

pfconfig::namespaces::config::TemplateSwitches -

=head1 DESCRIPTION

pfconfig::namespaces::config::TemplateSwitches

=cut

use strict;
use warnings;
use pfconfig::namespaces::config;
use pf::IniFiles;
use pf::log;
use pf::file_paths qw($template_switches_config_file $template_switches_default_config_file);
use pf::util;
use List::MoreUtils qw(any uniq);
use pf::config::builder::template_switches;

use base 'pfconfig::namespaces::config';

sub init {
    my ($self, $host_id) = @_;
    $self->{file}            = $template_switches_config_file;
}

sub build {
    my ($self) = @_;
    my $file = $self->{file};
    my $defaults = pf::IniFiles->new(-file => $template_switches_default_config_file);
    my $ini = pf::IniFiles->new(-file => $file, -allowempty => 1, -import => $defaults);
    unless ($ini) {
        my $error_msg = join("\n", @pf::IniFiles::errors, "");
        get_logger->error($error_msg);
        return {};
    }

    my $builder = pf::config::builder::template_switches->new();
    my ($errors, $data) = $builder->build($ini);
    for my $err (@{ $errors // [] }) {
        my $error_msg =  "$file: $err->{message}";
        get_logger->error($error_msg);
        warn($error_msg);
    }

    return $data;
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
