#!/usr/bin/perl

use Config::IniFiles;

my %ini;

tie %ini, 'Config::IniFiles';

print "Enter the MySQL root password: ";
my $mysql_root_password = <STDIN>;
chomp $mysql_root_password;


print "Enter the MySQL replication username: ";
my $replication_user = <STDIN>;
chomp $replication_user;

print "Enter the MySQL replication password: ";
my $replication_password = <STDIN>;
chomp $replication_password;

print "Enter the MySQL master ip address: ";
my $mysql_master_ip = <STDIN>;
chomp $mysql_master_ip;

print "Enter the pfconfig table name: ";
my $pfconfig_table = <STDIN>;
chomp $pfconfig_table;

$output = `sudo mysql -u root -p'$mysql_root_password' -e "CREATE USER IF NOT EXISTS '$replication_user'\@'%' IDENTIFIED BY '$replication_password'"`;

$output = `sudo mysql -u root -p'$mysql_root_password' -e "SET PASSWORD FOR '$replication_user'\@'%' = PASSWORD('$replication_password')"`;

$output = `sudo mysql -u root -p'$mysql_root_password' -e "GRANT REPLICATION SLAVE ON *.*  TO '$replication_user'\@'%'"`;

$output = `sudo mysql -u root -p'$mysql_root_password' -e "FLUSH PRIVILEGES"`;

$output = `sudo mysql -u root -p'$mysql_root_password' pf -e "CREATE TABLE IF NOT EXISTS $pfconfig_table ( id VARCHAR(255),  value LONGBLOB,  PRIMARY KEY(id)) ENGINE=InnoDB"`;

#$output = `sudo mysql -u root -p'$mysql_root_password' -e "set global wsrep_desync=ON"`;




$output = `sudo systemctl stop packetfence-mariadb`;

my $pfconf = "/usr/local/pf/conf/pf.conf";
my $pfconfigconf = "/usr/local/pf/conf/pfconfig.conf";

my %inipfconf;
tie %inipfconf, 'Config::IniFiles', ( -file => "$pfconf" );

my %inipfconfigconf;
tie %inipfconfigconf, 'Config::IniFiles', ( -file => "$pfconfigconf" );

$inipfconf{"database"}{"host"} = '127.0.0.1';

$inipfconfigconf{"mysql"}{"host"} = '127.0.0.1';
$inipfconfigconf{"mysql"}{"table"} = $pfconfig_table;

my $galera_replication_username = $inipfconf{"active_active"}{"galera_replication_username"};
my $galera_replication_password = $inipfconf{"active_active"}{"galera_replication_password"};

@output = `sudo mysql -u $galera_replication_username -p'$galera_replication_password' -h$mysql_master_ip -e "SHOW MASTER STATUS\\G"`;

my $position;
my $file;

foreach my $item (@output) {
    if ($item =~ /\s+Position:\s+(\d+)\s+/ ) {
        $position = $1;
    }
    if ($item =~ /\s+File:\s+([a-zA-Z0-9_\-\.]+)\s+/ ) {
        $file = $1;
    }
}

print "Position: $position";
print "File: $file";

@output = `sudo mysql -u $galera_replication_username -p'$galera_replication_password' -h$mysql_master_ip -e "SELECT BINLOG_GTID_POS('$file', $position)\\G"`;

my $gtid;

foreach my $item (@output) {
    if ($item =~ /(\d+-\d+-\d+)$/) {
        $gtid = $1;
    }
}

print $gtid;


tied( %inipfconf )->RewriteConfig($pfconf);
tied( %inipfconfigconf )->RewriteConfig($pfconfigconf);

#Restart pfconfig to use 127.0.0.1
$output = `systemctl restart packetfence-config`;
$output = `/usr/local/pf/bin/pfcmd configreload hard`;


$inipfconf{"database_advanced"}{"masterslave"} = "ON";
$inipfconf{"database_advanced"}{"masterslavemode"} = "SLAVE";

tied( %inipfconf )->RewriteConfig($pfconf);

$output = `/usr/local/pf/bin/pfcmd configreload hard`;
$output = `/usr/local/pf/bin/pfcmd generatemariadbconfig`;

$output = `sudo systemctl restart packetfence-mariadb`;

#Start slave

$output = `sudo mysql -u root -p'$mysql_root_password' -e "SET GLOBAL gtid_slave_pos = '$gtid'"`;
$output = `sudo mysql -u root -p'$mysql_root_password' -e "CHANGE MASTER TO MASTER_HOST='$mysql_master_ip', MASTER_PORT=3306, MASTER_USER='$replication_user', MASTER_PASSWORD='$replication_password', MASTER_USE_GTID=slave_pos"`;

$output = `sudo mysql -u root -p'$mysql_root_password' -e "START SLAVE"`;

@output = `sudo mysql -u root -p'$mysql_root_password' -e "select VARIABLE_VALUE from information_schema.GLOBAL_STATUS where VARIABLE_NAME=\'SLAVE_RUNNING\'\\G"`;

sleep 10;

foreach my $item (@output) {
    print $item."\n";
    if ($item =~ /VARIABLE_VALUE:\s+ON\s*/ ) {
        $inipfconf{"database_advanced"}{"readonly"} = "ON";
        tied( %inipfconf )->RewriteConfig($pfconf);

        $output = `/usr/local/pf/bin/pfcmd configreload hard`;
        $output = `/usr/local/pf/bin/pfcmd generatemariadbconfig`;

        $output = `sudo systemctl restart packetfence-mariadb`;

        print "Slave connected";
    }
}

