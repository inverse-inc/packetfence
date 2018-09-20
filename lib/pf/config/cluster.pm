package pf::config::cluster;

use strict;
use warnings;

use Exporter;
our ( @ISA, @EXPORT );
@ISA = qw(Exporter);
@EXPORT = qw($cluster_enabled);

use pf::util;
use pf::file_paths qw($cluster_config_file);
use Config::IniFiles;
use Sys::Hostname;
use pf::constants qw($FALSE);
use pf::file_paths qw(
    $config_version_file
);

our $host_id = hostname();

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
