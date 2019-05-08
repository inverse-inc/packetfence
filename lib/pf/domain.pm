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
use File::Slurp;

# This is to create the templates for the domain info
our $TT_OPTIONS = {ABSOLUTE => 1};
our $template = Template->new($TT_OPTIONS);

=head2 chroot_path

Returns the path to a domain chroot

=cut

sub chroot_path {
    my ($domain) = @_;
    return "$domains_chroot_dir/$domain";
}

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

sub test_join {
    my ($domain) = @_;
    my $chroot_path = chroot_path($domain);
    my ($status, $output) = run("/usr/bin/sudo /sbin/ip netns exec $domain /usr/sbin/chroot $chroot_path /usr/bin/net ads testjoin -s /etc/samba/$domain.conf 2>&1");
    return ($status, $output);
}

=head2 test_auth

Executes the command on the OS to test an authentication to the domain

=cut

sub test_auth {
    my ($domain, $info) = @_;
    $info //= $ConfigDomain{$domain};
    my $chroot_path = chroot_path($domain);
    my ($status, $output) = run("/usr/bin/sudo /usr/sbin/chroot $chroot_path /usr/bin/ntlm_auth --username=$info->{bind_dn} --password=$info->{bind_pass}");
    return ($status, $output);
}

=head2 escape_bind_user_string

Escapes the bind user string for any simple quote

=cut

sub escape_bind_user_string {
    my ($s) = @_;
    $s =~ s/'/'\\''/g;
    return $s;
}

=head2 join_domain

Joins the domain

=cut

sub join_domain {
    my ($domain, $info) = @_;
    my $logger = get_logger();
    my $chroot_path = chroot_path($domain);
    my $output;
    my $error;
    if (!exists $ConfigDomain{$domain}) {
        return { message => "Domain $domain is not configured", status => 404 }, undef;
    }

    regenerate_configuration();

    $info //= $ConfigDomain{$domain};
    (my $status, $output) = run("/usr/bin/sudo /sbin/ip netns exec $domain /usr/sbin/chroot $chroot_path net ads join -s /etc/samba/$domain.conf createcomputer=$info->{ou} -U '".escape_bind_user_string($info->{bind_dn}.'%'.$info->{bind_pass})."' 2>&1");
    chomp($output);
    $logger->info("domain join : $output");

    if ($status != 0) {
        ($status, my $test_output) = test_join($domain);
        if ($status != 0) {
            return {message => $output, status => 400}, undef;
        }
    }

    restart_winbinds();
    return undef, {message => $output, status => 200};
}

=head2 rejoin_domain

Unjoins then joins the domain

=cut

sub rejoin_domain {
    my ($domain, $info) = @_;
    my $logger = get_logger();
    $info //= $ConfigDomain{$domain};
    my @errors;
    my $results = {};
    my ($unjoin_error, $join_error);
    my $err;
    if ($info) {
        my ($unjoin_error, $leave_output) = unjoin_domain($domain, $info);
        if ($unjoin_error) {
            $results->{unjoin} = $unjoin_error->{message};
            push @errors, $unjoin_error;
        } else {
            $results->{unjoin} = $leave_output;
        }

        ($join_error, my $join_output) = join_domain($domain, $info);
        if ($join_error) {
            push @errors, $join_error;
        } else {
            $results->{join} = $join_output;
        }
    }

    if ($join_error) {
        $err = {
            message => "Error rejoining domain '$domain'",
            errors  => \@errors,
            status  => 400
        };
        $results = undef;
    }

    return $err, {status => 200, message => "Leave output:\n" . $results->{unjoin}->{message} . "\n\nJoin output:\n" . $results->{join}->{message}};
}

=head2 unjoin_domain

Joins the domain through the ip namespace

=cut

sub unjoin_domain {
    my ($domain, $info) = @_;
    my $logger = get_logger();
    if (!exists $ConfigDomain{$domain}) {
        return { message => "Domain $domain is not configured", status => 404 }, undef;
    }

    my $chroot_path = chroot_path($domain);

    $info //= $ConfigDomain{$domain};
    my ($status, $output) = run("/usr/bin/sudo /sbin/ip netns exec $domain /usr/sbin/chroot $chroot_path net ads leave -s /etc/samba/$domain.conf -U '".escape_bind_user_string($info->{bind_dn}.'%'.$info->{bind_pass})."' 2>&1");
    chomp($output);
    $logger->info("domain leave : $output");
    $logger->info("netns deletion : ".run("/usr/bin/sudo /sbin/ip netns delete $domain"));
    if ($status) {
        return {message => $output, status => 400}, undef;
    }

    return undef, {message => $output, status => 200};
}

