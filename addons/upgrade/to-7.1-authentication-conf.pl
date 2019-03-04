#!/usr/bin/perl

=head1 NAME

to-7.1-authentication-conf

=cut

=head1 DESCRIPTION

Add default required fields for SQL Twilio and SMS sources

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);
use pf::IniFiles;
use pf::Authentication::Source::TwilioSource;
use pf::Authentication::Source::SMSSource;
use pf::Authentication::Source::SQLSource;
use pf::file_paths qw($authentication_config_file);
my $twilio_meta = pf::Authentication::Source::TwilioSource->meta;
my $sms_meta    = pf::Authentication::Source::SMSSource->meta;
my $sql_meta    = pf::Authentication::Source::SQLSource->meta;

my %source_fields_to_update = (
    make_source_update_data(Twilio => qw(create_local_account local_account_logins pin_code_length)),
    make_source_update_data(SMS => qw(pin_code_length)),
    make_source_update_data(SQL => qw(stripped_user_name)),
);

sub make_source_update_data {
    my ( $type, @fields ) = @_;
    return unless @fields;
    my $meta = "pf::Authentication::Source::${type}Source"->meta;
    return $type =>
      { map { updated_field($meta, $_) } @fields };
}

sub updated_field {
    my ($meta, $f) = @_;
    my $attr = $meta->get_attribute($f);
    if (!defined $attr) {
        return;
    }
    return $f => $attr->default;
}

exit 0 unless -e $authentication_config_file;
my $ini =
  pf::IniFiles->new( -file => $authentication_config_file, -allowempty => 1 );

for my $section ( $ini->Sections() ) {
    next if $section =~ / /;
    next unless $ini->exists( $section, 'type' );
    my $type = $ini->val( $section, 'type' );
    unless ( exists $source_fields_to_update{$type} ) {
        next;
    }
    print "Updating $section\n";
    while ( my ( $k, $v ) = each %{ $source_fields_to_update{$type} } ) {
        if ( !$ini->exists( $section, $k ) ) {
            print "  $k updated\n";
            $ini->newval( $section, $k, $v );
        }
    }
}

$ini->RewriteConfig();

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

