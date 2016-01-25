#!/usr/bin/perl
use strict;
use warnings;

use lib '/usr/local/pf/lib';

use Lasso;
use Plack::Request;
use Plack::Response;
use MIME::Base64;
use Data::Dumper;

my $username_attribute = "urn:oid:0.9.2342.19200300.100.1.1";

my $sp_cert_path = "/usr/local/pf/conf/ssl/server.crt";
my $sp_key_path = "/usr/local/pf/conf/ssl/server.key";
my $sp_metadata_path = "/usr/local/pf/sp-metadata.xml";

my $idp_cert_path =  "/usr/local/pf/conf/ssl/simplesaml.crt";
my $idp_ca_cert_path = "/usr/local/pf/conf/ssl/simplesaml.crt";
my $idp_metadata_path = "/usr/local/pf/idp-metadata.xml";

my $sso_url = "http://172.20.155.56/saml2/idp/metadata.php";
 
my $app = sub {
    my $env = shift;
    my $res = Plack::Response->new();
    my $req = Plack::Request->new($env);


    eval {
        Lasso::init();
        my $server = Lasso::Server->new($sp_metadata_path, $sp_key_path, undef, $sp_cert_path);
        $server->add_provider(Lasso::Constants::PROVIDER_ROLE_IDP, $idp_metadata_path, $idp_cert_path, $idp_ca_cert_path);
        
        my $lassoLogin = Lasso::Login->new($server);
        if($req->method eq "POST"){
            $lassoLogin->process_authn_response_msg($req->body_parameters->{SAMLResponse});
            my $rc = $lassoLogin->accept_sso();
            if($rc){
                die "Single Sign-On failed..."
            }

            my $assertion = $lassoLogin->get_assertion();
            my @attribute_list = $assertion->AttributeStatement->Attribute;
            
            my $username;
            foreach my $attribute (@attribute_list){
                if($attribute->Name eq $username_attribute){
                    $username = $attribute->AttributeValue->any->content;
                    last;
                }
            }

            die "Can't find username in SAML response..." unless($username);

            $res->body("User $username has authenticated");
            $res->status(200);
        }
        else {
            $lassoLogin->init_authn_request($sso_url, Lasso::Constants::HTTP_METHOD_REDIRECT);
            my $lassoRequest = $lassoLogin->request;
            $lassoLogin->request->NameIDPolicy->Format(Lasso::Constants::SAML2_NAME_IDENTIFIER_FORMAT_PERSISTENT);
            $lassoLogin->request->NameIDPolicy->AllowCreate(1);
            $lassoLogin->request->ForceAuthn(0);
            $lassoLogin->request->IsPassive(0);
            $lassoLogin->request->ProtocolBinding(Lasso::Constants::SAML2_METADATA_BINDING_ARTIFACT);

            $lassoLogin->build_authn_request_msg();

            $res->redirect($lassoLogin->msg_url);
        }

    };
    if($@) {
        my $res = Plack::Response->new();
        $res->status(500);
        use Data::Dumper;
        $res->body(Dumper($@));
        return $res->finalize();
    }
    return $res->finalize();
};
