package pf::ssl::lets_encrypt;

=head1 NAME

pf::ssl

=cut

=head1 DESCRIPTION

Helper functions to interface with Crypt::LE

=cut

use strict;
use warnings;

use pf::file_paths qw($acme_challenge_dir);
use pf::config qw(%Config);
use pf::ConfigStore::Pf;
use pf::constants qw($TRUE $FALSE);
use pf::error qw(is_error);
use Crypt::LE;
use Data::Dumper;
use File::Slurp qw(read_file write_file);
use pf::log;
use pf::ssl;
use pf::util;
use URI::Escape::XS qw(uri_escape);
    
use Data::UUID;

my $UUID_GENERATOR = Data::UUID->new;

sub process_challenge {
   my ($challenge) = @_;

   my $logger = get_logger;

   my $fname = $challenge->{token};
   my $content = "$challenge->{token}.$challenge->{fingerprint}";
   $logger->info("A file '$fname' with the text: $challenge->{token}.$challenge->{fingerprint} will be created for the Let's Encrypt challenge");
   write_file("/usr/local/pf/conf/ssl/acme-challenge/$fname", $content);
   return 1;
};

=head2 obtain_certificate

For a key and domain, obtain a Let's Encrypt certificate

=cut

sub obtain_certificate {
    my ($key_path, $domain) = @_;

    my $le = Crypt::LE->new(
        debug => 2, 
        logger => get_logger,
        live => isenabled($Config{lets_encrypt}{live}),
    );
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

=head2 obtain_certificate

For a key and domain, obtain a Let's Encrypt certificate and its intermediate CAs

=cut

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

=head2 test_domain

Test a domain exposes the acme-challenge directory through the domain testing service

=cut

sub test_domain {
    my ($domain) = @_;
    
    my $ua = LWP::UserAgent->new;

    my $uuid = $UUID_GENERATOR->create_str;
    my $file = "$acme_challenge_dir/$uuid.txt";
    write_file($file, "Success");

    my $response = $ua->get($Config{lets_encrypt}{test_uri} . "?domain=".uri_escape($domain)."&uuid=".uri_escape($uuid));

    unlink $file;
    
    return ($response->is_success, $response->decoded_content);
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301,
USA.

=cut

1;

