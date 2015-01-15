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
use pf::ConfigStore::Domain;
use pf::log;

our $TT_OPTIONS = {ABSOLUTE => 1};
our $template = Template->new($TT_OPTIONS);

sub join_domain {
  my ($domain) = @_;
  my $logger = get_logger();
  my $cfg = pf::ConfigStore::Domain->new;

  my $info = $cfg->read($domain);
  $logger->debug("domain join : ".pf_run("sudo ip netns exec $domain net ads join -S $info->{ad_server} $info->{dns_name} -s /etc/samba/$domain.conf -U $info->{bind_dn}%$info->{bind_pass}"));

  $logger->debug("winbind restart : ".pf_run("sudo /etc/init.d/winbind.$domain restart"));

  $logger->debug("chkconfig $domain : ".pf_run("sudo /sbin/chkconfig --add winbind.$domain"));
  $logger->debug("chkconfig $domain : ".pf_run("sudo /sbin/chkconfig --add winbind.$domain on"));

}

sub rejoin_domain {
  my ($domain) = @_;
  my $logger = get_logger();
  my $cfg = pf::ConfigStore::Domain->new;

  my $info = $cfg->read($domain);
  if($info){
    $logger->debug("domain leave : ".system("sudo ip netns exec $domain net ads leave -S $info->{ad_server} $info->{dns_name} -s /etc/samba/$domain.conf -U $info->{bind_dn}%$info->{bind_pass}"));
    $logger->debug("domain join : ".system("sudo ip netns exec $domain net ads join -S $info->{ad_server} $info->{dns_name} -s /etc/samba/$domain.conf -U $info->{bind_dn}%$info->{bind_pass}"));
  }
}

sub unjoin_domain {
  my ($domain) = @_;
  my $logger = get_logger();
  my $cfg = pf::ConfigStore::Domain->new;

  my $info = $cfg->read($domain);
  if($info){
    $logger->debug("domain leave : ".system("sudo ip netns exec $domain net ads leave -S $info->{ad_server} $info->{dns_name} -s /etc/samba/$domain.conf -U $info->{bind_dn}%$info->{bind_pass}"));
    $logger->debug("netns deletion : ".system("sudo ip netns delete $domain"));
    pf_run("sudo /etc/init.d/winbind.$domain stop");
    pf_run("sudo rm -f /etc/init.d/winbind.$domain");
  }
  else{
    $logger->error("Domain $domain is not configured");
  }


}

sub generate_krb5_conf {
  my $logger = get_logger();
  my $vars = {domains => \%ConfigDomain};

  pf_run("sudo touch /etc/krb5.conf");
  pf_run("sudo chown pf_admin.pf_admin /etc/krb5.conf");
  $template->process("/usr/local/pf/addons/AD/krb5.tt", $vars, "/etc/krb5.conf") || $logger->error("Can't generate krb5 configuration : ".$template->error);
}

sub generate_smb_conf {
  my $logger = get_logger();
  foreach my $domain (keys %ConfigDomain){
    my %vars = (domain => $domain);
    my %tmp = (%vars, %{$ConfigDomain{$domain}});
    %vars = %tmp;
    pf_run("sudo touch /etc/samba/$domain.conf");
    pf_run("sudo chown pf_admin.pf_admin /etc/samba/$domain.conf");
    $template->process("/usr/local/pf/addons/AD/smb.tt", \%vars, "/etc/samba/$domain.conf") || $logger->error("Can't generate samba configuration for $domain : ".$template->error()); 
  }
}

sub generate_init_conf {
  my $logger = get_logger();
  foreach my $domain (keys %ConfigDomain){
    my %vars = (domain => $domain);
    pf_run("sudo touch /etc/init.d/winbind.$domain");
    pf_run("sudo chown pf_admin.pf_admin /etc/init.d/winbind.$domain");
    $template->process("/usr/local/pf/addons/AD/winbind.init.tt", \%vars, "/etc/init.d/winbind.$domain") || $logger->error("Can't generate init script for $domain : ".$template->error); 
    pf_run("sudo chmod ug+x /etc/init.d/winbind.$domain");
  } 
}

sub generate_resolv_conf {
  my $logger = get_logger();
  foreach my $domain (keys %ConfigDomain){
    pf_run("sudo mkdir -p /etc/netns/$domain");
    my %vars = (domain => $domain);
    my %tmp = (%vars, %{$ConfigDomain{$domain}});
    %vars = %tmp;
    pf_run("sudo chown pf_admin.pf_admin /etc/netns/$domain");
    pf_run("sudo touch /etc/netns/$domain/resolv.conf");
    pf_run("sudo chown pf_admin.pf_admin /etc/netns/$domain/resolv.conf");
    $template->process("/usr/local/pf/addons/AD/resolv.tt", \%vars, "/etc/netns/$domain/resolv.conf") || $logger->error("Can't generate resolv.conf for $domain : ".$template->error); 
  }  
}

sub restart_winbinds {
  my $logger = get_logger();
  foreach my $domain (keys %ConfigDomain){
    pf_run("sudo /etc/init.d/winbind.$domain restart");
  }  
}


sub regenerate_configuration {
  my $logger = get_logger();
  generate_krb5_conf();
  generate_smb_conf();
  generate_init_conf();
  generate_resolv_conf();
  pf_run("sudo cp /usr/local/pf/addons/AD/winbind.setup.init /etc/init.d/winbind.setup");
  pf_run("sudo chkconfig winbind.setup on");
  pf_run("sudo /etc/init.d/winbind.setup restart");
  pf_run("sudo /usr/local/pf/bin/pfcmd service iptables restart");
  restart_winbinds();
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

