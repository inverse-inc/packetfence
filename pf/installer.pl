#!/usr/bin/perl

=head1 NAME

installer.pl - install PacketFence and dependencies

=head1 USAGE

  cd /usr/local/pf && ./installer.pl

Then answer the questions ...

=head1 DESCRIPTION

installer.pl will help you with the following tasks:

=over

=item * creation of the C<pf> user

=item * creation of the database and database user

=item * installation of Perl module dependencies

=item * installation of JPGraph

=item * update of DHCP fingerprints to latest version

=item * update of OUI prefixes to the latest version

=item * compilation of pfcmd grammar

=item * compilation of message catalogue (i18n)

=item * creation of a self-signed SSL certificate

=item * account creation for the Web Admin GUI

=item * installation of the PHP Pear Log package

=item * permissions and ownerships of files in F</usr/local/pf>

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

#  check if user is root
die("You must be root to run the installer!\n") if ( $< != 0 );

my $pfrelease_fh;
open( $pfrelease_fh, '<', "$conf_dir/pf-release" );
$version = <$pfrelease_fh>;
close($pfrelease_fh);
my $pf_release = ( split( /\s+/, $version ) )[1];

my %snort_rules_version = (
    "RHEL5" => "snort-2.8.6",
    "RHEL6" => "snort-2.9.0",
    "latest" => "snort-2.9.0",
);

my %oses = (
    "CentOS release 5" => "RHEL5",
    "Red Hat Enterprise Linux Server release 5" => "RHEL5",
    "CentOS Linux release 6" => "RHEL6",
    "CentOS release 6" => "RHEL6",
    "Red Hat Enterprise Linux Server release 6" => "RHEL6",
);

my @suids = ( "$install_dir/bin/pfcmd" );

$ENV{'LANG'} = "C";

# can we install RPMs?
if ( -e "/etc/redhat-release" ) {
    my $rhrelease_fh;
    open( $rhrelease_fh, '<', "/etc/redhat-release" );
    $version = <$rhrelease_fh>;
    close($rhrelease_fh);
} else {
    $version = "X";
}

my $os_type = supported_os($version);
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

print
    "\nPlease note that the ARP-based registration code is currently disabled.\n\n";

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
            print "Perhaps you did not configure mysql with /usr/bin/mysql_secure_installation?\n";
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

# TODO: au démarrage de PF, créer les logs si les fichiers n'existent pas
# et supprimer cette section
print "Creating empty log files\n";
`touch $install_dir/logs/packetfence.log`;
`touch $install_dir/logs/snmptrapd.log`;
`touch $install_dir/logs/access_log`;
`touch $install_dir/logs/error_log`;
`touch $install_dir/logs/admin_access_log`;
`touch $install_dir/logs/admin_error_log`;
`touch $install_dir/logs/admin_debug_log`;
`touch $install_dir/logs/pfdetect`;
`touch $install_dir/logs/pfmon`;
`touch $install_dir/logs/pfredirect`;

print "Setting permissions\n";
print "  Chowning $install_dir pf:pf\n";
`chown -R pf:pf $install_dir`;
foreach my $file (@suids) {
    print "  Chowning $file root:root and setting SGID bits\n";
    `chown root:root $file`;
    `chmod 6755 $file`;
}

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
    my ($os) = @_;
    foreach my $supported ( keys(%oses) ) {
        return ( $oses{$supported} ) if ( $os =~ /^$supported/ );
    }
    return (0);
}

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

Copyright (C) 2007-2011 Inverse inc.

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

