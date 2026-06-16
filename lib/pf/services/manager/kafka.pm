package pf::services::manager::kafka;

=head1 NAME

pf::services::manager::kafka -

=head1 DESCRIPTION

pf::services::manager::kafka

=cut

use strict;
use warnings;

use pf::file_paths qw(
    $generated_conf_dir
    $conf_dir
    $kafka_config_file
    $kafka_config_dir
);

use pf::IniFiles;
use Sys::Hostname;

use Template;
use pf::constants qw($TRUE $FALSE);
use pf::util qw(isenabled);
use pf::config qw ($management_network);
use pfconfig::cached_hash;

# The kafka ssl directory as seen from inside the kafka container (the host
# /usr/local/pf/conf/kafka directory is bind-mounted at the same path).
use constant KAFKA_SSL_DIR => '/usr/local/pf/conf/kafka/ssl';

tie our %ConfigKafka, 'pfconfig::cached_hash', "config::Kafka";

use Moo;
extends 'pf::services::manager';
has '+name' => (default => sub { 'kafka' } );

sub generateConfig {
    my ($self) = @_;
    my $tt = Template->new(
        ABSOLUTE => 1,
    );
    $self->generateEnvFile($tt);
    $self->generateAuthFile($tt);
    return 1;
}

sub generateAuthFile {
    my ($self, $tt) = @_;
    $tt->process(
        "${kafka_config_dir}/kafka_server_jaas.conf.tt",
        \%ConfigKafka,
        "${kafka_config_dir}/kafka_server_jaas.conf",
    ) or die $tt->error();
}

sub generateEnvFile {
    my ($self, $tt) = @_;
    my $vars = {
       env_dict => $self->env_vars,
    };
    $tt->process(
        "/usr/local/pf/containers/environment.template",
        $vars,
        $generated_conf_dir . "/" . $self->name . ".env"
    ) or die $tt->error();
}

sub env_vars {
    my ($self) = @_;
    my %env;
    my $hostname = hostname();
    my $mgmt_ip = (defined($management_network->tag('vip'))) ? $management_network->tag('vip') : $management_network->tag('ip');
    for my $top ('cluster', $hostname, '%hostname%') {
        while (my ($k, $v) = each %{$ConfigKafka{$top}}) {
            $v =~ s/%mgmtip%/$mgmt_ip/g;
            $env{$k} = $v;
        }
    }
    $self->add_ssl_env_vars(\%env);
    return \%env;
}

=head2 add_ssl_env_vars

When the [ssl] section is enabled, switch only the external listener to SSL and
add the Confluent keystore/truststore environment variables. Internal and
inter-broker listeners (and all advertised addresses/ports) are left untouched,
so only the external Kafka exchanges are secured with mTLS.

=cut

sub add_ssl_env_vars {
    my ($self, $env) = @_;
    my $ssl = $ConfigKafka{ssl};
    return unless $ssl && isenabled($ssl->{enabled});
    my $listener = $ssl->{listener} || 'EXTERNAL';

    # Flip just the external listener's security protocol to SSL; the listener
    # name, port and advertised address stay exactly as they were.
    _set_listener_protocol($env, $listener, 'SSL');

    $env->{KAFKA_SSL_KEYSTORE_LOCATION}   = KAFKA_SSL_DIR . "/keystore.p12";
    $env->{KAFKA_SSL_KEYSTORE_TYPE}       = "PKCS12";
    $env->{KAFKA_SSL_KEYSTORE_PASSWORD}   = $ssl->{keystore_password} // '';
    $env->{KAFKA_SSL_KEY_PASSWORD}        = $ssl->{keystore_password} // '';
    $env->{KAFKA_SSL_TRUSTSTORE_LOCATION} = KAFKA_SSL_DIR . "/truststore.p12";
    $env->{KAFKA_SSL_TRUSTSTORE_TYPE}     = "PKCS12";
    $env->{KAFKA_SSL_TRUSTSTORE_PASSWORD} = $ssl->{truststore_password} // '';

    # Require a trusted client certificate, scoped to the external listener only,
    # so internal/inter-broker traffic keeps its current security protocol.
    $env->{"KAFKA_LISTENER_NAME_${listener}_SSL_CLIENT_AUTH"} = "required";
}

# Set (or add) the security protocol of a single named listener in
# KAFKA_LISTENER_SECURITY_PROTOCOL_MAP, preserving every other listener.
sub _set_listener_protocol {
    my ($env, $listener, $proto) = @_;
    my $key = 'KAFKA_LISTENER_SECURITY_PROTOCOL_MAP';
    my @pairs = grep { /\S/ } split(/\s*,\s*/, $env->{$key} // '');
    my @out;
    my $found = 0;
    for my $pair (@pairs) {
        my ($name, $p) = split(/:/, $pair, 2);
        if (defined $name && $name eq $listener) {
            push @out, "$name:$proto";
            $found = 1;
        } else {
            push @out, $pair;
        }
    }
    push @out, "$listener:$proto" unless $found;
    $env->{$key} = join(",", @out);
}

sub isManaged {
    my ($self) = @_;
    my $hostname = hostname();
    ($self->SUPER::isManaged && (exists $ConfigKafka{$hostname} || exists $ConfigKafka{'%hostname%'})) ? $TRUE : $FALSE
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

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

1;

