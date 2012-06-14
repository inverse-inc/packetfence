#!/usr/bin/perl

=head1 NAME

installer.pl - install PacketFence and dependencies

=head1 USAGE

  cd /usr/local/pf && ./installer.pl

=head1 SYNOPSIS

installer.pl [postinst PATH]

=head1 DESCRIPTION

installer.pl without any options will help you with the following tasks:

=over

=item * installation of Perl module dependencies

=item * update of DHCP fingerprints to latest version

=item * update of OUI prefixes to the latest version

=item * downloading snort rules

=item * compilation of pfcmd grammar

=item * compilation of message catalogue (i18n)

=item * creation of the empty directories required and not in source tarball

=item * permissions and ownerships of files in F</usr/local/pf>

=back

installer.pl postinst:

=over

=item * creation of empty log files required for PacketFence operation

=back

=head1 DEPENDENCIES

=over

=item * FindBin

=item * Term::ReadKey

=back

=cut

use strict;
use warnings;

use FindBin;
use Term::ReadKey;

my $unsupported = 0;
my $version;
my $rc;
my $mysqlAdminUser;
my $mysqlAdminPass;
my $pfpass;
my $pfuser = "pf";
my $adminpass;
my $adminuser = "admin";
my $db;
my $mysql_host;
my $mysql_port;
my $mysql_db;

my $install_dir = $FindBin::Bin;
my $conf_dir    = "$install_dir/conf";

if ($ARGV[0] eq 'postint') {
    die 'You must specify destination path' if (!defined($ARGV[1]));
    installer::postint($ARGV[1]);
    exit;
}

#  check if user is root
die("You must be root to run the installer!\n") if ( $< != 0 );

my %snort_rules_version = (
    "RHEL5" => "snort-2.8.6",
    "RHEL6" => "snort-2.9.0",
    "latest" => "snort-2.9.0",
    "SQUEEZE" => "snort-2.8.4",
);

my %oses = (
    "CentOS release 5" => "RHEL5",
    "Red Hat Enterprise Linux Server release 5" => "RHEL5",
    "CentOS Linux release 6" => "RHEL6",
    "CentOS release 6" => "RHEL6",
    "Red Hat Enterprise Linux Server release 6" => "RHEL6",
    "6" => "SQUEEZE",
);

my @suids = ( "$install_dir/bin/pfcmd" );

$ENV{'LANG'} = "C";

my $os_type = supported_os();
if ( !$os_type ) {
    if (questioner(
            "PacketFence has not been tested on your system would you like to continue?",
            "y",
            ( "y", "n" )
        )
        )
    {
        $unsupported = 1;
        $os_type = 'latest';
    } else {
        exit;
    }
}

