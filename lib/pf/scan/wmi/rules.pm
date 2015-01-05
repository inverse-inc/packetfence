package pf::scan::wmi::rules;

=head1 NAME

pf::scan::wmi::rules - Test wmi rules

=cut

=head1 DESCRIPTION

pf::scan::wmi::rules deny or allow based on rules. 

=cut

use strict;
use warnings;

use Log::Log4perl;
use Net::WMIClient qw(wmiclient);
use pf::api::jsonrpcclient;
use pf::ConfigStore::WMI();

=head1 SUBROUTINES

=over

=item new

=cut

sub new {
   my $logger = Log::Log4perl::get_logger("pf::scan::wmi::rules");
   $logger->debug("instantiating new pf::scan::wmi::rules");
   my ( $class, %argv ) = @_;
   my $self = bless {}, $class;
   return $self;
}

=item test

Test all the rules

=cut

sub test {
    my ($self, $rules) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );
    my $wmics = pf::ConfigStore::WMI->new();

    foreach my $rule  ( @{$rules->{'_rules'}} ) {
        $logger->warn($rule);
        my $rule_config = $wmics->read($rule);
        my $result = $self->runWmi($rules,$rule_config);

        if ($rule_config =~ /^\w+:(.*)$/) {
            my $test = $1;
            $test =~ s/(\w+)/$self->parse($rule_config,$result)/gee;
            $test =~ s/\|/ \|\| /g;
            $test =~ s/\&/ \&\& /g;
            if (eval $test) {
                $logger->info("Match WMI rule: ".$rule_config." for ".$mac);
                if ( defined($ConfigVlanFilters{$rule}->{'action'}) && $ConfigVlanFilters{$rule}->{'action'} ne '' ) {
                    $self->dispatchAction($ConfigVlanFilters{$rule},$switch,$ifIndex,$mac,$node_info,$connection_type,$user_name,$ssid,$radius_request)
                }
                if ( defined($ConfigVlanFilters{$rule}->{'role'}) && $ConfigVlanFilters{$rule}->{'role'} ne '' ) {
                    my $role = $ConfigVlanFilters{$rule}->{'role'};
                    my $vlan = $switch->getVlanByName($role);
                    return ($vlan, $role);
                } else {
                    return (0,0);
                }
            }
        }
    }
}

sub runWmi {
    my ($self, $rules, $rule) = @_;

    my $request = {};
    $request->{'Username'} = $rules->{'_domain'} .'/'. $rules->{'_username'} .'%'. $rules->{'_password'};
    $request->{'Host'} = $rules->{'_scanIp'};
    $request->{'Query'} = $rule->{'request'};

    my ($rc, $ret_string) = wmiclient($request);
    return $self->parseResult($ret_string);

}

sub parseResult {
    my ($self, $string) = @_;
    $string =~ s/\r\n/\n/g;

    my @ans = split('\n', $string);
    my $i = 0;
    my $line;
    my @result;

    my $resultat = {};

    shift @ans;
    my @entries = split(/\|/,shift @ans);


    foreach $line (@ans) {
        my @values = split(/\|/,$line);
        my $j = 0;
        foreach my $elements (@entries) {
            $resultat->{"$elements"} = @values[$j];
            $j++;
        }
        $result[$i] = $resultat;
        undef $resultat;
        $i++;
    }
return \@result;
}

our %RULE_PARSERS = (
    node_info => \&node_info_parser,
    switch  => \&switch_parser,
    ifIndex  => \&ifindex_parser,
    mac  => \&mac_parser,
    connection_type  => \&connection_type_parser,
    username  => \&username_parser,
    ssid  => \&ssid_parser,
    time => \&time_parser,
    owner => \&owner_parser,
    radius_request => \&radius_parser,
);

=item dispatchRule

Return the reference to the function that parses the rule.

=cut

sub dispatchRule {
    my ($self, $rule, $switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid, $radius_request, $name) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );

    if (!defined($rule)) {
        $logger->error("The rule $name you try to test doesn´t exist");
    }

    return $RULE_PARSERS{$rule->{'filter'}}->($self, $rule, $switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid, $radius_request);
}

=item dispatchAction

Return the reference to the function that call the api.

=cut

