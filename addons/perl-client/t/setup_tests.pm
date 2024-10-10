package setup_tests;

use strict;
use warnings;

use List::MoreUtils qw(any);

use data::seed;
use fingerbank::FilePath qw($INSTALL_PATH %SCHEMA_DBS);
use fingerbank::Util qw(is_success);
use fingerbank::Model::DHCP_Fingerprint;
use fingerbank::Model::DHCP_Vendor;
use fingerbank::Model::User_Agent;
use fingerbank::Model::DHCP6_Fingerprint;
use fingerbank::Model::DHCP6_Enterprise;
use fingerbank::Model::MAC_Vendor;
use fingerbank::Model::Device;
use fingerbank::Model::Combination;

use fingerbank::Log;
fingerbank::Log->init_logger();

sub setup_test_database {
    my ($schema, $path) = @_;
    $SCHEMA_DBS{$schema} = $path;
    unlink $SCHEMA_DBS{$schema};
    my $cmd = "db/upgrade.pl --database ".$SCHEMA_DBS{$schema};
    print `$cmd`;
}

sub seed_local_database {
    my @results;
    while(my ($class, $data) = each %data::seed::elements){
        my $i = 0;
        foreach my $info (@$data){
            push @results, [ "$class$i", "fingerbank::Model::$class"->create($info) ];
        }
    }
    foreach my $result (@results){
        unless(is_success($result->[1])){
            die "Can't create ".$result->[0]." (".$result->[1]."), ".$result->[2];
        }
    }
}

sub seed_upstream_database {
    my @results;
    my $cmd = "sqlite3 ".$SCHEMA_DBS{Upstream}." < t/data/upstream.sql";
    print `$cmd`;
}

sub import {
    my ($package, @flags) = @_;
    $fingerbank::FilePath::CONF_FILE = "$INSTALL_PATH/t/data/fingerbank.conf";
    setup_test_database("Local", $INSTALL_PATH."db/fingerbank_Local_Test.db");
    setup_test_database("Upstream", $INSTALL_PATH."db/fingerbank_Upstream_Test.db");
    if(any {$_ eq "-seed"} @flags){
        seed_local_database();
        seed_upstream_database();
    }
}



1;
