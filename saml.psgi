#!/usr/bin/perl
use strict;
use warnings;

use lib '/usr/local/pf/lib';

use pf::authentication;
use Plack::Request;
use Plack::Response;
use MIME::Base64;
use Data::Dumper;

 
my $app = sub {
    my $env = shift;
    my $res = Plack::Response->new();
    my $req = Plack::Request->new($env);

    my $source = pf::authentication::getAuthenticationSource("saml_test");
    eval {
        if($req->method eq "POST"){
            my ($username, $msg) = $source->handle_response($req->body_parameters->{SAMLResponse});

            unless($username){
                die $msg;
            }

            $res->body("User $username has authenticated");
            $res->status(200);
        }
        else {
            my $redirect_url = $source->sso_url;
            $res->redirect($redirect_url);
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
