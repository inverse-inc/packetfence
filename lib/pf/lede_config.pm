package pf::lede_config;

use JSON::MaybeXS;
use pf::log;
use LWP::UserAgent;
use pf::constants qw($TRUE $FALSE);

sub reconfigure {
    my ($ip, $ssids_config) = @_;

    my $data = encode_json({ssids => $ssids_config});

    my $ua = LWP::UserAgent->new;
    my $res = $ua->post(lede_uri($ip, 5150), Content => $data, "Content-Type" => "application/json");

    if($res->is_success) {
        return $TRUE;
    }
    else {
        get_logger->error("Error while performing configuration of LEDE. ".$res->status_line);
        return $FALSE;
    }
}

sub lede_uri {
    my ($ip, $port) = @_;
    $port ||= 5150;
    return "http://$ip:$port/configure";
}

1;
