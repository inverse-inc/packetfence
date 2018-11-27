package pf::Authentication::Source::SAMLSource;

=head1 NAME

pf::Authentication::Source::SAMLSource

=head1 DESCRIPTION

Model for a SAML source

=cut

use pf::Authentication::constants;
use pf::constants::authentication::messages;
use pf::constants;
use pf::config;
use Template::AutoFilter;
use File::Slurp qw(read_file write_file);
use File::Temp qw(tempfile);
use pf::util;

use Moose;
extends 'pf::Authentication::Source';

has '+type' => ( default => 'SAML' );
has 'authorization_source_id' => ( is => 'rw', required => 1 );

has 'sp_key_path' => ( is => 'rw', required => 1 );
has 'sp_cert_path' => ( is => 'rw', required => 1 );
has 'sp_entity_id' => ( is => 'rw', required => 1 );

has 'idp_cert_path' => ( is => 'rw', required => 1 );
has 'idp_ca_cert_path' => ( is => 'rw', required => 1 );
has 'idp_metadata_path' => ( is => 'rw', required => 1 );
has 'idp_entity_id' => ( is => 'rw', required => 1 );

has 'username_attribute' => ( is => 'rw', default => "urn:oid:0.9.2342.19200300.100.1.1" );

=head2 dynamic_routing_module

Which module to use for DynamicRouting

=cut

sub dynamic_routing_module { 'Authentication::SAML' }

=head2 has_authentication_rules

This source does not have any authentication rules

=cut

sub has_authentication_rules { $FALSE }

=head2 authenticate

Override parent method as SAML cannot be used directly for authentication

=cut

sub authenticate {
    my $msg = "Can't authenticate against a SAML source..."; 
    get_logger->info($msg);
    return ($FALSE, $msg);
} 

=head2 match

Forward matching to the authorization source

=cut

sub match {
    my ($self, $params) = @_;
    return $self->authorization_source->match($params);
}

=head2 authorization_source

Get authorization source from the ID defined in the source

=cut

sub authorization_source {
    my ($self) = @_;
    require pf::authentication;
    return pf::authentication::getAuthenticationSource($self->authorization_source_id);
}

=head2 lasso_server

Create the Lasso server

=cut

sub lasso_server {
    my ($self) = @_;

    require pf::constants::saml;
    require Lasso;
    Lasso->import();

    Lasso::init();
    my ($fh, $sp_metadata_path) = tempfile();
    write_file($sp_metadata_path, $self->generate_sp_metadata());
    my $server = Lasso::Server->new($sp_metadata_path, $self->sp_key_path, undef, $self->sp_cert_path);
    $server->add_provider($pf::constants::saml::PROVIDER_ROLE_IDP, $self->idp_metadata_path, $self->idp_cert_path, $self->idp_ca_cert_path);
    return $server;
}

=head2 lasso_login

Create the Lasso login

=cut

sub lasso_login {
    my ($self) = @_;

    require pf::constants::saml;
    require Lasso;
    Lasso->import();
    return Lasso::Login->new($self->lasso_server);
}

=head2 sso_url

Generate the Single-Sign-On URL that points to the Identity Provider

=cut

sub sso_url {
    my ($self) = @_;

    require pf::constants::saml;
    require Lasso;
    Lasso->import();

    my $url;
    eval {
        my $lassoLogin = $self->lasso_login;

        $lassoLogin->init_authn_request($self->idp_entity_id, $pf::constants::saml::HTTP_METHOD_REDIRECT);
        $lassoLogin->request->NameIDPolicy->Format($pf::constants::saml::SAML2_NAME_IDENTIFIER_FORMAT_PERSISTENT);
        $lassoLogin->request->NameIDPolicy->AllowCreate(1);
        $lassoLogin->request->ForceAuthn(0);
        $lassoLogin->request->IsPassive(0);

        $lassoLogin->build_authn_request_msg();

        $url = $lassoLogin->msg_url;
    };
    if($@){
        die "Can't create Single-Sign-On URL : ".$@->{message}."\n";
    }
    return $url;
}

=head2 handle_response

Handle the response from the Identity Provider and extract the username out of the assertion

=cut

sub handle_response {
    my ($self, $response) = @_;
    
    my ($result, $msg) = eval {
        my $lassoLogin = $self->lasso_login;

        $lassoLogin->process_authn_response_msg($response);

        my $rc = $lassoLogin->accept_sso();
        if($rc){
            return ($FALSE, "Single Sign-On failed. Code : $rc");
        }

        my $assertion = $lassoLogin->get_assertion();
        my @attribute_list = $assertion->AttributeStatement->Attribute;
        
        my $username;
        foreach my $attribute (@attribute_list){
            if($attribute->Name eq $self->username_attribute){
                $username = $attribute->AttributeValue->any->content;
                last;
            }
        }

        if($username){
            return ($username, "Authentication successful with username : $username");
        }
        else {
            return ($FALSE, "Can't find username in SAML response.")
        }
    };
    if($@){
        return ($FALSE, "Can't validate Identity provider return message : ".$@->{message});
    }

    return ($result, $msg);

}

=head2 generate_sp_metadata

Generate the metadata for the Service Provider (this server)

=cut

sub generate_sp_metadata {
    my ($self) = @_;
    require pf::config;
    my $vars = {
        hostname => $pf::config::fqdn,
        saml_source => $self,
        protocol => isenabled($pf::config::Config{captive_portal}{secure_redirect}) ? "https" : "http",
    };

    our $TT_OPTIONS = {
        ABSOLUTE => 1, 
        AUTO_FILTER => 'xml',
    };
    our $template = Template::AutoFilter->new($TT_OPTIONS);

    my $output = '';
    $template->process("/usr/local/pf/conf/saml-sp-metadata.xml", $vars, \$output) || die("Can't generate SP metadata : ".$template->error);

    return $output;
}

sub sp_cert {
    my ($self) = @_;
    my $cert = read_file($self->sp_cert_path);
    $cert = join("\n", map { ($_ !~ /^-----BEGIN CERTIFICATE-----/ && $_ !~ /^-----END CERTIFICATE-----/) ? $_ : () } split(/\n/, $cert));
    return $cert;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};
1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

