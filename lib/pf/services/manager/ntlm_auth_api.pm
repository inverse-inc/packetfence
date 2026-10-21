package pf::services::manager::ntlm_auth_api;

=head1 NAME

pf::services::manager::ntlm_auth_api

=cut

=head1 DESCRIPTION

pf::services::manager::ntlm_auth_api

=cut

use strict;
use warnings;
use Sys::Hostname;
use pf::db;

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
use pf::util qw(isenabled safe_pf_run);
use pf::constants qw($TRUE $FALSE);

extends 'pf::services::manager';

has '+name' => (default => sub {'ntlm-auth-api'});

sub generateConfig {
    my $self = shift;

    safe_pf_run(qw(sudo rm -rf), "$generated_conf_dir/" . $self->name() . ".d/");
    safe_pf_run(qw(sudo mkdir -p),  "$generated_conf_dir/" . $self->name() . ".d/");

    my $db_config = pf::db::db_config();

    my $db_host = $db_config->{'host'};
    my $db_port = $db_config->{'port'};
    my $db_user = $db_config->{'user'};
    my $db_pass = $db_config->{'pass'};
    my $db = $db_config->{'db'};
    my $db_unix_socket = $db_config->{'unix_socket'};
    my $redis_cache_host = $Config{services}{redis_cache_host};
    my $redis_cache_port = $Config{services}{redis_cache_port};

    if (!defined($db_host) || !defined($db_port) || !defined($db_user) || !defined($db_pass) || !defined($db) || !defined($db_unix_socket) || $db_host eq "" || $db_port eq "" || $db_user eq "" || $db_pass eq "" || $db eq "" || $db_unix_socket eq "") {
        print("Warning: Some of the database settings are missing while generating db.ini, ntlm-auth-api might not able to start properly\n")
    }

    my $db_ini = "$generated_conf_dir/" . $self->name . '.d/' . "db.ini";
    safe_pf_run("sudo", "echo", "[DB]", {stdout => $db_ini});
    safe_pf_run("sudo", "echo", "DB_HOST=$db_host", {stdout => $db_ini, stdout_append => 1});
    safe_pf_run("sudo", "echo", "DB_PORT=$db_port", {stdout => $db_ini, stdout_append => 1});
    safe_pf_run("sudo", "echo", "DB_USER=$db_user", {stdout => $db_ini, stdout_append => 1});
    safe_pf_run("sudo", "echo", "DB_PASS=$db_pass", {stdout => $db_ini, stdout_append => 1});
    safe_pf_run("sudo", "echo", "DB=$db", {stdout => $db_ini, stdout_append => 1});
    safe_pf_run("sudo", "echo", "DB_UNIX_SOCKET=$db_unix_socket", {stdout => $db_ini, stdout_append => 1});

    safe_pf_run("sudo", "echo", "[CACHE]", {stdout => $db_ini, stdout_append => 1});

    safe_pf_run("sudo", "echo", "CACHE_HOST=$redis_cache_host", {stdout => $db_ini, stdout_append => 1});
    safe_pf_run("sudo", "echo", "CACHE_PORT=$redis_cache_port", {stdout => $db_ini, stdout_append => 1});

    my $host_id = hostname();
    for my $identifier (keys(%ConfigDomain)) {
        my %conf = %{$ConfigDomain{$identifier}};
        next if (exists($conf{use_connector}) && isenabled($conf{use_connector}));
        if (exists($conf{ntlm_auth_host}) && exists($conf{ntlm_auth_port}) && exists($conf{machine_account_password})) {
            my $ntlm_auth_host = $conf{ntlm_auth_host};
            my $ntlm_auth_port = $conf{ntlm_auth_port};

            $identifier =~ s/$host_id //i;
            my $env_file = "$generated_conf_dir/" . $self->name . '.d/' . "$identifier.env";
            safe_pf_run("sudo", "echo", "HOST=$ntlm_auth_host", {stdout => $env_file});
            safe_pf_run("sudo", "echo", "LISTEN=$ntlm_auth_port", {stdout => $env_file, stdout_append => 1});
            safe_pf_run("sudo", "echo", "IDENTIFIER=$identifier", {stdout => $env_file, stdout_append => 1});
        }
    }
}

sub isManaged {
    my ($self) = @_;
    if ($self->SUPER::isManaged && keys(%ConfigDomain) > 0) {
        for my $identifier (keys(%ConfigDomain)) {
            my %conf = %{$ConfigDomain{$identifier}};
            if (!exists($conf{use_connector}) || !isenabled($conf{use_connector})) {
                return $TRUE;
            }
        }
    }
    return $FALSE;
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

