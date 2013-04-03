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

use constant OS => 'os';

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    @EXPORT = qw(
        os_db_prepare
        $os_db_prepared

        read_dhcp_fingerprints_conf
        dhcp_fingerprint_view
        dhcp_fingerprint_view_all
        dhcp_fingerprint_view_all_searchable
        dhcp_fingerprint_count
        import_dhcp_fingerprints
        update_dhcp_fingerprints_conf
        dhcp_fingerprint_count_searchable
    );
}

use pf::config;
use pf::config::cached;
use pf::db;

# The next two variables and the _prepare sub are required for database handling magic (see pf::db)
our $os_db_prepared = 0;
# in this hash reference we hold the database statements. We pass it to the query handler and he will repopulate
# the hash if required
our $os_statements = {};

=head1 SUBROUTINES

This list is incomplete.

=over

=cut

sub os_db_prepare {
    my $logger = Log::Log4perl::get_logger('pf::os');
    $logger->debug("Preparing pf::os database queries");

    $os_statements->{'os_delete_all_sql'} = get_db_handle()->prepare(qq[ DELETE FROM os_type ]);

    $os_statements->{'os_class_delete_all_sql'} = get_db_handle()->prepare(qq[ DELETE FROM os_class ]);

    $os_statements->{'dhcp_fingerprint_add_sql'} = get_db_handle()->prepare(
        qq [ INSERT INTO dhcp_fingerprint(fingerprint,os_id) VALUES(?,?) ]);

    $os_statements->{'os_add_sql'} = get_db_handle()->prepare(qq [ INSERT INTO os_type(os_id,description) VALUES(?,?) ]);

    $os_statements->{'os_class_add_sql'} = get_db_handle()->prepare(qq [ INSERT INTO os_class(class_id,description) VALUES(?,?) ]);

    $os_statements->{'os_mapping_add_sql'} = get_db_handle()->prepare(qq [ INSERT INTO os_mapping(os_type,os_class) VALUES(?,?) ]);

    $os_statements->{'dhcp_fingerprint_view_sql'} = get_db_handle()->prepare(qq[
         SELECT d.os_id AS id, d.fingerprint, o.description AS os, c.class_id AS classid, c.description AS class
         FROM dhcp_fingerprint d
            LEFT JOIN os_type o ON o.os_id=d.os_id
            LEFT JOIN os_mapping m ON m.os_type=o.os_id
            LEFT JOIN os_class c ON  m.os_class=c.class_id
         WHERE d.fingerprint=?
         GROUP BY c.class_id
         ORDER BY class_id
    ]);

    $os_statements->{'dhcp_fingerprint_view_all_sql'} = get_db_handle()->prepare(qq[
        SELECT d.os_id AS id, d.fingerprint, o.description AS os, c.class_id AS classid, c.description AS class
        FROM dhcp_fingerprint d
            LEFT JOIN os_type o ON o.os_id=d.os_id
            LEFT JOIN os_mapping m ON m.os_type=o.os_id
            LEFT JOIN os_class c ON  m.os_class=c.class_id
        ORDER BY class_id
    ]);


    $os_statements->{'dhcp_fingerprint_count_sql'} = get_db_handle()->prepare(<<"    SQL");
        SELECT count(*) FROM dhcp_fingerprint;
    SQL

    $os_db_prepared = 1;
}

