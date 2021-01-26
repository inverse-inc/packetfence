#!/usr/bin/perl

use DBI;
use strict;

BEGIN {
    use constant INSTALL_DIR => '/usr/local/pf';
    use lib INSTALL_DIR . "/lib";
}

use pf::db;
use WWW::Curl::Easy;

my $driver   = "SQLite";
my $database = "/usr/local/packetfence-pki/db.sqlite3";
my $dsn = "DBI:$driver:dbname=$database";
my $userid = "";
my $password = "";
my $dbh = DBI->connect($dsn, $userid, $password, { RaiseError => 1 })
   or die $DBI::errstr;


my $mysql_driver = "mysql";
my $pf_user = $pf::db::DB_Config->{user};
my $pf_password = $pf::db::DB_Config->{pass};
my $pf_db = $pf::db::DB_Config->{db};
my $pf_host = $pf::db::DB_Config->{host};
my $pf_dsn = "dbi:mysql:dbname=$pf_db;host=$pf_host";
my $pf_dbh = DBI->connect($pf_dsn, $pf_user, $pf_password, { RaiseError => 1 })
   or die $DBI::errstr;


my $cas;
my $profiles;
my $certs;
my $revokedCerts;

my %digest = (

    "md5" => 2,
    "sha1" => 3,
    "sha256" => 4,
);

my %reason = (
    "unspecified" => 0,
    "keyCompromise" => 1,
    "cACompromise" => 2,
    "affiliationChanged" => 3,
    "superseded" => 4,
    "cessationOfOperation" => 5,
    "certificateHold" => 6,
    "removeFromCRL" => 8,
    "privilegeWithdrawn" => 9,
    "aACompromise" => 10
);

ca();
profiles();
certs();
revokedcerts();
fixca();

$dbh->disconnect();

sub ca {

    my $stmt = qq(SELECT * from pki_ca;);
    my $sth = $dbh->prepare( $stmt );
    my $rv = $sth->execute() or die $DBI::errstr;

    if($rv < 0) {
        print $DBI::errstr;
    }

    my $sql = "INSERT INTO pki_cas(`id`, `cn` ,`mail`, `organisation`, `country`, `state`, `locality`, `key_type`, `key_size`, `digest`, `key_usage`, `extended_key_usage`, `days`, `key`, `cert`, `issuer_key_hash`) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)";

    my $pf_stmt = $pf_dbh->prepare($sql);

    while (my $hash = $sth->fetchrow_hashref()) {
        $cas->{$hash->{id}} = $hash;

        my $pf_stmt = $pf_dbh->prepare($sql);
        if($pf_stmt->execute($hash->{'id'},$hash->{'cn'},$hash->{'mail'},$hash->{'organisation'},$hash->{'country'},$hash->{'state'},$hash->{'locality'},$hash->{'key_type'}, $hash->{'key_size'},$digest{$hash->{'digest'}},$hash->{'key_usage'},$hash->{'extended_key_usage'},$hash->{'days'},$hash->{'ca_key'},$hash->{'ca_cert'},$hash->{'issuerKeyHashsha1'})){
            print "CA inserted successfully\n";
        }
    }

}

sub profiles {

    my $stmt = qq(SELECT * from pki_certprofile;);
    my $sth = $dbh->prepare( $stmt );
    my $rv = $sth->execute() or die $DBI::errstr;

    if($rv < 0) {
        print $DBI::errstr;
    }

    my $sql = "INSERT INTO pki_profiles(`id`, `name` ,`ca_id`, `ca_name`, `validity`, `key_type`, `key_size`, `digest`, `key_usage`, `extended_key_usage`, `p12_mail_password`, `p12_mail_subject`, `p12_mail_from`, `p12_mail_header`,`p12_mail_footer`) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)";

    my $pf_stmt = $pf_dbh->prepare($sql);

    while (my $hash = $sth->fetchrow_hashref()) {
        $profiles->{$hash->{id}} = $hash;
        if($pf_stmt->execute($hash->{'id'},$hash->{'name'},$hash->{'ca_id'},$cas->{$hash->{'ca_id'}}->{'cn'},$hash->{'validity'},$hash->{'key_type'},$hash->{'key_size'},$digest{$hash->{'digest'}},$hash->{'key_usage'}, $hash->{'extended_key_usage'},$hash->{'p12_mail_password'},$hash->{'p12_mail_subject'},$hash->{'p12_mail_from'},$hash->{'p12_mail_header'},$hash->{'p12_mail_footer'})){
            print "profiles inserted successfully\n";
        }
    }
}

