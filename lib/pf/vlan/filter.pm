package pf::vlan::filter;

=head1 NAME

pf::vlan::filter - handle the authorization rules on the vlan attribution

=cut

=head1 DESCRIPTION

pf::vlan::filter deny, rewrite role based on rules. 

=cut

use strict;
use warnings;

use Log::Log4perl;
use Time::Period;
use pf::config qw(%connection_type_to_str);

our (%ConfigVlanFilters, $cached_vlan_filters_config);

readVlanFiltersFile();

=head1 SUBROUTINES

=over

=item new

=cut

sub new {
   my $logger = Log::Log4perl::get_logger("pf::vlan::filter");
   $logger->debug("instantiating new pf::vlan::filter");
   my ( $class, %argv ) = @_;
   my $self = bless {}, $class;
   return $self;
}

=item test

Test all the rules

=cut

sub test {
    my ($self, $scope, $switch,$ifIndex,$mac,$node_info,$connection_type,$user_name,$ssid) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );

    foreach my $rule  ( sort keys %ConfigVlanFilters ) {
        if ( defined($ConfigVlanFilters{$rule}->{'scope'}) && $ConfigVlanFilters{$rule}->{'scope'} eq $scope) {
            if ($rule =~ /^\w+:(.*)$/) {
                my $test = $1;
                $test =~ s/(\w+)/$self->dispatch_rule($ConfigVlanFilters{$1},$switch,$ifIndex,$mac,$node_info,$connection_type,$user_name,$ssid,$1)/gee;
                $test =~ s/\|/ \|\| /g;
                $test =~ s/\&/ \&\& /g;
                if (eval $test) {
                    $logger->info("Match Vlan rule: ".$rule." for ".$mac);
                    my $role = $ConfigVlanFilters{$rule}->{'role'};
                    #TODO Add action that can be sent to the WebAPI
                    my $vlan = $switch->getVlanByName($role);
                    return ($vlan, $role);
                }
            }
        }
    }
}

=item dispatch_rules

Return the reference to the function that parses the rule.

=cut

sub dispatch_rule {
    my ($self, $rule, $switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid, $name) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );

    if (!defined($rule)) {
        $logger->error("The rule $name you try to test doesn´t exist");
    }

    my $key = {
        node_info => \&node_info_parser,
        switch  => \&switch_parser,
        ifIndex  => \&ifindex_parser,
        mac  => \&mac_parser,
        connection_type  => \&connection_type_parser,
        username  => \&username_parser,
        ssid  => \&ssid_parser,
        time => \&time_parser,
    };
    return $key->{$rule->{'filter'}}->($self, $rule, $switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid);
}

=item node_info_parser

Parse the node_info attribute and compare to the rule. If it matches then perform the action.

=cut

sub node_info_parser {
    my ($self, $rule, $switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid) = @_;

    if (defined($node_info)) {
        if ($rule->{'operator'} eq 'is') {
            if ($node_info->{$rule->{'attribute'}} eq $rule->{'value'}) {
                return 1;
            } else {
                return 0;
            }
        } elsif ($rule->{'operator'} eq 'is_not') {
            if ($node_info->{$rule->{'attribute'}} ne $rule->{'value'}) {
                return 1;
            } else {
                return 0;
        }
        } elsif  ($rule->{'operator'} eq 'match') {
            if ($node_info->{$rule->{'attribute'}} =~ m/$rule->{'value'}/) {
                return 1;
            } else {
                return 0;
            }
        } elsif ($rule->{'operator'} eq 'match_not') {
            if ($node_info->{$rule->{'attribute'}} !~ m/$rule->{'value'}/) {
                return 1;
            } else {
                return 0;
            }
        } else {
            return 0;
        }
    } else {
        return 0;
    }
}

=item switch_parser

Parse the switch attribute and compare to the rule. If it matches then return true.

=cut

sub switch_parser {
    my ($self, $rule, $switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid) = @_;

    if (defined($switch)) {
        if ($rule->{'operator'} eq 'is') {
            if ($switch->{$rule->{'attribute'}} eq $rule->{'value'}) {
                return 1;
            } else {
                return 0;
            }
        } elsif ($rule->{'operator'} eq 'is_not') {
            if ($switch->{$rule->{'attribute'}} ne $rule->{'value'}) {
                return 1;
            } else {
                return 0;
            }
        } elsif ($rule->{'operator'} eq 'match') {
            if ($switch->{$rule->{'attribute'}} =~ m/$rule->{'value'}/) {
                return 1;
            } else {
                return 0;
            }
        } elsif ($rule->{'operator'} eq 'match_not') {
            if ($switch->{$rule->{'attribute'}} !~ m/$rule->{'value'}/) {
                return 1;
            } else {
                return 0;
            }
        } else {
            return 0;
        }
    } else {
        return 0;
    }
}

=item ifindex_parser

Parse the ifindex value and compare to the rule. If it matches then return true.

=cut

sub ifindex_parser {
    my ($self, $rule, $switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid) = @_;

    if (defined($ifIndex)) {
        if ($rule->{'operator'} eq 'is') {
            if ($ifIndex eq $rule->{'value'}) {
                return 1;
            } else {
                return 0;
            }
        } elsif ($rule->{'operator'} eq 'is_not') {
            if ($ifIndex ne $rule->{'value'}) {
                return 1;
            } else {
                return 0;
            }
        } elsif ($rule->{'operator'} eq 'match') {
            if ($ifIndex =~ m/$rule->{'value'}/) {
                return 1;
            } else {
                return 0;
            }
        } elsif ($rule->{'operator'} eq 'match_not') {
            if ($ifIndex !~ m/$rule->{'value'}/) {
                return 1;
            } else {
                return 0;
            }
        } else {
            return 0;
        }
    } else {
        return 0;
    }
}

