package pf::ssl;

use strict;
use warnings;

use File::Temp qw(tempfile);
use pf::constants qw($TRUE $FALSE);
use File::Slurp qw(read_file write_file);
use LWP::UserAgent;
use pf::util;
use pf::log;

use Crypt::OpenSSL::RSA;
use Crypt::OpenSSL::X509;
use Crypt::OpenSSL::PKCS10;

sub rsa_from_string {
    my ($key) = @_;
    return Crypt::OpenSSL::RSA->new_private_key($key);
}

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

sub rsa_modulus_md5 {
    my ($rsa) = @_;
    return openssl_modulus_md5("rsa", $rsa->get_private_key_string());
}

sub x509_modulus_md5 {
    my ($x509) = @_;
    return openssl_modulus_md5("x509", $x509->as_string());
}

sub openssl_modulus_md5 {
    my ($type, $data) = @_;
    my $result = `echo "$data" | openssl $type -noout -modulus | openssl md5 | awk '{ print \$2 }'`;
    chomp($result);
    if($? != 0) {
        get_logger->error("Unable to get modulus: $result");
        return undef;
    }
    else {
        return $result;
    }
}

sub validate_cert_key_match {
    my ($cert, $key) = @_;
    my $cert_mod = x509_modulus_md5($cert);
    unless(defined($cert_mod)) {
        my $msg = "Unable to determine modulus of certificate ". $cert->subject();
        get_logger->error($msg);
        return (undef, $msg)
    }

    my $key_mod = rsa_modulus_md5($key);
    unless(defined($key_mod)) {
        my $msg = "Unable to determine modulus of key";
        get_logger->error($msg);
        return (undef, $msg)
    }

    if($cert_mod ne $key_mod) {
        return ($FALSE, "Modulus don't match. Key modulus MD5 '$key_mod' and certificate modulus MD5 '$cert_mod' aren't the same");
    }
    else {
        return ($TRUE);
    }
}

sub fetch_all_intermediates {
    my ($x509, $chain) = @_;
    $chain //= [];

    get_logger->info("Getting intermediate for ".$x509->subject());
    
    my $ca_info_ext = $x509->extensions_by_oid()->{"1.3.6.1.5.5.7.1.1"};
    unless($ca_info_ext) {
        get_logger->warn("Unable to read CA extension for certificate. Assuming end of the chain has been reached");
        return ($TRUE, $chain);
    }

    my $ca_info = $ca_info_ext->to_string;
    if($ca_info =~ /CA Issuers\s*-\s*URI:(.*)\n/) {
        my $url = $1;
        
        get_logger->info("Downloading certificate at $url");

        my ($res, $cert) = download_file($url);
        unless($res) {
            return ($FALSE, "Unable to download intermediate certificate $url: $cert");
        }

        my $inter = x509_from_string($cert);
        unless(defined($inter)) {
            get_logger->warn("Unable to load certificate as x509. Assuming end of the chain has been reached/");
            return ($TRUE, $chain);
        }

        push @$chain, $inter;

        if($inter->issuer() ne $inter->subject()) {
            return fetch_all_intermediates($inter, $chain);
        }
        else {
            get_logger->info("Reached the top of the signing chain");
            return ($TRUE, $chain);
        }
    }
    else {
        get_logger->warn("Unable to find CA issuer certificate download link in certificate data. Assuming top of the chain was reached.");
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
    eval {
        pf::util::safe_file_update($filename, $content);
    };
    if($@) {
        return ($FALSE, $@);
    }
    else {
        return ($TRUE);
    }
}

sub generate_csr {
    my ($rsa, $info) = @_;

    my $required = ["country", "state", "locality", "organization_name", "common_name"];

    foreach my $field (@$required) {
        my $value = $info->{$field};
        if(!defined($value) || length($value) == 0) {
            my $msg = "$field must be specified.";
            get_logger->error($msg);
            return ($FALSE, );
        }
    }
    
    if(length($info->{country}) != 2) {
        return ($FALSE, "Country length must be exactly 2.");
    }

    my $subject = "/C=$info->{country}/ST=$info->{state}/L=$info->{locality}/O=$info->{organization_name}/CN=$info->{common_name}";

    get_logger->info("Generating CSR with subject $subject");

    my $csr = Crypt::OpenSSL::PKCS10->new_from_rsa($rsa);
    $csr->set_subject($subject);
    $csr->sign();
    
    return ($TRUE, $csr);
}

sub verify_chain {
    my ($cert, $intermediates) = @_;
    my $cert_str = $cert->as_string();

    my (undef, $tmpinter) = tempfile();
    my $bundle = "";
    foreach my $inter (@$intermediates) {
        $bundle .= $inter->as_string();
    }
    write_file($tmpinter, $bundle);

    my $result = `/bin/bash -c "echo '$cert_str' | openssl verify -verbose -CAfile <(cat /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem $tmpinter)"`;
    unlink $tmpinter;

    if($? != 0) {
        get_logger->error("Chain verification failed");
        return ($FALSE, $result);
    }
    else {
        get_logger->info("Chain verification succeeded");
        return ($TRUE, $result);
    }
}

sub x509_info {
    my ($x509) = @_;
    return {
        subject => $x509->subject(),
        issuer => $x509->issuer(),
        not_before => $x509->notBefore(),
        not_after => $x509->notAfter(),
    };
}

1;
