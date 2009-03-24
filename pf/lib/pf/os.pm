package pf::os;

=head1 NAME

pf::os - module for DHCP fingerprints management.

=cut

=head1 DESCRIPTION

pf::os contains the functions necessary to read the DHCP fingerprints from
the fingerprint flat file and load them into the database.

=head1 CONFIGURATION AND ENVIRONMENT

Read the F<dhcp_fingerprints.conf> configuration file.

=cut

use strict;
use warnings;
use Log::Log4perl;

our (
    $dhcp_fingerprint_add_sql,  $os_delete_all_sql,
    $dhcp_fingerprint_view_sql, $dhcp_fingerprint_view_all_sql,
    $os_add_sql,                $os_class_add_sql,
    $os_mapping_add_sql,        $os_class_delete_all_sql,
    $os_db_prepared
);

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    @EXPORT
        = qw(read_dhcp_fingerprints_conf os_db_prepare dhcp_fingerprint_view dhcp_fingerprint_view_all);
}

use pf::config;
use pf::db;
use pf::trigger qw(trigger_in_range);

$os_db_prepared = 0;

#os_db_prepare($dbh) if (!$thread);

sub os_db_prepare {
    my ($dbh) = @_;
    db_connect($dbh);
    my $logger = Log::Log4perl::get_logger('pf::os');
    $logger->debug("Preparing pf::os database queries");
    $os_delete_all_sql        = $dbh->prepare(qq[ DELETE FROM os_type ]);
    $os_class_delete_all_sql  = $dbh->prepare(qq[ DELETE FROM os_class ]);
    $dhcp_fingerprint_add_sql = $dbh->prepare(
        qq [ INSERT INTO dhcp_fingerprint(fingerprint,os_id) VALUES(?,?) ]);
    $os_add_sql = $dbh->prepare(
        qq [ INSERT INTO os_type(os_id,description) VALUES(?,?) ]);
    $os_class_add_sql = $dbh->prepare(
        qq [ INSERT INTO os_class(class_id,description) VALUES(?,?) ]);
    $os_mapping_add_sql = $dbh->prepare(
        qq [ INSERT INTO os_mapping(os_type,os_class) VALUES(?,?) ]);
    $dhcp_fingerprint_view_sql
        = $dbh->prepare(
        qq [ SELECT d.fingerprint,o.os_id,o.description as os,c.class_id,c.description as class FROM dhcp_fingerprint d LEFT JOIN os_type o ON o.os_id=d.os_id LEFT JOIN os_mapping m ON m.os_type=o.os_id LEFT JOIN os_class c ON  m.os_class=c.class_id WHERE d.fingerprint=? GROUP BY c.class_id ORDER BY class_id ]
        );
    $dhcp_fingerprint_view_all_sql
        = $dbh->prepare(
        qq [ SELECT d.fingerprint,o.description as os,c.description as class FROM dhcp_fingerprint d LEFT JOIN os_type o ON o.os_id=d.os_id LEFT JOIN os_mapping m ON m.os_type=o.os_id LEFT JOIN os_class c ON  m.os_class=c.class_id ORDER BY class_id ]
        );

#$dhcp_fingerprint_view_all_sql=$dbh->prepare( qq [ SELECT d.fingerprint,o.description as os,c.description as class FROM dhcp_fingerprint d LEFT JOIN os_type o ON o.os_id=d.os_id LEFT JOIN os_mapping m ON m.os_type=o.os_id LEFT JOIN os_class c ON  m.os_class=c.class_id GROUP BY c.class_id ORDER BY class_id ]);
    $os_db_prepared = 1;
}

sub dhcp_fingerprint_view {
    my ($fingerprint) = @_;
    os_db_prepare($dbh) if ( !$os_db_prepared );
    return db_data( $dhcp_fingerprint_view_sql, $fingerprint );
}

sub dhcp_fingerprint_view_all {
    os_db_prepare($dbh) if ( !$os_db_prepared );
    return db_data($dhcp_fingerprint_view_all_sql);
}

sub read_dhcp_fingerprints_conf {
    my $logger = Log::Log4perl::get_logger('pf::os');
    my $fp_total;
    my %dhcp_fingerprints;
    os_db_prepare($dbh) if ( !$os_db_prepared );
    $os_delete_all_sql->execute();
    $os_class_delete_all_sql->execute();
    tie %dhcp_fingerprints, 'Config::IniFiles',
        ( -file => $dhcp_fingerprints_file );
    my @errors = @Config::IniFiles::errors;

    if ( scalar(@errors) ) {
        $logger->logdie( join( "\n", @errors ) );
    }
    my %seen_class;
    foreach my $os ( tied(%dhcp_fingerprints)->GroupMembers("os") ) {
        my $os_id = $os;
        $os_id =~ s/^os\s+//;
        $os_add_sql->execute( $os_id,
            $dhcp_fingerprints{$os}{"description"} );
        if ( exists( $dhcp_fingerprints{$os}{"fingerprints"} ) ) {
            if ( ref( $dhcp_fingerprints{$os}{"fingerprints"} ) eq "ARRAY" ) {
                foreach my $dhcp_fingerprint (
                    @{ $dhcp_fingerprints{$os}{"fingerprints"} } )
                {
                    $fp_total++;
                    $dhcp_fingerprint_add_sql->execute( $dhcp_fingerprint,
                        $os_id );
                }
            } else {
                foreach my $dhcp_fingerprint (
                    split(
                        /\n/,
                        $dhcp_fingerprints{$os}{"fingerprints"}
                    )
                    )
                {
                    $fp_total++;
                    $dhcp_fingerprint_add_sql->execute( $dhcp_fingerprint,
                        $os_id );
                }
            }
        }
        foreach my $class ( tied(%dhcp_fingerprints)->GroupMembers("class") )
        {
            my $os_class = $class;
            $os_class =~ s/^class\s+//;
            $os_class_add_sql->execute( $os_class,
                $dhcp_fingerprints{$class}{"description"} )
                if ( !$seen_class{$os_class} );
            $seen_class{$os_class} = 1;
            if (trigger_in_range(
                    $dhcp_fingerprints{$class}{"members"}, $os_id
                )
                )
            {
                $os_mapping_add_sql->execute( $os_id, $os_class );
            }
        }
    }
    return ($fp_total);
}

=head1 AUTHOR

David LaPorte <david@davidlaporte.org>

Kevin Amorin <kev@amorin.org>

=head1 COPYRIGHT

Copyright (C) 2005 David LaPorte

Copyright (C) 2005 Kevin Amorin

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
