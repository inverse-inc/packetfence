package pf::lede_config;

use JSON::MaybeXS;
use pf::log;
use LWP::UserAgent;
use pf::constants qw($TRUE $FALSE);

sub reconfigure {
    my ($ip, $ssids_config) = @_;

    my $data = encode_json({ssids => $ssids_config});

    my $ua = LWP::UserAgent->new;
    my $res = $ua->post("http://$ip:5150/configure", Content => $data, "Content-Type" => "application/json");

    if($res->is_success) {
        return $TRUE;
    }
    else {
        get_logger->error("Error while performing configuration of LEDE. ".$res->status_line);
        return $FALSE;
    }
}

1;