sub dispatchAction {
    my ($self, $rule, $switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid, $radius_request) = @_;

    my $param = $self->evalParam($rule->{'action_param'},$switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid, $radius_request);
    my $apiclient = pf::api::jsonrpcclient->new;
    $apiclient->notify($rule->{'action'},%{$$param});
}

=item evalParam

evaluate action parameters

=cut

sub evalParam {
    my ($self, $action_param, $switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid, $radius_request) = @_;
    $action_param =~ s/\s//g;
    my @params = split(',', $action_param);
    my $return = {};

    foreach my $param (@params) {
        $param =~ s/(\$.*)/$1/gee;
        my @param_unit = split('=',$param);
        $return = { %$return, @param_unit };
    }
    return \$return;
}

our %RULE_OPS = (
    is => sub { $_[0] eq $_[1] ? 1 : 0  },
    is_not => sub { $_[0] ne $_[1] ? 1 : 0  },
    match => sub { $_[0] =~ $_[1] ? 1 : 0  },
    match_not => sub { $_[0] !~ $_[1] ? 1 : 0  },
);

=item _match_rule_against_hash

Matches the rule against a hash

=cut

sub _match_rule_against_hash {
    my ($self, $rule, $data) = @_;

    if (defined($data)) {
        return $self->_match_rule_against_value($rule,$data->{$rule->{'attribute'}});
    }
    return 0;
}

=item _match_rule_against_value

Matches the rule against a value

=cut

sub _match_rule_against_value {
    my ($self, $rule, $value) = @_;

    if (defined($value)) {
        my $op = $rule->{'operator'};
        if ($op && exists $RULE_OPS{$op}) {
            return $RULE_OPS{$op}->($value, $rule->{'value'});
        }
    }
    return 0;
}


=item node_info_parser

Parse the node_info attribute and compare to the rule. If it matches then perform the action.

=cut

sub node_info_parser {
    my ($self, $rule, $switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid, $radius_request) = @_;
    return $self->_match_rule_against_hash($rule,$node_info);
}

=item radius_parser

Parse the RADIUS request attribute and compare to the rule. If it matches then perform the action.

=cut

sub radius_parser {
    my ($self, $rule, $switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid, $radius_request) = @_;
    return $self->_match_rule_against_hash($rule,$radius_request);
}

=item owner_parser

Parse the owner attribute and compare to the rule. If it matches then perform the action.

=cut

sub owner_parser {
    my ($self, $rule, $switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid, $radius_request) = @_;
    my $owner = person_view($node_info->{'pid'});
    return $self->_match_rule_against_hash($rule,$owner);
}

=item switch_parser

Parse the switch attribute and compare to the rule. If it matches then return true.

=cut

sub switch_parser {
    my ($self, $rule, $switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid, $radius_request) = @_;
    return $self->_match_rule_against_hash($rule,$switch);
}

=item ifindex_parser

Parse the ifindex value and compare to the rule. If it matches then return true.

=cut

sub ifindex_parser {
    my ($self, $rule, $switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid, $radius_request) = @_;
    return $self->_match_rule_against_value($rule,$ifIndex);
}

=item mac_parser

Parse the mac value and compare to the rule. If it matches then return.

=cut

sub mac_parser {
    my ($self, $rule, $switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid, $radius_request) = @_;
    return $self->_match_rule_against_value($rule,$mac);
}

=item connection_type_parser

Parse the connection_type value and compare to the rule. If it matches then return true.

=cut

sub connection_type_parser {
    my ($self, $rule, $switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid, $radius_request) = @_;
    return $self->_match_rule_against_value($rule,$connection_type_to_str{$connection_type});
}

=item username_parser

Parse the username value and compare to the rule. If it matches then return true.

=cut

sub username_parser {
    my ($self, $rule, $switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid, $radius_request) = @_;
    return $self->_match_rule_against_value($rule,$user_name);
}

=item ssid_parser

Parse the ssid valus and compare to the rule. If it matches then return true.

=cut

sub ssid_parser {
    my ($self, $rule, $switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid, $radius_request) = @_;
    return $self->_match_rule_against_value($rule,$ssid);
}

=item time_parser

Check the current time and compare to the period

=cut

sub time_parser {
    my ($self, $rule, $switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid, $radius_request) = @_;

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
