package pf::violation_config;

=head1 NAME

pf::violation_config

=cut

=head1 DESCRIPTION

pf::violation_config

=cut

use strict;
use warnings;
use Log::Log4perl qw(get_logger);
use Try::Tiny;

use pf::config;
use pf::trigger qw(trigger_delete_all parse_triggers);
use pf::class qw(class_merge);
use pf::db;

our (%Violation_Config, $cached_violations_config);

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    # Categorized by feature, pay attention when modifying
    @EXPORT = qw(%Violation_Config $cached_violations_config);
}

sub fileReloadViolationConfig {
    my ($config,$name) = @_;
    $config->toHash(\%Violation_Config);
    $config->cleanupWhitespace(\%Violation_Config);
    $config->cacheForData->set("Violation_Config",\%Violation_Config);
}

sub loadViolationsIntoDb {
    my ($config,$name) = @_;
    my $logger = get_logger();
    return unless db_ping;
    trigger_delete_all();
    while(my ($violation,$data) = each %Violation_Config) {
        # parse triggers if they exist
        my $triggers_ref = [];
        if ( defined $data->{'trigger'} ) {
            try {
                $triggers_ref = parse_triggers($data->{'trigger'});
            } catch {
                $logger->warn("Violation $violation is ignored: $_");
                $triggers_ref = [];
            };
        }

        # parse grace, try to understand trailing signs, and convert back to seconds
        my @time_values = (qw(grace delay_by));
        push (@time_values,'window') if (defined $data->{'window'} && $data->{'window'} ne "dynamic");
        foreach my $key (@time_values) {
            my $value = $data->{$key};
            if ( defined $value ) {
                $data->{$key} = normalize_time($value);
            }
        }

        # be careful of the way parameters are passed, whitelists, actions and triggers are expected at the end
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
            $data->{'whitelisted_categories'} || '',
            $data->{'actions'},
            $triggers_ref
        );
    }
}

$cached_violations_config = pf::config::cached->new(
    -file => $violations_config_file,
    -allowempty => 1,
    -default => 'defaults',
    -onfilereload => [file_reload_violation_config => \&fileReloadViolationConfig ],
    -onfilereloadonce => [ file_reload_once_violation_config => \&loadViolationsIntoDb ],
    -oncachereload => [
        cache_reload_violation_config => sub {
            my ($config,$name) = @_;
            my $data = $config->fromCacheForDataUntainted("Violation_Config");
            if($data) {
                %Violation_Config = %$data;
            } else {
                $config->_callFileReloadCallbacks();
            }
        }
    ],
);

=head1 AUTHOR

Inverse inc. <info@inverse.ca>


=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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

