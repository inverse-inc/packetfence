package pf::config::cluster;

use strict;
use warnings;

use pf::util;
use pf::file_paths qw($cluster_config_file);
use Config::IniFiles;

our $cluster_enabled = sub {
    my $cfg = Config::IniFiles->new( -file => $cluster_config_file );
    return 0 unless($cfg);
    my $mgmt_ip = $cfg->val('CLUSTER', 'management_ip');
    my $multi_cluster = $cfg->val('general', 'multi_cluster');
    use Data::Dumper; print Dumper($cfg->Groups);
    if (defined($mgmt_ip) && valid_ip($mgmt_ip)) {
        return 1;
    }
    elsif (isenabled($multi_cluster)) {
        return 1;
    }
    else {
        return 0;
    }
}->();


1;