sub update_dhcp_fingerprints_conf {
    require LWP::UserAgent;
    my $logger = Log::Log4perl::get_logger('pf::os');
    my $browser = LWP::UserAgent->new;
    my $response = $browser->get($dhcp_fingerprints_url);
    my ($status,$version_or_msg,$total) = ($response->code,undef,undef);
    if ( !$response->is_success ) {
        $version_or_msg = "Unable to update DHCP fingerprints: " . $response->status_line;
    } else {
        my ($fingerprints_fh);
        if( open( $fingerprints_fh, '>', "$dhcp_fingerprints_file" ) ) {
            my $fingerprints = $response->content;
            ($version_or_msg)
                = $fingerprints
                =~ /^#\s+dhcp_fingerprints.conf:\s+(version.+?)\n/;
            print $fingerprints_fh $fingerprints;
            close($fingerprints_fh);
            $logger->info(
                "DHCP fingerprints updated via $dhcp_fingerprints_url to $version_or_msg"
            );
            $total = pf::os::import_dhcp_fingerprints({ force => $TRUE });
            $logger->info("$total DHCP fingerprints reloaded");
        }
        else {
           $version_or_msg = "Unable to open $dhcp_fingerprints_file: $!";
        }
    }
    return ($status,$version_or_msg,$total);

}

sub dhcp_fingerprint_view {
    my ($fingerprint) = @_;
    return db_data(OS, $os_statements, 'dhcp_fingerprint_view_sql', $fingerprint );
}

sub dhcp_fingerprint_view_all {
    return db_data(OS, $os_statements, 'dhcp_fingerprint_view_all_sql');
}

=item dhcp_fingerprint_view_all

view all nodes based on several criterias

=cut

