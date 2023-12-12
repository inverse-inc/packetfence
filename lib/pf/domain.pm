package pf::domain;

=head1 NAME

pf::domain low level interface to manage the domain binding

=head1 DESCRIPTION

pf::domain

=cut

use strict;
use warnings;

use Net::SNMP;
use Template;
use pf::util;
use pf::config qw(%ConfigDomain $OS);
use pf::constants qw($TRUE $FALSE);
use pf::log;
use pf::file_paths qw($domains_chroot_dir);
use pf::constants::domain qw($SAMBA_CONF_PATH);
use File::Slurp;

# This is to create the templates for the domain info
our $TT_OPTIONS = {ABSOLUTE => 1};
our $template = Template->new($TT_OPTIONS);

our $ADD_COMPUTERS_BIN = '/usr/local/pf/bin/impacket-addcomputer';

=head2 run

Executes a command and returns the results as the domain interfaces expect it

=cut

sub run {
    my ($cmd) = @_;
    local $?;
    my $result = `$cmd`;
    my $code = $? >> 8;

    return ($code , $result);
}

=head2 test_join

Executes the command in the OS to test the domain join

=cut

sub add_computer {
    my $option = shift;
    my ($computer_name, $computer_password, $domain_controller_ip, $domain_controller_host, $baseDN, $computer_group, $domain_auth) = @_;

    $computer_name = escape_bind_user_string($computer_name) . "\$";
    $computer_password = escape_bind_user_string($computer_password);

    my $result;
    eval {
        my $command = "$ADD_COMPUTERS_BIN -computer-name $computer_name -computer-pass $computer_password -dc-ip $domain_controller_ip -dc-host '$domain_controller_host' -baseDN '$baseDN' -computer-group $computer_group $domain_auth $option";
        $result = pf_run($command, accepted_exit_status => [ 0 ]);
    };
    if ($@) {
        $result = "Executing add computers failed with unknown errors";
        return $FALSE, $result;
    }

    $result =~ s/Impacket v.*Corporation//g;
    $result =~ s/^\s+|\s+$//g;

    if ($result =~ /\[\*\] (.+)$/) {
        my $success_msg = $1;
        return $TRUE, $success_msg;
    }

    if ($result =~ /\[\-\] (.+)$/) {
        my $error_msg = $1;
        return $FALSE, $error_msg
    }

    return $FALSE, $result;
}



=head2 escape_bind_user_string

Escapes the bind user string for any simple quote

=cut

sub escape_bind_user_string {
    my ($s) = @_;
    $s =~ s/'/'\\''/g;
    return $s;
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