=head2 generate_krb5_conf

Generates the OS krb5.conf with all the domains configured in domain.conf

=cut

sub generate_krb5_conf {
    my $logger = get_logger();
    my @domains = keys %ConfigDomain;
    my $default_domain = $ConfigDomain{$domains[0]}->{dns_name};
    my $vars = {domains => \%ConfigDomain, default_domain => $default_domain};

    pf_run("/usr/bin/sudo touch /etc/krb5.conf");
    pf_run("/usr/bin/sudo /bin/chown pf.pf /etc/krb5.conf");
    $template->process("/usr/local/pf/addons/AD/krb5.tt", $vars, "/etc/krb5.conf") || $logger->error("Can't generate krb5 configuration : ".$template->error);
}

=head2 generate_smb_conf

Generates all files for the domains configured in domain.conf
Will generate one samba config file per domain
It will be in /etc/samba/$domain.conf

=cut

sub generate_smb_conf {
    my $logger = get_logger();
    foreach my $domain (keys %ConfigDomain){
        my %vars = (domain => $domain);
        my %tmp = (%vars, %{$ConfigDomain{$domain}});
        %vars = %tmp;
        pf_run("/usr/bin/sudo touch /etc/samba/$domain.conf");
        pf_run("/usr/bin/sudo /bin/chown pf.pf /etc/samba/$domain.conf");
        my $fname = untaint_chain("/etc/samba/$domain.conf");
        $template->process("/usr/local/pf/addons/AD/smb.tt", \%vars, $fname) || $logger->error("Can't generate samba configuration for $domain : ".$template->error());
    }
}

=head2 generate_resolv_conf

Generates the resolv.conf for the domain and puts it in the ip namespace configuration

=cut

sub generate_resolv_conf {
    my $logger = get_logger();
    foreach my $domain (keys %ConfigDomain){
        pf_run("/usr/bin/sudo /bin/mkdir -p /etc/netns/$domain");
        my @dns_servers = split(',', $ConfigDomain{$domain}{'dns_servers'});
        my %vars = (
            dns_name    => $ConfigDomain{$domain}{'dns_name'},
            dns_servers => [ @dns_servers ],
        );
        pf_run("/usr/bin/sudo /bin/chown pf.pf /etc/netns/$domain");
        pf_run("/usr/bin/sudo touch /etc/netns/$domain/resolv.conf");
        pf_run("/usr/bin/sudo chown pf.pf /etc/netns/$domain/resolv.conf");
        my $fname = untaint_chain("/etc/netns/$domain/resolv.conf");
        $template->process("/usr/local/pf/addons/AD/resolv.tt", \%vars, $fname) || $logger->error("Can't generate resolv.conf for $domain : ".$template->error);
    }
}

=head2 restart_winbinds

Calls pfcmd to restart the winbind processes

=cut

sub restart_winbinds {
    my $logger = get_logger();
    pf_run("/usr/bin/sudo /usr/local/pf/bin/pfcmd service winbindd restart");
}


=head2 regenerate_configuration

This generates the configuration for the domain
Since this needs elevated rights and that it's called by pf owned processes it needs to do it through pfcmd
A better solution should be found eventually

=cut

sub regenerate_configuration {
    my $logger = get_logger();
    pf_run("/usr/bin/sudo /usr/local/pf/bin/pfcmd generatedomainconfig");
}

=head2 has_os_configuration

Detects whether or not this server had a non-PF configuration before
Uses the samba configuration

=cut

sub has_os_configuration {
    if ( -e $SAMBA_CONF_PATH ) {
        my $samba_conf = read_file($SAMBA_CONF_PATH);
        if ( $samba_conf =~ /(\t){0,1}workgroup = (WORKGROUP|MYGROUP|SAMBA).*/ ) {
            return $FALSE;
        }
    }
    return $TRUE;
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