sub dhcp_fingerprint_view_all_searchable {
    my ( %params ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::os');

    os_db_prepare() if (!$os_db_prepared);
    my $sql = qq[
        SELECT d.os_id AS id, d.fingerprint, o.description AS os, c.class_id AS classid, c.description AS class
        FROM dhcp_fingerprint d
            LEFT JOIN os_type o ON o.os_id=d.os_id
            LEFT JOIN os_mapping m ON m.os_type=o.os_id
            LEFT JOIN os_class c ON  m.os_class=c.class_id
        ];

    if ( defined( $params{'where'} ) ) {
        my $where = $params{'where'};
        if ( $where->{type} eq 'any' && $where->{like} ne '' ) {
            my $like = " LIKE " . get_db_handle()->quote('%' . $params{'where'}{'like'} . '%');
            $sql .= " WHERE " . join (' or ',map { "$_ $like"  } qw(c.description o.description));
        }
    }
    if ( defined( $params{'orderby'} ) ) {
        $sql .= " " . $params{'orderby'};
    }
    if ( defined( $params{'limit'} ) ) {
        $sql .= " " . $params{'limit'};
    }

    # Hack! Because of the nature of the query built here (we cannot prepare it), we construct it as a string
    # and pf::db will recognize it and prepare it as such
    $os_statements->{'dhcp_fingerprint_view_all_sql_custom'} = $sql;
    $logger->info($sql);

    return db_data(OS, $os_statements, 'dhcp_fingerprint_view_all_sql_custom');
}

sub dhcp_fingerprint_count_searchable {
    my ( %params ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::os');

    os_db_prepare() if (!$os_db_prepared);
    my $sql = qq[
        SELECT count(*) FROM dhcp_fingerprint d
            LEFT JOIN os_type o ON o.os_id=d.os_id
            LEFT JOIN os_mapping m ON m.os_type=o.os_id
            LEFT JOIN os_class c ON  m.os_class=c.class_id
        ];

    if ( defined( $params{'where'} ) ) {
        my $where = $params{'where'};
        if ( $where->{type} eq 'any' && $where->{like} ne '' ) {
            my $like = " LIKE " . get_db_handle()->quote('%' . $params{'where'}{'like'} . '%');
            $sql .= " WHERE " . join (' or ',map { "$_ $like"  } qw(c.description o.description));
        }
    }
    # Hack! Because of the nature of the query built here (we cannot prepare it), we construct it as a string
    # and pf::db will recognize it and prepare it as such
    $os_statements->{'dhcp_fingerprint_view_all_sql_custom'} = $sql;
    $logger->info($sql);

    my $query = db_query_execute(OS, $os_statements, 'dhcp_fingerprint_view_all_sql_custom');
    my ($val) = $query->fetchrow_array();
    $query->finish();
    return ($val);
}

sub dhcp_fingerprint_count {
    my $query = db_query_execute(OS, $os_statements, 'dhcp_fingerprint_count_sql');
    my ($val) = $query->fetchrow_array();
    $query->finish();
    return ($val);
}

=item import_dhcp_fingerprints

Import all DHCP fingerprints if we currently don't have any in the table.
Options:

  force => $TRUE: will trigger the import anyway

=cut

sub import_dhcp_fingerprints {
    my ($opts_ref) = @_;
    my $logger = Log::Log4perl::get_logger('pf::os');

    if (dhcp_fingerprint_count() != 0 && !$opts_ref->{'force'}) {
        $logger->debug("DHCP fingerprints already present in database: Not loading again.");
        return 0;
    }

    return read_dhcp_fingerprints_conf();
}

sub read_dhcp_fingerprints_conf {
    my $logger = Log::Log4perl::get_logger('pf::os');
    my $fp_total;
    my %dhcp_fingerprints;

    db_query_execute(OS, $os_statements, 'os_delete_all_sql');
    db_query_execute(OS, $os_statements, 'os_class_delete_all_sql');
    tie %dhcp_fingerprints, 'pf::config::cached',
        ( -file => $dhcp_fingerprints_file );
    my @errors = @Config::IniFiles::errors;

    if ( scalar(@errors) ) {
        $logger->logcroak( join( "\n", @errors ) );
    }

    my %seen_class;
    foreach my $os ( tied(%dhcp_fingerprints)->GroupMembers("os") ) {
        my $os_id = $os;
        $os_id =~ s/^os\s+//;
        db_query_execute(OS, $os_statements, 'os_add_sql', $os_id, $dhcp_fingerprints{$os}{"description"});
        if ( exists( $dhcp_fingerprints{$os}{"fingerprints"} ) ) {
            if ( ref( $dhcp_fingerprints{$os}{"fingerprints"} ) eq "ARRAY" ) {
                foreach my $dhcp_fingerprint (
                    @{ $dhcp_fingerprints{$os}{"fingerprints"} } )
                {
                    $fp_total++;
                    db_query_execute(OS, $os_statements, 'dhcp_fingerprint_add_sql', $dhcp_fingerprint, $os_id);
                }
            } else {
                foreach my $dhcp_fingerprint (
                    split(/\n/, $dhcp_fingerprints{$os}{"fingerprints"})) {

                    $fp_total++;
                    db_query_execute(OS, $os_statements, 'dhcp_fingerprint_add_sql', $dhcp_fingerprint, $os_id);
                }
            }
        }

        foreach my $class ( tied(%dhcp_fingerprints)->GroupMembers("class") ) {

            my $os_class = $class;
            $os_class =~ s/^class\s+//;
            db_query_execute(OS, $os_statements, 'os_class_add_sql',
                $os_class, $dhcp_fingerprints{$class}{"description"}) if ( !$seen_class{$os_class} );
            $seen_class{$os_class} = 1;

            if (_class_member_in_range($dhcp_fingerprints{$class}{"members"}, $os_id)) {
                db_query_execute(OS, $os_statements, 'os_mapping_add_sql', $os_id, $os_class);
            }
        }
    }
    return ($fp_total);
}

=item _class_member_in_range

Handles the F<dhcp_fingerprints.conf> members=... field. If a given OS is in a member range returns true otherwise false.

=cut

sub _class_member_in_range {
    my ( $range, $member ) = @_;
    foreach my $element ( split( /\s*,\s*/, $range ) ) {
        if ( $element eq $member ) {
            return $TRUE;
        } elsif ( $element =~ /^\d+\s*\-\s*\d+$/ ) {
            my ( $begin, $end ) = split( /\s*\-\s*/, $element );
            if ( $member >= $begin && $member <= $end ) {
                return $TRUE;
            }
        } else {
            return $FALSE;
        }
    }
    return;
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

Copyright (C) 2005 Kevin Amorin

Copyright (C) 2005 David LaPorte

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
