#!/usr/bin/perl -w
use strict;
use warnings;
use constant INSTALL_DIR => '/usr/local/pf';

use lib INSTALL_DIR . "/lib";

use Data::Dumper;
use Net::SNMP;
use Template;
use pf::util;
use pf::config;
use pf::ConfigStore::Domain;


our $CONF_FILE = "/usr/local/pf/conf/domain.conf";
our $TT_OPTIONS = {ABSOLUTE => 1};
our $template = Template->new($TT_OPTIONS);

sub register_new_domain {
  my $cfg = pf::ConfigStore::Domain->new;


  my $info;

  print "Enter the friendly domain name : ";
  my $domain = <STDIN>;
  $domain =~ s/\n//g;

  if($cfg->read($domain)){
    print "There is already a domain configured for this name. Unjoin first.";
    exit 1;
  }

  print "Enter the workgroup : ";
  $info->{workgroup} = <STDIN>;
  $info->{workgroup} =~ s/\n//g;

  print "Enter the DNS name of the domain : ";
  $info->{dns_name} = <STDIN>;
  $info->{dns_name} =~ s/\n//g;

  print "Enter the server name (this server) : ";
  $info->{server_name} = <STDIN>;
  $info->{server_name} =~ s/\n//g;

  print "Enter the IP or DNS name of the Active Directory server : ";
  $info->{ad_server} = <STDIN>;
  $info->{ad_server} =~ s/\n//g;

  print "Enter the IP of the DNS server of this domain : ";
  $info->{dns_server} = <STDIN>;
  $info->{dns_server} =~ s/\n//g;

  print "Enter the username to bind to the domain : ";
  $info->{bind_dn} = <STDIN>;
  $info->{bind_dn} =~ s/\n//g;

  print "Enter the password to bind to the domain : ";
  $info->{bind_pass} = <STDIN>;
  $info->{bind_pass} =~ s/\n//g;

  $cfg->update_or_create($domain, $info);
  $cfg->commit;

  regenerate_configuration();  

  print system("ip netns exec $domain net ads join -S $info->{ad_server} $info->{dns_name} -s /etc/samba/$domain.conf -U $info->{bind_dn}%$info->{bind_pass}");

  print system("/etc/init.d/winbind.$domain restart");

  print system("chkconfig winbind.$domain on");

}

sub rejoin_domain {
  my $cfg = pf::ConfigStore::Domain->new;

  print "Enter the friendly domain name : ";
  my $domain = <STDIN>;
  $domain =~ s/\n//g;

  my $info = $cfg->read($domain);
  if($info){
    print system("ip netns exec $domain net ads leave -S $info->{ad_server} $info->{dns_name} -s /etc/samba/$domain.conf -U $info->{bind_dn}%$info->{bind_pass}");
    print system("ip netns exec $domain net ads join -S $info->{ad_server} $info->{dns_name} -s /etc/samba/$domain.conf -U $info->{bind_dn}%$info->{bind_pass}");
  }
}

sub unjoin_domain {
  my $cfg = pf::ConfigStore::Domain->new;
  
  print "Enter the friendly domain name : ";
  my $domain = <STDIN>;
  $domain =~ s/\n//g;

  my $info = $cfg->read($domain);
  if($info){
    print system("ip netns exec $domain net ads leave -S $info->{ad_server} $info->{dns_name} -s /etc/samba/$domain.conf -U $info->{bind_dn}%$info->{bind_pass}");
    print system("ip netns delete $domain");
    print pf_run("rm -f /etc/init.d/winbind.$domain");
    $cfg->remove($domain);
    $cfg->commit;
    exit 1;
  }
  else{
    print "Domain is not configured";
  }


}

sub generate_krb5_conf {
  my $vars = {domains => \%ConfigDomain};

  my $data = $template->process("/usr/local/pf/addons/AD/krb5.tt", $vars, "/etc/krb5.conf");
}

sub generate_smb_conf {
  foreach my $domain (keys %ConfigDomain){
    my %vars = (domain => $domain);
    my %tmp = (%vars, %{$ConfigDomain{$domain}});
    %vars = %tmp;
    $template->process("/usr/local/pf/addons/AD/smb.tt", \%vars, "/etc/samba/$domain.conf") || die $template->error();; 
  }
}

sub generate_init_conf {
  foreach my $domain (keys %ConfigDomain){
    my %vars = (domain => $domain);
    $template->process("/usr/local/pf/addons/AD/winbind.init.tt", \%vars, "/etc/init.d/winbind.$domain"); 
    pf_run("chmod ug+x /etc/init.d/winbind.$domain")
  } 
}

sub generate_resolv_conf {
  foreach my $domain (keys %ConfigDomain){
    pf_run("mkdir -p /etc/netns/$domain");
    my %vars = (domain => $domain);
    my %tmp = (%vars, %{$ConfigDomain{$domain}});
    %vars = %tmp;
    $template->process("/usr/local/pf/addons/AD/resolv.tt", \%vars, "/etc/netns/$domain/resolv.conf"); 
  }  
}

sub restart_winbinds {
  foreach my $domain (keys %ConfigDomain){
    pf_run("/etc/init.d/winbind.$domain restart");
  }  
}

sub setval{
  my ($cfg, $section, $key, $val) = @_;
  if($cfg->exists($section, $key)){
    $cfg->setval($section, $key, $val);
  }
  else{
    $cfg->newval($section, $key, $val);
  }
}

sub regenerate_configuration {
  generate_krb5_conf();
  generate_smb_conf();
  generate_init_conf();
  generate_resolv_conf();
  print pf_run("cp /usr/local/pf/addons/AD/winbind.setup.init /etc/init.d/winbind.setup");
  print pf_run("chkconfig winbind.setup on");
  print pf_run("/etc/init.d/winbind.setup restart");
  print pf_run("/usr/local/pf/bin/pfcmd service iptables restart");
  restart_winbinds();
}

sub status {
  my $cfg = pf::ConfigStore::Domain->new;
  
  print "Enter the friendly domain name : ";
  my $domain = <STDIN>;
  $domain =~ s/\n//g;

  my $info = $cfg->read($domain);
  if($info){
    print system("chroot /chroots/$domain ntlm_auth --username=$info->{bind_dn} --password=$info->{bind_pass}");
  }
  else{
    print "Domain is not configured";
    exit 1;
  }

 
}

my %actions = ("join" => \&register_new_domain, "unjoin" => \&unjoin_domain, "rejoin" => \&rejoin_domain, "refresh" => \&regenerate_configuration, "status" => \&status);

if(defined($ARGV[0]) && exists $actions{$ARGV[0]}){
  $actions{$ARGV[0]}->();
}
else{
  print "Unknown operation...\n";
  print "Valid operation are : \n".Dumper(keys %actions)."\n";
}

