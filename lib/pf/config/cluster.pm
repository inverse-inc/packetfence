package pf::config::cluster;

use strict;
use warnings;

use Exporter;
our ( @ISA, @EXPORT );
@ISA = qw(Exporter);
@EXPORT = qw($cluster_enabled $multi_zone_enabled $host_id);

use pf::log;
use File::Slurp qw(read_file write_file);
use pf::util;
use pf::file_paths qw($cluster_config_file);
use Config::IniFiles;
use Sys::Hostname;
use pf::constants qw($TRUE $FALSE);
use pf::file_paths qw(
    $config_version_file
);

our $host_id = hostname();

our $multi_zone_enabled = sub {
    my $cfg = cluster_ini_config();
    return $FALSE unless($cfg);
    my $multi_zone = $cfg->val('general', 'multi_zone');
    
    return isenabled($multi_zone);
}->();

our $cluster_enabled = sub {
    return $TRUE if $multi_zone_enabled;

    my $cfg = cluster_ini_config();
    return $FALSE unless($cfg);
    my $mgmt_ip = $cfg->val('CLUSTER', 'management_ip');
    if (defined($mgmt_ip) && valid_ip($mgmt_ip)) {
        return $TRUE;
    }
    else {
        return $FALSE;
    }
}->();

sub cluster_ini_config {
    my $cfg = Config::IniFiles->new( -file => $cluster_config_file );
    return $cfg;
}

=head2 increment_config_version

=cut

sub increment_config_version {
    return set_config_version(time);
}

=head2 set_config_version

Set the configuration version for this server

=cut

sub set_config_version {
    my ($ver) = @_;
    return write_file($config_version_file, $ver);
}

=head2 get_config_version

Get the configuration version for this server

=cut

sub get_config_version {
    my $result;
    eval {
        $result = read_file($config_version_file);
    };
    if($@) {
        get_logger->error("Cannot read $config_version_file to get the current configuration version.");
        return $FALSE;
    }
    return $result;
}


1;
