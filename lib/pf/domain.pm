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
use pf::config qw(%ConfigDomain);
use pf::constants qw($TRUE $FALSE);
use pf::log;
use pf::file_paths qw($domains_chroot_dir);
use pf::constants::domain qw($SAMBA_CONF_PATH);
use Digest::MD4 qw(md4_hex);
use Encode qw(encode);
use File::Slurp;

# This is to create the templates for the domain info
our $TT_OPTIONS = { ABSOLUTE => 1 };
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

    return ($code, $result);
}

=head2 test_join

Executes the command in the OS to test the domain join

=cut

sub add_computer {
    my $option = shift;
    my ($computer_name, $computer_password, $domain_controller_ip, $domain_controller_host, $dns_name, $workgroup, $ou, $bind_dn, $bind_pass) = @_;

    if (!defined($ou)) {
        $ou = ""
    }

    $ou =~ s/^\s+|\s+$//g;
    $ou =~ s/^['"]|['"]$//g;

    my $method = "LDAPS";
    if (uc($ou) eq "COMPUTERS" || $ou eq "") {
        $method = "SAMR"
    }

    $computer_name = $computer_name . "\$";
    my $domain_auth = "$dns_name/$bind_dn:$bind_pass";
    my $baseDN = generate_base_dn($dns_name);
    my $computer_group = generate_computer_group($dns_name, $ou);

    my $result;
    if ($option =~ /^\s+$/) {
        # no delete, simply adds the computer account.
        eval {
            $result = safe_pf_run($ADD_COMPUTERS_BIN,
                "-computer-name", "$computer_name",
                "-computer-pass", "$computer_password",
                "-dc-ip", "$domain_controller_ip",
                "-dc-host", "$domain_controller_host",
                "-baseDN", "$baseDN",
                "-computer-group", "$computer_group",
                "-method=$method",
                "$domain_auth",
                { accepted_exit_status => [ 0 ] }
            );
        };
    }
    else {
        # computer account already exists / or other cases.
        eval {
            $result = safe_pf_run($ADD_COMPUTERS_BIN,
                "-computer-name", "$computer_name",
                "-computer-pass", "$computer_password",
                "-dc-ip", "$domain_controller_ip",
                "-dc-host", "$domain_controller_host",
                "-baseDN", "$baseDN",
                "-computer-group", "$computer_group",
                "-method=$method",
                "$domain_auth",
                "$option",
                { accepted_exit_status => [ 0 ] }
            );
        };
    }

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
' -> '\''
=cut

sub escape_bind_user_string {
    my ($s) = @_;
    $s =~ s/'/'\\''/g;
    return $s;
}

sub generate_base_dn {
    my $ret = "";

    my ($dns_name) = @_;
    my @array = split(/\./, $dns_name);

    foreach my $element (@array) {
        $ret .= "DC=$element,";
    }
    $ret =~ s/,$//;
    return $ret;
}

sub generate_computer_group {
    my $ret = "";
    my ($dns_name, $ou) = @_;

    my $base_dn = generate_base_dn($dns_name);

    # for OU=Computer or OU="", we put the machine account to CN=Computers.
    if (!defined($ou) || uc($ou) eq "COMPUTERS" || $ou eq "") {
        return "CN=Computers," . $base_dn;
    }

    # Handle real OU strings
    my @array = split(/\//, $ou);
    my $dn_ou = "";

    foreach my $element (@array) {
        $dn_ou = "OU=$element," . $dn_ou;
    }
    $dn_ou =~ s/,$//;
    return $dn_ou . ",$base_dn";
}





=head1 AUTHOR

Inverse inc. <info@inverse.ca>


=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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

