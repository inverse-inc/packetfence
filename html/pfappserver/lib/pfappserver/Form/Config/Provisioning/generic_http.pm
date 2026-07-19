package pfappserver::Form::Config::Provisioning::generic_http;

=head1 NAME

pfappserver::Form::Config::Provisioning::generic_http

=head1 DESCRIPTION

Form definition of the generic HTTP provisioner

=cut

use HTML::FormHandler::Moose;
use JQ::XS;
use pf::provisioner::generic_http;
extends 'pfappserver::Form::Config::Provisioning';
with 'pfappserver::Base::Form::Role::Help';

has_field 'method' =>
  (
   type => 'Select',
   options => [ map { { label => $_, value => $_ } } qw(GET POST PUT PATCH DELETE) ],
   default => pf::provisioner::generic_http->meta->get_attribute('method')->default,
  );

has_field 'url' =>
  (
   type => 'Text',
   required => 1,
   tags => { after_element => \&help,
             help => 'The URL of the request. This is a template: $mac is the MAC address of the device and $node.&lt;attribute&gt; (ex: $node.pid, $node.category) are the attributes of the node.' },
  );

has_field 'headers' =>
  (
   type => 'TextArea',
   tags => { after_element => \&help,
             help => 'The headers of the request, one "Name: value" per line. Names and values are templates like the URL.' },
  );

has_field 'body' =>
  (
   type => 'TextArea',
   tags => { after_element => \&help,
             help => 'The body of the request, sent for POST, PUT and PATCH requests. This is a template like the URL.' },
  );

has_field 'content_type' =>
  (
   type => 'Text',
   default => pf::provisioner::generic_http->meta->get_attribute('content_type')->default,
   tags => { after_element => \&help,
             help => 'The Content-Type of the request body. Ignored when a Content-Type header is defined in the headers.' },
  );

has_field 'timeout' =>
  (
   type => 'PosInteger',
   default => pf::provisioner::generic_http->meta->get_attribute('timeout')->default,
   tags => { after_element => \&help,
             help => 'Timeout in seconds of the request.' },
  );

has_field 'username' =>
  (
   type => 'Text',
   tags => { after_element => \&help,
             help => 'Optional username for HTTP basic authentication.' },
  );

has_field 'password' =>
  (
   type => 'ObfuscatedText',
   tags => { after_element => \&help,
             help => 'Optional password for HTTP basic authentication.' },
  );

has_field 'verify_ssl' =>
  (
   type => 'Toggle',
   checkbox_value => 'enabled',
   unchecked_value => 'disabled',
   default => pf::provisioner::generic_http->meta->get_attribute('verify_ssl')->default,
   tags => { after_element => \&help,
             help => 'Whether or not the TLS certificate of the server is verified.' },
  );

has_field client_cert_file => (
    type => 'Path',
    file_type => 'file',
    tags => { after_element => \&help,
              help => 'The client TLS certificate used to authenticate against the server.' },
);

has_field 'client_cert_file_upload' => (
   type => 'PathUpload',
   accessor => 'client_cert_file',
   config_prefix => '.crt',
   required => 0,
   upload_namespace => 'provisioning',
);

has_field client_key_file => (
    type => 'Path',
    file_type => 'file',
    tags => { after_element => \&help,
              help => 'The private key of the client TLS certificate.' },
);

has_field 'client_key_file_upload' => (
   type => 'PathUpload',
   accessor => 'client_key_file',
   config_prefix => '.key',
   required => 0,
   upload_namespace => 'provisioning',
);

has_field ca_file => (
    type => 'Path',
    file_type => 'file',
    tags => { after_element => \&help,
              help => 'The CA certificate used to verify the server certificate.' },
);

has_field 'ca_file_upload' => (
   type => 'PathUpload',
   accessor => 'ca_file',
   config_prefix => '.crt',
   required => 0,
   upload_namespace => 'provisioning',
);

has '+dependency' => (
    default => sub {
        [
            [ 'client_cert_file', 'client_key_file' ]
        ];
    },
);

has_field 'jq_query' =>
  (
   type => 'TextArea',
   required => 1,
   validate_method => \&validate_jq_query,
   tags => { after_element => \&help,
             help => 'The jq query applied to the JSON response. The device is authorized when the query returns a truthy value: every result that is not null or false passes, an empty result fails.' },
  );

=head2 validate_jq_query

Ensure the jq query compiles before saving

=cut

sub validate_jq_query {
    my ($field) = @_;
    my $query = $field->value;
    return if !defined $query || $query eq '';
    eval { JQ::XS->new($query) };
    if (my $err = $@) {
        $err =~ s/\n.*//s;
        $err =~ s/\s*at <top-level>.*//s;
        $err =~ s/^jq compile error:\s*//;
        # escape maketext brackets so add_error does not interpret them
        $err =~ s/([\[\]])/~$1/g;
        $field->add_error("Invalid jq query: $err");
    }
}

has_block definition =>
  (
   render_list => [ qw(id type description category oses rules enforce autoregister apply_role role_to_apply non_compliance_security_event method url headers body content_type timeout username password verify_ssl client_cert_file client_key_file ca_file jq_query) ],
  );

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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