=item mac_parser

Parse the mac value and compare to the rule. If it matches then return.

=cut

sub mac_parser {
    my ($self, $rule, $switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid) = @_;

    if (defined($mac)) {
        if ($rule->{'operator'} eq 'is') {
            if ($mac eq $rule->{'value'} ) {
                return 1;
            } else {
                return 0;
            }
        } elsif ($rule->{'operator'} eq 'is_not') {
            if ($mac ne $rule->{'value'}) {
                return 1;
            } else {
                return 0;
            }
        } elsif ($rule->{'operator'} eq 'match') {
            if ($mac =~ m/$rule->{'value'}/) {
                return 1;
            } else {
                return 0;
            }
        } elsif ($rule->{'operator'} eq 'match_not') {
            if ($mac !~ m/$rule->{'value'}/) {
                return 1;
            } else {
                return 0;
            }
        } else {
            return 0;
        }
    } else {
        return 0;
    }
}

=item connection_type_parser

Parse the connection_type value and compare to the rule. If it matches then return true.

=cut

sub connection_type_parser {
    my ($self, $rule, $switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid) = @_;
 
    if (defined($connection_type)) {
        if ($rule->{'operator'} eq 'is') {
            if ($connection_type_to_str{$connection_type} eq $rule->{'value'}) {
                return 1;
            } else {
                return 0;
            }
        } elsif ($rule->{'operator'} eq 'is_not') {
            if ($connection_type_to_str{$connection_type} ne $rule->{'value'}) {
                return 1;
            } else {
                return 0;
            }
        } elsif ($rule->{'operator'} eq 'match') {
            if ($connection_type_to_str{$connection_type} =~ m/$rule->{'value'}/) {
                return 1;
            } else {
                return 0;
            }
        } elsif ($rule->{'operator'} eq 'match_not') {
            if ($connection_type_to_str{$connection_type} !~ m/$rule->{'value'}/) {
                return 1;
            } else {
                return 0;
            }
        } else {
            return 0;
        }
    } else {
        return 0;
    }
}

=item username_parser

Parse the ursername value and compare to the rule. If it matches then return true.

=cut

sub username_parser {
    my ($self, $rule, $switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid) = @_;

    if (defined($user_name)) {
        if ($rule->{'operator'} eq 'is') {
            if ($user_name eq $rule->{'value'}) {
                return 1;
            } else {
                return 0;
            }
        } elsif ($rule->{'operator'} eq 'is_not') {
            if ($user_name ne $rule->{'value'}) {
                return 1;
            } else {
                return 0;
            }
        } elsif ($rule->{'operator'} eq 'match') {
            if ($user_name =~ m/$rule->{'value'}/) {
                return 1;
            } else {
                return 0;
            }
        } elsif ($rule->{'operator'} eq 'match_not') {
            if ($user_name !~ m/$rule->{'value'}/) {
                return 1;
            } else {
                return 0;
            }
        } else {
            return 0;
        }
    } else {
        return 0;
    }
}

=item ssid_parser

Parse the ssid valus and compare to the rule. If it matches then return true.

=cut

sub ssid_parser {
    my ($self, $rule, $switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid) = @_;

    if (defined($ssid)) {
        if ($rule->{'operator'} eq 'is') {
            if ($ssid eq $rule->{'value'}) {
                return 1;
            } else {
                return 0;
            }
        } elsif ($rule->{'operator'} eq 'is_not') {
            if ($ssid ne $rule->{'value'}) {
                return 1;
            } else {
                return 0;
            }
        } elsif ($rule->{'operator'} eq 'match') {
            if ($ssid =~ m/$rule->{'value'}/) {
                return 1;
            } else {
                return 0;
            }
        } elsif ($rule->{'operator'} eq 'match_not') {
            if ($ssid !~ m/$rule->{'value'}/) {
                return 1;
            } else {
                return 0;
            }
        } else {
            return 0;
        }
    } else {
        return 0;
    }
}

=item time_parser

Check the current time and compare to the period

=cut

sub time_parser {
    my ($self, $rule, $switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid) = @_;

    my $time = time();
    if ($rule->{'operator'} eq 'is') {
        if (inPeriod($time,$rule->{'value'})) {
            return 1;
        } else {
            return 0;
        }
    } elsif ($rule->{'operator'} eq 'is_not') {
        if (!inPeriod($time,$rule->{'value'})) {
            return 1;
        } else {
            return 0;
        }
    } else {
        return 0;
    }
}



=item readVlanFiltersFile - vlan_filters.conf

=cut

sub readVlanFiltersFile {
    $cached_vlan_filters_config = pf::config::cached->new(
        -file => $vlan_filters_config_file,
        -allowempty => 1,
        -onreload => [ reload_vlan_filters_config => sub {
            my ($config) = @_;
            $config->toHash(\%ConfigVlanFilters);
            $config->cleanupWhitespace(\%ConfigVlanFilters);
        }]
    );
    if(@Config::IniFiles::errors) {
        my $logger = Log::Log4perl::get_logger("pf::vlan::filter");
        $logger->logcroak( join( "\n", @Config::IniFiles::errors ) );
    }
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2014 Inverse inc.

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