sub certs {

    my $stmt = qq(SELECT * from cert;);
    my $sth = $dbh->prepare( $stmt );
    my $rv = $sth->execute() or die $DBI::errstr;

    if($rv < 0) {
        print $DBI::errstr;
    }
    my $serial = 1;
    my $sql = "INSERT INTO pki_certs(`id`, `cn` ,`mail`, `ca_id`, `ca_name`, `organisation`, `country`, `state`, `key`, `cert`, `profile_id`, `profile_name`, `valid_until`, `date`, `serial_number`) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)";

     my $pf_stmt = $pf_dbh->prepare($sql);

    while (my $hash = $sth->fetchrow_hashref()) {
        $certs->{$hash->{id}} = $hash;
        if($pf_stmt->execute($hash->{'id'},$hash->{'cn'},$hash->{'mail'},$profiles->{$hash->{'profile_id'}}->{'ca_id'},$cas->{$profiles->{$hash->{'profile_id'}}->{'ca_id'}}->{'cn'},$hash->{'organisation'},$hash->{'country'},$hash->{'st'},$hash->{'pkey'},$hash->{'x509'},$hash->{'profile_id'}, $profiles->{$hash->{'profile_id'}}->{'name'},$hash->{'valid_until'},$hash->{'date'},$serial)){
            print "certificates inserted successfully\n";
            $serial ++;
       }
    }
}

sub revokedcerts {

    my $stmt = qq(SELECT * from pki_certrevoked;);
    my $sth = $dbh->prepare( $stmt );
    my $rv = $sth->execute() or die $DBI::errstr;

    if($rv < 0) {
        print $DBI::errstr;
    }
    my $serial = 1;

    my $sql = "INSERT INTO pki_revoked_certs(`id`, `cn` ,`mail`, `ca_id`, `ca_name`, `organisation`, `country`, `state`, `key`, `cert`, `profile_id`, `profile_name`, `valid_until`, `date`, `serial_number`, `revoked`, `crl_reason`) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)";
    my $pf_stmt = $pf_dbh->prepare($sql);

    while (my $hash = $sth->fetchrow_hashref()) {
        $revokedCerts->{$hash->{id}} = $hash;
        if($pf_stmt->execute($hash->{'id'},$hash->{'cn'},$hash->{'mail'},$profiles->{$hash->{'profile_id'}}->{'ca_id'},$cas->{$profiles->{$hash->{'profile_id'}}->{'ca_id'}}->{'cn'},$hash->{'organisation'},$hash->{'country'},$hash->{'st'},$hash->{'pkey'},$hash->{'x509'},$hash->{'profile_id'}, $profiles->{$hash->{'profile_id'}}->{'name'},$hash->{'valid_until'},$hash->{'date'},$serial,$hash->{'revoked'},$reason{$hash->{'CRLReason'}})){
            print "revoked certificates inserted successfully\n";
            $serial ++;
        }
    }
}

sub fixca {
    my $curl = WWW::Curl::Easy->new;
    my $url = "http://127.0.0.1:22225/api/v1/pki/ca/fix";

    $curl->setopt(CURLOPT_URL, $url );
    $curl->setopt(CURLOPT_SSL_VERIFYPEER, 0) ;
    $curl->setopt(CURLOPT_HEADER, 0);

    my $curl_return_code = $curl->perform;
    my $curl_info = $curl->getinfo(CURLINFO_HTTP_CODE); # or CURLINFO_RESPONSE_CODE depending on libcurl version

    if ( $curl_return_code != 0 or $curl_info != 200 ) {
        print "Error fixing CA, does the pfpki running ";
    }
}
