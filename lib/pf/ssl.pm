package pf::ssl;

use strict;
use warnings;

use pf::constants qw($TRUE $FALSE);
use File::Slurp qw(write_file);
use LWP::UserAgent;
use pf::util;
use pf::log;

use Crypt::OpenSSL::X509;
use Crypt::OpenSSL::PKCS12;

sub x509_from_string {
    my ($cert) = @_;
   
    my %encodings = (
        PEM => Crypt::OpenSSL::X509::FORMAT_PEM, 
        ASN1 => Crypt::OpenSSL::X509::FORMAT_ASN1,
    );

    while(my ($encoding_str, $encoding) = each(%encodings)) {
        my $x509;
        eval {
            $x509 = Crypt::OpenSSL::X509->new_from_string($cert, $encoding);
        };
        if($@) {
            get_logger->info("Certificate is not $encoding_str encoded. Trying next encoding.");
        }
        else {
            return $x509;
        }
    }

    get_logger->warn("Certificate cannot be decoded with known encodings: ".join(", ", keys(%encodings)));
    return undef;
}

sub cn_from_dn {
    my ($dn) = @_;
    if($dn =~ /CN=(.*?)(\/|$)/) {
        return $1; 
    }
    else {
        get_logger->error("Unable to extract CN from DN");
        return undef;
    }
}

sub validate_cert_key_match {

}

sub fetch_all_intermediates {
    my ($x509, $chain) = @_;
    $chain //= [];

    print "Getting intermediate for ".$x509->subject() . "\n";
    
    my $ca_info_ext = $x509->extensions_by_oid()->{"1.3.6.1.5.5.7.1.1"};
    unless($ca_info_ext) {
        print "Unable to read CA extension for certificate. Assuming end of the chain has been reached\n";
        return ($TRUE, $chain);
    }

    my $ca_info = $ca_info_ext->to_string;
    print $ca_info . "\n";
    if($ca_info =~ /CA Issuers\s*-\s*URI:(.*)\n/) {
        my $url = $1;
        
        print "Downloading $url \n";

        my ($res, $cert) = download_file($url);
        unless($res) {
            return ($FALSE, "Unable to download intermediate certificate $url: $cert");
        }

        my $inter = x509_from_string($cert);
        unless(defined($inter)) {
            print "Unable to load certificate as x509. Assuming end of the chain has been reached.\n";
            return ($TRUE, $chain);
        }

        push @$chain, $inter;

        if($inter->issuer() ne $inter->subject()) {
            return fetch_all_intermediates($inter, $chain);
        }
        else {
            print "Reached the top of the signing chain\n";
            return ($TRUE, $chain);
        }
    }
    else {
        print "Unable to find CA issuer certificate download link in certificate data. Assuming top of the chain was reached. \n";
        return ($TRUE, $chain);
    }
}

sub download_file {
    my ($url) = @_;
    my $ua = LWP::UserAgent->new;
    my $response = $ua->get($url);

    if($response->is_success) {
        return ($TRUE, $response->decoded_content);
    }
    else {
        return ($FALSE, "Unable to download $url: ".$response->status_line);
    }
}

sub install_file {
    my ($filename, $content) = @_;
    unless(write_file($filename, $content)) {
        return ($FALSE, "Error writing file $filename")
    }
    pf_chown($filename);
    return ($TRUE);
}

sub convert_der_to_pem {

}

1;