exit
    if (
    !questioner( "
DISCLAIMER
By your use of this software, you recognize and agree that this software is
provided 'as is' without warranty of any kind. The authors do not make any
warranties, expressed or implied, including but not limited to implied
warranties of merchantability and fitness for any particular purpose, with
respect to this software.  In no event shall the authors be liable for any
incidental, consequential, or other damages whatsoever (including without
limitation, damages for loss of critical data, loss of profits, interruption
of business, etc) arising out of the use or inability to use this software.
\n\nSorry for the legalese...do you agree?", "y", ( "y", "n" ) )
    );

# create pf account
if ( !`/usr/bin/getent passwd | grep "^pf:"` ) {
    if (questioner(
            "PacketFence prefers to run as user 'pf' - can I create it?",
            "y", ( "y", "n" )
        )
        )
    {
        print "  Creating account\n";
        if ( !`/usr/bin/getent group | grep "^pf:"` ) {
            $rc = system("/usr/sbin/groupadd pf");
            die("Error in creating group!\n") if ($rc);
        }
        $rc = system("/usr/sbin/useradd -g pf pf");
        die("Error in creating user!\n") if ($rc);
        print "  Locking account\n";
        $rc = system("/usr/bin/passwd -l pf");
        die("Error in locking user!\n") if ($rc);
    }
}

if (questioner(
        "PacketFence requires a MySQL server as a backend.  Would you like to create or verify the database now?",
        "y",
        ( "y", "n" )
    )
    )
{
    print "  MySQL Host [localhost]: ";
    $mysql_host = <STDIN>;
    chop $mysql_host;
    $mysql_host = "localhost" if ( !$mysql_host );
    print "  MySQL Port [3306]: ";
    $mysql_port = <STDIN>;
    chop $mysql_port;
    $mysql_port = "3306" if ( !$mysql_port );

    print "Database Name [pf]: ";
    $mysql_db = <STDIN>;
    chop $mysql_db;
    $mysql_db = "pf" if ( !$mysql_db );

    my $times  = 0;
    my $is_mysql_accessible;
    do {
        if ( $times > 0 ) {
            print "MySQL is reporting access denied or can't connect, try again\n";
            print "Perhaps you did not configure mysql with /usr/bin/mysql_secure_installation (start mysqld first!)?\n";
        }
        $times++;
        print "  Current Admin User [root]: ";
        $mysqlAdminUser = <STDIN>;
        chop $mysqlAdminUser;
        $mysqlAdminUser = "root" if ( !$mysqlAdminUser );
        print "  Current Admin Password: ";
        ReadMode('noecho');
        chomp($mysqlAdminPass = ReadLine(0));
        ReadMode('restore');
        print "\n";
        if ($mysqlAdminPass =~ /^$/) {
            print "Please set a proper root password for your MySQL instance. Exiting\n";
            print "Perhaps you did not configure mysql with /usr/bin/mysql_secure_installation?\n";
            exit 1;
        }
        $is_mysql_accessible = 
            `echo "use pf"|mysql --host=$mysql_host --port=$mysql_port -u $mysqlAdminUser -p'$mysqlAdminPass' 2>&1`;
    } while ($is_mysql_accessible =~ /Access denied|Can't connect/);

    my $exists = 0;

    if (`echo "use $mysql_db"|mysql --host=$mysql_host --port=$mysql_port -u $mysqlAdminUser -p'$mysqlAdminPass' 2>&1`
        !~ /Unknown database/ ) {

        print "\n";
        print "PF database already exists - If you are upgrading your installation make sure you read the UPGRADE "
            . "document to be aware of changes affecting your upgrade and instructions to ugprade your database "
            . "(if required).\n";
        print "\n";
        $exists = 1;
    }

    if (!$exists && questioner("PF needs to create the PF database - is that ok?", "y", ("y", "n"))) {

        # create the database
        `/usr/bin/mysqladmin --host=$mysql_host --port=$mysql_port -u $mysqlAdminUser -p'$mysqlAdminPass' create $mysql_db`;
        print "  Loading schema\n";
        if ( -e "$install_dir/db/pf-schema.sql" ) {
            `/usr/bin/mysql --host=$mysql_host --port=$mysql_port -u $mysqlAdminUser -p'$mysqlAdminPass' $mysql_db < $install_dir/db/pf-schema.sql`;
        } else {
            die("Where's my schema?  Nothing at $install_dir/db/pf-schema.sql\n"
            );
        }
    }

    if (questioner(
            "Do you want to create a database user to access the PF database now?",
            "y",
            ( "y", "n" )
        )
        )
    {
        print "Username [pf]: ";
        $pfuser = <STDIN>;
        chop $pfuser;
        $pfuser = 'pf' if ( !$pfuser );
        my $pfpass2;
        do {
            print "  Password: ";
            ReadMode('noecho');
            chomp($pfpass = ReadLine(0));
            print "\n";
            print "  Confirm: ";
            chomp($pfpass2 = ReadLine(0));
            print "\n";
            ReadMode('restore');
        } while ( $pfpass ne $pfpass2 );

        if (!`echo 'GRANT SELECT,INSERT,UPDATE,DELETE,EXECUTE,LOCK TABLES ON $mysql_db.* TO "$pfuser"@"%" IDENTIFIED BY "$pfpass"; GRANT SELECT,INSERT,UPDATE,DELETE,EXECUTE,LOCK TABLES ON $mysql_db.* TO "$pfuser"@"localhost" IDENTIFIED BY "$pfpass";' | mysql --host=$mysql_host --port=$mysql_port -u $mysqlAdminUser -p'$mysqlAdminPass' mysql`
            )
        {
            if (`echo "FLUSH PRIVILEGES" | mysql --host=$mysql_host --port=$mysql_port -u $mysqlAdminUser -p'$mysqlAdminPass' mysql`
                )
            {
                print "ERROR: UNABLE TO FLUSH PRIVILEGES!\n";
            }
            print
                "  ** NOTE: AFTER RUNNING THE CONFIGURATOR, BE SURE TO CHECK THAT $conf_dir/pf.conf\n";
            print "           REFLECTS YOUR MYSQL CONFIGURATION:\n";
            print "    - HOST: $mysql_host\n";
            print "    - PORT: $mysql_port\n";
            print "    - USER: $pfuser\n";
            print "    - PASS: $pfpass\n";
            print "    - DB  : $mysql_db\n";
        } else {
            print "ERROR: UNABLE TO CREATE '$pfuser' DATABASE USER!\n";
        }
    }

}

print "Pre-compiling pfcmd grammar\n";
`/usr/bin/perl -w -e 'use strict; use warnings; use Parse::RecDescent; use lib "$install_dir/lib"; use pf::pfcmd::pfcmd; Parse::RecDescent->Precompile(\$grammar, "pfcmd_pregrammar");'`;
rename "pfcmd_pregrammar.pm", "$install_dir/lib/pf/pfcmd/pfcmd_pregrammar.pm";

print "Compiling message catalogue (i18n)\n";
my $locale_start_dir = "$conf_dir/locale";
opendir( LOCALE_START_DIR, $locale_start_dir )
    || die "can't open directory $locale_start_dir: $!";
my @locale_dirs = grep {
           /^[^.]+$/
        && -d "$locale_start_dir/$_"
        && -d "$locale_start_dir/$_/LC_MESSAGES"
        && -f "$locale_start_dir/$_/LC_MESSAGES/packetfence.po"
} readdir(LOCALE_START_DIR);
closedir(LOCALE_START_DIR);
foreach my $locale_dir (@locale_dirs) {
    print "  language $locale_dir\n";
    `/usr/bin/msgfmt $locale_start_dir/$locale_dir/LC_MESSAGES/packetfence.po`;
    rename "packetfence.mo",
        "$locale_start_dir/$locale_dir/LC_MESSAGES/packetfence.mo";
}

if ( !( -e "$conf_dir/httpd.conf" ) ) {
    print "$conf_dir/httpd.conf symlink does not yet exist\n";

    print "creating symlink to httpd.conf.apache22\n";
    `ln -s $conf_dir/httpd.conf.apache22 $conf_dir/httpd.conf`;
}

if ( !( -e "$conf_dir/named.conf" ) ) {
    print "$conf_dir/named.conf symlink does not yet exist\n";

    if ( `/usr/sbin/named -v | grep "^BIND 9.[7-9]"` ) {
        print "creating symlink to named.conf.bind97\n";
        `ln -s $conf_dir/named.conf.bind97 $conf_dir/named.conf`;
    } else {
        print "creating symlink to named.conf.pre_bind97\n";
        `ln -s $conf_dir/named.conf.pre_bind97 $conf_dir/named.conf`;
    }
}

if ( !( -e "$conf_dir/ssl/server.crt" ) ) {
    if (questioner(
            "Would you like me to create a self-signed SSL certificate for the PacketFence web pages?",
            "y",
            ( "y", "n" )
        )
        )
    {
        `openssl req -x509 -new -nodes  -keyout newkey.pem -out newcert.pem -days 365`;
        `mv newcert.pem $conf_dir/ssl/server.crt`;
        `mv newkey.pem $conf_dir/ssl/server.key`;
    } else {
        print
            "You must save your SSL certificates as $conf_dir/ssl/server.crt and $conf_dir/ssl/server.key before starting PacketFence";
    }
}

# TODO: créer un compte par défaut et ajouter une section dans la doc qui dit:
# 1) c koi le pwd par défaut de admin
# 2) comment maj le pwd de admin ou mieux: rajouter une section dans l'interface web pour maj le pwd de admin
# et supprimer cette section
if (questioner(
        "Would you like me to create an account for the web administrative interface?\n** NOTE: this will overwrite any existing accounts **",
        "y",
        ( "y", "n" )
    )
    )
{
    do {
        print "Username [admin]: ";
        $adminuser = <STDIN>;
        chop $adminuser;
        $adminuser = "admin" if ( !$adminuser );
    } while ( system("htpasswd -d -c $conf_dir/admin.conf $adminuser") );
}

# TODO: ajouter une section dans la doc qui explique comment télécharger ces fichiers
# et supprimer cette section
if (questioner(
        "Do you want me to download the latest Emergingthreats rule files ?"
        . " This is only necessary if you intent to use Snort.",
        "y", ( "y", "n" )
    )
    )
{
    my @rule_files = (
        'emerging-botcc.rules',
        'emerging-attack_response.rules',
        'emerging-exploit.rules',
        'emerging-malware.rules',
        'emerging-p2p.rules',
        'emerging-scan.rules',
        'emerging-shellcode.rules',
        'emerging-trojan.rules',
        'emerging-virus.rules',
        'emerging-worm.rules'
    );
    foreach my $current_rule_file (@rule_files) {
        `/usr/bin/wget -N http://rules.emergingthreats.net/open/$snort_rules_version{$os_type}/rules/$current_rule_file -P $conf_dir/snort`;
    }
}

# TODO: ajouter une section dans la doc pour MAJ les fingerprints
# et supprimer cette section
if (questioner(
        "Do you want me to update the DHCP fingerprints to the latest available version ?",
        "y",
        ( "y", "n" )
    )
    )
{
    `/usr/bin/wget -N http://www.packetfence.org/dhcp_fingerprints.conf -P $conf_dir`;
}

# TODO: ajouter une section dans la doc pour MAJ les OUI
# et supprimer cette section
if (questioner(
        "Do you want me to update the OUI prefixes to the latest available version ?",
        "y",
        ( "y", "n" )
    )
    )
{
    `/usr/bin/wget -N http://standards.ieee.org/regauth/oui/oui.txt -P $conf_dir`;
}

print "Creating required directories (you can safely ignore 'already exists' notices)\n";
installer::create_empty_directories($install_dir);

print "Creating empty log files\n";
installer::create_empty_log_files($install_dir);

print "Setting permissions\n";
print "  Chowning $install_dir pf:pf\n";
`chown -R pf:pf $install_dir`;
foreach my $file (@suids) {
    print "  Chowning $file root:root and setting SGID bits\n";
    `chown root:root $file`;
    `chmod 6755 $file`;
}

# TODO change that
print
    "Installation is complete\n** Please run $install_dir/configurator.pl before starting PacketFence **\n\n\n";

sub questioner {
    my ( $query, $response, @choices ) = @_;
    my $answer;
    my $choices = join( "|", @choices );
    do {
        if (@choices) {
            print "$query [$choices] ";
        } else {
            print "$query: ";
        }
        $answer = <STDIN>;
        $answer =~ s/\s+//g;
    } while ( $answer !~ /^($choices)$/i );
    if ( $response =~ /^$answer$/i ) {
        return (1);
    } else {
        return (0);
    }
}

sub supported_os {

    # RedHat and derivatives
    if ( -e "/etc/redhat-release" ) {
        my $rhrelease_fh;
        open( $rhrelease_fh, '<', "/etc/redhat-release" );
        $version = <$rhrelease_fh>;
        close($rhrelease_fh);
    } 
    # Debian and derivatives
    elsif (-e "/etc/debian_version" ) {
        my $debianversion;
        open( $debianversion, '<', "/etc/debian_version" );
        $version = <$debianversion>;
        close($debianversion);
    }
    # Unknown
    else {
        $version = "X";
    }

    foreach my $supported ( keys(%oses) ) {
        return ( $oses{$supported} ) if ( $version =~ /^$supported/ );
    }
    return (0);
}

=head1 SUBROUTINES

=over

=cut
package installer;

sub create_empty_directories {
    my ($root_dir) = @_;
    `mkdir -p $root_dir/conf/ssl $root_dir/conf/users $root_dir/html/admin/mrtg $root_dir/html/admin/traplog $root_dir/html/admin/scan/results $root_dir/logs $root_dir/var/conf $root_dir/var/dhcpd $root_dir/var/named $root_dir/var/run $root_dir/var/rrd $root_dir/var/session $root_dir/var/webadmin_cache`;
}

sub postinst {
    my ($root_dir) = @_;
    create_empty_log_files($root_dir);
}

=item create_empty_log_files

Create log files in a way that PacketFence will start. Files must exist and
be owned by pf:pf.

If the files already exists they won't be re-created or deleted.

=cut
sub create_empty_log_files {
    my ($root_dir) = @_;
    my @logfiles = qw(
        packetfence.log
        snmptrapd.log
        access_log error_log
        admin_access_log admin_error_log admin_debug_log
        pfdetect pfmon pfredirect
    );
    print "Creating log files if they don't already exist\n";
    foreach my $file (@logfiles) {
        print "...$file\n";
        `touch $root_dir/logs/$file`;
    }
    print "Setting log file ownership\n";
    `chown -R pf:pf $root_dir/logs`;
}

=back

=head1 SEE ALSO

L<configurator.pl>

=head1 AUTHOR

Dave Laporte <dave@laportestyle.org>

Kevin Amorin <kev@amorin.org>

Dominik Gehl <dgehl@inverse.ca>

Olivier Bilodeau <obilodeau@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005 Dave Laporte

Copyright (C) 2005 Kevin Amorin

Copyright (C) 2007-2012 Inverse inc.

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

