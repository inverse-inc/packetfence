package pf::ssl::lets_encrypt;

use strict;
use warnings;

use pf::ConfigStore::Pf;
use pf::constants qw($TRUE $FALSE);
use pf::error qw(is_error);
use Crypt::LE;
use Data::Dumper;
use File::Slurp qw(read_file write_file);
use pf::log;
use pf::ssl;
    
sub process_challenge {
   my ($challenge) = @_;

   my $logger = get_logger;

   my $fname = $challenge->{token};
   my $content = "$challenge->{token}.$challenge->{fingerprint}";
   $logger->info("A file '$fname' with the text: $challenge->{token}.$challenge->{fingerprint} will be created for the Let's Encrypt challenge");
   write_file("/usr/local/pf/conf/ssl/acme-challenge/$fname", $content);
   return 1;
};

sub obtain_certificate {
    my ($key_path, $domain) = @_;

    my $le = Crypt::LE->new(debug => 2, logger => get_logger);
    $le->generate_account_key();
    $le->load_csr_key($key_path);
    $le->generate_csr($domain);
    $le->register();
    $le->accept_tos();
    $le->request_challenge();
    $le->accept_challenge(\&process_challenge);
    $le->verify_challenge();
    my $status = $le->request_certificate();
    if(is_error($status)) {
        return ($FALSE, $le->error_details());
    }
    else {
        return ($TRUE, $le->certificate());
    }
}

sub obtain_bundle {
    my ($key_path, $domain) = @_;

    my ($result, $data) = obtain_certificate($key_path, $domain);
    unless($result) {
        return ($result, $data);
    }

    my $x509 = pf::ssl::x509_from_string($data);
    ($result, my $chain) = pf::ssl::fetch_all_intermediates($x509); 

    unless($result) {
        return ($result, $chain);
    }

    return ($result, {certificate => $x509, intermediate_cas => $chain });
}

=head2 certificate_lets_encrypt

Gets or sets the Let's Encrypt flag for a certificate resource

=cut

sub resource_state {
    my ($type, $param) = @_;

    unless(exists(pf::ssl::certs_map()->{$type})) {
        return ($FALSE, "Resource $type doesn't exist")
    }

    my $cs = pf::ConfigStore::Pf->new;
    if(defined($param)) {
        # We are setting the parameter
        $cs->update(lets_encrypt => {$type => $param});
        return $cs->commit();
    }
    else {
        # We are getting the parameter
        return $cs->read("lets_encrypt")->{$type};
    }
}

1;
