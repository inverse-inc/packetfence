#!/usr/bin/perl
#
# Copyright 2005 Dave Laporte <dave@laportestyle.org>
# Copyright 2005 Kevin Amorin <kev@amorin.org>
# Copyright 2007-2008 Dominik Gehl <dgehl@inverse.ca>
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html.
#

use strict;
use warnings;
use CPAN;
use Net::FTP;
use Cwd;

my $unsupported = 0;
my $version;
my $rc;
my $pass;
my $pfpass;
my $pfuser = "pf";
my $adminpass;
my $adminuser = "admin";
my $db;
my $updater;
my $mysql_host;
my $mysql_port;
my $mysql_db;

die("Please install to /usr/local/pf and run this script again!\n") if (cwd() ne "/usr/local/pf");

#  check if user is root
die("You must be root to run the installer!\n") if ($< != 0);

open(PFRELEASE,"/usr/local/pf/conf/pf-release");
$version = <PFRELEASE>;
close(PFRELEASE);   
my $pf_release = (split(/\s+/, $version))[1];

my %oses    = ( "Red Hat Enterprise Linux AS release 4" => "RHEL4",
                "Red Hat Enterprise Linux ES release 4" => "RHEL4",
                "White Box Enterprise Linux release 4"  => "RHEL4",
                "CentOS release 4"			=> "RHEL4",
                "CentOS release 5"			=> "RHEL5",
                "Red Hat Enterprise Linux Server release 5" => "RHEL5",
                "Fedora Core release 4"			=> "FC4"
              );

my @modules = ( "Time::HiRes",
                "Config::IniFiles",
                "Net::Netmask",
                "Net::Ping",
                "Date::Parse",
                "Parse::RecDescent",
                "IPTables::IPv4",
                "Net::RawIP",
                "Net::Pcap",
                "CGI",
		"CGI::Session",
                "Term::ReadKey",
                "File::Tail",
                "Net::MAC::Vendor",
                "Net::SNMP",
                "LWP::UserAgent",
                "Net::Telnet::Cisco",
                "Log::Log4perl",
                "Thread::Pool",
                "Apache::Htpasswd",
                "Template"
              );

my @rpms    = ( 
	       "perl-DBD-MySQL",
               "perl",
               "perl-suidperl",
               "httpd",
               "php",
               "libpcap",
	       "gcc",
	       "php-gd",
               "net-snmp"
              );

my @suids   = ( 
               "/usr/local/pf/bin/pfcmd"
              );

my %schemas = ( "5588316d6e053eea32fe73b22ae3bde9" => "1.7.2",
                "5588316d6e053eea32fe73b22ae3bde9" => "1.7.1",
                "37929828877c2328f0146f4c76740fb4" => "1.7.0",
                "8ce4c53fe0700c7d499213015e95f810" => "1.6.0",
                "305de249fd415f181eb990e8cd25863d" => "1.5.1",
                "e997a9969f196762859b9505e08d0459" => "1.5.0",
                "b125feaa50bc9c1fdf591e7c9caabf91" => "1.4.4p1"
              );

my $external_deps = { "jpgraph_v1" => {"url_path"     => "http://hem.bredband.net/jpgraph/",
                                       "file_name"    => "jpgraph-1.26.tar.gz",
                                       "install_path" => "/usr/local/pf/html/admin/common/jpgraph/jpgraph-1.26"},
                      "jpgraph_v2" => {"url_path"     => "http://hem.bredband.net/jpgraph2/",
                                       "file_name"    => "jpgraph-2.3.3.tar.gz",
                                       "install_path" => "/usr/local/pf/html/admin/common/jpgraph/jpgraph-2.3.3"}
                    };

$ENV{'LANG'} = "C";

# can we install RPMs?
if (-e "/etc/redhat-release") {
  open(RHRELEASE,"/etc/redhat-release");
  $version = <RHRELEASE>;
  close(RHRELEASE);
} else {
  $version = "X";
}

my $os_type = supported_os($version);
if (!$os_type) {
  if(questioner("PacketFence has not been tested on your system would you like to continue?","y",("y", "n"))) {
    print " Please enter the full path to your RPM updater: ";
    $updater = <STDIN>;
    chop $updater;
    $unsupported = 1;
    @rpms=();	
  } else {
    exit;
  }
} else {
  if ($os_type eq 'RHEL5') {
    $updater="/usr/bin/yum";
  } else {
    $updater="/usr/sbin/up2date";
  }
}

