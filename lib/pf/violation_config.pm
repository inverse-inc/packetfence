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
use pf::trigger qw(trigger_delete_all parse_triggers);
use pf::class qw(class_merge);

our (%Violation_Config, $cached_violations_config);

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    # Categorized by feature, pay attention when modifying
    @EXPORT = qw(%Violation_Config $cached_violations_config readViolationConfigFile);
}

sub fileReloadViolationConfig {
    my ($config,$name) = @_;
    my $logger = get_logger();
    $logger->info("called $name");
    $config->toHash(\%Violation_Config);
    $config->cleanupWhitespace(\%Violation_Config);
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
        if ( defined $data->{'grace'} ) {
            $data->{'grace'} = normalize_time($data->{'grace'});
        }

        if ( defined $data->{'window'} && $data->{'window'} ne "dynamic" ) {
            $data->{'window'} = normalize_time($data->{'window'});
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
            $data->{'whitelisted_categories'} || '',
            $data->{'actions'},
            $triggers_ref
        );
    }
    $config->cache->set("Violation_Config",\%Violation_Config);
}

sub readViolationConfigFile {
    unless ($cached_violations_config) {
        $cached_violations_config = pf::config::cached->new(
            -file => $violations_config_file,
            -allowempty => 1,
            -default => 'defaults',
            -onfilereload => [file_reload_violation_config => \&fileReloadViolationConfig ],
            -oncachereload => [
                cache_reload_violation_config => sub {
                    my ($config,$name) = @_;
                    my $data = $config->cache->get("Violation_Config");
                    if($data) {
                        %Violation_Config = %$data;
                    } else {
                        fileReloadViolationConfig($config,$name);
                    }
                }
            ],
        );
        if ( scalar(@Config::IniFiles::errors) ) {
            my $logger = get_logger();
            $logger->error( "Error reading $violations_config_file " .  join( "\n", @Config::IniFiles::errors ) . "\n" );
            return 0;
        }
    } else {
        $cached_violations_config->ReadConfig();
    }
    return 1;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

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

