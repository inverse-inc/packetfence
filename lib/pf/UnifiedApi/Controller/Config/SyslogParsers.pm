package pf::UnifiedApi::Controller::Config::SyslogParsers;

=head1 NAME

pf::UnifiedApi::Controller::Config::SyslogParsers - 

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Controller::Config::SyslogParsers



=cut

use strict;
use warnings;


use Mojo::Base qw(pf::UnifiedApi::Controller::Config::Subtype);
use pf::error qw(is_error);

has 'config_store_class' => 'pf::ConfigStore::Pfdetect';
has 'form_class' => 'pfappserver::Form::Config::Pfdetect';
has 'primary_key' => 'syslog_parser_id';

use pf::ConfigStore::Pfdetect;
use pfappserver::Form::Config::Pfdetect;
use pfappserver::Form::Config::Pfdetect::dhcp;
use pfappserver::Form::Config::Pfdetect::fortianalyser;
use pfappserver::Form::Config::Pfdetect::regex;
use pfappserver::Form::Config::Pfdetect::security_onion;
use pfappserver::Form::Config::Pfdetect::snort;
use pfappserver::Form::Config::Pfdetect::suricata_md5;
use pfappserver::Form::Config::Pfdetect::suricata;
use pf::detect::parser::regex;

our %TYPES_TO_FORMS = (
    map { $_ => "pfappserver::Form::Config::Pfdetect::$_" } qw(
        dhcp
        fortianalyser
        regex
        security_onion
        snort
        suricata_md5
        suricata
    )
);

sub type_lookup {
    return \%TYPES_TO_FORMS;
}

=head2 dry_run

Dry run a regex parser configuration

=cut

sub dry_run {
    my ($self) = @_;
    my ( $error, $new_data ) = $self->get_json;
    if ( defined $error ) {
        return $self->render_error( 400, "Bad Request : $error" );
    }

    my ($status, $form) = $self->form($new_data);
    if ( is_error($status) ) {
        return $self->render_error( 422, "Cannot determine the valid type" );
    }

    if ($new_data->{type} ne 'regex') {
        return $self->render_error(422, "Type of $new_data->{type} does not support dry_run");
    }

    $form->process( params => $new_data, posted => 1, active => [qw(lines)]);
    if ($form->has_errors) {
        return $self->render_error(422, "Unable to validate", $self->format_form_errors($form));
    }

    my $data     = $form->value;
    my $lines = delete $data->{lines} // [];
    my $parser   = pf::detect::parser::regex->new($data);
    my $dryrun_info = $parser->dryRun(@$lines);
    return $self->render(status => 200, json => {items => $dryrun_info});
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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
