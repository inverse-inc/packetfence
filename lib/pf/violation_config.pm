package pf::violation_config;

=head1 NAME

pf::violation_config

=cut

=head1 DESCRIPTION

pf::violation_config

=cut

use strict;
use warnings;
use pf::log;
use Try::Tiny;

use pf::config;
use pf::class qw(class_merge);
use pf::db;
use pfconfig::cached_hash;
use pf::util;
use pf::dal::class;

our (%Violation_Config);

tie %Violation_Config, 'pfconfig::cached_hash', 'config::Violations';


BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    # Categorized by feature, pay attention when modifying
    @EXPORT = qw(%Violation_Config);
}

sub loadViolationsIntoDb {
    my $logger = get_logger();
    unless(db_ping){
        $logger->error("Can't connect to db");
        return;
    }

    if (db_readonly_mode()) {
        my $msg = "Cannot reload violations when the database is in read only mode\n";
        print STDERR $msg;
        $logger->error($msg);
        return;
    }

    my @keys;
    while(my ($violation,$data) = each %Violation_Config) {
        # parse grace, try to understand trailing signs, and convert back to seconds
        my @time_values = qw(grace delay_by);
        push (@time_values,'window') if (defined $data->{'window'} && $data->{'window'} ne "dynamic");
        foreach my $key (@time_values) {
            my $value = $data->{$key};
            if ( defined $value ) {
                $data->{$key} = normalize_time($value);
            }
        }

        $violation = 0 if ($violation eq "defaults");

        # be careful of the way parameters are passed, whitelists, actions are expected at the end
        class_merge(
            $violation,
            $data->{'desc'} || '',
            $data->{'auto_enable'},
            $data->{'max_enable'},
            $data->{'grace'},
            $data->{'window'},
            $data->{'vclose'},
            $data->{'priority'},
            $data->{'template'},
            $data->{'max_enable_url'},
            $data->{'redirect_url'},
            $data->{'button_text'},
            $data->{'enabled'},
            $data->{'vlan'},
            $data->{'target_category'},
            $data->{'delay_by'},
            $data->{'external_command'},
            $data->{'whitelisted_roles'} || '',
            $data->{'actions'},
        );
        push @keys, $violation;
    }
    remove_deleted_violations(\@keys);
}

sub remove_deleted_violations {
    my ($ids) = @_;
    my ($status, $rows) = pf::dal::class->remove_by_search(
        {
            vid => { -not_in => $ids }
        }
    );
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>


=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

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
