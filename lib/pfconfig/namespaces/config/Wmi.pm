package pfconfig::namespaces::config::Wmi;

=head1 NAME

pfconfig::namespaces::config::Wmi

=cut

=head1 DESCRIPTION

pfconfig::namespaces::config::Wmi

This module creates the configuration hash associated to wmi.conf

=cut


use strict;
use warnings;

use pfconfig::namespaces::config;
use pf::log;
use pf::file_paths qw($wmi_config_file);
use pf::config::builder::wmi_action;
use pf::IniFiles;

use base 'pfconfig::namespaces::config';

sub init {
    my ($self) = @_;
    $self->{file} = $wmi_config_file;
    $self->{expandable_params} = qw(actions);
}

sub build_child {
    my ($self) = @_;

    my %tmp_cfg = %{$self->{cfg}};
    $self->cleanup_whitespaces( \%tmp_cfg );

    foreach my $key ( keys %tmp_cfg){
        $self->cleanup_after_read($key, $tmp_cfg{$key});
    }

    return \%tmp_cfg;

}

sub cleanup_after_read {
    my ($self, $id, $item) = @_;
    $self->expand_list($item, $self->{expandable_params});
    my $action = $item->{action};
    my $file = $self->{file};
    if ($action) {
        my $ini = pf::IniFiles->new(-file => \$action, -allowempty => 1);
        if (!defined($ini)) {
            my $msg =  join(" ", @pf::IniFiles::errors);
            get_logger->error($msg);
            return;
        }

        my $builder = pf::config::builder::wmi_action->new();
        my ($errors, $filters) = $builder->build($ini);
        $item->{filters} = $filters // [];
        for my $err (@{ $errors // [] }) {
            my $error_msg =  "$file: $err->{rule}) $err->{message}";
            get_logger->error($error_msg);
            warn($error_msg);
        }

    }
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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

