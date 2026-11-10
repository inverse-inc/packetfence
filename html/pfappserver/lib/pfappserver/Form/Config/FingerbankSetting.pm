package pfappserver::Form::Config::FingerbankSetting;

=head1 NAME

pfappserver::Form::Config::FingerbankSetting - Web form for fingerbank.conf

=head1 DESCRIPTION

Form definition to create or update a section of fingerbank.conf

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';
with 'pfappserver::Base::Form::Role::Help';
with 'pfappserver::Base::Form::Role::Defaults';
use pfconfig::cached_hash;
use pf::log;
use fingerbank::API;
use fingerbank::Config;
use fingerbank::Constant;
use LWP::UserAgent;
use pf::error qw(is_error);
use pf::util qw(isenabled);
tie our %Doc_Config, 'pfconfig::cached_hash', 'config::FingerbankDoc';
tie our %Defaults, 'pfconfig::cached_hash', 'config::FingerbankSettingsDefaults';

has 'section' => ( is => 'rw' );

# The proxy section submitted in the same request (bulk update of the general settings)
has 'submitted_proxy' => ( is => 'rw' );

my %FIELD_VALIDATORS = (
);

=head2 validate

Test the upstream API key with the submitted upstream (and proxy) settings,
not the saved ones, so wrong saved settings can be fixed.
It runs once all the fields are validated.

=cut

sub validate {
    my ($self) = @_;
    return if ($self->section // '') ne 'upstream';
    my $key_field = $self->field('api_key');
    return unless $key_field;
    my $key = $key_field->value;
    return if !defined($key) || $key eq '';
    # A key test with invalid upstream settings would only repeat their errors
    return if grep { my $f = $self->field($_); $f && $f->has_errors } qw(api_key host port use_https);

    my $api;
    if ($self->submitted_proxy) {
        $api = pfappserver::Form::Config::FingerbankSetting::KeyTestAPI->new_from_config;
        $api->lwp_client(_lwp_client($self->submitted_proxy));
    }
    else {
        $api = fingerbank::API->new_from_config;
    }
    for my $name (qw(host port use_https)) {
        my $field = $self->field($name);
        next unless $field;
        my $value = $field->value;
        # An emptied field goes back to the default
        $value = $Defaults{upstream}{$name} if !defined($value) || $value eq '';
        $api->$name($value);
    }
    my ($result, $msg) = $api->test_key($key);
    if (is_error($result)) {
        $key_field->add_error($msg);
    }
}

# The LWP client of fingerbank::Util::get_lwp_client, with the submitted proxy settings over the saved ones
sub _lwp_client {
    my ($submitted) = @_;
    my %proxy = %{ fingerbank::Config::get_config()->{proxy} // {} };
    for my $name (qw(use_proxy host port verify_ssl)) {
        $proxy{$name} = $submitted->{$name} if exists $submitted->{$name};
    }
    my %args = (keep_alive => 1);
    my $ua;
    if (isenabled($proxy{use_proxy}) && $proxy{host} && $proxy{port}) {
        $ua = LWP::UserAgent->new(%args, ssl_opts => { verify_hostname => isenabled($proxy{verify_ssl}) ? 1 : 0 });
        $ua->proxy(['https', 'http', 'ftp'] => "connect://$proxy{host}:$proxy{port}");
    }
    else {
        $ua = LWP::UserAgent->new(%args);
    }
    $ua->default_header('Accept-Encoding' => 'gzip, x-gzip');
    $ua->agent("Fingerbank-Perl-Library/" . $fingerbank::Constant::VERSION);
    $ua->timeout(2);
    return $ua;
}

=head2 validator_for_field

Get the validator for a field

=cut

sub validator_for_field {
    my ($self, $field) = @_;

    return $FIELD_VALIDATORS{$field};
}

=head2 build_field_info

build_field

=cut

sub build_field_info {
    my ($self, $section, $name) = @_;
    my $doc = $Doc_Config{$section}{$name};
    my $field = {
        id   => $name,
        name => $name,
        type => $self->field_type( $section, $name, $doc ),
        element_attr => {
            placeholder => $Defaults{$section}{$name}
        },
        tags => {
            after_element => \&help,
            help => do {
                my $d = $doc->{description};
                $d = join( "\n", @$d ) if ref($d) eq 'ARRAY';
                $d;
            },
        }
    };

    if (my $validate_method = $self->validator_for_field("$section.$name")) {
        $field->{validate_method} = $validate_method;
    }

    my $type = $doc->{type};
    my $method = "build_${type}_field";
    $self->$method($field, $section, $name, $doc);
    return $field;
}

=head2 build_toggle_field

build_toggle_field

=cut

sub build_toggle_field {
    my ($self, $field, $section, $name, $doc) = @_;
    $field->{checkbox_value}  = 'enabled';
    $field->{unchecked_value} = 'disabled';
    return ;
}

=head2 build_numeric_field

build_numeric_field

=cut

sub build_numeric_field {
    my ($self, $field, $section, $name, $doc) = @_;
    return ;
}

=head2 build_text_field

build_text_field

=cut

sub build_text_field {
    my ($self, $field, $section, $name, $doc) = @_;
    $field->{element_class} = ['input-xxlarge'];
    return ;
}

my %DOC_TYPE_2_FIELD_TYPE = (
    numeric => 'PosInteger',
    text => 'Text',
    toggle => 'Toggle',
);

=head2 field_type

field_type

=cut

sub field_type {
    my ($self, $section, $name, $doc) = @_;
    return $DOC_TYPE_2_FIELD_TYPE{$doc->{type}};
}

=head2 field_list

Dynamically build the field list from the 'section' instance attribute.

=cut

sub field_list {
    my $self = shift;
    my $section = $self->section;
    return [] if !defined $section;
    my @list;
    
    foreach my $name (keys %{$Doc_Config{$section}} ) {
        push @list, $self->build_field_info($section, $name);
    }

    return \@list;
}

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

package pfappserver::Form::Config::FingerbankSetting::KeyTestAPI;

# fingerbank::API using a given LWP client, to test a key through submitted proxy settings

use Moose;
extends 'fingerbank::API';

has 'lwp_client' => ( is => 'rw' );

sub get_lwp_client { $_[0]->lwp_client }

1;
