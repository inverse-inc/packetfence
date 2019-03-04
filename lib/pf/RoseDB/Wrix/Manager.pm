package pf::RoseDB::Wrix::Manager;
=head1 NAME

pf::RoseDB::Wrix::Manager add documentation

=cut

=head1 DESCRIPTION

pf::RoseDB::Wrix::Manager

=cut

use strict;
use warnings;
use base qw(pf::Base::RoseDB::Wrix::Manager);
use pf::RoseDB::Wrix;
use Text::CSV;
use DateTime;

sub object_class { "pf::RoseDB::Wrix" }

sub csvImporter {
    my ($self) = @_;
    return Text::CSV->new ({
        quote_char          => '"',
        escape_char         => '"',
        sep_char            => ',',
        always_quote        => 1,
        quote_space         => 1,
        quote_null          => 1,
        binary              => 0,
        keep_meta_info      => 0,
        allow_loose_quotes  => 0,
        allow_loose_escapes => 0,
        allow_whitespace    => 0,
        blank_is_undef      => 0,
        empty_is_undef      => 0,
        verbatim            => 0,
        auto_diag           => 0,
    });
}

sub csvExporter {
    my ($self,$file) = @_;
    return Text::CSV->new ({
        quote_char          => '"',
        escape_char         => '"',
        sep_char            => ',',
        always_quote        => 1,
        quote_space         => 1,
        quote_null          => 1,
        binary              => 0,
        keep_meta_info      => 0,
        allow_loose_quotes  => 0,
        allow_loose_escapes => 0,
        allow_whitespace    => 0,
        blank_is_undef      => 0,
        empty_is_undef      => 0,
        verbatim            => 0,
        auto_diag           => 0,
        eol                 => "\r\n"
    });
}

our @FIELDS = (
    'Provider_Identifier',
    'Location_Identifier',
    'Service_Provider_Brand',
    'Location_Type',
    'Sub_Location_Type',
    'English_Location_Name',
    'Location_Address1',
    'Location_Address2',
    'English_Location_City',
    'Location_Zip_Postal_Code',
    'Location_State_Province_Name',
    'Location_Country_Name',
    'Location_Phone_Number',
    'SSID_Open_Auth',
    'SSID_Broadcasted',
    'WEP_Key',
    'WEP_Key_Entry_Method',
    'WEP_Key_Size',
    'SSID_1X',
    'SSID_1X_Broadcasted',
    'Security_Protocol_1X',
    'Client_Support',
    'Restricted_Access',
    'Location_URL',
    'Coverage_Area',
    'Open_Monday',
    'Open_Tuesday',
    'Open_Wednesday',
    'Open_Thursday',
    'Open_Friday',
    'Open_Saturday',
    'Open_Sunday',
    'Longitude',
    'Latitude',
    'UTC_Timezone',
    'MAC_Address'
);


sub importCsv {
    my ($self,$file) = @_;
    my $rows = $self->getRows($file);
    foreach my $row (@$rows) {
        my $data = $self->makeEntry($row);
        my $object = $self->object_class->new(%$data);
        $object->load( speculative => 1);
        $object->save;
    }
    return 1;
}

sub exportCsv {
    my ($self,$fh) = @_;
    my $it = $self->get_objects_iterator;
    my $csvExporter = $self->csvExporter;
    my $eol = $csvExporter->eol || $/;
    print $fh  DateTime->now->strftime("Version 1.1 %B %d %Y$eol");
    $csvExporter->print($fh,\@FIELDS);
    while(my $row = $it->next) {
       my @cols = map { $row->$_() } @FIELDS;
       $csvExporter->print($fh,\@cols);
    }
}

sub getRows {
    my ($self,$file) = @_;
    my $csvImporter = $self->csvImporter;
    my $row;
    my $fh;
    open($fh,"<$file") or die "unable to open $file";
    return $csvImporter->getline_all ($fh,2);
}

sub makeEntry {
    my ($self,$row) = @_;
    my %data;
    @data{@FIELDS} = @$row;
    $data{id} = $data{Location_Identifier};
    return \%data;
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

