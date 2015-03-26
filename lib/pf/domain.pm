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
use pf::config;
use pf::log;
use pf::file_paths;

our $TT_OPTIONS = {ABSOLUTE => 1};
our $template = Template->new($TT_OPTIONS);

sub chroot_path {
    my ($domain) = @_;
    return $domains_chroot_dir."/".$domain; 
}

sub run {
    my ($cmd) = @_;

    my $result = `$cmd`;
    my $code = $? >> 8;

    return ($code , $result);
}

sub test_join {
    my ($domain) = @_;
    my ($status, $output) = run("sudo /sbin/ip netns exec $domain /usr/bin/net ads testjoin -s /etc/samba/$domain.conf");
    return ($status, $output);
}

sub test_auth {
    my ($domain) = @_;
    my $chroot_path = chroot_path($domain);
    my $info = $ConfigDomain{$domain};
    my ($status, $output) = run("/usr/bin/sudo /usr/sbin/chroot $chroot_path /usr/bin/ntlm_auth --username=$info->{bind_dn} --password=$info->{bind_pass}");
    return ($status, $output);
}


sub join_domain {
  my ($domain) = @_;
  my $logger = get_logger();

  regenerate_configuration();

  my $info = $ConfigDomain{$domain};
  my ($status, $output) = run("sudo ip netns exec $domain net ads join -S $info->{ad_server} $info->{dns_name} -s /etc/samba/$domain.conf -U $info->{bind_dn}%$info->{bind_pass}");
  $logger->info("domain join : ".$output);

  restart_winbinds();
  
  return $output; 
}

sub rejoin_domain {
  my ($domain) = @_;
  my $logger = get_logger();

  my $info = $ConfigDomain{$domain};
  if($info){
    my ($leave_output) = unjoin_domain($domain);

    my $join_output = join_domain($domain);

    return {leave_output => $leave_output, join_output => $join_output};
  }
}

sub unjoin_domain {
  my ($domain) = @_;
  my $logger = get_logger();

  my $info = $ConfigDomain{$domain};
  if($info){
    my ($status, $output) = run("sudo ip netns exec $domain net ads leave -S $info->{ad_server} $info->{dns_name} -s /etc/samba/$domain.conf -U $info->{bind_dn}%$info->{bind_pass}");
    $logger->info("domain leave : ".$output);
    $logger->info("netns deletion : ".run("sudo ip netns delete $domain"));
    return $output;
  }
  else{
    $logger->error("Domain $domain is not configured");
  }

}

sub generate_krb5_conf {
  my $logger = get_logger();
  my $vars = {domains => \%ConfigDomain};

  pf_run("sudo touch /etc/krb5.conf");
  pf_run("sudo chown pf.pf /etc/krb5.conf");
  $template->process("/usr/local/pf/addons/AD/krb5.tt", $vars, "/etc/krb5.conf") || $logger->error("Can't generate krb5 configuration : ".$template->error);
}

sub generate_smb_conf {
  my $logger = get_logger();
  foreach my $domain (keys %ConfigDomain){
    my %vars = (domain => $domain);
    my %tmp = (%vars, %{$ConfigDomain{$domain}});
    %vars = %tmp;
    pf_run("sudo touch /etc/samba/$domain.conf");
    pf_run("sudo chown pf.pf /etc/samba/$domain.conf");
    my $fname = untaint_chain("/etc/samba/$domain.conf");
    $template->process("/usr/local/pf/addons/AD/smb.tt", \%vars, $fname) || $logger->error("Can't generate samba configuration for $domain : ".$template->error()); 
  }
}

sub generate_resolv_conf {
  my $logger = get_logger();
  foreach my $domain (keys %ConfigDomain){
    pf_run("sudo mkdir -p /etc/netns/$domain");
    my %vars = (domain => $domain);
    my %tmp = (%vars, %{$ConfigDomain{$domain}});
    %vars = %tmp;
    pf_run("sudo chown pf.pf /etc/netns/$domain");
    pf_run("sudo touch /etc/netns/$domain/resolv.conf");
    pf_run("sudo chown pf.pf /etc/netns/$domain/resolv.conf");
    my $fname = untaint_chain("/etc/netns/$domain/resolv.conf");
    $template->process("/usr/local/pf/addons/AD/resolv.tt", \%vars, $fname) || $logger->error("Can't generate resolv.conf for $domain : ".$template->error); 
  }  
}

sub restart_winbinds {
  my $logger = get_logger();
  #my $result = pf::services::service_ctl("winbindd", "restart");
  pf_run("sudo /usr/local/pf/bin/pfcmd service winbindd restart");
}


sub regenerate_configuration {
  my $logger = get_logger();
  pf_run("sudo /usr/local/pf/bin/pfcmd generatedomainconfig");
}



=head1 AUTHOR

Inverse inc. <info@inverse.ca>


=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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

