#!/bin/perl

use strict;
use warnings;

use IPC::Cmd qw[can_run run ];
use File::Temp qw/ tempfile tempdir /;
use Template;



my $client_conf_template = <<'EOF';
[ req ]
prompt			= no
distinguished_name	= client
default_bits		= 2048
input_password		= ''
output_password		= ''
attributes          = req_attributes
req_extensions      = req_extensions

[ req_attributes ]
challengePassword   = [% password %] 

[ req_extensions ]
extendedKeyUsage = 1.3.6.1.5.5.7.3.2
crlDistributionPoints = URI:http://www.example.com/example_ca.crl
subjectAltName =   email:[% email %]

[client]
countryName		= FR
stateOrProvinceName	= Radius
localityName		= Somewhere
organizationName	= Example Inc.
emailAddress		= [% email %]
commonName		= [% email %]
EOF


my %vars = ( 
    password => "Secret.123",
    email    => 'user@inverse.ca',
);

my $tt = Template->new();
my $client_conf;
$tt->process( \$client_conf_template, \%vars, \$client_conf);


my $fh = File::Temp->new();
my $tmp_config = $fh->filename;
print $fh $client_conf;
close $fh;



my $cmd = qq[ openssl req -new -out testclient.csr  -nodes -keyout testclient.key  -config $tmp_config ];
my $buffer;
scalar run ( 
    command => $cmd,
    verbose => 1,
    buffer  => \$buffer,
    timeout => 10 ) ;


