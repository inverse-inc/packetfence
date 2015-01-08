#!/usr/bin/perl -w
use strict;
use warnings;
use constant INSTALL_DIR => '/usr/local/pf';

use lib INSTALL_DIR . "/lib";

use Data::Dumper;
use Net::SNMP;
use Config::IniFiles;
use Template;
use pf::util;


our $CONF_FILE = "/usr/local/pf/conf/domain.conf";

sub register_new_domain {
  my $cfg = Config::IniFiles->new( -file => $CONF_FILE );

  my $info;

  print "Enter the friendly domain name : ";
  $info->{domain} = <STDIN>;
  $info->{domain} =~ s/\n//g;

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


  $cfg->AddSection($info->{domain});
  setval($cfg, $info->{domain}, "workgroup", $info->{workgroup});
  setval($cfg, $info->{domain}, "dns_name", $info->{dns_name});
  setval($cfg, $info->{domain}, "server_name", $info->{server_name});
  setval($cfg, $info->{domain}, "ad_server", $info->{ad_server});
  setval($cfg, $info->{domain}, "dns_server", $info->{dns_server});
  setval($cfg, $info->{domain}, "bind_dn", $info->{bind_dn});
  setval($cfg, $info->{domain}, "bind_pass", $info->{bind_pass});

  $cfg->WriteConfig($CONF_FILE);
}

sub generate_krb5_conf {
  my %domains;
  tie %domains, 'Config::IniFiles', (-file=>$CONF_FILE );

  use Data::Dumper;
  print Dumper(\%domains);

  my $vars = {domains => \%domains};

  my $template = Template->new;
  my $data = $template->process("addons/AD/krb5.tt", $vars, "/etc/krb5.conf");
  print $data;
}

sub generate_smb_conf {
  my %domains;
  tie %domains, 'Config::IniFiles', (-file=>$CONF_FILE );

  foreach my $domain (keys %domains){
    my %vars = (domain => $domain);
    my %tmp = (%vars, %{%domains->{$domain}});
    %vars = %tmp;
    use Data::Dumper;
    print Dumper(\%vars);
    my $template = Template->new;
    $template->process("addons/AD/smb.tt", \%vars, "/etc/samba/$domain.conf"); 
  }
}

sub generate_init_conf {
  my %domains;
  tie %domains, 'Config::IniFiles', (-file=>$CONF_FILE );

  use Data::Dumper;
  print Dumper(\%domains);


  foreach my $domain (keys %domains){
    my %vars = (domain => $domain);
    use Data::Dumper;
    print Dumper(\%vars);
    my $template = Template->new;
    $template->process("addons/AD/winbind.init.tt", \%vars, "/etc/init.d/winbind.$domain"); 
    pf_run("chmod ug+x /etc/init.d/winbind.$domain")
  } 
}

sub generate_resolv_conf {
  my %domains;
  tie %domains, 'Config::IniFiles', (-file=>$CONF_FILE );

  use Data::Dumper;
  print Dumper(\%domains);

  foreach my $domain (keys %domains){
    pf_run("mkdir -p /etc/netns/$domain");
    my %vars = (domain => $domain);
    my %tmp = (%vars, %{%domains->{$domain}});
    %vars = %tmp;    use Data::Dumper;
    print Dumper(\%vars);
    my $template = Template->new;
    $template->process("addons/AD/resolv.tt", \%vars, "/etc/netns/$domain/resolv.conf"); 
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
  print pf_run("/etc/init.d/winbind.setup restart");
  print pf_run("/usr/local/pf/bin/pfcmd service iptables restart");
}

regenerate_configuration();
