package pf::cmd::pf::renew_lets_encrypt;
=head1 NAME

pf::cmd::pf::renew_lets_encrypt add documentation

=head1 SYNOPSIS

 pfcmd renew_lets_encrypt [http|radius|all]

Renews Let's Encrypt certificates

  http   | Renews the certificate for the HTTP resource if its enabled
  radius | Renews the certificate for the RADIUS resource if its enabled
  all    | Renews all the Let's Encrypt certificates that are enabled

  defaults to all

=head1 DESCRIPTION

pf::cmd::pf::renew_lets_encrypt

=cut

use strict;
use warnings;
use pf::constants::exit_code qw($EXIT_SUCCESS);
use pf::util;
use pf::ssl;
use pf::ssl::lets_encrypt;
use File::Slurp qw(read_file);

use base qw(pf::base::cmd::action_cmd);

sub default_action { 'all' }

sub action_http {
    my ($self) = @_;
    $self->renew_lets_encrypt("http");
}

sub action_radius {
    my ($self) = @_;
    $self->renew_lets_encrypt("radius");
}

sub action_all {
    my ($self) = @_;
    $self->renew_lets_encrypt();
}


sub renew_lets_encrypt {
    my ($self,$resource)  = @_;
    run_as_pf();

    my $config = pf::ssl::certs_map();
    
    my @to_renew;

    if(defined($resource)) {
        push @to_renew, $resource;
    }
    else {
        @to_renew =  keys(%$config);
    }

    for my $resource (@to_renew) {
        unless(isenabled(pf::ssl::lets_encrypt::resource_state($resource))) {
            print "- Let's Encrypt is not enabled for $resource. Skipping renewal. \n";
            next;
        }

        print "- Renewing certificate resource $resource \n";

        my $config = pf::ssl::certs_map()->{$resource};

        my $cert_str = read_file($config->{cert_file});
        my $old_cert = pf::ssl::x509_from_string($cert_str);

        my $common_name = pf::ssl::cn_from_dn($old_cert->subject());
        
        my ($result, $bundle) = pf::ssl::lets_encrypt::obtain_bundle($config->{key_file}, $common_name);

        unless($result) {
            print "-- Error while renewing certificate: $bundle \n";
            next;
        }

        my $cert = $bundle->{certificate};
        my $intermediate_cas = $bundle->{intermediate_cas};

        my $key_str = read_file($config->{key_file});

        my %to_install = (
            cert_file => join("\n", map { $_->as_string() } ($cert, @$intermediate_cas)),
            key_file => $key_str,
        );
        $to_install{bundle_file} = join("\n", $to_install{cert_file}, $to_install{key_file});

        my @errors = pf::ssl::install_to_file($resource, %to_install);

        if(scalar(@errors) > 0) {
            for my $error (@errors) {
                print "-- Error while renewing certificate: $error\n";
            }
        }
        else {
            print "-- Renewed certificate for $common_name successfully \n";
        }
    
    }

    return $EXIT_SUCCESS;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and::or
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

