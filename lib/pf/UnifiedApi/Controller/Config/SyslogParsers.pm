package pf::UnifiedApi::Controller::Config::SyslogParsers;

=head1 NAME

pf::UnifiedApi::Controller::Config::SyslogParsers - 

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Controller::Config::SyslogParsers



=cut

use strict;
use warnings;


use Mojo::Base qw(pf::UnifiedApi::Controller::Config);

has 'config_store_class' => 'pf::ConfigStore::Pfdetect';
has 'form_class' => 'pfappserver::Form::Config::Pfdetect';
has 'primary_key' => 'syslog_parser_id';

use pf::ConfigStore::Pfdetect;
use pfappserver::Form::Config::Pfdetect;

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

sub form {
    my ($self, $item) = @_;
    my $type = $item->{type};
    if ( !defined $type ) {
        $self->render_error(417, "Unable to validate", [{ type => "type field is required"}]);
        return undef;
    }

    if ( !exists $TYPES_TO_FORMS{$type} ){
        $self->render_error(417, "Unable to validate", [{ type => "type field is invalid '$type'"}]);
        return undef;
    }

    return $TYPES_TO_FORMS{$type}->new;
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

1;

