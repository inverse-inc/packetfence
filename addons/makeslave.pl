#!/usr/bin/perl


BEGIN {
    # log4perl init
    use constant INSTALL_DIR => '/usr/local/pf';
    use lib (INSTALL_DIR . "/lib", INSTALL_DIR . "/lib_perl/lib/perl5");
}

use lib qw(/usr/local/pf/lib /usr/local/pf/lib_perl/lib/perl5);
use Config::IniFiles;
use pf::file_paths qw($pf_config_file);

my %ini;

tie %ini, 'Config::IniFiles';

my %inipfconf;
tie %inipfconf, 'Config::IniFiles', ( -file => "$pf_config_file" );

my $replication_username = $inipfconf{"active_active"}{"galera_replication_username"};
my $replication_password = $inipfconf{"active_active"}{"galera_replication_password"};

if ($replication_username eq "" | $replication_password eq "") {
    die "replication information is missing, check your galera_replication_username or galera_replication_password configuration parameters";
}

print "Enter the MySQL root password: ";
my $mysql_root_password = <STDIN>;
chomp $mysql_root_password;

print "Enter the MySQL master IP address: ";
my $mysql_master_ip = <STDIN>;
chomp $mysql_master_ip;

if ($mysql_master_ip !~ /(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/) {
    die "wrong ip address format";
}

my $position_file = '/root/backup/restore/xtrabackup_binlog_info';

open(my $fh, '<:encoding(UTF-8)', $position_file)
  or die "Could not open file '$position_file' your backup does not contain the binary log position file.";

my $position;
my $file;
my $gtid;

while (my $row = <$fh>) {
    chomp $row;
    if ($row =~ /^([a-zA-Z0-9_\-\.]+)\s+(\d+)(\s+)?((\d+-\d+-\d+)?(,(\d+-\d+-\d+))?)?$/ ) {
        $file = $1;
        $position = $2;
        if (defined($4)) {
            $gtid = $4;
        }
    } else {
        die "unable to find the position in the binary log, check if the file /var/lib/mysql/xtrabackup_binlog_info contains the correct information";
    }
}

close $fh;

if (!defined($gtid)) {
    @output = `sudo mysql -u $replication_username -p'$replication_password' -h$mysql_master_ip -e "SELECT BINLOG_GTID_POS('$file', $position)\\G"`;

    foreach my $item (@output) {
        if ($item =~ /((\d+-\d+-\d+)?(,(\d+-\d+-\d+))?)$/) {
            $gtid = $1;
        }
    }
}


#Start slave

$output = `sudo mysql -u root -p'$mysql_root_password' -e "SET GLOBAL read_only = OFF"`;
if ($?) {
    die "Unable to set the local database in read write mode";
}

$output = `sudo mysql -u root -p'$mysql_root_password' -e "SET GLOBAL gtid_slave_pos = '$gtid'"`;

if ($?) {
    die "Unable to set the gtid_slave_pos in the database";
}


$output = `sudo mysql -u root -p'$mysql_root_password' -e "CHANGE MASTER TO MASTER_HOST='$mysql_master_ip', MASTER_PORT=3306, MASTER_USER='$replication_username', MASTER_PASSWORD='$replication_password', MASTER_USE_GTID=slave_pos"`;

if ($?) {
    die "Unable to configure the master server";
}


$output = `sudo mysql -u root -p'$mysql_root_password' -e "START SLAVE"`;

if ($?) {
    die "Unable to start the slave mode";
}

my $break = 0;

while (1) {
    @output = `sudo mysql -u root -p'$mysql_root_password' -e "select VARIABLE_VALUE from information_schema.GLOBAL_STATUS where VARIABLE_NAME=\'SLAVE_RUNNING\'\\G"`;

    foreach my $item (@output) {
        if ($item =~ /VARIABLE_VALUE:\s+ON\s*/ ) {
            $output = `sudo mysql -u root -p'$mysql_root_password' -e "FLUSH TABLES WITH READ LOCK"`;
            $output = `sudo mysql -u root -p'$mysql_root_password' -e "SET GLOBAL read_only = ON"`;
            if ($?) {
                die "Unable to set the database in readonly mode";
            }
            $break = 1;
        }
    }
    if ($break) {
        last;
    }
    sleep 10;
}