exit if (!questioner("
DISCLAIMER
By your use of this software, you recognize and agree that this software is
provided 'as is' without warranty of any kind. The authors do not make any
warranties, expressed or implied, including but not limited to implied
warranties of merchantability and fitness for any particular purpose, with
respect to this software.  In no event shall the authors be liable for any
incidental, consequential, or other damages whatsoever (including without
limitation, damages for loss of critical data, loss of profits, interruption
of business, etc) arising out of the use or inability to use this software.
\n\nSorry for the legalese...do you agree?","y",("y", "n"))); 

print "\nPlease not that the ARP-based registration code is currently disabled.\n\n";

if (`cat /proc/modules | grep ^ip_tables` !~ /^ip_tables/) {
  die("IPTables module is not loaded!  Try 'modprobe ip_tables' or /etc/init.d/iptables restart and re-running the installer.\n");
} 


# create pf account
if (!`/usr/bin/getent passwd | grep "^pf:"`) {
  if(questioner("PacketFence prefers to run as user 'pf' - can I create it?","y",("y", "n"))) {
    print "  Creating account\n";
    if (!`/usr/bin/getent group | grep "^pf:"`) {
	   $rc=system("/usr/sbin/groupadd pf");
	   die("Error in creating group!\n") if ($rc);
	}
	$rc=system("/usr/sbin/useradd -g pf pf");
    die("Error in creating user!\n") if ($rc);
    print "  Locking account\n";
    $rc=system("/usr/bin/passwd -l pf");
    die("Error in locking user!\n") if ($rc);
  }
}

if(questioner("Do you plan on using Nessus to scan client systems?","y",("y", "n"))) {
  push @rpms, "openssl-devel";
  print "  You will need to manually (force) install the following Perl modules:\n";
  print "    IO::Socket::SSL\n";
  print "    Net::Nessus::Client\n";
  print "    Net::Nessus::Message\n";
  print "    Net::Nessus::ScanLite\n";
}

my @notfound;

# installing RPMs
foreach my $rpm (@rpms) {
   next if (installed($rpm));
   if ($updater) {
     if (questioner("PF needs $rpm - do you wish to install it?","y",("y", "n"))) {
       if ($updater eq "/usr/bin/yum") {
         $rc=system("$updater -y install $rpm");
       } else {
         $rc=system("$updater $rpm");
       }
       die("Error installing $rpm!\n") if ($rc);
     }
   } else {
     push @notfound,$rpm;
   }
}

if (@notfound){
  print "Please install the following packages before proceeding:\n";
  foreach my $mod (@notfound){
     print "  RPM Module : $mod not found \n";
  }
  exit;
}

if(questioner("PacketFence requires a MySQL server as a backend.  Would you like to install it locally?","y",("y", "n"))) {
  if (!installed("mysql-server")) {
    `$updater mysql-server`;
  } else {
    print "  MySQL server already installed\n";
  }
  print "  (Re)starting MySQL\n";
  my $mysql = `chkconfig --list | grep -i mysql | cut -f1`;
  chop $mysql;
  print `/etc/init.d/$mysql restart`;
  `chkconfig --level 35 $mysql on`;

  $mysql_host = "localhost";
  $mysql_port = "3306";
} else {
  print "  Host [localhost]: ";
  $mysql_host = <STDIN>;
  chop $mysql_host;
  $mysql_host = "localhost" if (!$mysql_host);
  print "  Port [3306]: ";
  $mysql_port = <STDIN>;
  chop $mysql_port;
  $mysql_port = "3306" if (!$mysql_port);
}

print "Database [pf]: ";
$mysql_db = <STDIN>;
chop $mysql_db;
$mysql_db = "pf" if (!$mysql_db);

# build database
my ($times, $denied);
do {
  $denied = 0;
  print "MySQL is reporting access denied, try again\n" if ($times++);
  if (questioner("PF needs to set the MySQL administrator password - is that ok? (answer 'Y' only if this is a new MySQL install)","y",("y", "n"))) {
    my $pass2;
    do {
      print "  Password: ";
      $pass = <STDIN>;
      print "  Confirm: ";
      $pass2 = <STDIN>;
      chop $pass;
      chop $pass2;
    } while ($pass ne $pass2);
    $denied = 1 if (`mysqladmin -u root password '$pass' 2>&1` =~ /Access denied/);
  } else {
    print "  Current Password: ";
    $pass = <STDIN>;
    chop $pass;
    $denied = 1 if (`echo "use pf"|mysql --host=$mysql_host --port=$mysql_port -u root -p'$pass' 2>&1` =~ /Access denied/);
  }
} while ($denied);

my $dropped = 1;
my $upgraded = 0;
my $unknown = 0;

if(`echo "use $mysql_db"|mysql --host=$mysql_host --port=$mysql_port -u root -p'$pass' 2>&1` !~ /Unknown database/) {
  my $md5sum = (split(/\s+/, `/usr/bin/mysqldump --host=$mysql_host --port=$mysql_port -n -d -u root -p'$pass' $mysql_db|egrep -v '^(\/|\$|--|DROP)'|md5sum`))[0];
  if (!$schemas{$md5sum}) {
    print "Unable to determine current schema version!  If you're running a beta release, you'll need to manually update it.\n";
    $unknown = 1;
  } else {
    my $schema_version = $schemas{$md5sum};
    if ($schema_version ne '1.7.1') {
      if (questioner("PF database already exists - do you want to upgrade it?","y",("y", "n"))) {
        my $update_script = "/usr/local/pf/db/upgrade-$schema_version-1.7.1.sql";
        if (-e $update_script) {
          `/usr/bin/mysql --host=$mysql_host --port=$mysql_port -u root -p'$pass' $mysql_db < $update_script`;
          $upgraded = 1;
        } else {
          die "Unable to locate SQL update script for $schema_version -> $pf_release!\n";
        }
      }  elsif (questioner("PF database already exists - do you want to delete it?","y",("y", "n"))) {
        `echo "y" | /usr/bin/mysqladmin --host=$mysql_host --port=$mysql_port -u root -p'$pass' drop $mysql_db`;
      }  else {
        print "  ** NOTE: EXISTING DATABASE MAY NOT BE COMPATIBLE WITH THIS SCHEMA **\n";
        $dropped = 0;
      }
    } else {
      $upgraded = 1;
    }
  }
}

if ($dropped && !$unknown && !$upgraded && questioner("PF needs to create the PF database - is that ok?","y",("y", "n"))) {
  `/usr/bin/mysqladmin --host=$mysql_host --port=$mysql_port -u root -p'$pass' create $mysql_db`;
  print "  Loading schema\n";
  if (-e "/usr/local/pf/db/pfschema.mysql.171") {
    `/usr/bin/mysql --host=$mysql_host --port=$mysql_port -u root -p'$pass' $mysql_db < /usr/local/pf/db/pfschema.mysql.171`
  } else {
    die("Where's my schema?  Nothing at /usr/local/pf/db/pfschema.mysql.171\n");
  }
}

if(questioner("PF needs to create a database user to access the PF database - is that ok?","y",("y", "n"))) {
  if(!questioner("Can I use 'pf' as the username?","y",("y", "n"))) {
    print "Username: ";
    $pfuser = <STDIN>;
    chop $pfuser;
  }
  my $pfpass2;
  do {
    print "  Password: ";
    $pfpass = <STDIN>;
    print "  Confirm: ";
    $pfpass2 = <STDIN>;
    chop $pfpass;
    chop $pfpass2;
  } while ($pfpass ne $pfpass2);
 
   if (!`echo 'GRANT SELECT,INSERT,UPDATE,DELETE,LOCK TABLES ON $mysql_db.* TO "$pfuser"@"%" IDENTIFIED BY "$pfpass"; GRANT SELECT,INSERT,UPDATE,DELETE,LOCK TABLES ON $mysql_db.* TO "$pfuser"@"localhost" IDENTIFIED BY "$pfpass";' | mysql --host=$mysql_host --port=$mysql_port -u root -p'$pass' mysql`)      
  {
    if (`echo "FLUSH PRIVILEGES" | mysql --host=$mysql_host --port=$mysql_port -u root -p'$pass' mysql`) {
      print "ERROR: UNABLE TO FLUSH PRIVILEGES!\n";
    }
    print "  ** NOTE: AFTER RUNNING THE CONFIGURATOR, BE SURE TO CHECK THAT /usr/local/pf/conf/pf.conf\n";
    print "           REFLECTS YOUR MYSQL CONFIGURATION:\n";
    print "    - HOST: $mysql_host\n";
    print "    - PORT: $mysql_port\n";
    print "    - USER: $pfuser\n";
    print "    - PASS: $pfpass\n";
    print "    - DB  : $mysql_db\n";
  } else {
    print "ERROR: UNABLE TO CREATE '$pfuser' DATABASE USER!\n";
  }

} else {
  print "  ** NOTE: THE ROOT MYSQL ACCOUNT WILL BE USED.  THIS IS NOT SECURE! **\n";
}

if (!installed("snort")) {
  print "PF requires snort for several functions (NAT TTL detection, worm detection). Please visit http://www.snort.org/dl/ to download and install Snort.\n";
} else {
  my $snort_version = `rpm -q --qf %{VERSION} snort`;
  #print "You are running Snort 2.6.x, which is incompatible with PacketFence - please downgrade to 2.4.x.\n" if ($snort_version =~ /^2\.6/);
}
print "We encourage the usage of oinkmaster to manage your snort rules. If you don't have it installed yet, please visit http://oinkmaster.sourceforge.net/download.shtml to download oinkmaster. A sample oinkmaster configuration file is provided at /usr/local/pf/contrib/oinkmaster.conf.\n";

# check if modules are installed
if (questioner("PF needs several Perl modules to function properly.  May I download and install them?","y",("y", "n"))) {
  print "Installing perl modules - note that if CPAN has not been run before it may prompt for configuration (just answer 'N')\n";
  foreach my $module (@modules) {
    my $mod = CPAN::Shell->expand("Module",$module);
    if ($mod->inst_file) {
      if (!$mod->uptodate) {
        if (questioner("Module $module is installed (version " . $mod->inst_version . ") but not up to date (CPAN has version " . $mod->cpan_version . ") - do you wish to upgrade it?","y",("y", "n"))) {
          print "    Upgrading module $module\n";
          my $obj = CPAN::Shell->install($module);
        }
      }
    } else {
      if (!$mod->uptodate) {
        if (questioner("Module $module is not installed (CPAN has version " . $mod->cpan_version . ") - do you wish to install it?","y",("y", "n"))) {
          print "    Installing module $module\n";
          my $obj = CPAN::Shell->install($module);
        }
      }
    }
  }
}

# check if external dependencies should be installed
if (questioner("PF needs JPGraph for its administrative Web GUI.  May I download and install it?","y",("y", "n"))) {
  foreach my $name (keys %$external_deps) {
    if ($name =~ /^jpgraph/) {
      my $url = $external_deps->{$name}->{'url_path'} . $external_deps->{$name}->{'file_name'};
      my $local_file_name = '/usr/local/pf/html/admin/common/jpgraph/' . $external_deps->{$name}->{'file_name'};
      `/usr/bin/wget -N $url -P /usr/local/pf/html/admin/common/jpgraph/`;
      `/bin/tar zxvf $local_file_name --strip-components 1 -C $external_deps->{$name}->{'install_path'}`;
    }
  }
}

print "Pre-compiling pfcmd grammar\n";
`/usr/bin/perl -w -e 'use strict; use warnings; use diagnostics; use Parse::RecDescent; use lib "/usr/local/pf/lib"; use pf::pfcmd::pfcmd; Parse::RecDescent->Precompile(\$grammar, "pfcmd_pregrammar");'`;
rename "pfcmd_pregrammar.pm", '/usr/local/pf/lib/pf/pfcmd/pfcmd_pregrammar.pm';

print "Compiling message catalogue (i18n)\n";
my $locale_start_dir = "/usr/local/pf/conf/locale";
opendir(LOCALE_START_DIR, $locale_start_dir) || die "can't open directory $locale_start_dir: $!";
my @locale_dirs = grep { /^[^.]+$/ && -d "$locale_start_dir/$_" && -d "$locale_start_dir/$_/LC_MESSAGES" && -f "$locale_start_dir/$_/LC_MESSAGES/packetfence.po"} readdir(LOCALE_START_DIR);
closedir(LOCALE_START_DIR);
foreach my $locale_dir (@locale_dirs){
  print "  language $locale_dir\n";
  `/usr/bin/msgfmt $locale_start_dir/$locale_dir/LC_MESSAGES/packetfence.po`;
  rename "packetfence.mo", "$locale_start_dir/$locale_dir/LC_MESSAGES/packetfence.mo";
}

if (! (-e '/usr/local/pf/conf/ssl/server.crt')) {
  if (questioner("Would you like me to create a self-signed SSL certificate for the PacketFence web pages?","y",("y", "n"))) {
    `openssl req -x509 -new -nodes  -keyout newkey.pem -out newcert.pem -days 365`;
    `mv newcert.pem /usr/local/pf/conf/ssl/server.crt`;
    `mv newkey.pem /usr/local/pf/conf/ssl/server.key`;
  } else {
    print "You must save your SSL certificates as /usr/local/pf/conf/ssl/server.crt and /usr/local/pf/conf/ssl/server.key before starting PacketFence";
  }
}

if (! (-e '/usr/local/pf/conf/templates/httpd.conf')) {
  print "/usr/local/pf/conf/templates/httpd.conf symlink does not yet exist\n";
  if (`httpd -v` =~ /Apache\/2\.[2-9]\./) {
    print "creating symlink to httpd.conf.apache22\n";
    `ln -s /usr/local/pf/conf/templates/httpd.conf.apache22 /usr/local/pf/conf/templates/httpd.conf`;
  } else {
    print "creating symlink to httpd.conf.pre_apache22\n";
    `ln -s /usr/local/pf/conf/templates/httpd.conf.pre_apache22 /usr/local/pf/conf/templates/httpd.conf`;
  }
}

if (! (-e '/usr/local/pf/conf/templates/local.conf')) {
  print "/usr/local/pf/conf/templates/local.conf symlink does not yet exist\n";
  if (`httpd -v` =~ /Apache\/2\.[2-9]\./) {
    print "creating symlink to local.conf.apache22\n";
    `ln -s /usr/local/pf/conf/templates/local.conf.apache22 /usr/local/pf/conf/templates/local.conf`;
  } else {
    print "creating symlink to local.conf.pre_apache22\n";
    `ln -s /usr/local/pf/conf/templates/local.conf.pre_apache22 /usr/local/pf/conf/templates/local.conf`;
  }
}

if (questioner("Would you like me to create an account for the web administrative interface?\n** NOTE: this will overwrite any existing accounts **","y",("y", "n"))) {
  do {
    print "Username [admin]: ";
    $adminuser = <STDIN>;
    chop $adminuser;
    $adminuser = "admin" if (!$adminuser);
  } while (system("htpasswd -c /usr/local/pf/conf/admin.conf $adminuser"));
}

print "Setting permissions\n";
print "  Chowning /usr/local/pf pf:pf\n";
`chown -R pf:pf /usr/local/pf`;
foreach my $file (@suids) {
  print "  Chowning $file root:root and setting SGID bits\n";
  `chown root:root $file`;
  `chmod 6755 $file`;
}

print "Installation is complete\n** Please run cd /usr/local/pf && ./configurator.pl before starting PacketFence **\n\n\n";

sub questioner {
  my ($query, $response, @choices) = @_;
  my $answer;
  my $choices = join("|", @choices);
  do {
    if (@choices) {
      print "$query [$choices] ";
    } else {
      print "$query: ";
    }
    $answer = <STDIN>;
    $answer =~ s/\s+//g;
  } while ($answer !~ /^($choices)$/i);
  if ($response =~ /^$answer$/i) {
    return(1);
  } else {
    return(0);
  }
}

sub supported_os {
  my ($os) = @_;
  foreach my $supported (keys(%oses)) {
    return($oses{$supported}) if ($os =~ /^$supported/);
  }
  return(0);
}

sub installed {
  my ($rpm) = @_;
  if (`rpm -q $rpm` =~ /not installed/i) {
    return(0);
  } else {
    return(1);
  }
} 
