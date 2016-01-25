package pf::Authentication::Source::SAMLSource;

=head1 NAME

pf::Authentication::Source::ADSource

=head1 DESCRIPTION

=cut

use pf::Authentication::constants;
use pf::constants::authentication::messages;
use pf::constants;
use Lasso;
use Template;
use File::Slurp qw(read_file);

use Moose;
extends 'pf::Authentication::Source';

has '+type' => ( default => 'SAML' );
has 'authorization_source_id' => ( is => 'rw', required => 1 );

has 'sp_metadata_path' => ( is => 'rw', required => 1 );
has 'sp_key_path' => ( is => 'rw', required => 1 );
has 'sp_cert_path' => ( is => 'rw', required => 1 );
has 'sp_entity_id' => ( is => 'rw', required => 1 );

has 'idp_cert_path' => ( is => 'rw', required => 1 );
has 'idp_ca_cert_path' => ( is => 'rw', required => 1 );
has 'idp_metadata_path' => ( is => 'rw', required => 1 );
has 'idp_entity_id' => ( is => 'rw', required => 1 );

has 'username_attribute' => ( is => 'rw', default => "urn:oid:0.9.2342.19200300.100.1.1" );

sub has_authentication_rules { $FALSE }

sub authenticate {
    my $msg = "Can't authenticate against a SAML source..."; 
    get_logger->info($msg);
    return ($FALSE, $msg);
} 

sub match {
    my ($self, $params) = @_;
    return $self->authorization_source->match($params);
}

sub authorization_source {
    my ($self) = @_;
    require pf::authentication;
    return pf::authentication::getAuthenticationSource($self->authorization_source_id);
}

sub lasso_server {
    my ($self) = @_;
    Lasso::init();
    my $server = Lasso::Server->new($self->sp_metadata_path, $self->sp_key_path, undef, $self->sp_cert_path);
    $server->add_provider(Lasso::Constants::PROVIDER_ROLE_IDP, $self->idp_metadata_path, $self->idp_cert_path, $self->idp_ca_cert_path);
    return $server;
}

sub lasso_login {
    my ($self) = @_;
    return Lasso::Login->new($self->lasso_server);
}

sub sso_url {
    my ($self) = @_;
    my $url;
    eval {
        my $lassoLogin = $self->lasso_login;

        $lassoLogin->init_authn_request($self->idp_entity_id, Lasso::Constants::HTTP_METHOD_REDIRECT);
        $lassoLogin->request->NameIDPolicy->Format(Lasso::Constants::SAML2_NAME_IDENTIFIER_FORMAT_PERSISTENT);
        $lassoLogin->request->NameIDPolicy->AllowCreate(1);
        $lassoLogin->request->ForceAuthn(0);
        $lassoLogin->request->IsPassive(0);
        $lassoLogin->request->ProtocolBinding(Lasso::Constants::SAML2_METADATA_BINDING_ARTIFACT);

        $lassoLogin->build_authn_request_msg();

        $url = $lassoLogin->msg_url;
    };
    if($@){
        die "Can't create Single-Sign-On URL : ".$@->{message}."\n";
    }
    return $url;
}

sub handle_response {
    my ($self, $response) = @_;
    
    my ($result, $msg) = eval {
        my $lassoLogin = $self->lasso_login;

        $lassoLogin->process_authn_response_msg($response);

        my $rc = $lassoLogin->accept_sso();
        if($rc){
            return ($FALSE, "Single Sign-On failed...");
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

sub generate_sp_metadata {
    my ($self) = @_;
    require pf::config;
    my $cert = read_file($self->sp_cert_path);
    $cert = join("\n", map { ($_ !~ /^-----BEGIN CERTIFICATE-----/ && $_ !~ /^-----END CERTIFICATE-----/) ? $_ : () } split(/\n/, $cert));
    my $vars = {
        callback => $pf::config::fqdn."/saml/assertion",
        sp_entity_id => $self->sp_entity_id,
        sp_cert => $cert,
        entity_id => $self->sp_entity_id
    };

    our $TT_OPTIONS = {ABSOLUTE => 1};
    our $template = Template->new($TT_OPTIONS);

    my $output = '';
    $template->process("/usr/local/pf/addons/saml-sp-metadata.xml", $vars, \$output) || die("Can't generate SP metadata : ".$template->error);

    print $output;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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

__PACKAGE__->meta->make_immutable;
1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

