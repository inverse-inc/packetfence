#!/usr/bin/perl

use Config::IniFiles;

my %ini;

tie %ini, 'Config::IniFiles';

my $pfconf = "/usr/local/pf/conf/pf.conf";

my %inipfconf;
tie %inipfconf, 'Config::IniFiles', ( -file => "$pfconf" );

my $replication_username = $inipfconf{"active_active"}{"galera_replication_username"};
my $replication_password = $inipfconf{"active_active"}{"galera_replication_password"};


print "Enter the MySQL root password: ";
my $mysql_root_password = <STDIN>;
chomp $mysql_root_password;


print "Enter the MySQL master ip address: ";
my $mysql_master_ip = <STDIN>;
chomp $mysql_master_ip;

$output = `sudo mysql -u root -p'$mysql_root_password' -h$mysql_master_ip -e "GRANT REPLICATION SLAVE ON *.*  TO '$replication_username'\@'%'"`;

$output = `sudo mysql -u root -p'$mysql_root_password' -h$mysql_master_ip -e "FLUSH PRIVILEGES"`;

my $position_file = '/var/lib/mysql/xtrabackup_binlog_info';

open(my $fh, '<:encoding(UTF-8)', $position_file)
  or die "Could not open file '$position_file' $!";

my $position;
my $file;
my $gtid;

while (my $row = <$fh>) {
    chomp $row;
    if ($row =~ /^([a-zA-Z0-9_\-\.]+)\s+(\d+)(\s+)?(\d+-\d+-\d+)?$/ ) {
        $file = $1;
        $position = $2;
        if (defined($4)) {
            $gtid = $4;
        }
    }
}

close $fh;

if (!defined($gtid)) {
    @output = `sudo mysql -u $replication_username -p'$replication_password' -h$mysql_master_ip -e "SELECT BINLOG_GTID_POS('$file', $position)\\G"`;

    foreach my $item (@output) {
        if ($item =~ /(\d+-\d+-\d+)$/) {
            $gtid = $1;
        }
    }
}


#Start slave

$output = `sudo mysql -u root -p'$mysql_root_password' -e "SET GLOBAL read_only = OFF"`;
$output = `sudo mysql -u root -p'$mysql_root_password' -e "SET GLOBAL gtid_slave_pos = '$gtid'"`;
$output = `sudo mysql -u root -p'$mysql_root_password' -e "CHANGE MASTER TO MASTER_HOST='$mysql_master_ip', MASTER_PORT=3306, MASTER_USER='$replication_username', MASTER_PASSWORD='$replication_password', MASTER_USE_GTID=slave_pos"`;

$output = `sudo mysql -u root -p'$mysql_root_password' -e "START SLAVE"`;

@output = `sudo mysql -u root -p'$mysql_root_password' -e "select VARIABLE_VALUE from information_schema.GLOBAL_STATUS where VARIABLE_NAME=\'SLAVE_RUNNING\'\\G"`;

sleep 10;

foreach my $item (@output) {
    if ($item =~ /VARIABLE_VALUE:\s+ON\s*/ ) {
        $output = `sudo mysql -u root -p'$mysql_root_password' -e "FLUSH TABLES WITH READ LOCK"`;
        $output = `sudo mysql -u root -p'$mysql_root_password' -e "SET GLOBAL read_only = ON"`;
    }
}

