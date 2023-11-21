package pf::services::manager::ntlm_auth_api;

=head1 NAME

pf::services::manager::httpd_dispatcher

=cut

=head1 DESCRIPTION

pf::services::manager::httpd_dispatcher

=cut

use strict;
use warnings;
use Moo;
use pf::config qw(
    %ConfigDomain
    %Config
);
use pf::file_paths qw(
    $generated_conf_dir
    $install_dir
    $conf_dir
    $var_dir
    $captiveportal_templates_path
);
use pf::util;

extends 'pf::services::manager';

has '+name' => (default => sub {'ntlm-auth-api'});

sub generateConfig {
    my $self = shift;

    pf_run("sudo mkdir -p $generated_conf_dir/" . $self->name() . ".d/");
    pf_run("sudo rm -rf $generated_conf_dir/" . $self->name() . ".d/*.env");

    for my $identifier (keys(%ConfigDomain)) {
        my %conf = %{$ConfigDomain{$identifier}};
        if (exists($conf{ntlm_auth_host}) && exists($conf{ntlm_auth_port}) && exists($conf{machine_account_password})) {
            my $ntlm_auth_host = $conf{ntlm_auth_host};
            my $ntlm_auth_port = $conf{ntlm_auth_port};

            pf_run("sudo echo 'HOST=$ntlm_auth_host' > $generated_conf_dir/" . $self->name . '.d/' . "$identifier.env");
            pf_run("sudo echo 'LISTEN=$ntlm_auth_port' >> $generated_conf_dir/" . $self->name . '.d/' . "$identifier.env");
            pf_run("sudo echo 'IDENTIFIER=$identifier' >> $generated_conf_dir/" . $self->name . '.d/' . "$identifier.env");
        }
    }
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>


=head1 COPYRIGHT

Copyright (C) 2005-2023 Inverse inc.

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

